import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/exchange_models.dart';

/// Exchange and buyback.
///
/// One workflow distinguished by `exchangeType`, because that is how the
/// backend models it — two near-identical implementations would only drift.
class ExchangeRepository {
  ExchangeRepository(this._client);

  final ApiClient _client;

  Future<PageResponse<ExchangeRecord>> search({
    ExchangeStatus? status,
    ExchangeType? type,
    String? customerId,
    String? branchId,
    int page = 0,
    int size = 20,
  }) {
    return _client.getPage<ExchangeRecord>(
      ApiEndpoints.exchanges,
      query: {
        'page': page,
        'size': size,
        if (status != null) 'status': status.code,
        if (type != null) 'exchangeType': type.code,
        if (customerId != null) 'customerId': customerId,
        if (branchId != null) 'branchId': branchId,
      },
      parseItem: ExchangeRecord.fromJson,
    );
  }

  Future<ExchangeRecord> byId(String id) => _client.get<ExchangeRecord>(
    ApiEndpoints.exchange(id),
    parse: (data) => ExchangeRecord.fromJson(data! as Map<String, dynamic>),
  );

  Future<ExchangeRecord> receive({
    required ExchangeType type,
    required String customerId,
    required String branchId,
    required String metalId,
    required String description,
    String? locationId,
    String? declaredPurityId,
    int itemCount = 1,
  }) {
    return _client.post<ExchangeRecord>(
      ApiEndpoints.exchanges,
      body: {
        'exchangeType': type.code,
        'customerId': customerId,
        'branchId': branchId,
        'metalId': metalId,
        'description': description,
        'itemCount': itemCount,
        if (locationId != null) 'locationId': locationId,
        if (declaredPurityId != null) 'declaredPurityId': declaredPurityId,
      },
      parse: (data) => ExchangeRecord.fromJson(data! as Map<String, dynamic>),
    );
  }

  Future<ExchangeRecord> _step(
    String id,
    String step, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) => _client.post<ExchangeRecord>(
    '${ApiEndpoints.exchange(id)}/$step',
    body: body,
    query: query,
    parse: (data) => ExchangeRecord.fromJson(data! as Map<String, dynamic>),
  );

  /// Records weights. Net weight comes back derived — never sent.
  Future<ExchangeRecord> weigh(
    String id, {
    required double grossWeight,
    double? stoneWeight,
  }) => _step(
    id,
    'weigh',
    body: {
      'grossWeight': grossWeight,
      if (stoneWeight != null) 'stoneWeight': stoneWeight,
    },
  );

  Future<ExchangeRecord> testPurity(
    String id, {
    required String testedPurityId,
    String? testMethod,
  }) => _step(
    id,
    'purity-test',
    body: {
      'testedPurityId': testedPurityId,
      if (testMethod != null) 'testMethod': testMethod,
    },
  );

  /// Requests a valuation.
  ///
  /// The client sends **only** a deduction percentage and a note. The rate,
  /// pure weight, gross valuation, deduction amount and net payable all come
  /// back computed. There is no parameter through which the app could supply a
  /// figure of its own.
  Future<ExchangeRecord> value(
    String id, {
    required double deductionPercentage,
    String? notes,
  }) => _step(
    id,
    'valuation',
    body: {
      'deductionPercentage': deductionPercentage,
      if (notes != null) 'notes': notes,
    },
  );

  Future<ExchangeRecord> approve(String id) => _step(id, 'approve');

  Future<ExchangeRecord> reject(String id, String reason) =>
      _step(id, 'reject', query: {'reason': reason});

  Future<ExchangeRecord> complete(String id, {String? scrapLocationId}) =>
      _step(
        id,
        'complete',
        body: {if (scrapLocationId != null) 'scrapLocationId': scrapLocationId},
      );

  Future<ExchangeRecord> returnToCustomer(String id, {String? reason}) =>
      _step(id, 'return', query: {if (reason != null) 'reason': reason});
}
