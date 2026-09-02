import 'package:uuid/uuid.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/procurement_models.dart';

/// Purchase orders, goods receipts and suppliers.
///
/// Mobile scope is read + approve + receive. Authoring a purchase order is an
/// Admin-portal job: it needs supplier terms and pricing that do not belong on
/// a phone at a loading bay.
class ProcurementRepository {
  ProcurementRepository(this._client);

  final ApiClient _client;
  static const _uuid = Uuid();

  Future<PageResponse<PurchaseOrder>> purchaseOrders({
    PurchaseOrderStatus? status,
    int page = 0,
    int size = 20,
  }) {
    return _client.getPage<PurchaseOrder>(
      ApiEndpoints.purchaseOrders,
      query: {
        'page': page,
        'size': size,
        if (status != null) 'status': status.code,
      },
      parseItem: PurchaseOrder.fromJson,
    );
  }

  Future<PurchaseOrder> purchaseOrder(String id) => _client.get<PurchaseOrder>(
    ApiEndpoints.purchaseOrder(id),
    parse: (data) => PurchaseOrder.fromJson(data! as Map<String, dynamic>),
  );

  Future<PurchaseOrder> approve(String id) => _client.post<PurchaseOrder>(
    '${ApiEndpoints.purchaseOrder(id)}/approve',
    parse: (data) => PurchaseOrder.fromJson(data! as Map<String, dynamic>),
  );

  Future<PurchaseOrder> reject(String id, String reason) =>
      _client.post<PurchaseOrder>(
        '${ApiEndpoints.purchaseOrder(id)}/reject',
        body: {'reason': reason},
        parse: (data) => PurchaseOrder.fromJson(data! as Map<String, dynamic>),
      );

  Future<PageResponse<GoodsReceipt>> goodsReceipts({
    GoodsReceiptStatus? status,
    int page = 0,
    int size = 20,
  }) {
    return _client.getPage<GoodsReceipt>(
      ApiEndpoints.goodsReceipts,
      query: {
        'page': page,
        'size': size,
        if (status != null) 'status': status.code,
      },
      parseItem: GoodsReceipt.fromJson,
    );
  }

  /// Records a receipt.
  ///
  /// This is the one endpoint where the backend already honours
  /// `X-Idempotency-Key`, and it matters most here: a retried request could
  /// otherwise duplicate real stock.
  Future<GoodsReceipt> createReceipt({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) {
    return _client.post<GoodsReceipt>(
      ApiEndpoints.goodsReceipts,
      body: body,
      idempotencyKey: idempotencyKey,
      parse: (data) => GoodsReceipt.fromJson(data! as Map<String, dynamic>),
    );
  }

  Future<GoodsReceipt> acceptReceipt(String id) => _client.post<GoodsReceipt>(
    '${ApiEndpoints.goodsReceipts}/$id/accept',
    parse: (data) => GoodsReceipt.fromJson(data! as Map<String, dynamic>),
  );

  Future<GoodsReceipt> rejectReceipt(String id, String reason) =>
      _client.post<GoodsReceipt>(
        '${ApiEndpoints.goodsReceipts}/$id/reject',
        body: {'reason': reason},
        parse: (data) => GoodsReceipt.fromJson(data! as Map<String, dynamic>),
      );

  Future<List<Supplier>> suppliers() async {
    final page = await _client.getPage<Supplier>(
      ApiEndpoints.suppliers,
      query: {'size': 200},
      parseItem: Supplier.fromJson,
    );
    return page.content;
  }

  /// A fresh key per user intent, never per retry.
  String newIdempotencyKey() => _uuid.v4();
}
