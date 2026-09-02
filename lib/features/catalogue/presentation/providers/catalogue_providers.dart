import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../data/catalogue_repository.dart';
import '../../domain/catalogue_item.dart';

final catalogueRepositoryProvider = Provider<CatalogueRepository>(
  (ref) => CatalogueRepository(ref.watch(apiClientProvider)),
);

/// What the customer is being shown right now.
class CatalogueFilters {
  const CatalogueFilters({this.categoryId, this.metalId, this.search});

  final String? categoryId;
  final String? metalId;
  final String? search;

  bool get isEmpty =>
      categoryId == null && metalId == null && (search ?? '').isEmpty;

  CatalogueFilters copyWith({
    Object? categoryId = _unset,
    Object? metalId = _unset,
    Object? search = _unset,
  }) {
    return CatalogueFilters(
      categoryId: categoryId == _unset
          ? this.categoryId
          : categoryId as String?,
      metalId: metalId == _unset ? this.metalId : metalId as String?,
      search: search == _unset ? this.search : search as String?,
    );
  }

  /// Distinguishes "clear this" from "leave it alone" — a plain null cannot.
  static const _unset = Object();

  @override
  bool operator ==(Object other) =>
      other is CatalogueFilters &&
      other.categoryId == categoryId &&
      other.metalId == metalId &&
      other.search == search;

  @override
  int get hashCode => Object.hash(categoryId, metalId, search);
}

class CatalogueFilterController extends Notifier<CatalogueFilters> {
  @override
  CatalogueFilters build() => const CatalogueFilters();

  void setCategory(String? id) => state = state.copyWith(categoryId: id);
  void setMetal(String? id) => state = state.copyWith(metalId: id);
  void setSearch(String? value) =>
      state = state.copyWith(search: (value ?? '').isEmpty ? null : value);
  void clear() => state = const CatalogueFilters();
}

final catalogueFiltersProvider =
    NotifierProvider<CatalogueFilterController, CatalogueFilters>(
      CatalogueFilterController.new,
    );

/// The current branch's sellable stock.
///
/// Scoped to the branch the user is standing in: a customer at the counter
/// cares about what can be handed to them today, not what sits in another
/// city's vault.
final catalogueProvider = FutureProvider.autoDispose<List<CatalogueItem>>((
  ref,
) async {
  final branch = ref.watch(currentBranchProvider);
  final filters = ref.watch(catalogueFiltersProvider);

  final page = await ref
      .watch(catalogueRepositoryProvider)
      .browse(
        branchId: branch?.id,
        categoryId: filters.categoryId,
        metalId: filters.metalId,
        search: filters.search,
        size: 60,
      );
  return page.content;
});
