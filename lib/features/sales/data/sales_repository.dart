import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/reference_data.dart';
import '../domain/sales_models.dart';

class SalesRepository {
  SalesRepository(this._client);

  final ApiClient _client;

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
}
