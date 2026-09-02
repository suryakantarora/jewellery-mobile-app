import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../data/jewellery_repository.dart';
import '../../data/reference_data_service.dart';
import '../../domain/jewellery_item.dart';

final jewelleryRepositoryProvider = Provider<JewelleryRepository>(
  (ref) => JewelleryRepository(ref.watch(apiClientProvider)),
);

/// The reference cache is rebuilt whenever the branch changes, so one branch's
/// locations can never label another branch's items.
final referenceDataProvider = Provider<ReferenceDataService>((ref) {
  final service = ReferenceDataService(ref.watch(apiClientProvider));
  ref.watch(currentBranchProvider);
  ref.onDispose(service.clear);
  return service;
});

/// Resolves once per branch; screens await this before rendering names.
///
/// Locations are loaded for **every** branch the user can act in, not just the
/// active one — a cross-branch transfer names a source location belonging to
/// another branch, and without it the row cannot say where stock came from.
final referenceDataReadyProvider = FutureProvider<ReferenceDataService>((
  ref,
) async {
  final service = ref.watch(referenceDataProvider);
  final user = ref.watch(currentUserProvider);
  final branch = ref.watch(currentBranchProvider);

  final branchIds = <String>{
    if (branch != null) branch.id,
    ...?user?.branchIds,
  }.toList(growable: false);

  await service.prefetch(branchIds: branchIds);
  return service;
});

/// The active filter set, scoped to the current branch.
class ItemFiltersController extends Notifier<ItemSearchFilters> {
  @override
  ItemSearchFilters build() {
    final branch = ref.watch(currentBranchProvider);
    return ItemSearchFilters(branchId: branch?.id);
  }

  void setSearch(String? value) => state = state.copyWith(
    search: value?.trim().isEmpty ?? true ? null : value,
  );

  void setStatus(ItemStatus? value) => state = state.copyWith(status: value);
  void setLocation(String? value) => state = state.copyWith(locationId: value);
  void setMetal(String? value) =>
      // Purity belongs to a metal, so changing the metal invalidates it.
      state = state.copyWith(metalId: value, purityId: null);
  void setPurity(String? value) => state = state.copyWith(purityId: value);
  void setProduct(String? value) => state = state.copyWith(productId: value);

  void clearFilters() => state = state.cleared();

  void replace(ItemSearchFilters filters) => state = filters;
}

final itemFiltersProvider =
    NotifierProvider<ItemFiltersController, ItemSearchFilters>(
      ItemFiltersController.new,
    );

/// A page of results plus the paging state around it.
class ItemSearchState {
  const ItemSearchState({
    this.items = const [],
    this.total = 0,
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<JewelleryItem> items;
  final int total;
  final int page;
  final bool hasMore;
  final bool loadingMore;

  bool get isEmpty => items.isEmpty;

  ItemSearchState copyWith({
    List<JewelleryItem>? items,
    int? total,
    int? page,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return ItemSearchState(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

/// Paginated item search.
///
/// Rebuilds whenever the filters change — which includes a branch switch, since
/// the filter set carries the branch id.
class ItemSearchController extends AsyncNotifier<ItemSearchState> {
  @override
  Future<ItemSearchState> build() async {
    // Every dependency is read *before* the first await. `ref.watch` after an
    // await re-registers the dependency on each rebuild, which produced an
    // endless rebuild loop here: watching the reference service after awaiting
    // the search recreated it, clearing its cache, which triggered another
    // rebuild, which re-fetched every product again.
    final filters = ref.watch(itemFiltersProvider);
    final pageSize = ref.watch(appConfigProvider).pageSize;
    final repository = ref.watch(jewelleryRepositoryProvider);
    final reference = ref.watch(referenceDataProvider);

    // No CancelToken here on purpose. AsyncNotifier already discards the
    // result of a superseded build, and cancelling raced with that: a rebuild
    // could cancel the request belonging to the build that was about to become
    // current, leaving the provider stuck. Debouncing already keeps the request
    // volume down, so cancellation bought nothing and cost correctness.
    final page = await repository.search(filters, page: 0, size: pageSize);

    // Warm product names so the first frame shows them, rather than the list
    // filling in row by row.
    await reference.warmFor(page.content.map((item) => item.productId));

    return ItemSearchState(
      items: page.content,
      total: page.totalElements,
      page: page.page,
      hasMore: page.hasMore,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(current.copyWith(loadingMore: true));

    try {
      final filters = ref.read(itemFiltersProvider);
      final pageSize = ref.read(appConfigProvider).pageSize;
      final next = await ref
          .read(jewelleryRepositoryProvider)
          .search(filters, page: current.page + 1, size: pageSize);

      await ref
          .read(referenceDataProvider)
          .warmFor(next.content.map((item) => item.productId));

      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...next.content],
          total: next.totalElements,
          page: next.page,
          hasMore: next.hasMore,
          loadingMore: false,
        ),
      );
    } on AppException {
      // Keep what is already on screen; the next scroll can retry.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final itemSearchProvider =
    AsyncNotifierProvider<ItemSearchController, ItemSearchState>(
      ItemSearchController.new,
    );

/// A single item, for the passport screen.
final itemPassportProvider = FutureProvider.autoDispose
    .family<ItemPassport, String>((ref, id) async {
      final passport = await ref
          .watch(jewelleryRepositoryProvider)
          .passport(id);

      // The passport screen names the product and design, so warm them here rather
      // than letting the screen flash placeholder text.
      final reference = ref.read(referenceDataProvider);
      await Future.wait([
        reference.product(passport.item.productId),
        reference.design(passport.item.designId),
      ]);

      return passport;
    });

/// Resolves a scanned tag. Kept separate from search so a scan cannot be
/// confused with a query.
final itemByTagProvider = FutureProvider.autoDispose
    .family<JewelleryItem, String>(
      (ref, tag) => ref.watch(jewelleryRepositoryProvider).byTag(tag),
    );

/// Recently viewed items, newest first. Seeds the Phase 17 read-only cache.
///
/// Held in memory only, and tied to the signed-in user. The provider itself
/// outlives a sign-out, so without watching the user the next person to use the
/// device saw their colleague's browsing history on the dashboard — showroom
/// devices are shared between shifts, so that is the normal case, not an edge
/// one.
class RecentItemsController extends Notifier<List<JewelleryItem>> {
  static const _limit = 20;

  @override
  List<JewelleryItem> build() {
    // Watched for its identity, not its contents: a change of user rebuilds
    // this notifier and the list starts empty again.
    ref.watch(currentUserProvider);
    return const [];
  }

  void record(JewelleryItem item) {
    final without = state.where((existing) => existing.id != item.id);
    state = [item, ...without].take(_limit).toList(growable: false);
  }

  void clear() => state = const [];
}

final recentItemsProvider =
    NotifierProvider<RecentItemsController, List<JewelleryItem>>(
      RecentItemsController.new,
    );
