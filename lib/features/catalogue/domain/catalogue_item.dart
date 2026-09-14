/// A piece as a customer should see it.
///
/// Mirrors `CatalogueItemResponse`. There is no cost, supplier, location or bin
/// field here because the endpoint does not return them — the response was
/// designed so that a screen shown to a customer cannot leak what a customer
/// must never see, even by accident.
class CatalogueItem {
  const CatalogueItem({
    required this.id,
    required this.itemCode,
    required this.productName,
    this.categoryName,
    this.typeName,
    this.metalName,
    this.purityCode,
    this.purityName,
    this.grossWeight,
    this.netMetalWeight,
    this.stoneCount = 0,
    this.totalCarat,
    this.hallmarkNumber,
    this.primaryImageKey,
    this.fallbackImageKey,
    this.price,
    this.currency,
  });

  final String id;
  final String itemCode;
  final String productName;
  final String? categoryName;
  final String? typeName;
  final String? metalName;
  final String? purityCode;
  final String? purityName;
  final double? grossWeight;
  final double? netMetalWeight;
  final int stoneCount;
  final double? totalCarat;
  final String? hallmarkNumber;
  final String? primaryImageKey;

  /// Design or product artwork, for pieces without their own photo.
  final String? fallbackImageKey;

  /// What to show: the piece itself, else its catalogue artwork.
  String? get displayImageKey => primaryImageKey ?? fallbackImageKey;

  /// Priced live by the backend. Null when it could not be priced — usually a
  /// missing metal rate — and the screen says so rather than showing a zero.
  final double? price;
  final String? currency;

  /// "22K Gold", the way staff and customers actually say it.
  String get material => [purityCode, metalName].whereType<String>().join(' ');

  factory CatalogueItem.fromJson(Map<String, dynamic> json) => CatalogueItem(
    id: json['id'] as String? ?? '',
    itemCode: json['itemCode'] as String? ?? '',
    productName: json['productName'] as String? ?? '',
    categoryName: json['categoryName'] as String?,
    typeName: json['typeName'] as String?,
    metalName: json['metalName'] as String?,
    purityCode: json['purityCode'] as String?,
    purityName: json['purityName'] as String?,
    grossWeight: (json['grossWeight'] as num?)?.toDouble(),
    netMetalWeight: (json['netMetalWeight'] as num?)?.toDouble(),
    stoneCount: (json['stoneCount'] as num?)?.toInt() ?? 0,
    totalCarat: (json['totalCarat'] as num?)?.toDouble(),
    hallmarkNumber: json['hallmarkNumber'] as String?,
    primaryImageKey: json['primaryImageKey'] as String?,
    fallbackImageKey: json['fallbackImageKey'] as String?,
    price: (json['price'] as num?)?.toDouble(),
    currency: json['currency'] as String?,
  );
}
