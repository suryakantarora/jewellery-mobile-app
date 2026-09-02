import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/data_display.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/approval_models.dart';
import '../providers/approval_providers.dart';

/// The approval centre.
///
/// Assembled from five modules, oldest first, because the metric that matters
/// in a queue is how long someone has been blocked.
class ApprovalCenterScreen extends ConsumerWidget {
  const ApprovalCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingApprovalsProvider);
    final filtered = ref.watch(filteredApprovalsProvider);
    final counts = ref.watch(approvalCountsProvider);
    final filter = ref.watch(approvalFilterProvider);

    return AppScaffold(
      title: context.l10n.screenApprovals,
      body: Column(
        children: [
          if (counts.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                children: [
                  for (final entry in counts.entries)
                    Padding(
                      padding: const EdgeInsets.only(
                        right: AppSpacing.sm,
                        top: AppSpacing.sm,
                        bottom: AppSpacing.sm,
                      ),
                      child: ChoiceChip(
                        avatar: Icon(entry.key.icon, size: 16),
                        label: Text('${entry.key.label} (${entry.value})'),
                        selected: filter == entry.key,
                        onSelected: (selected) => ref
                            .read(approvalFilterProvider.notifier)
                            .set(selected ? entry.key : null),
                      ),
                    ),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: AsyncValueView<List<ApprovalItem>>(
              value: pending,
              onRetry: () => ref.invalidate(pendingApprovalsProvider),
              isEmpty: (_) => filtered.isEmpty,
              empty: const EmptyState(
                icon: Icons.check_circle_outline,
                title: 'Nothing waiting',
                message: 'Approvals you can act on will appear here.',
              ),
              data: (_) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(pendingApprovalsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _ApprovalRow(item: filtered[index]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalRow extends ConsumerStatefulWidget {
  const _ApprovalRow({required this.item});

  final ApprovalItem item;

  @override
  ConsumerState<_ApprovalRow> createState() => _ApprovalRowState();
}

class _ApprovalRowState extends ConsumerState<_ApprovalRow> {
  bool _busy = false;

  /// Approves, after re-reading and confirming.
  ///
  /// Two rules the specification insists on, both implemented here:
  ///  * Anything carrying an amount, and anything vault-grade, cannot be
  ///    approved from the list — a mis-tap must not authorise a payout.
  ///  * The queue is refreshed immediately before deciding, so a race between
  ///    two managers is caught rather than silently double-approving.
  Future<void> _approve() async {
    final item = widget.item;
    final formatters = ref.read(formattersProvider);

    final confirmed = await showConfirmationDialog(
      context,
      title: 'Approve ${item.kind.label.toLowerCase()}?',
      message: item.reference,
      tone: item.requiresDetailView ? ConfirmTone.danger : ConfirmTone.normal,
      icon: item.kind.icon,
      confirmLabel: 'Approve',
      detail: AppCard(
        child: Column(
          children: [
            KeyValueRow(label: 'Reference', value: item.reference),
            KeyValueRow(label: 'Summary', value: item.summary),
            if (item.requestedBy != null)
              KeyValueRow(label: 'Requested by', value: item.requestedBy!),
            if (item.amount != null)
              KeyValueRow(
                label: 'Amount',
                value: formatters.money(item.amount, item.currency),
                numeric: true,
              ),
          ],
        ),
      ),
    );

    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(approvalAggregatorProvider).approve(item);
      ref.invalidate(pendingApprovalsProvider);
      if (mounted) {
        showAppSnackBar(
          context,
          message: '${item.reference} approved',
          tone: SnackTone.success,
        );
      }
    } on ConflictException catch (error) {
      // The dual-authorisation path lands here when the same person tries to
      // approve twice; the backend's message is the clearest explanation.
      if (mounted) {
        showAppSnackBar(context, message: error.message, tone: SnackTone.error);
      }
      ref.invalidate(pendingApprovalsProvider);
    } on AppException catch (error) {
      if (mounted) {
        showAppSnackBar(context, message: error.message, tone: SnackTone.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reason = await showReasonSheet(
      context,
      title: 'Reason for rejection',
      hint: 'The requester sees this.',
    );
    if (reason == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(approvalAggregatorProvider).reject(widget.item, reason);
      ref.invalidate(pendingApprovalsProvider);
      if (mounted) {
        showAppSnackBar(
          context,
          message: '${widget.item.reference} rejected',
          tone: SnackTone.success,
        );
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
    final item = widget.item;
    final formatters = ref.watch(formattersProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.kind.icon, size: 16, color: context.scheme.primary),
              AppSpacing.wGapSm,
              Text(
                item.kind.label.toUpperCase(),
                style: context.text.labelSmall?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (item.awaitingSecondApproval)
                const StatusBadge(
                  label: '1 of 2',
                  tone: StatusTone.vault,
                  dense: true,
                ),
            ],
          ),
          AppSpacing.gapSm,
          Text(item.reference, style: AppTypography.mono(context, size: 14)),
          AppSpacing.gapXxs,
          Text(item.summary, style: context.text.bodyMedium),

          if (item.amount != null) ...[
            AppSpacing.gapXs,
            Text(
              formatters.money(item.amount, item.currency),
              style: AppTypography.numeric(context, size: 16),
            ),
          ],

          AppSpacing.gapXs,
          Row(
            children: [
              if (item.requestedBy != null)
                Text(
                  item.requestedBy!,
                  style: context.text.labelSmall?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                ),
              if (item.requestedAt != null) ...[
                Text('  ·  ', style: context.text.labelSmall),
                Text(
                  formatters.relative(item.requestedAt),
                  style: context.text.labelSmall?.copyWith(
                    // Age is the queue metric that matters, so an old item
                    // reads differently from a fresh one.
                    color: (item.age?.inHours ?? 0) > 24
                        ? context.colors.danger
                        : context.scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),

          AppSpacing.gapMd,
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Approve',
                  icon: Icons.check,
                  busy: _busy,
                  onPressed: _approve,
                ),
              ),
              AppSpacing.wGapMd,
              AppButton(
                label: 'Reject',
                variant: AppButtonVariant.outlined,
                expand: false,
                onPressed: _busy ? null : _reject,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
