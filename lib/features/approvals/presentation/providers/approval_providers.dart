import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../data/approval_repository.dart';
import '../../domain/approval_models.dart';

final approvalRepositoryProvider = Provider<ApprovalRepository>(
  (ref) => ApprovalRepository(
    ref.watch(apiClientProvider),
    offlineGuard: ref.watch(offlineGuardProvider),
  ),
);

final approvalFilterProvider =
    NotifierProvider<ApprovalFilterController, ApprovalKind?>(
      ApprovalFilterController.new,
    );

class ApprovalFilterController extends Notifier<ApprovalKind?> {
  @override
  ApprovalKind? build() => null;
  void set(ApprovalKind? kind) => state = kind;
}

/// The whole queue for the current branch, oldest first, from the unified
/// endpoint. Filtering by type happens client-side so the chips stay instant.
final pendingApprovalsProvider = FutureProvider.autoDispose<List<ApprovalItem>>(
  (ref) {
    final branch = ref.watch(currentBranchProvider);
    return ref.watch(approvalRepositoryProvider).pending(branchId: branch?.id);
  },
);

/// The queue after the type filter, so counts and list agree.
final filteredApprovalsProvider = Provider.autoDispose<List<ApprovalItem>>((
  ref,
) {
  final all = ref.watch(pendingApprovalsProvider).valueOrNull ?? const [];
  final filter = ref.watch(approvalFilterProvider);
  if (filter == null) return all;
  return all.where((item) => item.kind == filter).toList(growable: false);
});

/// Counts per type from `GET /approvals/pending/count` — the badge source.
final approvalCountsProvider = FutureProvider.autoDispose<ApprovalCounts>((
  ref,
) {
  final branch = ref.watch(currentBranchProvider);
  return ref.watch(approvalRepositoryProvider).counts(branchId: branch?.id);
});

/// The information thread on one pending item.
final approvalInformationProvider = FutureProvider.autoDispose
    .family<List<InformationRequest>, ({ApprovalKind kind, String id})>(
      (ref, key) =>
          ref.watch(approvalRepositoryProvider).information(key.kind, key.id),
    );
