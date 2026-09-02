import '../../../shared/widgets/status_badge.dart';

/// Mirrors `PurchaseOrderStatus`.
enum PurchaseOrderStatus {
  draft('DRAFT', 'Draft', StatusTone.info),
  pendingApproval('PENDING_APPROVAL', 'Awaiting approval', StatusTone.warning),
  approved('APPROVED', 'Approved', StatusTone.success),
  rejected('REJECTED', 'Rejected', StatusTone.danger),
  partiallyReceived(
    'PARTIALLY_RECEIVED',
    'Partly received',
    StatusTone.warning,
  ),
  received('RECEIVED', 'Received', StatusTone.success),
  cancelled('CANCELLED', 'Cancelled', StatusTone.neutral),
  closed('CLOSED', 'Closed', StatusTone.neutral),
  unknown('UNKNOWN', 'Unknown', StatusTone.neutral);

  const PurchaseOrderStatus(this.code, this.label, this.tone);

  final String code;
  final String label;
  final StatusTone tone;

  /// Only an approved or partly received order can accept goods.
  bool get canReceive =>
      this == PurchaseOrderStatus.approved ||
      this == PurchaseOrderStatus.partiallyReceived;

  static PurchaseOrderStatus fromCode(String? code) => values.firstWhere(
    (status) => status.code == code,
    orElse: () => PurchaseOrderStatus.unknown,
  );
}

/// Mirrors `GoodsReceiptStatus`.
enum GoodsReceiptStatus {
  draft('DRAFT', 'Draft', StatusTone.info),
  pendingQualityCheck(
    'PENDING_QUALITY_CHECK',
    'Pending QC',
    StatusTone.warning,
  ),
  accepted('ACCEPTED', 'Accepted', StatusTone.success),
  rejected('REJECTED', 'Rejected', StatusTone.danger),
  cancelled('CANCELLED', 'Cancelled', StatusTone.neutral),
  unknown('UNKNOWN', 'Unknown', StatusTone.neutral);

  const GoodsReceiptStatus(this.code, this.label, this.tone);

  final String code;
  final String label;
  final StatusTone tone;

  static GoodsReceiptStatus fromCode(String? code) => values.firstWhere(
    (status) => status.code == code,
    orElse: () => GoodsReceiptStatus.unknown,
  );
}

class PurchaseOrderLine {
  const PurchaseOrderLine({
    required this.id,
    this.productId,
    this.description,
    this.orderedQuantity = 0,
    this.receivedQuantity = 0,
    this.unitPrice,
    this.lineTotal,
  });

  final String id;
  final String? productId;
  final String? description;
  final int orderedQuantity;
  final int receivedQuantity;
  final double? unitPrice;
  final double? lineTotal;

  int get outstanding => (orderedQuantity - receivedQuantity).clamp(0, 1 << 31);
  bool get isComplete => receivedQuantity >= orderedQuantity;

  double get progress =>
      orderedQuantity == 0 ? 0 : receivedQuantity / orderedQuantity;

  factory PurchaseOrderLine.fromJson(Map<String, dynamic> json) =>
      PurchaseOrderLine(
        id: json['id'] as String? ?? '',
        productId: json['productId'] as String?,
        description: json['description'] as String?,
        orderedQuantity: (json['orderedQuantity'] as num?)?.toInt() ?? 0,
        receivedQuantity: (json['receivedQuantity'] as num?)?.toInt() ?? 0,
        unitPrice: (json['unitPrice'] as num?)?.toDouble(),
        lineTotal: (json['lineTotal'] as num?)?.toDouble(),
      );
}

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    this.supplierId,
    this.deliveryLocationId,
    this.orderDate,
    this.expectedDeliveryDate,
    this.currency,
    this.estimatedTotal,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.notes,
    this.lines = const [],
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String orderNumber;
  final PurchaseOrderStatus status;
  final String? supplierId;
  final String? deliveryLocationId;
  final DateTime? orderDate;
  final DateTime? expectedDeliveryDate;
  final String? currency;
  final double? estimatedTotal;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? notes;
  final List<PurchaseOrderLine> lines;
  final String? createdBy;
  final DateTime? createdAt;

  int get orderedTotal =>
      lines.fold(0, (sum, line) => sum + line.orderedQuantity);
  int get receivedTotal =>
      lines.fold(0, (sum, line) => sum + line.receivedQuantity);

  double get receiptProgress =>
      orderedTotal == 0 ? 0 : receivedTotal / orderedTotal;

  bool get isOverdue =>
      expectedDeliveryDate != null &&
      status.canReceive &&
      expectedDeliveryDate!.isBefore(DateTime.now());

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) => PurchaseOrder(
    id: json['id'] as String? ?? '',
    orderNumber: json['orderNumber'] as String? ?? '',
    status: PurchaseOrderStatus.fromCode(json['status'] as String?),
    supplierId: json['supplierId'] as String?,
    deliveryLocationId: json['deliveryLocationId'] as String?,
    orderDate: DateTime.tryParse(json['orderDate'] as String? ?? ''),
    expectedDeliveryDate: DateTime.tryParse(
      json['expectedDeliveryDate'] as String? ?? '',
    ),
    currency: json['currency'] as String?,
    estimatedTotal: (json['estimatedTotal'] as num?)?.toDouble(),
    approvedBy: json['approvedBy'] as String?,
    approvedAt: DateTime.tryParse(json['approvedAt'] as String? ?? ''),
    rejectionReason: json['rejectionReason'] as String?,
    notes: json['notes'] as String?,
    lines: ((json['lines'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PurchaseOrderLine.fromJson)
        .toList(growable: false),
    createdBy: json['createdBy'] as String?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );
}

class GoodsReceipt {
  const GoodsReceipt({
    required this.id,
    required this.receiptNumber,
    required this.status,
    this.purchaseOrderId,
    this.supplierId,
    this.locationId,
    this.receiptDate,
    this.supplierDeliveryNote,
    this.qualityCheckedBy,
    this.qualityCheckedAt,
    this.rejectionReason,
    this.notes,
    this.createdBy,
  });

  final String id;
  final String receiptNumber;
  final GoodsReceiptStatus status;
  final String? purchaseOrderId;
  final String? supplierId;
  final String? locationId;
  final DateTime? receiptDate;
  final String? supplierDeliveryNote;
  final String? qualityCheckedBy;
  final DateTime? qualityCheckedAt;
  final String? rejectionReason;
  final String? notes;
  final String? createdBy;

  factory GoodsReceipt.fromJson(Map<String, dynamic> json) => GoodsReceipt(
    id: json['id'] as String? ?? '',
    receiptNumber: json['receiptNumber'] as String? ?? '',
    status: GoodsReceiptStatus.fromCode(json['status'] as String?),
    purchaseOrderId: json['purchaseOrderId'] as String?,
    supplierId: json['supplierId'] as String?,
    locationId: json['locationId'] as String?,
    receiptDate: DateTime.tryParse(json['receiptDate'] as String? ?? ''),
    supplierDeliveryNote: json['supplierDeliveryNote'] as String?,
    qualityCheckedBy: json['qualityCheckedBy'] as String?,
    qualityCheckedAt: DateTime.tryParse(
      json['qualityCheckedAt'] as String? ?? '',
    ),
    rejectionReason: json['rejectionReason'] as String?,
    notes: json['notes'] as String?,
    createdBy: json['createdBy'] as String?,
  );
}

class Supplier {
  const Supplier({
    required this.id,
    required this.code,
    required this.name,
    this.phone,
    this.email,
    this.city,
    this.country,
    this.currency,
    this.paymentTermsDays,
  });

  final String id;
  final String code;
  final String name;
  final String? phone;
  final String? email;
  final String? city;
  final String? country;
  final String? currency;
  final int? paymentTermsDays;

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
    id: json['id'] as String? ?? '',
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String?,
    email: json['email'] as String?,
    city: json['city'] as String?,
    country: json['country'] as String?,
    currency: json['currency'] as String?,
    paymentTermsDays: (json['paymentTermsDays'] as num?)?.toInt(),
  );
}
