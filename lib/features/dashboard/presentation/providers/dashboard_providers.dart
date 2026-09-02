import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/permissions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../../jewellery/data/jewellery_repository.dart';
import '../../../jewellery/domain/jewellery_item.dart';
import '../../../jewellery/presentation/providers/jewellery_providers.dart';

/// Dashboard figures.
///
/// There is **no dashboard endpoint on the backend**, so each tile is composed
/// from a module query. Two consequences shape this file:
///
/// * Every tile is its own provider, so one 403 or timeout blanks one tile
///   rather than the whole screen. A manager missing a finance permission
///   should still see pending transfers.
/// * Counts use `size=1` and read `totalElements`, so a tile costs one small
///   response rather than a page of rows nobody renders.
///
/// A single `GET /api/v1/dashboard/summary` would replace all of this with one
/// round trip, and would let the backend decide which figures a user may see
/// rather than the client. Recorded in BACKEND-GAPS as the top item.

/// A figure, so a tile can render a value without inspecting exceptions.
class DashboardMetric {
  const DashboardMetric({this.value, this.secondary, this.currency});

  final num? value;
  final num? secondary;
  final String? currency;

  bool get hasValue => value != null;
}

/// Today's sales for the active branch.
final todaySalesProvider = FutureProvider.autoDispose<DashboardMetric>((
  ref,
) async {
  final branchId = _requireBranch(ref);
  final today = _todayIso();

  final data = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>?>(
        ApiEndpoints.salesReport,
        query: {'from': today, 'to': today, 'branchId': branchId},
        parse: (raw) => raw is Map<String, dynamic> ? raw : null,
      );

  return DashboardMetric(
    value:
        (data?['totalNet'] ?? data?['totalGross'] ?? data?['netAmount'])
            as num?,
    secondary: (data?['saleCount'] ?? data?['count']) as num?,
    currency: data?['currency'] as String?,
  );
});

/// Total items in the active branch.
final inventoryCountProvider = FutureProvider.autoDispose<DashboardMetric>((
  ref,
) async {
  final branchId = _requireBranch(ref);
  final count = await ref
      .watch(jewelleryRepositoryProvider)
      .count(ItemSearchFilters(branchId: branchId));
  return DashboardMetric(value: count);
});

/// Items available to sell right now — more actionable than a raw total.
final availableCountProvider = FutureProvider.autoDispose<DashboardMetric>((
  ref,
) async {
  final branchId = _requireBranch(ref);
  final count = await ref
      .watch(jewelleryRepositoryProvider)
      .count(
        ItemSearchFilters(branchId: branchId, status: ItemStatus.available),
      );
  return DashboardMetric(value: count);
});

/// Inventory value. Permission-gated at the call site, so a refusal means the
/// tile is absent rather than an error banner.
final inventoryValueProvider = FutureProvider.autoDispose<DashboardMetric>((
  ref,
) async {
  final branchId = _requireBranch(ref);

  final data = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>?>(
        ApiEndpoints.inventoryValuation,
        query: {'branchId': branchId},
        parse: (raw) => raw is Map<String, dynamic> ? raw : null,
      );

  return DashboardMetric(
    value: (data?['totalValue'] ?? data?['totalCost']) as num?,
    secondary: (data?['itemCount'] ?? data?['totalItems']) as num?,
    currency: data?['currency'] as String?,
  );
});

/// Transfers waiting for approval.
final pendingTransfersProvider = FutureProvider.autoDispose<DashboardMetric>((
  ref,
) async {
  _requireBranch(ref);
  final count = await _countOf(
    ref.watch(apiClientProvider),
    ApiEndpoints.transfers,
    {'status': 'PENDING_APPROVAL'},
  );
  return DashboardMetric(value: count);
});

/// Shipments dispatched and not yet received.
final incomingTransfersProvider = FutureProvider.autoDispose<DashboardMetric>((
  ref,
) async {
  _requireBranch(ref);
  final count = await _countOf(
    ref.watch(apiClientProvider),
    ApiEndpoints.transfers,
    {'status': 'DISPATCHED'},
  );
  return DashboardMetric(value: count);
});

/// Repairs ready for collection.
///
/// The backend filters repairs by a single status, so a true "open" figure
/// would need one call per status. This uses the one staff actually act on
/// rather than firing six requests to build a number nobody uses directly.
final repairsReadyProvider = FutureProvider.autoDispose<DashboardMetric>((
  ref,
) async {
  final branchId = _requireBranch(ref);
  final count = await _countOf(
    ref.watch(apiClientProvider),
    ApiEndpoints.repairs,
    {'status': 'READY', 'branchId': branchId},
  );
  return DashboardMetric(value: count);
});

/// The tiles, each declaring the permission it needs.
///
/// The specification's four example roles fall out of these declarations on
/// their own — no role string appears anywhere in the app.
enum DashboardTile {
  todaySales([Permission.saleView]),
  availableCount([Permission.inventoryView]),
  inventoryCount([Permission.inventoryView]),
  inventoryValue([Permission.reportView, Permission.financeView]),
  pendingTransfers([
    Permission.inventoryTransfer,
    Permission.inventoryTransferApprove,
  ]),
  incomingTransfers([Permission.inventoryTransfer]),
  repairsReady([Permission.repairView]);

  const DashboardTile(this.requiresAny);
  final List<Permission> requiresAny;

  bool isVisibleTo(PermissionSet permissions) =>
      requiresAny.isEmpty || permissions.hasAny(requiresAny);
}

String _todayIso() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

String _requireBranch(Ref ref) {
  final branch = ref.watch(currentBranchProvider);
  if (branch == null) {
    throw StateError('Dashboard figures require a branch');
  }
  return branch.id;
}

/// Reads `totalElements` from a paged endpoint without fetching rows.
Future<int> _countOf(
  ApiClient client,
  String path,
  Map<String, dynamic> query,
) async {
  final page = await client.getPage<Object>(
    path,
    query: {...query, 'page': 0, 'size': 1},
    parseItem: (json) => json,
  );
  return page.totalElements;
}
