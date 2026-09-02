import '../../../shared/widgets/status_badge.dart';

enum CustomerStatus {
  active('ACTIVE', 'Active', StatusTone.success),
  inactive('INACTIVE', 'Inactive', StatusTone.neutral),
  blacklisted('BLACKLISTED', 'Blacklisted', StatusTone.danger),
  unknown('UNKNOWN', 'Unknown', StatusTone.neutral);

  const CustomerStatus(this.code, this.label, this.tone);
  final String code;
  final String label;
  final StatusTone tone;

  static CustomerStatus fromCode(String? code) => values.firstWhere(
    (status) => status.code == code,
    orElse: () => CustomerStatus.unknown,
  );
}

enum KycStatus {
  notRequired('NOT_REQUIRED', 'Not required', StatusTone.neutral),
  pending('PENDING', 'KYC pending', StatusTone.warning),
  verified('VERIFIED', 'KYC verified', StatusTone.success),
  rejected('REJECTED', 'KYC rejected', StatusTone.danger),
  expired('EXPIRED', 'KYC expired', StatusTone.warning),
  unknown('UNKNOWN', 'Unknown', StatusTone.neutral);

  const KycStatus(this.code, this.label, this.tone);
  final String code;
  final String label;
  final StatusTone tone;

  static KycStatus fromCode(String? code) => values.firstWhere(
    (status) => status.code == code,
    orElse: () => KycStatus.unknown,
  );
}

class Customer {
  const Customer({
    required this.id,
    required this.customerCode,
    required this.fullName,
    this.customerType,
    this.companyName,
    this.phone,
    this.email,
    this.dateOfBirth,
    this.gender,
    this.status = CustomerStatus.active,
    this.kycStatus = KycStatus.notRequired,
    this.notes,
    this.documentCount = 0,
  });

  final String id;
  final String customerCode;
  final String fullName;
  final String? customerType;
  final String? companyName;
  final String? phone;
  final String? email;
  final DateTime? dateOfBirth;
  final String? gender;
  final CustomerStatus status;
  final KycStatus kycStatus;
  final String? notes;

  /// Documents are counted but never listed without `CUSTOMER_KYC_VERIFY`.
  final int documentCount;

  bool get isBlacklisted => status == CustomerStatus.blacklisted;

  String get displayName =>
      companyName?.isNotEmpty ?? false ? companyName! : fullName;

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'] as String? ?? '',
    customerCode: json['customerCode'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    customerType: json['customerType'] as String?,
    companyName: json['companyName'] as String?,
    phone: json['phone'] as String?,
    email: json['email'] as String?,
    dateOfBirth: DateTime.tryParse(json['dateOfBirth'] as String? ?? ''),
    gender: json['gender'] as String?,
    status: CustomerStatus.fromCode(json['status'] as String?),
    kycStatus: KycStatus.fromCode(json['kycStatus'] as String?),
    notes: json['notes'] as String?,
    documentCount: ((json['documents'] as List?) ?? const []).length,
  );
}

/// The Customer 360 payload — one call, as the backend documents it.
class Customer360 {
  const Customer360({
    required this.customerId,
    required this.customerCode,
    required this.fullName,
    this.phone,
    this.kycVerified = false,
    this.purchaseCount,
    this.purchaseTotal,
    this.purchaseCurrency,
    this.lastPurchaseAt,
    this.loyaltyTier,
    this.loyaltyPoints,
    this.recentActivity = const [],
    this.openFollowUps = const [],
  });

  final String customerId;
  final String customerCode;
  final String fullName;
  final String? phone;
  final bool kycVerified;

  final int? purchaseCount;
  final double? purchaseTotal;
  final String? purchaseCurrency;
  final DateTime? lastPurchaseAt;

  final String? loyaltyTier;
  final int? loyaltyPoints;

  final List<CustomerActivity> recentActivity;
  final List<FollowUp> openFollowUps;

  factory Customer360.fromJson(Map<String, dynamic> json) {
    final purchases = json['purchases'] as Map<String, dynamic>?;
    final loyalty = json['loyalty'] as Map<String, dynamic>?;

    return Customer360(
      customerId: json['customerId'] as String? ?? '',
      customerCode: json['customerCode'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      phone: json['phone'] as String?,
      kycVerified: json['kycVerified'] as bool? ?? false,
      purchaseCount:
          (purchases?['count'] ??
                  purchases?['purchaseCount'] ??
                  purchases?['totalOrders'])
              as int?,
      purchaseTotal:
          ((purchases?['totalAmount'] ??
                      purchases?['lifetimeValue'] ??
                      purchases?['total'])
                  as num?)
              ?.toDouble(),
      purchaseCurrency: purchases?['currency'] as String?,
      lastPurchaseAt: DateTime.tryParse(
        (purchases?['lastPurchaseAt'] ?? '') as String? ?? '',
      ),
      loyaltyTier: (loyalty?['tierCode'] ?? loyalty?['tier']) as String?,
      loyaltyPoints: ((loyalty?['pointsBalance'] ?? loyalty?['points']) as num?)
          ?.toInt(),
      recentActivity: ((json['recentActivity'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CustomerActivity.fromJson)
          .toList(growable: false),
      openFollowUps: ((json['openFollowUps'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FollowUp.fromJson)
          .toList(growable: false),
    );
  }
}

class CustomerActivity {
  const CustomerActivity({
    required this.id,
    required this.activityType,
    this.subject,
    this.notes,
    this.occurredAt,
    this.performedBy,
  });

  final String id;
  final String activityType;
  final String? subject;
  final String? notes;
  final DateTime? occurredAt;
  final String? performedBy;

  StatusTone get tone => switch (activityType) {
    'COMPLAINT' => StatusTone.danger,
    'FEEDBACK' => StatusTone.info,
    'VISIT' || 'MEETING' => StatusTone.success,
    _ => StatusTone.neutral,
  };

  factory CustomerActivity.fromJson(Map<String, dynamic> json) =>
      CustomerActivity(
        id: json['id'] as String? ?? '',
        activityType: json['activityType'] as String? ?? 'NOTE',
        subject: json['subject'] as String?,
        notes: json['notes'] as String?,
        occurredAt: DateTime.tryParse(
          (json['occurredAt'] ?? json['activityDate'] ?? '') as String? ?? '',
        ),
        performedBy: json['performedBy'] as String?,
      );
}

class FollowUp {
  const FollowUp({
    required this.id,
    required this.title,
    this.dueDate,
    this.assignedTo,
    this.customerId,
    this.notes,
  });

  final String id;
  final String title;
  final DateTime? dueDate;
  final String? assignedTo;
  final String? customerId;
  final String? notes;

  bool get isOverdue => dueDate != null && dueDate!.isBefore(DateTime.now());

  factory FollowUp.fromJson(Map<String, dynamic> json) => FollowUp(
    id: json['id'] as String? ?? '',
    title: (json['subject'] ?? json['title'] ?? 'Follow-up') as String,
    dueDate: DateTime.tryParse(
      (json['dueDate'] ?? json['dueAt'] ?? '') as String? ?? '',
    ),
    assignedTo: json['assignedTo'] as String?,
    customerId: json['customerId'] as String?,
    notes: json['notes'] as String?,
  );
}
