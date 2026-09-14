/// Small master-data records used to turn the UUIDs on an item into names.
///
/// `JewelleryItemResponse` carries `productId`, `metalId`, `purityId` and
/// `currentLocationId` but no display names, so rendering "22K Gold · Ladies
/// Ring · Counter 2" for a twenty-row list would otherwise need sixty extra
/// lookups. These types back the cache that solves it.
class NamedRef {
  const NamedRef({required this.id, required this.code, required this.name});

  final String id;
  final String code;
  final String name;

  factory NamedRef.fromJson(Map<String, dynamic> json) => NamedRef(
    id: json['id'] as String? ?? '',
    code: (json['code'] ?? json['designCode'] ?? json['sku'] ?? '') as String,
    name: json['name'] as String? ?? '',
  );
}

class Metal {
  const Metal({
    required this.id,
    required this.code,
    required this.name,
    this.symbol,
  });

  final String id;
  final String code;
  final String name;
  final String? symbol;

  factory Metal.fromJson(Map<String, dynamic> json) => Metal(
    id: json['id'] as String? ?? '',
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    symbol: json['symbol'] as String?,
  );
}

class Purity {
  const Purity({
    required this.id,
    required this.metalId,
    required this.code,
    required this.name,
    this.fineness,
  });

  final String id;
  final String metalId;

  /// The code staff actually say out loud — "22K", "925".
  final String code;

  final String name;
  final double? fineness;

  factory Purity.fromJson(Map<String, dynamic> json) => Purity(
    id: json['id'] as String? ?? '',
    metalId: json['metalId'] as String? ?? '',
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    fineness: (json['fineness'] as num?)?.toDouble(),
  );
}

class Product {
  const Product({
    required this.id,
    required this.sku,
    required this.name,
    this.designId,
    this.productTypeId,
    this.categoryId,
    this.defaultMetalId,
    this.defaultPurityId,
    this.nominalGrossWeight,
    this.primaryImageKey,
  });

  final String id;
  final String sku;
  final String name;
  final String? designId;
  final String? productTypeId;
  final String? categoryId;
  final String? defaultMetalId;
  final String? defaultPurityId;
  final double? nominalGrossWeight;

  /// Catalogue artwork shared by every item made to this product. Fetch the
  /// bytes via `GET /files?key=`.
  final String? primaryImageKey;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String? ?? '',
    sku: json['sku'] as String? ?? '',
    name: json['name'] as String? ?? '',
    designId: json['designId'] as String?,
    productTypeId: json['productTypeId'] as String?,
    categoryId: json['categoryId'] as String?,
    defaultMetalId: json['defaultMetalId'] as String?,
    defaultPurityId: json['defaultPurityId'] as String?,
    nominalGrossWeight: (json['nominalGrossWeight'] as num?)?.toDouble(),
    primaryImageKey: json['primaryImageKey'] as String?,
  );
}

class Design {
  const Design({
    required this.id,
    required this.designCode,
    required this.name,
    this.productTypeId,
    this.primaryImageKey,
  });

  final String id;
  final String designCode;
  final String name;
  final String? productTypeId;

  /// The design's reference image, when one has been uploaded.
  final String? primaryImageKey;

  factory Design.fromJson(Map<String, dynamic> json) => Design(
    id: json['id'] as String? ?? '',
    designCode: json['designCode'] as String? ?? '',
    name: json['name'] as String? ?? '',
    productTypeId: json['productTypeId'] as String?,
    primaryImageKey: json['primaryImageKey'] as String?,
  );
}

/// A metal rate, used for pricing context and staleness warnings.
///
/// The response denormalises `metalCode` and `purityCode`, so this needs no
/// lookup of its own.
class MetalRate {
  const MetalRate({
    required this.metalCode,
    required this.purityCode,
    required this.rateType,
    required this.ratePerUnit,
    required this.currency,
    this.effectiveDate,
    this.publishedAt,
  });

  final String metalCode;
  final String purityCode;
  final String rateType;
  final double ratePerUnit;
  final String currency;
  final DateTime? effectiveDate;
  final DateTime? publishedAt;

  factory MetalRate.fromJson(Map<String, dynamic> json) => MetalRate(
    metalCode: json['metalCode'] as String? ?? '',
    purityCode: json['purityCode'] as String? ?? '',
    rateType: json['rateType'] as String? ?? 'SELLING',
    ratePerUnit: (json['ratePerUnit'] as num?)?.toDouble() ?? 0,
    currency: json['currency'] as String? ?? 'LAK',
    effectiveDate: DateTime.tryParse(json['effectiveDate'] as String? ?? ''),
    publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
  );
}
