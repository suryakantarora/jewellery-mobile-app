import '../../../shared/widgets/status_badge.dart';

/// Mirrors the backend's `MovementStatus`.
enum MovementStatus {
  draft('DRAFT', 'Draft', StatusTone.info),
  pendingApproval('PENDING_APPROVAL', 'Awaiting approval', StatusTone.warning),
  approved('APPROVED', 'Approved', StatusTone.success),
  rejected('REJECTED', 'Rejected', StatusTone.danger),
  dispatched('DISPATCHED', 'In transit', StatusTone.warning),
  completed('COMPLETED', 'Completed', StatusTone.success),
  cancelled('CANCELLED', 'Cancelled', StatusTone.neutral),
  unknown('UNKNOWN', 'Unknown', StatusTone.neutral);

  const MovementStatus(this.code, this.label, this.tone);

  final String code;
  final String label;
  final StatusTone tone;

  static MovementStatus fromCode(String? code) => values.firstWhere(
    (status) => status.code == code,
    orElse: () => MovementStatus.unknown,
  );
}

/// Mirrors the backend's `MovementType`.
///
/// Note that "issue" and "return" — the warehouse operations in Phase 8 — are
/// movement types on this same endpoint, not a separate domain.
enum MovementType {
  goodsReceipt('GOODS_RECEIPT', 'Goods receipt'),
  transfer('TRANSFER', 'Transfer'),
  issue('ISSUE', 'Issue'),
  returned('RETURN', 'Return'),
  adjustment('ADJUSTMENT', 'Adjustment'),
  saleDelivery('SALE_DELIVERY', 'Sale delivery'),
  saleReturn('SALE_RETURN', 'Sale return'),
  repairOut('REPAIR_OUT', 'Repair out'),
  repairIn('REPAIR_IN', 'Repair in'),
  scrap('SCRAP', 'Scrap'),
  unknown('UNKNOWN', 'Movement');

  const MovementType(this.code, this.label);

  final String code;
  final String label;

  static MovementType fromCode(String? code) => values.firstWhere(
    (type) => type.code == code,
    orElse: () => MovementType.unknown,
  );
}

/// One line on a movement.
///
/// Carries a denormalised `itemCode`, so a transfer's contents render without
/// any reference lookup — unlike the item endpoints.
class MovementLine {
  const MovementLine({
    required this.id,
    required this.jewelleryItemId,
    required this.itemCode,
    this.dispatchedWeight,
    this.receivedWeight,
    this.received = false,
    this.discrepancyNote,
  });

  final String id;
  final String jewelleryItemId;
  final String itemCode;
  final double? dispatchedWeight;
  final double? receivedWeight;
  final bool received;
  final String? discrepancyNote;

  /// Non-zero when the item was re-weighed on arrival and differs.
  double? get weightDelta =>
      (dispatchedWeight != null && receivedWeight != null)
      ? receivedWeight! - dispatchedWeight!
      : null;

  factory MovementLine.fromJson(Map<String, dynamic> json) => MovementLine(
    id: json['id'] as String? ?? '',
    jewelleryItemId: json['jewelleryItemId'] as String? ?? '',
    itemCode: json['itemCode'] as String? ?? '',
    dispatchedWeight: (json['dispatchedWeight'] as num?)?.toDouble(),
    receivedWeight: (json['receivedWeight'] as num?)?.toDouble(),
    received: json['received'] as bool? ?? false,
    discrepancyNote: json['discrepancyNote'] as String?,
  );
}

/// A stock movement, mirroring `MovementResponse`.
class Movement {
  const Movement({
    required this.id,
    required this.referenceNumber,
    required this.movementType,
    required this.status,
    this.fromLocationId,
    this.toLocationId,
    this.fromBranchId,
    this.toBranchId,
    this.requiresApproval = false,
    this.approvedBy,
    this.approvedAt,
    this.secondApprovedBy,
    this.secondApprovedAt,
    this.dispatchedBy,
    this.dispatchedAt,
    this.receivedBy,
    this.completedAt,
    this.rejectionReason,
    this.notes,
    this.lines = const [],
    this.createdAt,
    this.createdBy,
  });

  final String id;
  final String referenceNumber;
  final MovementType movementType;
  final MovementStatus status;

  final String? fromLocationId;
  final String? toLocationId;
  final String? fromBranchId;
  final String? toBranchId;

  final bool requiresApproval;

  final String? approvedBy;
  final DateTime? approvedAt;

  /// The backend models **dual authorisation** for high-value movements, so a
  /// movement can be one of two approvals in. Phase 8 depends on this.
  final String? secondApprovedBy;
  final DateTime? secondApprovedAt;

  final String? dispatchedBy;
  final DateTime? dispatchedAt;
  final String? receivedBy;
  final DateTime? completedAt;
  final String? rejectionReason;
  final String? notes;

  final List<MovementLine> lines;
  final DateTime? createdAt;
  final String? createdBy;

  int get itemCount => lines.length;

  bool get awaitingSecondApproval =>
      requiresApproval && approvedBy != null && secondApprovedBy == null;

  /// Total weight moving, for the summary line.
  double get totalWeight =>
      lines.fold(0, (sum, line) => sum + (line.dispatchedWeight ?? 0));

  factory Movement.fromJson(Map<String, dynamic> json) => Movement(
    id: json['id'] as String? ?? '',
    referenceNumber: json['referenceNumber'] as String? ?? '',
    movementType: MovementType.fromCode(json['movementType'] as String?),
    status: MovementStatus.fromCode(json['status'] as String?),
    fromLocationId: json['fromLocationId'] as String?,
    toLocationId: json['toLocationId'] as String?,
    fromBranchId: json['fromBranchId'] as String?,
    toBranchId: json['toBranchId'] as String?,
    requiresApproval: json['requiresApproval'] as bool? ?? false,
    approvedBy: json['approvedBy'] as String?,
    approvedAt: DateTime.tryParse(json['approvedAt'] as String? ?? ''),
    secondApprovedBy: json['secondApprovedBy'] as String?,
    secondApprovedAt: DateTime.tryParse(
      json['secondApprovedAt'] as String? ?? '',
    ),
    dispatchedBy: json['dispatchedBy'] as String?,
    dispatchedAt: DateTime.tryParse(json['dispatchedAt'] as String? ?? ''),
    receivedBy: json['receivedBy'] as String?,
    completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
    rejectionReason: json['rejectionReason'] as String?,
    notes: json['notes'] as String?,
    lines: ((json['lines'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MovementLine.fromJson)
        .toList(growable: false),
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    createdBy: json['createdBy'] as String?,
  );
}
