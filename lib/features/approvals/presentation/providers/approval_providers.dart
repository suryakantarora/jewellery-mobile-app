import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/session_controller.dart';
import '../../../exchange/presentation/providers/exchange_providers.dart';
import '../../../procurement/presentation/providers/procurement_providers.dart';
import '../../../transfers/presentation/providers/transfer_providers.dart';
import '../../../warehouse/presentation/providers/warehouse_providers.dart';
import '../../data/approval_aggregator.dart';
import '../../domain/approval_models.dart';

final approvalAggregatorProvider = Provider<ApprovalAggregator>(
  (ref) => ApprovalAggregator(
    movements: ref.watch(movementRepositoryProvider),
    procurement: ref.watch(procurementRepositoryProvider),
    exchanges: ref.watch(exchangeRepositoryProvider),
    warehouse: ref.watch(warehouseRepositoryProvider),
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

final pendingApprovalsProvider = FutureProvider.autoDispose<List<ApprovalItem>>(
  (ref) async {
    final permissions = ref.watch(permissionsProvider);
    final branch = ref.watch(currentBranchProvider);

    return ref
        .watch(approvalAggregatorProvider)
        .pending(permissions: permissions, branchId: branch?.id);
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

/// Counts per type, for the filter chips.
final approvalCountsProvider = Provider.autoDispose<Map<ApprovalKind, int>>((
  ref,
) {
  final all = ref.watch(pendingApprovalsProvider).valueOrNull ?? const [];
  final counts = <ApprovalKind, int>{};
  for (final item in all) {
    counts[item.kind] = (counts[item.kind] ?? 0) + 1;
  }
  return counts;
});
