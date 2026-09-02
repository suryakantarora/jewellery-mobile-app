import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../shared/models/reference_data.dart';
import '../../../jewellery/data/jewellery_repository.dart';
import '../../../jewellery/domain/jewellery_item.dart';
import '../../../jewellery/presentation/providers/jewellery_providers.dart';
import '../../data/sales_repository.dart';
import '../../domain/sales_models.dart';

final salesRepositoryProvider = Provider<SalesRepository>(
  (ref) => SalesRepository(ref.watch(apiClientProvider)),
);

/// The price of one item, computed server-side.
final itemPriceProvider = FutureProvider.autoDispose
    .family<PriceBreakdown, String>((ref, itemId) {
      return ref
          .watch(salesRepositoryProvider)
          .calculatePrice(
            jewelleryItemId: itemId,
            branchId: ref.watch(currentBranchProvider)?.id,
          );
    });

/// The rate behind a price, so its age can be shown.
final currentRateProvider = FutureProvider.autoDispose
    .family<MetalRate?, ({String metalId, String purityId})>((ref, key) {
      return ref
          .watch(salesRepositoryProvider)
          .currentRate(metalId: key.metalId, purityId: key.purityId);
    });

/// Whether a rate is old enough to warn about.
///
/// Quoting yesterday's gold rate to a customer is a real commercial loss, so
/// staleness is surfaced rather than left for someone to notice.
bool isRateStale(MetalRate? rate) {
  final published = rate?.publishedAt;
  if (published == null) return false;
  return DateTime.now().difference(published) >
      AppConstants.metalRateStaleAfter;
}

/// Stock of a product across the branches this user may see.
///
/// There is no aggregate availability endpoint, so this issues one count per
/// accessible branch in parallel. Branches outside the user's access are never
/// queried — the specification is explicit that employees must not see them,
/// and the backend would refuse anyway.
final crossBranchAvailabilityProvider = FutureProvider.autoDispose
    .family<List<BranchAvailability>, String>((ref, productId) async {
      final user = ref.watch(currentUserProvider);
      final repository = ref.watch(jewelleryRepositoryProvider);
      final auth = ref.watch(authRepositoryProvider);

      if (user == null) return const [];

      final branches = await auth.branchesFor(user);

      final counts = await Future.wait(
        branches.map((branch) async {
          try {
            final total = await repository.count(
              ItemSearchFilters(
                branchId: branch.id,
                productId: productId,
                status: ItemStatus.available,
              ),
            );
            return BranchAvailability(
              branchId: branch.id,
              branchName: branch.name,
              available: total,
            );
          } on Object {
            // A branch that refuses is simply not shown, rather than reported as
            // zero — "no stock" and "no access" are different claims.
            return null;
          }
        }),
      );

      return counts.whereType<BranchAvailability>().toList(growable: false);
    });
