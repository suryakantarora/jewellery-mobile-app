import 'dart:async';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/organization.dart';
import '../../../shared/models/reference_data.dart';

/// Master data for pickers, and a **fallback** for names.
///
/// `JewelleryItemResponse` now carries display names (`productName`,
/// `metalName`, `purityCode`, `currentLocationName`, ...) next to its UUIDs,
/// so item rows and the passport read those first and only consult this cache
/// when a name is null — an older payload, or a nested item the backend did not
/// enrich. The cache remains the source of truth for anything that needs the
/// full set rather than one item's labels: filter chips, metal and purity
/// pickers, location choosers, and the metal code behind a thumbnail's tint.
///
/// Two strategies, chosen per data set:
///
/// * **Prefetched** — metals, purities, categories, product types and the
///   current branch's locations. All small and slow-changing, so they are
///   loaded once per session in a single burst.
/// * **Lazy with coalescing** — products and designs. There can be thousands,
///   so they are fetched per id on demand, and concurrent requests for the same
///   id share one in-flight future. Twenty rows referencing five products issue
///   five requests, not twenty.
class ReferenceDataService {
  ReferenceDataService(this._client);

  final ApiClient _client;

  final Map<String, Metal> _metals = {};
  final Map<String, Purity> _purities = {};
  final Map<String, NamedRef> _categories = {};
  final Map<String, NamedRef> _productTypes = {};
  final Map<String, BranchLocation> _locations = {};

  final Map<String, Product> _products = {};
  final Map<String, Design> _designs = {};

  /// In-flight lazy loads, keyed by id, so duplicate requests coalesce.
  final Map<String, Future<Product?>> _productLoads = {};
  final Map<String, Future<Design?>> _designLoads = {};

  bool _prefetched = false;
  Future<void>? _prefetching;

  /// Loads the small master sets. Safe to call repeatedly; only the first call
  /// does work, and concurrent callers await the same future.
  ///
  /// [branchIds] should be every branch the user can act in, not just the
  /// active one: a cross-branch transfer names a source location that belongs
  /// to a different branch, and without it the row reads "Origin → Destination".
  Future<void> prefetch({List<String> branchIds = const []}) {
    if (_prefetched) return Future.value();
    return _prefetching ??= _doPrefetch(branchIds).whenComplete(() {
      _prefetching = null;
    });
  }

  Future<void> _doPrefetch(List<String> branchIds) async {
    await Future.wait([
      _loadMetals(),
      _loadCategories(),
      _loadProductTypes(),
      ...branchIds.map(loadLocations),
    ]);

    // Purities hang off a metal, so they follow rather than run in parallel.
    await Future.wait(_metals.keys.map(_loadPurities));
    _prefetched = true;
  }

  /// Clears everything. Called on branch switch and sign-out, so one branch's
  /// locations can never label another branch's items.
  void clear() {
    _metals.clear();
    _purities.clear();
    _categories.clear();
    _productTypes.clear();
    _locations.clear();
    _products.clear();
    _designs.clear();
    _productLoads.clear();
    _designLoads.clear();
    _prefetched = false;
  }

  // --- Synchronous lookups, safe to call during build ----------------------

  Metal? metal(String? id) => id == null ? null : _metals[id];
  Purity? purity(String? id) => id == null ? null : _purities[id];
  NamedRef? category(String? id) => id == null ? null : _categories[id];
  NamedRef? productType(String? id) => id == null ? null : _productTypes[id];
  BranchLocation? location(String? id) => id == null ? null : _locations[id];
  Product? cachedProduct(String? id) => id == null ? null : _products[id];
  Design? cachedDesign(String? id) => id == null ? null : _designs[id];

  List<Metal> get metals => _metals.values.toList(growable: false);
  List<NamedRef> get categories => _categories.values.toList(growable: false);
  List<BranchLocation> get locations =>
      _locations.values.toList(growable: false);

  List<Purity> puritiesFor(String? metalId) => _purities.values
      .where((p) => metalId == null || p.metalId == metalId)
      .toList(growable: false);

  /// A short human label for an item's material, e.g. "22K Gold".
  String materialLabel(String? metalId, String? purityId) {
    final purityCode = purity(purityId)?.code;
    final metalName = metal(metalId)?.name;
    return [purityCode, metalName].whereType<String>().join(' ');
  }

  // --- Lazy, coalesced -----------------------------------------------------

  Future<Product?> product(String? id) {
    if (id == null) return Future.value();
    final cached = _products[id];
    if (cached != null) return Future.value(cached);

    return _productLoads[id] ??= _load<Product>(
      id: id,
      inFlight: _productLoads,
      cache: _products,
      path: '${ApiEndpoints.products}/$id',
      fromJson: Product.fromJson,
      idOf: (product) => product.id,
    );
  }

  Future<Design?> design(String? id) {
    if (id == null) return Future.value();
    final cached = _designs[id];
    if (cached != null) return Future.value(cached);

    return _designLoads[id] ??= _load<Design>(
      id: id,
      inFlight: _designLoads,
      cache: _designs,
      path: '${ApiEndpoints.designs}/$id',
      fromJson: Design.fromJson,
      idOf: (design) => design.id,
    );
  }

  /// Warms the cache for a page of items in one pass, so a list can render
  /// names on its first frame instead of filling in row by row.
  Future<void> warmFor(Iterable<String?> productIds) async {
    final wanted = productIds
        .whereType<String>()
        .where((id) => !_products.containsKey(id))
        .toSet();
    if (wanted.isEmpty) return;
    await Future.wait(wanted.map(product));
  }

  /// Fetches one record, caches it, and clears its in-flight entry.
  ///
  /// The cleanup deliberately does **not** use
  /// `.whenComplete(() => map.remove(id))`. `Map.remove` returns the removed
  /// value — here the very future being chained — and `whenComplete` waits on a
  /// Future its callback returns. That made each load wait on itself, so the
  /// future never completed and every list that awaited it hung forever.
  Future<T?> _load<T>({
    required String id,
    required Map<String, Future<T?>> inFlight,
    required Map<String, T> cache,
    required String path,
    required T Function(Map<String, dynamic> json) fromJson,
    required String Function(T value) idOf,
  }) async {
    try {
      final result = await _client.get<T?>(
        path,
        parse: (data) => data is Map<String, dynamic> ? fromJson(data) : null,
      );
      if (result != null) cache[idOf(result)] = result;
      return result;
    } on Object {
      // A missing or forbidden record degrades to "no name"; it must never
      // break the list that referenced it.
      return null;
    } finally {
      // The removed value is the future itself; it is discarded deliberately,
      // never returned or awaited. Awaiting it is what caused the deadlock.
      unawaited(inFlight.remove(id) ?? Future<T?>.value());
    }
  }

  Future<void> loadLocations(String branchId) async {
    try {
      final result = await _client.get<List<BranchLocation>>(
        ApiEndpoints.branchLocations(branchId),
        parse: (data) => data is List
            ? data
                  .whereType<Map<String, dynamic>>()
                  .map(BranchLocation.fromJson)
                  .toList(growable: false)
            : const [],
      );
      for (final location in result) {
        _locations[location.id] = location;
      }
    } on Object {
      // A branch that refuses simply contributes no names; it must not stop
      // the rest of the master data loading.
    }
  }

  Future<void> _loadMetals() async {
    final result = await _client.get<List<Metal>>(
      ApiEndpoints.metals,
      parse: (data) => _list(data, Metal.fromJson),
    );
    for (final metal in result) {
      _metals[metal.id] = metal;
    }
  }

  Future<void> _loadPurities(String metalId) async {
    final result = await _client.get<List<Purity>>(
      ApiEndpoints.metalPurities(metalId),
      parse: (data) => _list(data, Purity.fromJson),
    );
    for (final purity in result) {
      _purities[purity.id] = purity;
    }
  }

  Future<void> _loadCategories() async {
    final result = await _client.get<List<NamedRef>>(
      ApiEndpoints.productCategories,
      parse: (data) => _list(data, NamedRef.fromJson),
    );
    for (final category in result) {
      _categories[category.id] = category;
    }
  }

  Future<void> _loadProductTypes() async {
    final result = await _client.get<List<NamedRef>>(
      ApiEndpoints.productTypes,
      parse: (data) => _list(data, NamedRef.fromJson),
    );
    for (final type in result) {
      _productTypes[type.id] = type;
    }
  }

  /// Master endpoints return either a bare list or a paged envelope depending
  /// on the module, so both shapes are accepted.
  static List<T> _list<T>(Object? data, T Function(Map<String, dynamic>) from) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map(from).toList();
    }
    if (data is Map<String, dynamic> && data['content'] is List) {
      return (data['content'] as List)
          .whereType<Map<String, dynamic>>()
          .map(from)
          .toList();
    }
    return const [];
  }
}
