import 'package:dio/dio.dart';

import '../../../core/connectivity/offline_guard.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/bulk_tag_resolution.dart';
import '../domain/jewellery_item.dart';

/// Filters for the item search, mirroring the backend's query parameters.
///
/// The price range is applied server-side (`minPrice`/`maxPrice`, inclusive,
/// on `currentPrice`), so a filtered page and its total count always agree.
/// Nothing here filters client-side.
class ItemSearchFilters {
  const ItemSearchFilters({
    this.search,
    this.branchId,
    this.locationId,
    this.metalId,
    this.purityId,
    this.productId,
    this.status,
    this.minPrice,
    this.maxPrice,
  });

  final String? search;
  final String? branchId;
  final String? locationId;
  final String? metalId;
  final String? purityId;
  final String? productId;
  final ItemStatus? status;

  /// Inclusive bounds on `currentPrice`, in the branch currency.
  final num? minPrice;
  final num? maxPrice;

  bool get hasPriceRange => minPrice != null || maxPrice != null;

  bool get hasFilters =>
      locationId != null ||
      metalId != null ||
      purityId != null ||
      productId != null ||
      status != null ||
      hasPriceRange;

  /// Filters excluding the free-text query, for the "clear filters" affordance.
  /// A price range counts once however many bounds are set.
  int get activeCount =>
      [
        locationId,
        metalId,
        purityId,
        productId,
        status,
      ].where((value) => value != null).length +
      (hasPriceRange ? 1 : 0);

  ItemSearchFilters copyWith({
    Object? search = _unset,
    Object? branchId = _unset,
    Object? locationId = _unset,
    Object? metalId = _unset,
    Object? purityId = _unset,
    Object? productId = _unset,
    Object? status = _unset,
    Object? minPrice = _unset,
    Object? maxPrice = _unset,
  }) {
    return ItemSearchFilters(
      search: search == _unset ? this.search : search as String?,
      branchId: branchId == _unset ? this.branchId : branchId as String?,
      locationId: locationId == _unset
          ? this.locationId
          : locationId as String?,
      metalId: metalId == _unset ? this.metalId : metalId as String?,
      purityId: purityId == _unset ? this.purityId : purityId as String?,
      productId: productId == _unset ? this.productId : productId as String?,
      status: status == _unset ? this.status : status as ItemStatus?,
      minPrice: minPrice == _unset ? this.minPrice : minPrice as num?,
      maxPrice: maxPrice == _unset ? this.maxPrice : maxPrice as num?,
    );
  }

  ItemSearchFilters cleared() =>
      ItemSearchFilters(search: search, branchId: branchId);

  static const _unset = Object();

  // Value equality matters: the filter object is rebuilt whenever the branch
  // provider recomputes, and without this an identical filter set would count
  // as a change and re-run every dependent query.
  @override
  bool operator ==(Object other) =>
      other is ItemSearchFilters &&
      other.search == search &&
      other.branchId == branchId &&
      other.locationId == locationId &&
      other.metalId == metalId &&
      other.purityId == purityId &&
      other.productId == productId &&
      other.status == status &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice;

  @override
  int get hashCode => Object.hash(
    search,
    branchId,
    locationId,
    metalId,
    purityId,
    productId,
    status,
    minPrice,
    maxPrice,
  );

  Map<String, dynamic> toQuery({required int page, required int size}) => {
    'page': page,
    'size': size,
    if (search != null && search!.trim().isNotEmpty) 'search': search!.trim(),
    if (branchId != null) 'branchId': branchId,
    if (locationId != null) 'locationId': locationId,
    if (metalId != null) 'metalId': metalId,
    if (purityId != null) 'purityId': purityId,
    if (productId != null) 'productId': productId,
    if (status != null) 'status': status!.code,
    if (minPrice != null) 'minPrice': minPrice,
    if (maxPrice != null) 'maxPrice': maxPrice,
  };
}

class JewelleryRepository {
  JewelleryRepository(this._client, {OfflineGuard? offlineGuard})
    : _offlineGuard = offlineGuard;

  final ApiClient _client;

  /// Refuses mutations while offline. Null in tests that construct the
  /// repository directly; the provider always supplies one.
  final OfflineGuard? _offlineGuard;

  Future<T> _guarded<T>(Future<T> Function() action) =>
      _offlineGuard?.run(action) ?? action();

  Future<PageResponse<JewelleryItem>> search(
    ItemSearchFilters filters, {
    int page = 0,
    int size = 20,
    CancelToken? cancelToken,
  }) {
    return _client.getPage<JewelleryItem>(
      ApiEndpoints.items,
      query: filters.toQuery(page: page, size: size),
      parseItem: JewelleryItem.fromJson,
      cancelToken: cancelToken,
    );
  }

  /// Total matching count without fetching a page of results.
  ///
  /// Used for group headers and dashboard tiles, where the number is the whole
  /// point and the rows are not needed.
  Future<int> count(
    ItemSearchFilters filters, {
    CancelToken? cancelToken,
  }) async {
    final page = await _client.getPage<JewelleryItem>(
      ApiEndpoints.items,
      query: filters.toQuery(page: 0, size: 1),
      parseItem: JewelleryItem.fromJson,
      cancelToken: cancelToken,
    );
    return page.totalElements;
  }

  Future<JewelleryItem> byId(String id) => _client.get<JewelleryItem>(
    ApiEndpoints.item(id),
    parse: (data) => JewelleryItem.fromJson(data! as Map<String, dynamic>),
  );

  /// Everything stored in one bin.
  ///
  /// Deliberately not routed through [ItemSearchFilters]: a tray listing needs
  /// no branch, metal or status facets, and adding a field the filter sheet
  /// cannot show would leave a filter chip nobody can clear.
  Future<PageResponse<JewelleryItem>> inBin(String binId, {int size = 100}) {
    return _client.getPage<JewelleryItem>(
      ApiEndpoints.items,
      query: {'binId': binId, 'size': size},
      parseItem: JewelleryItem.fromJson,
    );
  }

  /// Puts an item in a bin, or takes it out when [binId] is null.
  ///
  /// The backend refuses a bin belonging to another location, so a stale bin
  /// list cannot silently record stock in a tray on the other side of the
  /// country.
  Future<JewelleryItem> assignBin(String itemId, String? binId) {
    return _guarded(
      () => _client.post<JewelleryItem>(
        '${ApiEndpoints.item(itemId)}/bin',
        body: {'binId': binId},
        parse: (data) => JewelleryItem.fromJson(data! as Map<String, dynamic>),
      ),
    );
  }

  /// Resolves an RFID tag, QR code, barcode or item code.
  ///
  /// One endpoint handles all four, which is why the scanner does not need to
  /// know which symbology produced a value.
  Future<JewelleryItem> byTag(String tag, {CancelToken? cancelToken}) {
    return _client.get<JewelleryItem>(
      ApiEndpoints.itemByTag,
      query: {'tag': tag},
      parse: (data) => JewelleryItem.fromJson(data! as Map<String, dynamic>),
      cancelToken: cancelToken,
    );
  }

  /// Resolves many scanned values in one round trip per chunk.
  ///
  /// The endpoint accepts up to 500 tags; [byTagsChunkSize] stays well under
  /// that so a payload of item responses never approaches the size at which a
  /// mobile connection starts timing out. Duplicates are removed client-side
  /// first so a tag re-read across chunks cannot resolve twice.
  static const byTagsChunkSize = 200;
  static const _byTagsPath = '/inventory/items/by-tags';

  Future<BulkTagResolution> byTags(
    List<String> tags, {
    CancelToken? cancelToken,
  }) async {
    var result = BulkTagResolution.empty;
    for (final chunk in chunkTags(tags)) {
      final part = await _client.post<BulkTagResolution>(
        _byTagsPath,
        body: {'tags': chunk},
        parse: (data) => BulkTagResolution.fromJson(
          data is Map<String, dynamic> ? data : const {},
        ),
        cancelToken: cancelToken,
      );
      result = result.merge(part);
    }
    return result;
  }

  /// Distinct, non-empty tags in first-seen order, split into request-sized
  /// chunks. Pure, so it is testable without a client.
  static List<List<String>> chunkTags(
    Iterable<String> tags, {
    int size = byTagsChunkSize,
  }) {
    assert(size > 0, 'chunk size must be positive');
    final distinct = <String>{};
    for (final tag in tags) {
      final trimmed = tag.trim();
      if (trimmed.isNotEmpty) distinct.add(trimmed);
    }
    final ordered = distinct.toList(growable: false);
    return [
      for (var i = 0; i < ordered.length; i += size)
        ordered.sublist(
          i,
          i + size > ordered.length ? ordered.length : i + size,
        ),
    ];
  }

  Future<ItemPassport> passport(String id) => _client.get<ItemPassport>(
    ApiEndpoints.itemPassport(id),
    parse: (data) => ItemPassport.fromJson(data! as Map<String, dynamic>),
  );

  Future<JewelleryItem> reserve({
    required String itemId,
    required String customerId,
    int holdHours = 24,
    String? notes,
  }) {
    return _guarded(
      () => _client.post<JewelleryItem>(
        ApiEndpoints.reservations,
        body: {
          'jewelleryItemId': itemId,
          'customerId': customerId,
          'holdHours': holdHours,
          if (notes != null) 'notes': notes,
        },
        parse: (data) => JewelleryItem.fromJson(data! as Map<String, dynamic>),
      ),
    );
  }

  Future<void> releaseReservation(String itemId) =>
      _guarded(() => _client.send(ApiEndpoints.releaseReservation(itemId)));

  /// Manual status correction. The backend requires a reason and audits it.
  Future<JewelleryItem> changeStatus({
    required String itemId,
    required ItemStatus target,
    required String reason,
  }) {
    return _guarded(
      () => _client.post<JewelleryItem>(
        ApiEndpoints.itemStatus(itemId),
        body: {'targetStatus': target.code, 'reason': reason},
        parse: (data) => JewelleryItem.fromJson(data! as Map<String, dynamic>),
      ),
    );
  }
}
