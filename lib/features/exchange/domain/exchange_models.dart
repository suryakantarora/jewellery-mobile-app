import '../../../shared/widgets/status_badge.dart';

enum ExchangeStatus {
  received('RECEIVED', 'Received', StatusTone.info),
  weighed('WEIGHED', 'Weighed', StatusTone.info),
  purityTested('PURITY_TESTED', 'Purity tested', StatusTone.info),
  valued('VALUED', 'Valued', StatusTone.warning),
  pendingApproval('PENDING_APPROVAL', 'Awaiting approval', StatusTone.warning),
  approved('APPROVED', 'Approved', StatusTone.success),
  rejected('REJECTED', 'Rejected', StatusTone.danger),
  completed('COMPLETED', 'Completed', StatusTone.success),
  returnedToCustomer('RETURNED_TO_CUSTOMER', 'Returned', StatusTone.neutral),
  cancelled('CANCELLED', 'Cancelled', StatusTone.neutral),
  unknown('UNKNOWN', 'Unknown', StatusTone.neutral);

  const ExchangeStatus(this.code, this.label, this.tone);
  final String code;
  final String label;
  final StatusTone tone;

  static ExchangeStatus fromCode(String? code) => values.firstWhere(
    (status) => status.code == code,
    orElse: () => ExchangeStatus.unknown,
  );
}

enum ExchangeType {
  exchange('EXCHANGE', 'Exchange'),
  buyback('BUYBACK', 'Buyback');

  const ExchangeType(this.code, this.label);
  final String code;
  final String label;

  static ExchangeType fromCode(String? code) => values.firstWhere(
    (type) => type.code == code,
    orElse: () => ExchangeType.buyback,
  );
}

/// An exchange or buyback.
///
/// **Every monetary and weight-derived figure on this class is server-supplied.**
/// There is deliberately no method that computes a valuation, applies a rate or
/// derives a net weight — the app posts inputs and renders what comes back.
/// The `ValuationRequest` contract confirms the design: the client sends only a
/// deduction percentage.
class ExchangeRecord {
  const ExchangeRecord({
    required this.id,
    required this.referenceNumber,
    required this.exchangeType,
    required this.status,
    required this.allowedTransitions,
    this.customerId,
    this.description,
    this.itemCount = 1,
    this.receivedDate,
    this.metalId,
    this.grossWeight,
    this.stoneWeight,
    this.netWeight,
    this.weighedBy,
    this.declaredPurityId,
    this.testedPurityId,
    this.testedFineness,
    this.testMethod,
    this.testedBy,
    this.ratePerUnit,
    this.pureWeight,
    this.grossValuation,
    this.deductionPercentage,
    this.deductionAmount,
    this.netValuation,
    this.currency,
    this.valuedBy,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.completedAt,
    this.notes,
  });

  final String id;
  final String referenceNumber;
  final ExchangeType exchangeType;
  final ExchangeStatus status;
  final Set<ExchangeStatus> allowedTransitions;

  final String? customerId;
  final String? description;
  final int itemCount;
  final DateTime? receivedDate;

  final String? metalId;

  /// Entered by staff.
  final double? grossWeight;
  final double? stoneWeight;

  /// Derived by the backend from gross minus stones.
  final double? netWeight;
  final String? weighedBy;

  final String? declaredPurityId;
  final String? testedPurityId;
  final double? testedFineness;
  final String? testMethod;
  final String? testedBy;

  /// All server-computed.
  final double? ratePerUnit;
  final double? pureWeight;
  final double? grossValuation;
  final double? deductionPercentage;
  final double? deductionAmount;
  final double? netValuation;
  final String? currency;
  final String? valuedBy;

  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final DateTime? completedAt;
  final String? notes;

  bool canTransitionTo(ExchangeStatus target) =>
      allowedTransitions.contains(target);

  factory ExchangeRecord.fromJson(Map<String, dynamic> json) => ExchangeRecord(
    id: json['id'] as String? ?? '',
    referenceNumber: json['referenceNumber'] as String? ?? '',
    exchangeType: ExchangeType.fromCode(json['exchangeType'] as String?),
    status: ExchangeStatus.fromCode(json['status'] as String?),
    allowedTransitions: ((json['allowedTransitions'] as List?) ?? const [])
        .whereType<String>()
        .map(ExchangeStatus.fromCode)
        .toSet(),
    customerId: json['customerId'] as String?,
    description: json['description'] as String?,
    itemCount: (json['itemCount'] as num?)?.toInt() ?? 1,
    receivedDate: DateTime.tryParse(json['receivedDate'] as String? ?? ''),
    metalId: json['metalId'] as String?,
    grossWeight: (json['grossWeight'] as num?)?.toDouble(),
    stoneWeight: (json['stoneWeight'] as num?)?.toDouble(),
    netWeight: (json['netWeight'] as num?)?.toDouble(),
    weighedBy: json['weighedBy'] as String?,
    declaredPurityId: json['declaredPurityId'] as String?,
    testedPurityId: json['testedPurityId'] as String?,
    testedFineness: (json['testedFineness'] as num?)?.toDouble(),
    testMethod: json['testMethod'] as String?,
    testedBy: json['testedBy'] as String?,
    ratePerUnit: (json['ratePerUnit'] as num?)?.toDouble(),
    pureWeight: (json['pureWeight'] as num?)?.toDouble(),
    grossValuation: (json['grossValuation'] as num?)?.toDouble(),
    deductionPercentage: (json['deductionPercentage'] as num?)?.toDouble(),
    deductionAmount: (json['deductionAmount'] as num?)?.toDouble(),
    netValuation: (json['netValuation'] as num?)?.toDouble(),
    currency: json['currency'] as String?,
    valuedBy: json['valuedBy'] as String?,
    approvedBy: json['approvedBy'] as String?,
    approvedAt: DateTime.tryParse(json['approvedAt'] as String? ?? ''),
    rejectionReason: json['rejectionReason'] as String?,
    completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
    notes: json['notes'] as String?,
  );
}
