import '../../core/constants/permissions.dart';

/// The authenticated user, mirroring the backend's `UserResponse`.
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.permissions,
    this.email,
    this.phone,
    this.employeeCode,
    this.status = UserStatus.active,
    this.primaryBranchId,
    this.branchIds = const [],
    this.roles = const [],
    this.lastLoginAt,
    this.companyId,
    this.companyName,
  });

  final String id;
  final String username;
  final String fullName;
  final String? email;
  final String? phone;
  final String? employeeCode;
  final UserStatus status;

  /// Default branch, used to preselect when the user has several.
  final String? primaryBranchId;

  /// Every branch this user may act in. The backend enforces it; the app uses
  /// it to scope the branch picker and cross-branch lookups.
  final List<String> branchIds;

  final List<String> roles;

  /// Parsed permission codes. Roles are never branched on in UI code — only
  /// permissions are, because roles are configurable per deployment.
  final PermissionSet permissions;

  final DateTime? lastLoginAt;

  /// The tenant the user belongs to. Null only for platform super admins, who
  /// act across every company. Sent by the backend since company scoping
  /// landed (14 Sep 2026); absent on older responses, so both stay nullable.
  final String? companyId;
  final String? companyName;

  /// A user without a company is a platform administrator.
  bool get isPlatformUser => companyId == null;

  bool get hasMultipleBranches => branchIds.length > 1;
  bool get hasNoBranch => branchIds.isEmpty;
  bool get canSignIn => status == UserStatus.active;

  /// Initials for the avatar, derived defensively — names arrive in many shapes.
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'))
      ..removeWhere((part) => part.isEmpty);
    if (parts.isEmpty) {
      return username.isEmpty ? '?' : username[0].toUpperCase();
    }
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final permissionCodes =
        (json['permissions'] as List?)?.whereType<String>().toList() ??
        const [];
    final roles =
        (json['roles'] as List?)?.whereType<String>().toList() ?? const [];

    return AppUser(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      employeeCode: json['employeeCode'] as String?,
      status: UserStatus.fromName(json['status'] as String?),
      primaryBranchId: json['primaryBranchId'] as String?,
      branchIds:
          (json['branchIds'] as List?)?.whereType<String>().toList() ??
          const [],
      roles: roles,
      permissions: PermissionSet.fromCodes(
        permissionCodes,
        // The backend models a super-admin bypass; mirror it so the UI agrees.
        superAdmin: roles.any((role) => role.toUpperCase().contains('SUPER')),
      ),
      lastLoginAt: DateTime.tryParse(json['lastLoginAt'] as String? ?? ''),
      companyId: json['companyId'] as String?,
      companyName: json['companyName'] as String?,
    );
  }
}

/// Mirrors the backend's `UserStatus`.
enum UserStatus {
  active('ACTIVE'),
  inactive('INACTIVE'),
  locked('LOCKED'),
  suspended('SUSPENDED');

  const UserStatus(this.code);
  final String code;

  static UserStatus fromName(String? value) => values.firstWhere(
    (status) => status.code == value,
    orElse: () => UserStatus.active,
  );
}
