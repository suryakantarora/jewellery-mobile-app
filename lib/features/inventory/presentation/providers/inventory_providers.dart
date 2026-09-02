import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../jewellery/domain/jewellery_item.dart';
import '../../../jewellery/presentation/providers/jewellery_providers.dart';

/// How the inventory list is grouped.
///
/// The specification lists six separate screens — by branch, location,
/// category, metal, and so on. They are all the same backend query with a
/// different filter, so they are one screen with a grouping selector rather
/// than six near-identical code paths.
enum InventoryGrouping {
  none('All items'),
  location('Location'),
  metal('Metal'),
  status('Status');

  const InventoryGrouping(this.label);
  final String label;
}

final inventoryGroupingProvider =
    NotifierProvider<InventoryGroupingController, InventoryGrouping>(
      InventoryGroupingController.new,
    );

class InventoryGroupingController extends Notifier<InventoryGrouping> {
  @override
  InventoryGrouping build() => InventoryGrouping.none;

  void set(InventoryGrouping value) => state = value;
}

/// A group header with an honest total.
class InventoryGroup {
  const InventoryGroup({
    required this.key,
    required this.label,
    required this.items,
    required this.total,
  });

  final String key;
  final String label;
  final List<JewelleryItem> items;

  /// The count as currently known. For an ungrouped list this is the server
  /// total; for a group it starts as the loaded count and is replaced by
  /// [groupTotalProvider] once the real figure arrives.
  final int total;
}

/// Groups the loaded page.
///
/// Synchronous on purpose. An earlier version awaited `itemSearchProvider.future`
/// and then fetched every group total before emitting, which meant the list
/// showed skeletons until the slowest count returned — and any hiccup in that
/// chain left the screen loading forever. Grouping is now pure, and each
/// group's true total arrives separately via [groupTotalProvider].
final inventoryGroupsProvider = Provider.autoDispose<List<InventoryGroup>>((
  ref,
) {
  final grouping = ref.watch(inventoryGroupingProvider);
  final search = ref.watch(itemSearchProvider).valueOrNull;
  final reference = ref.watch(referenceDataProvider);

  if (search == null) return const [];

  if (grouping == InventoryGrouping.none) {
    return [
      InventoryGroup(
        key: 'all',
        label: 'All items',
        items: search.items,
        total: search.total,
      ),
    ];
  }

  final buckets = <String, List<JewelleryItem>>{};
  final labels = <String, String>{};

  for (final item in search.items) {
    final (key, label) = switch (grouping) {
      InventoryGrouping.location => (
        item.currentLocationId ?? 'none',
        reference.location(item.currentLocationId)?.name ?? 'Unassigned',
      ),
      InventoryGrouping.metal => (
        item.metalId ?? 'none',
        reference.metal(item.metalId)?.name ?? 'Unspecified',
      ),
      InventoryGrouping.status => (item.status.code, item.status.label),
      InventoryGrouping.none => ('all', 'All items'),
    };

    buckets.putIfAbsent(key, () => []).add(item);
    labels[key] = label;
  }

  final groups = [
    for (final entry in buckets.entries)
      InventoryGroup(
        key: entry.key,
        label: labels[entry.key] ?? entry.key,
        items: entry.value,
        // Until the real count arrives, the loaded count stands in — and the
        // header labels it as such rather than presenting it as the total.
        total: entry.value.length,
      ),
  ];

  groups.sort((a, b) => b.items.length.compareTo(a.items.length));
  return groups;
});

/// The true, server-side total for one group.
///
/// Fetched per group so a header can show an honest number without the list
/// waiting on it.
final groupTotalProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  key,
) async {
  final grouping = ref.watch(inventoryGroupingProvider);
  final filters = ref.watch(itemFiltersProvider);

  if (grouping == InventoryGrouping.none || key == 'none') {
    return ref.watch(itemSearchProvider).valueOrNull?.total ?? 0;
  }

  final scoped = switch (grouping) {
    InventoryGrouping.location => filters.copyWith(locationId: key),
    InventoryGrouping.metal => filters.copyWith(metalId: key),
    InventoryGrouping.status => filters.copyWith(
      status: ItemStatus.fromCode(key),
    ),
    InventoryGrouping.none => filters,
  };

  return ref.watch(jewelleryRepositoryProvider).count(scoped);
});

/// Multi-select, feeding bulk transfer in Phase 7.
class ItemSelectionController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String id) {
    state = state.contains(id)
        ? (Set.of(state)..remove(id))
        : (Set.of(state)..add(id));
  }

  void clear() => state = const {};

  bool get isActive => state.isNotEmpty;
}

final itemSelectionProvider =
    NotifierProvider<ItemSelectionController, Set<String>>(
      ItemSelectionController.new,
    );

/// Inventory valuation, gated behind REPORT_VIEW at the call site.
final inventoryValuationProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
      final branch = ref.watch(currentBranchIdForReportsProvider);
      if (branch == null) return null;

      try {
        return await ref
            .watch(apiClientProvider)
            .get<Map<String, dynamic>?>(
              '/reports/inventory-valuation',
              query: {'branchId': branch},
              parse: (data) => data is Map<String, dynamic> ? data : null,
            );
      } on Object {
        // Valuation is supplementary; a permission failure must not blank the
        // inventory screen itself.
        return null;
      }
    });

final currentBranchIdForReportsProvider = Provider<String?>((ref) {
  return ref.watch(itemFiltersProvider).branchId;
});
