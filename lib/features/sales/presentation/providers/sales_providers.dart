import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../shared/models/reference_data.dart';
import '../../data/sales_repository.dart';
import '../../domain/sales_models.dart';

final salesRepositoryProvider = Provider<SalesRepository>(
  (ref) => SalesRepository(
    ref.watch(apiClientProvider),
    offlineGuard: ref.watch(offlineGuardProvider),
  ),
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
/// One call to `GET /inventory/availability`; the backend limits the answer to
/// the caller's branches, so nothing outside their access can appear here.
final crossBranchAvailabilityProvider = FutureProvider.autoDispose
    .family<List<BranchAvailability>, String>((ref, productId) async {
      ref.watch(currentUserProvider);
      final result = await ref
          .watch(salesRepositoryProvider)
          .availability(productId);
      return result.branches;
    });

/// The signed-in user's own discount requests at the current branch, newest
/// first as the backend returns them.
final myDiscountRequestsProvider =
    FutureProvider.autoDispose<List<DiscountRequest>>((ref) async {
      final branch = ref.watch(currentBranchProvider);
      ref.watch(currentUserProvider);
      final page = await ref
          .watch(salesRepositoryProvider)
          .discountRequests(branchId: branch?.id, mine: true, size: 50);
      return page.content;
    });
