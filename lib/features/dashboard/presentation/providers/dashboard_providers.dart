import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/permissions.dart';
import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/dashboard_summary.dart';

/// Dashboard figures.
///
/// One request — `GET /dashboard/summary` — returns every figure the signed-in
/// user may see, and **omits** the sections they may not. The backend decides
/// what a user sees; the client renders what is present. That replaces the
/// earlier seven-query composition and its per-tile "Unavailable" state: with a
/// single source there is one loading state, one failure state, and no way for
/// a permission gap to look like an outage.
///
/// The section-to-permission mapping in [DashboardSection] is kept as a
/// belt-and-braces check so a mis-scoped server response cannot surface a
/// figure the client knows the user lacks; presence in the payload is the
/// source of truth.

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(apiClientProvider)),
);

/// The summary for the active branch. Rebuilds on a branch switch, and is
/// disposed when the dashboard is not on screen so a stale branch's numbers
/// are never shown after a change.
class DashboardSummaryController
    extends AutoDisposeAsyncNotifier<DashboardSummary> {
  @override
  Future<DashboardSummary> build() {
    final branchId = _requireBranch();
    return ref.watch(dashboardRepositoryProvider).summary(branchId);
  }

  /// Pull-to-refresh: bypasses the server's 30 s cache.
  ///
  /// Keeps the previous figures on screen while the new ones load, so the grid
  /// does not collapse to skeletons under the refresh indicator.
  Future<void> refresh() async {
    final branchId = _requireBranch();
    final repository = ref.read(dashboardRepositoryProvider);
    state = await AsyncValue.guard(
      () => repository.summary(branchId, refresh: true),
    );
  }

  String _requireBranch() {
    final branch = ref.watch(currentBranchProvider);
    if (branch == null) {
      throw StateError('Dashboard figures require a branch');
    }
    return branch.id;
  }
}

final dashboardSummaryProvider =
    AsyncNotifierProvider.autoDispose<
      DashboardSummaryController,
      DashboardSummary
    >(DashboardSummaryController.new);

/// The sections the dashboard can render, each with the permission the backend
/// requires to include it. Used only as a secondary filter — see the file
/// comment.
enum DashboardSection {
  sales([Permission.saleView]),
  inventory([Permission.inventoryView]),
  inventoryValue([Permission.reportView, Permission.financeView]),
  transfers([
    Permission.inventoryTransfer,
    Permission.inventoryTransferApprove,
  ]),
  approvals([
    Permission.inventoryTransferApprove,
    Permission.procurementApprove,
    Permission.exchangeApprove,
    Permission.stockCountApprove,
    Permission.discountApprove,
    Permission.procurementReceive,
  ]),
  repairs([Permission.repairView]),
  procurement([Permission.procurementView]),
  metalRates([Permission.metalView]);

  const DashboardSection(this.requiresAny);
  final List<Permission> requiresAny;

  bool isVisibleTo(PermissionSet permissions) =>
      requiresAny.isEmpty || permissions.hasAny(requiresAny);
}
