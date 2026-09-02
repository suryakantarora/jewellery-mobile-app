import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../data/procurement_repository.dart';
import '../../domain/procurement_models.dart';

final procurementRepositoryProvider = Provider<ProcurementRepository>(
  (ref) => ProcurementRepository(ref.watch(apiClientProvider)),
);

final poStatusFilterProvider =
    NotifierProvider<PoStatusController, PurchaseOrderStatus?>(
      PoStatusController.new,
    );

class PoStatusController extends Notifier<PurchaseOrderStatus?> {
  @override
  PurchaseOrderStatus? build() => null;
  void set(PurchaseOrderStatus? status) => state = status;
}

final purchaseOrderListProvider =
    FutureProvider.autoDispose<List<PurchaseOrder>>((ref) async {
      ref.watch(currentBranchProvider);
      final page = await ref
          .watch(procurementRepositoryProvider)
          .purchaseOrders(status: ref.watch(poStatusFilterProvider), size: 50);
      return page.content;
    });

final purchaseOrderDetailProvider = FutureProvider.autoDispose
    .family<PurchaseOrder, String>(
      (ref, id) => ref.watch(procurementRepositoryProvider).purchaseOrder(id),
    );

/// Suppliers, cached for the session so a PO row can name its supplier without
/// a lookup per row.
final suppliersProvider = FutureProvider<Map<String, Supplier>>((ref) async {
  final list = await ref.watch(procurementRepositoryProvider).suppliers();
  return {for (final supplier in list) supplier.id: supplier};
});

final goodsReceiptListProvider = FutureProvider.autoDispose<List<GoodsReceipt>>(
  (ref) async {
    ref.watch(currentBranchProvider);
    final page = await ref
        .watch(procurementRepositoryProvider)
        .goodsReceipts(size: 50);
    return page.content;
  },
);
