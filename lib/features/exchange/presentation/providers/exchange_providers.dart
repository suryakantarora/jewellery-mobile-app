import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../data/exchange_repository.dart';
import '../../domain/exchange_models.dart';

final exchangeRepositoryProvider = Provider<ExchangeRepository>(
  (ref) => ExchangeRepository(ref.watch(apiClientProvider)),
);

final exchangeTypeFilterProvider =
    NotifierProvider<ExchangeTypeController, ExchangeType?>(
      ExchangeTypeController.new,
    );

class ExchangeTypeController extends Notifier<ExchangeType?> {
  @override
  ExchangeType? build() => null;
  void set(ExchangeType? type) => state = type;
}

final exchangeListProvider = FutureProvider.autoDispose<List<ExchangeRecord>>((
  ref,
) async {
  final branch = ref.watch(currentBranchProvider);
  final page = await ref
      .watch(exchangeRepositoryProvider)
      .search(
        type: ref.watch(exchangeTypeFilterProvider),
        branchId: branch?.id,
        size: 50,
      );

  // Anything waiting on a decision is surfaced first — it is the only thing on
  // this screen that blocks a customer standing at a counter.
  final records = [...page.content];
  records.sort((a, b) {
    int rank(ExchangeRecord record) =>
        record.status == ExchangeStatus.pendingApproval ? 0 : 1;
    return rank(a).compareTo(rank(b));
  });
  return records;
});

final exchangeDetailProvider = FutureProvider.autoDispose
    .family<ExchangeRecord, String>(
      (ref, id) => ref.watch(exchangeRepositoryProvider).byId(id),
    );
