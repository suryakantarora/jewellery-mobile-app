import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/permissions.dart';
import '../../../../core/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../data/jewellery_repository.dart';
import '../providers/jewellery_providers.dart';
import '../widgets/item_card.dart';
import '../widgets/item_filter_sheet.dart';

/// Item search — the entry point to the digital passport.
class ItemSearchScreen extends ConsumerStatefulWidget {
  const ItemSearchScreen({super.key});

  @override
  ConsumerState<ItemSearchScreen> createState() => _ItemSearchScreenState();
}

class _ItemSearchScreenState extends ConsumerState<ItemSearchScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Prefetch at 80% so the next page is usually already there.
    if (position.pixels >= position.maxScrollExtent * 0.8) {
      ref.read(itemSearchProvider.notifier).loadMore();
    }
  }

  /// A query that looks like a tag or item code is resolved directly.
  ///
  /// This is what makes a barcode typed by hand behave exactly like a scan —
  /// one hit goes straight to the passport instead of a one-row result list.
  Future<void> _handleSubmit(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || !_looksLikeTag(trimmed)) return;

    try {
      final item = await ref.read(jewelleryRepositoryProvider).byTag(trimmed);
      if (!mounted) return;
      ref.read(recentItemsProvider.notifier).record(item);
      unawaited(context.push(AppRoutes.itemDetailPath(item.id)));
    } on Object {
      // Not a tag after all; the normal search results already cover it.
    }
  }

  static bool _looksLikeTag(String value) {
    // Item codes (JW-000001), RFID (RFID00000001), barcodes (8900000001).
    return RegExp(r'^[A-Za-z]{2,6}-?\d{4,}$').hasMatch(value) ||
        RegExp(r'^\d{8,}$').hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(itemSearchProvider);
    final filters = ref.watch(itemFiltersProvider);
    final reference = ref.watch(referenceDataReadyProvider);

    return AppScaffold(
      title: context.l10n.navInventory,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: AppSearchField(
              hint: 'Item code, barcode, RFID…',
              debounce: ref.watch(appConfigProvider).searchDebounce,
              onChanged: (value) {
                ref.read(itemFiltersProvider.notifier).setSearch(value);
                unawaited(_handleSubmit(value));
              },
              onScan: () => context.push(AppRoutes.scan),
            ),
          ),
          _FilterBar(filters: filters),
          const Divider(height: 1),
          Expanded(
            // Names come from the reference cache, so the list waits for it
            // rather than rendering rows that fill in afterwards.
            child: reference.when(
              loading: () => const _SearchSkeleton(),
              error: (error, _) => ErrorState(
                error: error,
                onRetry: () => ref.invalidate(referenceDataReadyProvider),
              ),
              data: (_) => AsyncValueView<ItemSearchState>(
                value: results,
                onRetry: () => ref.invalidate(itemSearchProvider),
                isEmpty: (state) => state.isEmpty,
                empty: EmptyState(
                  icon: Icons.search_off,
                  title: 'No items match',
                  message: filters.hasFilters || filters.search != null
                      ? 'Try removing a filter or searching for a different code.'
                      : 'This branch has no items yet.',
                  action: filters.hasFilters
                      ? TextButton(
                          onPressed: () => ref
                              .read(itemFiltersProvider.notifier)
                              .clearFilters(),
                          child: Text(context.l10n.actionClear),
                        )
                      : null,
                ),
                data: (state) => RefreshIndicator(
                  onRefresh: () =>
                      ref.read(itemSearchProvider.notifier).refresh(),
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                    itemCount: state.items.length + 1,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: AppSpacing.huge),
                    itemBuilder: (context, index) {
                      if (index == state.items.length) {
                        return _ListFooter(state: state);
                      }
                      final item = state.items[index];
                      return ItemCard(
                        item: item,
                        onTap: () {
                          ref.read(recentItemsProvider.notifier).record(item);
                          context.push(AppRoutes.itemDetailPath(item.id));
                        },
                      );
                    },
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

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filters});

  final ItemSearchFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reference = ref.watch(referenceDataProvider);
    final total = ref.watch(itemSearchProvider).valueOrNull?.total;

    final chips = <Widget>[];

    void addChip(String label, VoidCallback onRemove) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: InputChip(
            label: Text(label),
            onDeleted: onRemove,
            visualDensity: VisualDensity.compact,
          ),
        ),
      );
    }

    final controller = ref.read(itemFiltersProvider.notifier);

    if (filters.status != null) {
      addChip(filters.status!.label, () => controller.setStatus(null));
    }
    if (filters.metalId != null) {
      addChip(
        reference.metal(filters.metalId)?.name ?? 'Metal',
        () => controller.setMetal(null),
      );
    }
    if (filters.purityId != null) {
      addChip(
        reference.purity(filters.purityId)?.code ?? 'Purity',
        () => controller.setPurity(null),
      );
    }
    if (filters.locationId != null) {
      addChip(
        reference.location(filters.locationId)?.name ?? 'Location',
        () => controller.setLocation(null),
      );
    }
    if (filters.hasPriceRange) {
      final min = filters.minPrice;
      final max = filters.maxPrice;
      addChip(
        min != null && max != null
            ? '$min – $max'
            : min != null
            ? 'From $min'
            : 'Up to $max',
        () => controller.setPriceRange(),
      );
    }

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          AppSpacing.wGapMd,
          IconButton(
            icon: Badge(
              isLabelVisible: filters.activeCount > 0,
              label: Text('${filters.activeCount}'),
              child: const Icon(Icons.tune),
            ),
            tooltip: 'Filters',
            onPressed: () => showItemFilterSheet(context, ref),
          ),
          Expanded(
            child: chips.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      total == null
                          ? ''
                          : '$total item${total == 1 ? '' : 's'}',
                      style: context.text.labelMedium?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView(scrollDirection: Axis.horizontal, children: chips),
          ),
          if (filters.activeCount > 0)
            TextButton(
              onPressed: controller.clearFilters,
              child: Text(context.l10n.actionClear),
            ),
          AppSpacing.wGapSm,
        ],
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.state});

  final ItemSearchState state;

  @override
  Widget build(BuildContext context) {
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!state.hasMore && state.items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: Text(
            'All ${state.total} items',
            style: context.text.labelSmall?.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return const SizedBox(height: AppSpacing.xl);
  }
}

class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      height: 22,
      width: 22,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );
}

/// Kept so the permission gate reads explicitly at the call site.
const inventoryViewPermission = Permission.inventoryView;
