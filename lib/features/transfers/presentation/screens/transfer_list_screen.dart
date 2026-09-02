import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../jewellery/presentation/providers/jewellery_providers.dart';
import '../../domain/movement.dart';
import '../providers/transfer_providers.dart';

/// The transfer list.
///
/// Three tabs framed around the job someone came to do — a dispatcher thinks
/// "what am I sending", a receiver thinks "what is arriving" — rather than
/// around the status enum.
class TransferListScreen extends ConsumerWidget {
  const TransferListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(transferTabProvider);
    final transfers = ref.watch(transferListProvider);
    final status = ref.watch(transferStatusFilterProvider);

    return AppScaffold(
      title: context.l10n.navTransfers,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: SegmentedButton<TransferTab>(
              segments: [
                for (final option in TransferTab.values)
                  ButtonSegment(value: option, label: Text(option.label)),
              ],
              selected: {tab},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  ref.read(transferTabProvider.notifier).set(selection.first),
            ),
          ),
          if (tab == TransferTab.all) _StatusChips(selected: status),
          const Divider(height: 1),
          Expanded(
            // Names come from the reference cache; waiting for it avoids rows
            // that render "Origin → Destination" and fill in afterwards.
            child: ref
                .watch(referenceDataReadyProvider)
                .maybeWhen(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  orElse: () => AsyncValueView<List<Movement>>(
                    value: transfers,
                    onRetry: () => ref.invalidate(transferListProvider),
                    isEmpty: (list) => list.isEmpty,
                    empty: EmptyState(
                      icon: Icons.swap_horiz,
                      title: switch (tab) {
                        TransferTab.incoming => 'Nothing arriving',
                        TransferTab.outgoing => 'Nothing outgoing',
                        TransferTab.all => 'No transfers',
                      },
                      message: switch (tab) {
                        TransferTab.incoming =>
                          'Shipments dispatched to this branch will appear here.',
                        TransferTab.outgoing =>
                          'Transfers you raise from this branch will appear here.',
                        TransferTab.all => 'No stock movements recorded yet.',
                      },
                    ),
                    data: (list) => RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(transferListProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) =>
                            _TransferRow(movement: list[index]),
                      ),
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _StatusChips extends ConsumerWidget {
  const _StatusChips({required this.selected});

  final MovementStatus? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const shown = [
      MovementStatus.pendingApproval,
      MovementStatus.approved,
      MovementStatus.dispatched,
      MovementStatus.completed,
      MovementStatus.rejected,
    ];

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          for (final status in shown)
            Padding(
              padding: const EdgeInsets.only(
                right: AppSpacing.sm,
                top: 6,
                bottom: 6,
              ),
              child: ChoiceChip(
                label: Text(status.label),
                selected: selected == status,
                onSelected: (isSelected) => ref
                    .read(transferStatusFilterProvider.notifier)
                    .set(isSelected ? status : null),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransferRow extends ConsumerWidget {
  const _TransferRow({required this.movement});

  final Movement movement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reference = ref.watch(referenceDataProvider);
    final formatters = ref.watch(formattersProvider);

    final from = reference.location(movement.fromLocationId)?.name;
    final to = reference.location(movement.toLocationId)?.name;

    // The action a receiver came for, surfaced on the row itself.
    final isReceivable = movement.status == MovementStatus.dispatched;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              movement.referenceNumber,
              style: AppTypography.mono(context, size: 13),
            ),
          ),
          StatusBadge(
            label: movement.status.label,
            tone: movement.status.tone,
            dense: true,
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSpacing.gapXs,
          Text(
            [from ?? 'Origin', to ?? 'Destination'].join('  →  '),
            style: context.text.bodySmall,
          ),
          AppSpacing.gapXxs,
          Row(
            children: [
              Text(
                '${movement.itemCount} item'
                '${movement.itemCount == 1 ? '' : 's'}',
                style: context.text.labelSmall?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
              if (movement.createdAt != null) ...[
                Text(
                  '  ·  ',
                  style: context.text.labelSmall?.copyWith(
                    color: context.scheme.outline,
                  ),
                ),
                Text(
                  formatters.relative(movement.createdAt),
                  style: context.text.labelSmall?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (movement.awaitingSecondApproval) ...[
                AppSpacing.wGapSm,
                const StatusBadge(
                  label: '1 of 2 approvals',
                  tone: StatusTone.vault,
                  dense: true,
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: isReceivable
          ? FilledButton.tonal(
              onPressed: () =>
                  context.push(AppRoutes.transferReceivePath(movement.id)),
              child: const Text('Receive'),
            )
          : const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoutes.transferDetailPath(movement.id)),
    );
  }
}
