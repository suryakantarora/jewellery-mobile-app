import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/warehouse_models.dart';

/// Warehouse operations: bins and physical stock counts.
///
/// Issue and return are **not** here — they are `MovementType.ISSUE` and
/// `RETURN` on the movements endpoint, so they reuse `MovementRepository`.
class WarehouseRepository {
  WarehouseRepository(this._client);

  final ApiClient _client;

  Future<List<StorageBin>> bins(String locationId) =>
      _client.get<List<StorageBin>>(
        ApiEndpoints.bins,
        query: {'locationId': locationId},
        parse: (data) => data is List
            ? data
                  .whereType<Map<String, dynamic>>()
                  .map(StorageBin.fromJson)
                  .toList(growable: false)
            : const [],
      );

  Future<PageResponse<StockCount>> counts({
    StockCountStatus? status,
    String? locationId,
    String? branchId,
    int page = 0,
    int size = 20,
  }) {
    return _client.getPage<StockCount>(
      ApiEndpoints.stockCounts,
      query: {
        'page': page,
        'size': size,
        if (status != null) 'status': status.code,
        if (locationId != null) 'locationId': locationId,
        if (branchId != null) 'branchId': branchId,
      },
      parseItem: StockCount.fromJson,
    );
  }

  Future<StockCount> byId(String id) => _client.get<StockCount>(
    ApiEndpoints.stockCount(id),
    parse: (data) => StockCount.fromJson(data! as Map<String, dynamic>),
  );

  /// Opens a count. The response carries the expected item list.
  Future<StockCount> start({required String locationId, String? notes}) {
    return _client.post<StockCount>(
      ApiEndpoints.stockCounts,
      body: {
        'locationId': locationId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
      parse: (data) => StockCount.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Submits what was physically found.
  ///
  /// The payload is `foundItemIds` — observations only. There is deliberately
  /// no way for the app to submit an adjusted quantity: the backend does the
  /// reconciliation and a separate permission approves it, so a counter can
  /// never quietly correct stock.
  Future<StockCount> submit(
    String id, {
    required List<String> foundItemIds,
    String? notes,
  }) {
    return _client.post<StockCount>(
      ApiEndpoints.stockCountSubmit(id),
      body: {
        'foundItemIds': foundItemIds,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
      parse: (data) => StockCount.fromJson(data! as Map<String, dynamic>),
    );
  }

  Future<StockCount> approve(String id) => _client.post<StockCount>(
    ApiEndpoints.stockCountApprove(id),
    parse: (data) => StockCount.fromJson(data! as Map<String, dynamic>),
  );

  Future<StockCount> cancel(String id, {String? reason}) =>
      _client.post<StockCount>(
        ApiEndpoints.stockCountCancel(id),
        query: {if (reason != null) 'reason': reason},
        parse: (data) => StockCount.fromJson(data! as Map<String, dynamic>),
      );
}
