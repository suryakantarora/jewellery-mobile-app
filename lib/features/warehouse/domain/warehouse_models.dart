import '../../../shared/widgets/status_badge.dart';

/// Mirrors the backend's `StockCountStatus`.
enum StockCountStatus {
  inProgress('IN_PROGRESS', 'In progress', StatusTone.warning),
  pendingReview('PENDING_REVIEW', 'Pending review', StatusTone.info),
  approved('APPROVED', 'Approved', StatusTone.success),
  closed('CLOSED', 'Closed', StatusTone.neutral),
  cancelled('CANCELLED', 'Cancelled', StatusTone.neutral),
  unknown('UNKNOWN', 'Unknown', StatusTone.neutral);

  const StockCountStatus(this.code, this.label, this.tone);

  final String code;
  final String label;
  final StatusTone tone;

  static StockCountStatus fromCode(String? code) => values.firstWhere(
    (status) => status.code == code,
    orElse: () => StockCountStatus.unknown,
  );
}

/// Mirrors the backend's `BinType`.
enum BinType {
  zone('ZONE', 'Zone'),
  shelf('SHELF', 'Shelf'),
  tray('TRAY', 'Tray'),
  bin('BIN', 'Bin'),
  safe('SAFE', 'Safe'),
  unknown('UNKNOWN', 'Bin');

  const BinType(this.code, this.label);

  final String code;
  final String label;

  static BinType fromCode(String? code) => values.firstWhere(
    (type) => type.code == code,
    orElse: () => BinType.unknown,
  );
}

/// A storage bin inside a location.
class StorageBin {
  const StorageBin({
    required this.id,
    required this.locationId,
    required this.code,
    required this.name,
    required this.type,
    this.parentId,
    this.active = true,
  });

  final String id;
  final String locationId;
  final String code;
  final String name;
  final BinType type;
  final String? parentId;
  final bool active;

  factory StorageBin.fromJson(Map<String, dynamic> json) => StorageBin(
    id: json['id'] as String? ?? '',
    locationId: json['locationId'] as String? ?? '',
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    type: BinType.fromCode(json['binType'] as String?),
    parentId: json['parentId'] as String?,
    active: json['active'] as bool? ?? true,
  );
}

/// A physical stock count.
class StockCount {
  const StockCount({
    required this.id,
    required this.referenceNumber,
    required this.status,
    this.locationId,
    this.branchId,
    this.expectedCount = 0,
    this.countedCount = 0,
    this.missingCount = 0,
    this.unexpectedCount = 0,
    this.hasVariance = false,
    this.dualAuthorization = false,
    this.countedBy,
    this.countedAt,
    this.approvedBy,
    this.approvedAt,
    this.secondApprovedBy,
    this.secondApprovedAt,
    this.notes,
    this.lines = const [],
  });

  final String id;
  final String referenceNumber;
  final StockCountStatus status;
  final String? locationId;
  final String? branchId;
  final int expectedCount;
  final int countedCount;

  /// The backend does the reconciliation; the app displays it. Computing these
  /// client-side would risk disagreeing with the record of truth.
  final int missingCount;
  final int unexpectedCount;
  final bool hasVariance;

  /// Vault counts require two approvers, mirroring high-value movements.
  final bool dualAuthorization;

  final String? countedBy;
  final DateTime? countedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? secondApprovedBy;
  final DateTime? secondApprovedAt;

  final String? notes;
  final List<StockCountLine> lines;

  bool get awaitingSecondApproval =>
      dualAuthorization && approvedBy != null && secondApprovedBy == null;

  factory StockCount.fromJson(Map<String, dynamic> json) => StockCount(
    id: json['id'] as String? ?? '',
    referenceNumber:
        (json['referenceNumber'] ?? json['countNumber'] ?? '') as String,
    status: StockCountStatus.fromCode(json['status'] as String?),
    locationId: json['locationId'] as String?,
    branchId: json['branchId'] as String?,
    expectedCount: (json['expectedCount'] as num?)?.toInt() ?? 0,
    countedCount: (json['countedCount'] as num?)?.toInt() ?? 0,
    missingCount: (json['missingCount'] as num?)?.toInt() ?? 0,
    unexpectedCount: (json['unexpectedCount'] as num?)?.toInt() ?? 0,
    hasVariance: json['hasVariance'] as bool? ?? false,
    dualAuthorization: json['dualAuthorization'] as bool? ?? false,
    countedBy: json['countedBy'] as String?,
    countedAt: DateTime.tryParse(json['countedAt'] as String? ?? ''),
    approvedBy: json['approvedBy'] as String?,
    approvedAt: DateTime.tryParse(json['approvedAt'] as String? ?? ''),
    secondApprovedBy: json['secondApprovedBy'] as String?,
    secondApprovedAt: DateTime.tryParse(
      json['secondApprovedAt'] as String? ?? '',
    ),
    notes: json['notes'] as String?,
    lines: ((json['lines'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(StockCountLine.fromJson)
        .toList(growable: false),
  );
}

/// One expected item on a count.
class StockCountLine {
  const StockCountLine({
    required this.jewelleryItemId,
    required this.itemCode,
    this.expected = true,
    this.counted = false,
    this.missing = false,
    this.unexpected = false,
    this.binId,
    this.varianceNote,
  });

  final String jewelleryItemId;
  final String itemCode;

  /// The backend classifies each line; the app renders that classification
  /// rather than deriving its own, so the two can never disagree.
  final bool expected;
  final bool counted;
  final bool missing;
  final bool unexpected;

  final String? binId;
  final String? varianceNote;

  factory StockCountLine.fromJson(Map<String, dynamic> json) => StockCountLine(
    jewelleryItemId: json['jewelleryItemId'] as String? ?? '',
    itemCode: json['itemCode'] as String? ?? '',
    expected: json['expected'] as bool? ?? true,
    counted: json['counted'] as bool? ?? false,
    missing: json['missing'] as bool? ?? false,
    unexpected: json['unexpected'] as bool? ?? false,
    binId: json['binId'] as String?,
    varianceNote: json['varianceNote'] as String?,
  );
}
