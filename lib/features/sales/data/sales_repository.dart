import '../../../core/connectivity/offline_guard.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../shared/models/reference_data.dart';
import '../domain/sales_models.dart';

class SalesRepository {
  SalesRepository(this._client, {OfflineGuard? offlineGuard})
    : _offlineGuard = offlineGuard;

  final ApiClient _client;

  /// Refuses mutations while offline. Null in tests that construct the
  /// repository directly; the provider always supplies one.
  final OfflineGuard? _offlineGuard;

  Future<T> _guarded<T>(Future<T> Function() action) =>
      _offlineGuard?.run(action) ?? action();

  static const _discountRequests = '/sales/discount-requests';
  static const _availability = '/inventory/availability';

  /// Asks the backend what an item costs.
  ///
  /// The app never multiplies a metal rate by a weight — that is the whole
  /// reason this endpoint exists, and a client-side figure could disagree with
  /// the price the POS actually charges.
  Future<PriceBreakdown> calculatePrice({
    required String jewelleryItemId,
    String? customerId,
    String? branchId,
  }) {
    return _client.post<PriceBreakdown>(
      ApiEndpoints.pricingCalculate,
      body: {
        'jewelleryItemId': jewelleryItemId,
        if (customerId != null) 'customerId': customerId,
        if (branchId != null) 'branchId': branchId,
      },
      parse: (data) => PriceBreakdown.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// The current rate for a metal and purity.
  ///
  /// `metalId` and `purityId` are required; omitting them returns a 500 rather
  /// than a validation error, so they are never optional here.
  Future<MetalRate?> currentRate({
    required String metalId,
    required String purityId,
    String rateType = 'SELLING',
  }) async {
    try {
      return await _client.get<MetalRate?>(
        ApiEndpoints.currentMetalRates,
        query: {'metalId': metalId, 'purityId': purityId, 'rateType': rateType},
        parse: (data) =>
            data is Map<String, dynamic> ? MetalRate.fromJson(data) : null,
      );
    } on Object {
      // A missing rate must not break the price screen; the breakdown from
      // /pricing/calculate is the authoritative figure regardless.
      return null;
    }
  }

  /// Stock of a product at every branch the caller may see, in one call.
  Future<ProductAvailability> availability(String productId) =>
      _client.get<ProductAvailability>(
        _availability,
        query: {'productId': productId},
        parse: (data) =>
            ProductAvailability.fromJson(data! as Map<String, dynamic>),
      );

  // --- Discount requests ---------------------------------------------------

  /// Exactly one of [percentage] / [amount] must be given; the backend rejects
  /// both or neither.
  Future<DiscountRequest> createDiscountRequest({
    required String branchId,
    required String reason,
    double? percentage,
    double? amount,
    String? currency,
    String? customerId,
    String? jewelleryItemId,
    String? quotationId,
    String? idempotencyKey,
  }) {
    assert(
      (percentage == null) != (amount == null),
      'Give exactly one of percentage or amount',
    );
    return _guarded(
      () => _client.post<DiscountRequest>(
        _discountRequests,
        body: {
          'branchId': branchId,
          'reason': reason,
          if (percentage != null) 'requestedPercentage': percentage,
          if (amount != null) 'requestedAmount': amount,
          if (currency != null) 'currency': currency,
          if (customerId != null) 'customerId': customerId,
          if (jewelleryItemId != null) 'jewelleryItemId': jewelleryItemId,
          if (quotationId != null) 'quotationId': quotationId,
        },
        idempotencyKey: idempotencyKey,
        parse: (data) =>
            DiscountRequest.fromJson(data! as Map<String, dynamic>),
      ),
    );
  }

  Future<PageResponse<DiscountRequest>> discountRequests({
    String? branchId,
    DiscountRequestStatus? status,
    bool mine = false,
    int page = 0,
    int size = 20,
  }) {
    return _client.getPage<DiscountRequest>(
      _discountRequests,
      query: {
        'page': page,
        'size': size,
        if (branchId != null) 'branchId': branchId,
        if (status != null) 'status': status.code,
        if (mine) 'mine': true,
      },
      parseItem: DiscountRequest.fromJson,
    );
  }

  Future<DiscountRequest> discountRequest(String id) =>
      _client.get<DiscountRequest>(
        '$_discountRequests/$id',
        parse: (data) =>
            DiscountRequest.fromJson(data! as Map<String, dynamic>),
      );

  Future<DiscountRequest> approveDiscountRequest(String id, {String? reason}) =>
      _guarded(
        () => _client.post<DiscountRequest>(
          '$_discountRequests/$id/approve',
          body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
          parse: (data) =>
              DiscountRequest.fromJson(data! as Map<String, dynamic>),
        ),
      );

  Future<DiscountRequest> rejectDiscountRequest(String id, String reason) =>
      _guarded(
        () => _client.post<DiscountRequest>(
          '$_discountRequests/$id/reject',
          body: {'reason': reason},
          parse: (data) =>
              DiscountRequest.fromJson(data! as Map<String, dynamic>),
        ),
      );

  Future<void> cancelDiscountRequest(String id) =>
      _guarded(() => _client.send('$_discountRequests/$id/cancel'));
}
