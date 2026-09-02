/// A branch, mirroring the backend's `BranchResponse`.
class Branch {
  const Branch({
    required this.id,
    required this.companyId,
    required this.code,
    required this.name,
    this.headOffice = false,
    this.city,
    this.country,
    this.timezone,
    this.status = OrganizationStatus.active,
  });

  final String id;
  final String companyId;
  final String code;
  final String name;
  final bool headOffice;
  final String? city;
  final String? country;

  /// Reports must use the branch's day, not the device's, so the timezone is
  /// carried through rather than assumed.
  final String? timezone;

  final OrganizationStatus status;

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
    id: json['id'] as String? ?? '',
    companyId: json['companyId'] as String? ?? '',
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    headOffice: json['headOffice'] as bool? ?? false,
    city: json['city'] as String?,
    country: json['country'] as String?,
    timezone: json['timezone'] as String?,
    status: OrganizationStatus.fromName(json['status'] as String?),
  );
}

/// A physical location inside a branch.
class BranchLocation {
  const BranchLocation({
    required this.id,
    required this.branchId,
    required this.code,
    required this.name,
    required this.type,
    this.dualAuthorization = false,
  });

  final String id;
  final String branchId;
  final String code;
  final String name;
  final LocationType type;

  /// Whether movements out of this location need two approvals. Set on vaults;
  /// consumed by the high-value flows in Phase 8.
  final bool dualAuthorization;

  factory BranchLocation.fromJson(Map<String, dynamic> json) => BranchLocation(
    id: json['id'] as String? ?? '',
    branchId: json['branchId'] as String? ?? '',
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    type: LocationType.fromName(json['type'] as String?),
    dualAuthorization: json['dualAuthorization'] as bool? ?? false,
  );
}

/// The institution. `UserResponse` carries no company, so this is resolved from
/// the selected branch's `companyId` and cached for the session.
class Company {
  const Company({
    required this.id,
    required this.code,
    required this.name,
    this.legalName,
    this.baseCurrency,
  });

  final String id;
  final String code;
  final String name;
  final String? legalName;

  /// The institution's trading currency. Preferred over a device default where
  /// the app has to choose one itself.
  final String? baseCurrency;

  factory Company.fromJson(Map<String, dynamic> json) => Company(
    id: json['id'] as String? ?? '',
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    legalName: json['legalName'] as String?,
    baseCurrency: json['baseCurrency'] as String?,
  );
}

enum OrganizationStatus {
  active('ACTIVE'),
  inactive('INACTIVE');

  const OrganizationStatus(this.code);
  final String code;

  static OrganizationStatus fromName(String? value) => values.firstWhere(
    (status) => status.code == value,
    orElse: () => OrganizationStatus.active,
  );
}

/// Mirrors the backend's `LocationType`.
enum LocationType {
  headOffice('HEAD_OFFICE', 'Head Office'),
  centralWarehouse('CENTRAL_WAREHOUSE', 'Central Warehouse'),
  branchWarehouse('BRANCH_WAREHOUSE', 'Branch Warehouse'),
  showroom('SHOWROOM', 'Showroom'),
  counter('COUNTER', 'Counter'),
  vault('VAULT', 'Vault'),
  storeRoom('STORE_ROOM', 'Store Room'),
  inTransit('IN_TRANSIT', 'In Transit');

  const LocationType(this.code, this.label);
  final String code;
  final String label;

  static LocationType fromName(String? value) => values.firstWhere(
    (type) => type.code == value,
    orElse: () => LocationType.showroom,
  );
}
