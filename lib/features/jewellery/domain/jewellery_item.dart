import '../../../shared/widgets/status_badge.dart';

/// Mirrors the backend's `ItemStatus`.
enum ItemStatus {
  draft('DRAFT', 'Draft', StatusTone.info),
  available('AVAILABLE', 'Available', StatusTone.success),
  reserved('RESERVED', 'Reserved', StatusTone.warning),
  inTransit('IN_TRANSIT', 'In transit', StatusTone.warning),
  sold('SOLD', 'Sold', StatusTone.neutral),
  underRepair('UNDER_REPAIR', 'Under repair', StatusTone.warning),
  returned('RETURNED', 'Returned', StatusTone.info),
  exchanged('EXCHANGED', 'Exchanged', StatusTone.neutral),
  buyback('BUYBACK', 'Buyback', StatusTone.vault),
  scrapped('SCRAPPED', 'Scrapped', StatusTone.danger),

  /// A status this build does not know. Rendered with its raw code rather than
  /// dropped, so a backend addition is visible instead of invisible.
  unknown('UNKNOWN', 'Unknown', StatusTone.neutral);

  const ItemStatus(this.code, this.label, this.tone);

  final String code;
  final String label;

  /// Shared semantic tone, so "pending" looks the same across every module.
  final StatusTone tone;

  static ItemStatus fromCode(String? code) => values.firstWhere(
    (status) => status.code == code,
    orElse: () => ItemStatus.unknown,
  );
}

/// A serialised jewellery item, mirroring `JewelleryItemResponse`.
class JewelleryItem {
  const JewelleryItem({
    required this.id,
    required this.itemCode,
    required this.status,
    required this.allowedTransitions,
    required this.grossWeight,
    this.productId,
    this.designId,
    this.metalId,
    this.purityId,
    this.binId,
    this.primaryImageKey,
    this.netMetalWeight,
    this.stoneWeight,
    this.stoneCount = 0,
    this.totalCarat,
    this.sizeId,
    this.rfidTag,
    this.qrCode,
    this.barcode,
    this.hallmarkNumber,
    this.purchaseCost,
    this.makingCost,
    this.stoneCost,
    this.totalCost,
    this.currentPrice,
    this.currency,
    this.currentLocationId,
    this.currentBranchId,
    this.reservedForCustomerId,
    this.reservedUntil,
    this.supplierId,
    this.receivedDate,
    this.soldDate,
    this.qualityChecked = false,
    this.notes,
    this.version = 0,
    this.productName,
    this.productCode,
    this.designName,
    this.metalName,
    this.purityCode,
    this.currentLocationName,
    this.currentBranchName,
    this.binCode,
    this.supplierName,
  });

  final String id;
  final String itemCode;
  final ItemStatus status;

  /// The backend's own state machine, returned with every item.
  ///
  /// Action buttons are `allowedTransitions ∩ permissions`, so the app never
  /// guesses whether something can be reserved or transferred.
  final Set<ItemStatus> allowedTransitions;

  final double grossWeight;
  final String? productId;
  final String? designId;
  final String? metalId;
  final String? purityId;

  /// The storage bin the piece sits in, within its current location.
  /// Null is normal: a counter needs no bin, and stock not yet put away has none.
  final String? binId;

  /// Storage key of the item's primary photograph, or null if it has none.
  ///
  /// Returned inline by the list endpoint so rendering a page of results costs
  /// no extra request per row. Fetch the bytes via `GET /files?key=`.
  final String? primaryImageKey;
  final double? netMetalWeight;
  final double? stoneWeight;
  final int stoneCount;
  final double? totalCarat;
  final String? sizeId;

  final String? rfidTag;
  final String? qrCode;
  final String? barcode;
  final String? hallmarkNumber;

  /// Cost fields. Gated behind `REPORT_VIEW` in the UI — a salesperson sees
  /// price, never cost.
  final double? purchaseCost;
  final double? makingCost;
  final double? stoneCost;
  final double? totalCost;

  final double? currentPrice;
  final String? currency;

  final String? currentLocationId;
  final String? currentBranchId;
  final String? reservedForCustomerId;
  final DateTime? reservedUntil;
  final String? supplierId;
  final DateTime? receivedDate;
  final DateTime? soldDate;
  final bool qualityChecked;
  final String? notes;

  /// Optimistic-lock token, sent back on mutations.
  final int version;

  /// Display names resolved by the server alongside the UUIDs above.
  ///
  /// Preferred over the reference cache wherever a name is rendered, because
  /// they are correct for *this* item even when the cache belongs to another
  /// branch or has not loaded the product yet. Null on older payloads, in which
  /// case the cache is the fallback.
  final String? productName;
  final String? productCode;
  final String? designName;
  final String? metalName;
  final String? purityCode;
  final String? currentLocationName;
  final String? currentBranchName;
  final String? binCode;
  final String? supplierName;

  /// "22K Gold" from the server-supplied names, or null when neither is known.
  String? get materialLabel {
    final label = [purityCode, metalName].whereType<String>().join(' ');
    return label.isEmpty ? null : label;
  }

  bool get isReserved => status == ItemStatus.reserved;
  bool get hasTags => rfidTag != null || qrCode != null || barcode != null;

  bool canTransitionTo(ItemStatus target) =>
      allowedTransitions.contains(target);

  factory JewelleryItem.fromJson(Map<String, dynamic> json) {
    return JewelleryItem(
      id: json['id'] as String? ?? '',
      itemCode: json['itemCode'] as String? ?? '',
      status: ItemStatus.fromCode(json['status'] as String?),
      allowedTransitions: ((json['allowedTransitions'] as List?) ?? const [])
          .whereType<String>()
          .map(ItemStatus.fromCode)
          .toSet(),
      grossWeight: (json['grossWeight'] as num?)?.toDouble() ?? 0,
      productId: json['productId'] as String?,
      designId: json['designId'] as String?,
      metalId: json['metalId'] as String?,
      purityId: json['purityId'] as String?,
      binId: json['binId'] as String?,
      primaryImageKey: json['primaryImageKey'] as String?,
      netMetalWeight: (json['netMetalWeight'] as num?)?.toDouble(),
      stoneWeight: (json['stoneWeight'] as num?)?.toDouble(),
      stoneCount: (json['stoneCount'] as num?)?.toInt() ?? 0,
      totalCarat: (json['totalCarat'] as num?)?.toDouble(),
      sizeId: json['sizeId'] as String?,
      rfidTag: json['rfidTag'] as String?,
      qrCode: json['qrCode'] as String?,
      barcode: json['barcode'] as String?,
      hallmarkNumber: json['hallmarkNumber'] as String?,
      purchaseCost: (json['purchaseCost'] as num?)?.toDouble(),
      makingCost: (json['makingCost'] as num?)?.toDouble(),
      stoneCost: (json['stoneCost'] as num?)?.toDouble(),
      totalCost: (json['totalCost'] as num?)?.toDouble(),
      currentPrice: (json['currentPrice'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      currentLocationId: json['currentLocationId'] as String?,
      currentBranchId: json['currentBranchId'] as String?,
      reservedForCustomerId: json['reservedForCustomerId'] as String?,
      reservedUntil: DateTime.tryParse(json['reservedUntil'] as String? ?? ''),
      supplierId: json['supplierId'] as String?,
      receivedDate: DateTime.tryParse(json['receivedDate'] as String? ?? ''),
      soldDate: DateTime.tryParse(json['soldDate'] as String? ?? ''),
      qualityChecked: json['qualityChecked'] as bool? ?? false,
      notes: json['notes'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 0,
      productName: json['productName'] as String?,
      productCode: json['productCode'] as String?,
      designName: json['designName'] as String?,
      metalName: json['metalName'] as String?,
      purityCode: json['purityCode'] as String?,
      currentLocationName: json['currentLocationName'] as String?,
      currentBranchName: json['currentBranchName'] as String?,
      binCode: json['binCode'] as String?,
      supplierName: json['supplierName'] as String?,
    );
  }
}

/// A stone set on an item.
class ItemStone {
  const ItemStone({
    required this.id,
    this.stoneType,
    this.shape,
    this.carat,
    this.count = 1,
    this.colour,
    this.clarity,
    this.cut,
    this.settingType,
    this.certificateNumber,
  });

  final String id;
  final String? stoneType;
  final String? shape;
  final double? carat;
  final int count;
  final String? colour;
  final String? clarity;
  final String? cut;
  final String? settingType;
  final String? certificateNumber;

  factory ItemStone.fromJson(Map<String, dynamic> json) => ItemStone(
    id: json['id'] as String? ?? '',
    stoneType: (json['stoneType'] ?? json['gemstoneName']) as String?,
    shape: json['shape'] as String?,
    carat: (json['caratWeight'] ?? json['carat']) is num
        ? ((json['caratWeight'] ?? json['carat']) as num).toDouble()
        : null,
    count: (json['stoneCount'] as num?)?.toInt() ?? 1,
    colour: (json['colour'] ?? json['color']) as String?,
    clarity: json['clarity'] as String?,
    cut: json['cut'] as String?,
    settingType: json['settingType'] as String?,
    certificateNumber: json['certificateNumber'] as String?,
  );
}

/// One entry in an item's lifecycle history.
class LifecycleEvent {
  const LifecycleEvent({
    required this.eventType,
    this.performedBy,
    this.occurredAt,
    this.notes,
    this.fromStatus,
    this.toStatus,
    this.locationId,
  });

  final String eventType;
  final String? performedBy;
  final DateTime? occurredAt;
  final String? notes;
  final String? fromStatus;
  final String? toStatus;
  final String? locationId;

  /// A readable label for the timeline. Unknown types fall back to a
  /// title-cased version of the raw code rather than being hidden.
  String get label => switch (eventType) {
    'CREATED' => 'Created',
    'QUALITY_CHECKED' => 'Quality checked',
    'TAGGED' => 'Tagged',
    'STATUS_CHANGED' => 'Status changed',
    'LOCATION_CHANGED' => 'Moved',
    'RESERVED' => 'Reserved',
    'RESERVATION_RELEASED' => 'Reservation released',
    'PRICE_UPDATED' => 'Price updated',
    'SOLD' => 'Sold',
    'RETURNED' => 'Returned',
    'REPAIRED' => 'Repaired',
    'EXCHANGED' => 'Exchanged',
    'BOUGHT_BACK' => 'Bought back',
    'SCRAPPED' => 'Scrapped',
    _ =>
      eventType
          .split('_')
          .map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}')
          .join(' '),
  };

  StatusTone get tone => switch (eventType) {
    'CREATED' || 'TAGGED' => StatusTone.info,
    'QUALITY_CHECKED' => StatusTone.success,
    'SOLD' || 'EXCHANGED' || 'BOUGHT_BACK' => StatusTone.neutral,
    'SCRAPPED' => StatusTone.danger,
    'RESERVED' || 'STATUS_CHANGED' => StatusTone.warning,
    _ => StatusTone.info,
  };

  factory LifecycleEvent.fromJson(Map<String, dynamic> json) => LifecycleEvent(
    eventType: json['eventType'] as String? ?? 'UNKNOWN',
    performedBy: json['performedBy'] as String?,
    occurredAt: DateTime.tryParse(json['occurredAt'] as String? ?? ''),
    notes: json['notes'] as String?,
    fromStatus: json['fromStatus'] as String?,
    toStatus: json['toStatus'] as String?,
    locationId: json['locationId'] as String?,
  );
}

/// The digital passport: identity, stones and full lifecycle history.
class ItemPassport {
  const ItemPassport({
    required this.item,
    this.stones = const [],
    this.history = const [],
  });

  final JewelleryItem item;
  final List<ItemStone> stones;
  final List<LifecycleEvent> history;

  factory ItemPassport.fromJson(Map<String, dynamic> json) => ItemPassport(
    item: JewelleryItem.fromJson(
      (json['item'] as Map<String, dynamic>?) ?? const {},
    ),
    stones: ((json['stones'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ItemStone.fromJson)
        .toList(growable: false),
    history: ((json['history'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LifecycleEvent.fromJson)
        .toList(growable: false),
  );
}
