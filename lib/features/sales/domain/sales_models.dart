import '../../../shared/widgets/status_badge.dart';

/// A server-computed price breakdown.
///
/// Every figure here comes from `POST /pricing/calculate`. The app performs no
/// arithmetic on money or metal value — it renders what the backend returns.
/// That is why there is no constructor that takes a rate and a weight.
class PriceBreakdown {
  const PriceBreakdown({
    required this.itemCode,
    required this.finalPrice,
    required this.currency,
    this.metalRatePerUnit,
    this.netMetalWeight,
    this.metalValue,
    this.wastagePercentage,
    this.wastageValue,
    this.makingChargeType,
    this.makingCharge,
    this.stoneValue,
    this.subTotal,
    this.taxTotal,
    this.tierDiscountPercentage,
    this.discountAmount,
    this.loyaltyTierCode,
    this.discountRequiresApproval = false,
  });

  final String itemCode;
  final double finalPrice;
  final String currency;

  final double? metalRatePerUnit;
  final double? netMetalWeight;
  final double? metalValue;
  final double? wastagePercentage;
  final double? wastageValue;
  final String? makingChargeType;
  final double? makingCharge;
  final double? stoneValue;
  final double? subTotal;
  final double? taxTotal;
  final double? tierDiscountPercentage;
  final double? discountAmount;
  final String? loyaltyTierCode;

  /// The backend decides whether a discount needs authorising, not the client.
  final bool discountRequiresApproval;

  factory PriceBreakdown.fromJson(Map<String, dynamic> json) => PriceBreakdown(
    itemCode: json['itemCode'] as String? ?? '',
    finalPrice: (json['finalPrice'] as num?)?.toDouble() ?? 0,
    currency: json['currency'] as String? ?? 'LAK',
    metalRatePerUnit: (json['metalRatePerUnit'] as num?)?.toDouble(),
    netMetalWeight: (json['netMetalWeight'] as num?)?.toDouble(),
    metalValue: (json['metalValue'] as num?)?.toDouble(),
    wastagePercentage: (json['wastagePercentage'] as num?)?.toDouble(),
    wastageValue: (json['wastageValue'] as num?)?.toDouble(),
    makingChargeType: json['makingChargeType'] as String?,
    makingCharge: (json['makingCharge'] as num?)?.toDouble(),
    stoneValue: (json['stoneValue'] as num?)?.toDouble(),
    subTotal: (json['subTotal'] as num?)?.toDouble(),
    taxTotal: (json['taxTotal'] as num?)?.toDouble(),
    tierDiscountPercentage: (json['tierDiscountPercentage'] as num?)
        ?.toDouble(),
    discountAmount: (json['discountAmount'] as num?)?.toDouble(),
    loyaltyTierCode: json['loyaltyTierCode'] as String?,
    discountRequiresApproval:
        json['discountRequiresApproval'] as bool? ?? false,
  );
}

/// Stock of a product at one branch.
class BranchAvailability {
  const BranchAvailability({
    required this.branchId,
    required this.branchName,
    required this.available,
    this.total,
  });

  final String branchId;
  final String branchName;
  final int available;

  /// All pieces of the product at the branch, whatever their status.
  final int? total;

  bool get inStock => available > 0;

  factory BranchAvailability.fromJson(Map<String, dynamic> json) =>
      BranchAvailability(
        branchId: json['branchId'] as String? ?? '',
        branchName: json['branchName'] as String? ?? '',
        available: (json['available'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt(),
      );
}

/// `GET /inventory/availability?productId=` — one call, scoped by the backend
/// to the caller's branches, zeros included.
class ProductAvailability {
  const ProductAvailability({
    required this.productId,
    this.productName,
    this.branches = const [],
  });

  final String productId;
  final String? productName;
  final List<BranchAvailability> branches;

  factory ProductAvailability.fromJson(Map<String, dynamic> json) {
    final raw = json['branches'];
    return ProductAvailability(
      productId: json['productId'] as String? ?? '',
      productName: json['productName'] as String?,
      branches: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(BranchAvailability.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

enum DiscountRequestStatus {
  pending('PENDING', 'Pending', StatusTone.warning),
  approved('APPROVED', 'Approved', StatusTone.success),
  rejected('REJECTED', 'Rejected', StatusTone.danger),
  consumed('CONSUMED', 'Used', StatusTone.neutral),
  expired('EXPIRED', 'Expired', StatusTone.neutral),
  cancelled('CANCELLED', 'Cancelled', StatusTone.neutral),
  unknown('UNKNOWN', 'Unknown', StatusTone.neutral);

  const DiscountRequestStatus(this.code, this.label, this.tone);
  final String code;
  final String label;
  final StatusTone tone;

  static DiscountRequestStatus fromCode(String? code) => values.firstWhere(
    (status) => status.code == code,
    orElse: () => DiscountRequestStatus.unknown,
  );
}

/// A request for a discount beyond what the price policy allows.
///
/// Exactly one of [requestedPercentage] / [requestedAmount] is set. The app
/// never computes the discounted price — the sale's price comes from the
/// backend once the approved request is consumed.
class DiscountRequest {
  const DiscountRequest({
    required this.id,
    required this.branchId,
    required this.status,
    this.customerId,
    this.jewelleryItemId,
    this.quotationId,
    this.requestedPercentage,
    this.requestedAmount,
    this.currency,
    this.reason,
    this.requestedBy,
    this.requestedAt,
    this.decidedBy,
    this.decidedAt,
    this.decisionNote,
    this.expiresAt,
    this.consumedBySaleId,
  });

  final String id;
  final String branchId;
  final DiscountRequestStatus status;
  final String? customerId;
  final String? jewelleryItemId;
  final String? quotationId;
  final double? requestedPercentage;
  final double? requestedAmount;
  final String? currency;
  final String? reason;
  final String? requestedBy;
  final DateTime? requestedAt;
  final String? decidedBy;
  final DateTime? decidedAt;
  final String? decisionNote;
  final DateTime? expiresAt;
  final String? consumedBySaleId;

  bool get isPercentage => requestedPercentage != null;
  bool get canCancel => status == DiscountRequestStatus.pending;

  factory DiscountRequest.fromJson(Map<String, dynamic> json) =>
      DiscountRequest(
        id: json['id'] as String? ?? '',
        branchId: json['branchId'] as String? ?? '',
        status: DiscountRequestStatus.fromCode(json['status'] as String?),
        customerId: json['customerId'] as String?,
        jewelleryItemId: json['jewelleryItemId'] as String?,
        quotationId: json['quotationId'] as String?,
        requestedPercentage: (json['requestedPercentage'] as num?)?.toDouble(),
        requestedAmount: (json['requestedAmount'] as num?)?.toDouble(),
        currency: json['currency'] as String?,
        reason: json['reason'] as String?,
        requestedBy: json['requestedBy'] as String?,
        requestedAt: DateTime.tryParse(json['requestedAt'] as String? ?? ''),
        decidedBy: json['decidedBy'] as String?,
        decidedAt: DateTime.tryParse(json['decidedAt'] as String? ?? ''),
        decisionNote: json['decisionNote'] as String?,
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
        consumedBySaleId: json['consumedBySaleId'] as String?,
      );
}
