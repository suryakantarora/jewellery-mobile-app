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
  });

  final String branchId;
  final String branchName;
  final int available;

  bool get inStock => available > 0;
}
