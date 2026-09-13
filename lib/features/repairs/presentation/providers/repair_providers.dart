import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../data/repair_repository.dart';
import '../../domain/repair_models.dart';

final repairRepositoryProvider = Provider<RepairRepository>(
  (ref) => RepairRepository(
    ref.watch(apiClientProvider),
    offlineGuard: ref.watch(offlineGuardProvider),
  ),
);

final repairStatusProvider =
    NotifierProvider<RepairStatusController, RepairStatus>(
      RepairStatusController.new,
    );

class RepairStatusController extends Notifier<RepairStatus> {
  @override
  RepairStatus build() => RepairStatus.received;
  void set(RepairStatus status) => state = status;
}

/// Restricts the board to jobs assigned to the signed-in user.
///
/// The default view for an artisan, who cares about their own bench, not the
/// whole shop.
final myJobsOnlyProvider = NotifierProvider<MyJobsController, bool>(
  MyJobsController.new,
);

class MyJobsController extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final repairBoardProvider = FutureProvider.autoDispose<List<RepairJob>>((
  ref,
) async {
  final status = ref.watch(repairStatusProvider);
  final branch = ref.watch(currentBranchProvider);
  final mine = ref.watch(myJobsOnlyProvider);
  final user = ref.watch(currentUserProvider);

  final page = await ref
      .watch(repairRepositoryProvider)
      .search(
        status: status,
        branchId: branch?.id,
        assignedTo: mine ? user?.username : null,
        size: 50,
      );
  return page.content;
});

/// Per-status counts for the board tabs.
///
/// The backend filters repairs by one status at a time, so a tab count is one
/// call each. They run in parallel and are cheap (`size=1`).
final repairStatusCountProvider = FutureProvider.autoDispose
    .family<int, RepairStatus>((ref, status) {
      final branch = ref.watch(currentBranchProvider);
      return ref
          .watch(repairRepositoryProvider)
          .count(status: status, branchId: branch?.id);
    });

final repairDetailProvider = FutureProvider.autoDispose
    .family<RepairJob, String>(
      (ref, id) => ref.watch(repairRepositoryProvider).byId(id),
    );

final overdueRepairsProvider = FutureProvider.autoDispose<List<RepairJob>>((
  ref,
) async {
  final branch = ref.watch(currentBranchProvider);
  if (branch == null) return const [];
  return ref.watch(repairRepositoryProvider).overdue(branch.id);
});
