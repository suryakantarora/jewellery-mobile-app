import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/permissions.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../../../shared/widgets/app_timeline.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/data_display.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../jewellery/presentation/providers/jewellery_providers.dart';
import '../../domain/movement.dart';
import '../providers/transfer_providers.dart';
import '../../../jewellery/presentation/widgets/reference_gate.dart';

/// One transfer, with the actions its current status allows.
class TransferDetailScreen extends ConsumerWidget {
  const TransferDetailScreen({super.key, required this.movementId});

  final String movementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movement = ref.watch(movementDetailProvider(movementId));

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer')),
      body: ReferenceGate(
        child: AsyncValueView<Movement>(
          value: movement,
          onRetry: () => ref.invalidate(movementDetailProvider(movementId)),
          loading: const Center(child: CircularProgressIndicator()),
          data: (data) => _Body(movement: data),
        ),
      ),
      bottomNavigationBar: movement.maybeWhen(
        data: (data) => _ActionBar(movement: data),
        orElse: () => null,
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.movement});

  final Movement movement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reference = ref.watch(referenceDataProvider);
    final formatters = ref.watch(formattersProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.huge,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                movement.referenceNumber,
                style: AppTypography.mono(context, size: 16),
              ),
            ),
            StatusBadge(
              label: movement.status.label,
              tone: movement.status.tone,
            ),
          ],
        ),
        AppSpacing.gapLg,

        AppCard(
          child: Column(
            children: [
              KeyValueRow(label: 'Type', value: movement.movementType.label),
              KeyValueRow(
                label: 'From',
                value: reference.location(movement.fromLocationId)?.name ?? '—',
              ),
              KeyValueRow(
                label: 'To',
                value: reference.location(movement.toLocationId)?.name ?? '—',
              ),
              KeyValueRow(
                label: 'Items',
                value: '${movement.itemCount}',
                numeric: true,
              ),
              KeyValueRow(
                label: 'Total weight',
                value: formatters.weight(movement.totalWeight),
                numeric: true,
              ),
              if (movement.notes != null)
                KeyValueRow(label: 'Notes', value: movement.notes!),
            ],
          ),
        ),
        AppSpacing.gapLg,

        if (movement.rejectionReason != null) ...[
          AppCard(
            tone: context.colors.dangerContainer.withValues(alpha: 0.4),
            borderColor: context.colors.danger.withValues(alpha: 0.4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.block, size: 18, color: context.colors.danger),
                AppSpacing.wGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rejected', style: context.text.titleSmall),
                      AppSpacing.gapXxs,
                      Text(
                        movement.rejectionReason!,
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,
        ],

        SectionCard(
          title: 'Items',
          icon: Icons.inventory_2_outlined,
          subtitle: '${movement.itemCount} lines',
          child: Column(
            children: [
              for (final line in movement.lines)
                _LineRow(line: line, formatters: formatters),
            ],
          ),
        ),
        AppSpacing.gapLg,

        // The audit chain the specification requires for high-value movements.
        // The backend exposes both approval signatures, so both are shown.
        SectionCard(
          title: 'History',
          icon: Icons.timeline,
          child: AppTimeline(
            formatTimestamp: formatters.dateTime,
            events: [
              if (movement.completedAt != null)
                TimelineEvent(
                  title: 'Received',
                  actor: movement.receivedBy,
                  timestamp: movement.completedAt,
                  tone: StatusTone.success,
                  icon: Icons.check,
                ),
              if (movement.dispatchedAt != null)
                TimelineEvent(
                  title: 'Dispatched',
                  actor: movement.dispatchedBy,
                  timestamp: movement.dispatchedAt,
                  tone: StatusTone.warning,
                ),
              if (movement.secondApprovedAt != null)
                TimelineEvent(
                  title: 'Second approval',
                  subtitle: 'Dual authorisation',
                  actor: movement.secondApprovedBy,
                  timestamp: movement.secondApprovedAt,
                  tone: StatusTone.vault,
                ),
              if (movement.approvedAt != null)
                TimelineEvent(
                  title: 'Approved',
                  actor: movement.approvedBy,
                  timestamp: movement.approvedAt,
                  tone: StatusTone.success,
                ),
              TimelineEvent(
                title: 'Raised',
                actor: movement.createdBy,
                timestamp: movement.createdAt,
                tone: StatusTone.info,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.formatters});

  final MovementLine line;
  final dynamic formatters;

  @override
  Widget build(BuildContext context) {
    final delta = line.weightDelta;
    // A weight change between dispatch and receipt is the one thing a customer
    // or an auditor will check, so it is called out rather than buried.
    final hasDelta = delta != null && delta.abs() > 0.0005;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            line.received ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: line.received
                ? context.colors.success
                : context.scheme.outline,
          ),
          AppSpacing.wGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.itemCode, style: AppTypography.mono(context)),
                if (line.discrepancyNote != null)
                  Text(
                    line.discrepancyNote!,
                    style: context.text.labelSmall?.copyWith(
                      color: context.colors.warning,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatters.weight(line.dispatchedWeight) as String,
                style: AppTypography.numeric(context, size: 13),
              ),
              if (hasDelta)
                Text(
                  '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(3)} g',
                  style: context.text.labelSmall?.copyWith(
                    color: context.colors.danger,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Actions available for the current status, intersected with permissions.
class _ActionBar extends ConsumerStatefulWidget {
  const _ActionBar({required this.movement});

  final Movement movement;

  @override
  ConsumerState<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends ConsumerState<_ActionBar> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(movementDetailProvider(widget.movement.id));
      ref.invalidate(transferListProvider);
      if (mounted) {
        showAppSnackBar(context, message: success, tone: SnackTone.success);
      }
    } on AppException catch (error) {
      if (mounted) {
        showAppSnackBar(context, message: error.message, tone: SnackTone.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final movement = widget.movement;
    final permissions = ref.watch(permissionsProvider);
    final repository = ref.read(movementRepositoryProvider);

    final canApprove = permissions.has(Permission.inventoryTransferApprove);
    final canTransfer = permissions.has(Permission.inventoryTransfer);

    final actions = <Widget>[];

    switch (movement.status) {
      case MovementStatus.pendingApproval:
        if (canApprove) {
          actions.addAll([
            Expanded(
              child: AppButton(
                label: 'Approve',
                icon: Icons.check,
                busy: _busy,
                onPressed: () async {
                  // A consequential decision is never one tap: the dialog
                  // restates what is being approved.
                  final confirmed = await showConfirmationDialog(
                    context,
                    title: 'Approve transfer?',
                    message:
                        '${movement.referenceNumber} · '
                        '${movement.itemCount} items',
                    icon: Icons.check_circle_outline,
                  );
                  if (confirmed) {
                    await _run(
                      () => repository.approve(movement.id),
                      'Transfer approved',
                    );
                  }
                },
              ),
            ),
            AppSpacing.wGapMd,
            AppButton(
              label: 'Reject',
              variant: AppButtonVariant.danger,
              expand: false,
              onPressed: () async {
                final reason = await showReasonSheet(
                  context,
                  title: 'Reason for rejection',
                  hint: 'Why is this transfer being rejected?',
                );
                if (reason != null) {
                  await _run(
                    () => repository.reject(movement.id, reason),
                    'Transfer rejected',
                  );
                }
              },
            ),
          ]);
        }
      case MovementStatus.approved:
        if (canTransfer) {
          actions.add(
            Expanded(
              child: AppButton(
                label: 'Dispatch',
                icon: Icons.local_shipping_outlined,
                busy: _busy,
                onPressed: () => _run(
                  () => repository.dispatch(movement.id),
                  'Dispatched — items are now in transit',
                ),
              ),
            ),
          );
        }
      case MovementStatus.dispatched:
        if (canTransfer) {
          actions.add(
            Expanded(
              child: AppButton(
                label: 'Receive',
                icon: Icons.qr_code_scanner,
                onPressed: () =>
                    context.push(AppRoutes.transferReceivePath(movement.id)),
              ),
            ),
          );
        }
      case MovementStatus.draft:
      case MovementStatus.rejected:
      case MovementStatus.completed:
      case MovementStatus.cancelled:
      case MovementStatus.unknown:
        break;
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainer,
        border: Border(top: BorderSide(color: context.scheme.outlineVariant)),
      ),
      child: SafeArea(top: false, child: Row(children: actions)),
    );
  }
}
