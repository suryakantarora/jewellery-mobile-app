import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/permissions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../jewellery/presentation/providers/jewellery_providers.dart';
import '../../../jewellery/presentation/widgets/item_card.dart';
import '../../../jewellery/presentation/widgets/item_filter_sheet.dart';
import '../providers/inventory_providers.dart';

/// The inventory list.
///
/// One screen with a grouping selector rather than the six near-identical
/// screens the specification lists, because they are all the same backend query
/// with a different filter.
class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouping = ref.watch(inventoryGroupingProvider);
    final groups = ref.watch(inventoryGroupsProvider);
    final reference = ref.watch(referenceDataReadyProvider);
    final filters = ref.watch(itemFiltersProvider);
    final selection = ref.watch(itemSelectionProvider);

    return AppScaffold(
      title: context.l10n.navInventory,
      actions: [
        IconButton(
          icon: Badge(
            isLabelVisible: filters.activeCount > 0,
            label: Text('${filters.activeCount}'),
            child: const Icon(Icons.tune),
          ),
          tooltip: 'Filters',
          onPressed: () => showItemFilterSheet(context, ref),
        ),
        IconButton(
          icon: const Icon(Icons.qr_code_scanner),
          tooltip: context.l10n.actionScan,
          onPressed: () => context.push(AppRoutes.scan),
        ),
      ],
      body: Column(
        children: [
          _GroupingBar(grouping: grouping),
          const Divider(height: 1),
          if (selection.isNotEmpty) _SelectionBar(selection: selection),
          Expanded(
            child: reference.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorState(
                error: error,
                onRetry: () => ref.invalidate(referenceDataReadyProvider),
              ),
              data: (_) => AsyncValueView<ItemSearchState>(
                value: ref.watch(itemSearchProvider),
                onRetry: () => ref.invalidate(itemSearchProvider),
                isEmpty: (state) => state.isEmpty,
                empty: EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No stock here',
                  message: filters.hasFilters
                      ? 'No items match the current filters.'
                      : 'This branch has no items yet.',
                ),
                data: (_) => RefreshIndicator(
                  onRefresh: () =>
                      ref.read(itemSearchProvider.notifier).refresh(),
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                    children: [
                      for (final group in groups)
                        _GroupSection(
                          group: group,
                          showHeader: grouping != InventoryGrouping.none,
                        ),
                      _LoadMoreFooter(),
                    ],
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

class _GroupingBar extends ConsumerWidget {
  const _GroupingBar({required this.grouping});

  final InventoryGrouping grouping;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          for (final option in InventoryGrouping.values)
            Padding(
              padding: const EdgeInsets.only(
                right: AppSpacing.sm,
                top: AppSpacing.sm,
                bottom: AppSpacing.sm,
              ),
              child: ChoiceChip(
                label: Text(option.label),
                selected: option == grouping,
                onSelected: (_) =>
                    ref.read(inventoryGroupingProvider.notifier).set(option),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupSection extends ConsumerWidget {
  const _GroupSection({required this.group, required this.showHeader});

  final InventoryGroup group;
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(itemSelectionProvider);
    final selecting = selection.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader)
          Container(
            width: double.infinity,
            color: context.scheme.surfaceContainerHigh,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(group.label, style: context.text.titleSmall),
                ),
                // The real total arrives separately; until it does, the loaded
                // count is shown as a partial rather than as the whole.
                ref
                    .watch(groupTotalProvider(group.key))
                    .when(
                      loading: () => Text(
                        '${group.items.length}',
                        style: context.text.labelMedium?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      ),
                      error: (_, __) => Text(
                        '${group.items.length}',
                        style: context.text.labelMedium?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      ),
                      data: (total) => Text(
                        total > group.items.length
                            ? '${group.items.length} of $total'
                            : '$total',
                        style: context.text.labelMedium?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        for (final item in group.items)
          ItemCard(
            item: item,
            selected: selecting ? selection.contains(item.id) : null,
            onTap: () {
              if (selecting) {
                ref.read(itemSelectionProvider.notifier).toggle(item.id);
              } else {
                ref.read(recentItemsProvider.notifier).record(item);
                context.push(AppRoutes.itemDetailPath(item.id));
              }
            },
            onLongPress: () =>
                ref.read(itemSelectionProvider.notifier).toggle(item.id),
          ),
      ],
    );
  }
}

/// Multi-select action bar. Bulk transfer lands in Phase 7; the selection
/// mechanism it needs is built here.
class _SelectionBar extends ConsumerWidget {
  const _SelectionBar({required this.selection});

  final Set<String> selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: context.scheme.primaryContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text('${selection.length} selected', style: context.text.labelLarge),
          const Spacer(),
          PermissionGuardedButton(
            permission: Permission.inventoryTransfer,
            label: 'Transfer',
            icon: Icons.swap_horiz,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bulk transfer arrives in Phase 7')),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => ref.read(itemSelectionProvider.notifier).clear(),
          ),
        ],
      ),
    );
  }
}

/// A small button that disables itself when the permission is missing.
class PermissionGuardedButton extends ConsumerWidget {
  const PermissionGuardedButton({
    super.key,
    required this.permission,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final Permission permission;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref.watch(permissionsProvider).has(permission);
    return Tooltip(
      message: allowed ? '' : context.l10n.stateNoPermission,
      child: TextButton.icon(
        onPressed: allowed ? onPressed : null,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _LoadMoreFooter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(itemSearchProvider).valueOrNull;
    if (state == null) return const SizedBox.shrink();

    if (state.hasMore) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AppButton(
          label: state.loadingMore ? 'Loading…' : 'Load more',
          variant: AppButtonVariant.outlined,
          busy: state.loadingMore,
          onPressed: () => ref.read(itemSearchProvider.notifier).loadMore(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Text(
          '${state.total} item${state.total == 1 ? '' : 's'}',
          style: context.text.labelSmall?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
