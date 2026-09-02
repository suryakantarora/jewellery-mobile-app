import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/catalogue_item.dart';

/// Sellable stock, priced and named by the backend.
///
/// Nothing here computes or formats money beyond display: the price arrives
/// from the same engine that will charge it, so the figure shown across the
/// counter is the figure the customer pays.
class CatalogueRepository {
  CatalogueRepository(this._client);

  final ApiClient _client;

  Future<PageResponse<CatalogueItem>> browse({
    String? branchId,
    String? categoryId,
    String? metalId,
    String? search,
    int page = 0,
    int size = 20,
  }) {
    return _client.getPage<CatalogueItem>(
      ApiEndpoints.catalogueItems,
      query: {
        if (branchId != null) 'branchId': branchId,
        if (categoryId != null) 'categoryId': categoryId,
        if (metalId != null) 'metalId': metalId,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'page': page,
        'size': size,
      },
      parseItem: CatalogueItem.fromJson,
    );
  }
}
