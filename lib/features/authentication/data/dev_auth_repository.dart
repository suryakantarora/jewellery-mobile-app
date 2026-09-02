import '../../../core/constants/permissions.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/storage/storage_keys.dart';
import '../../../shared/models/organization.dart';
import '../../../shared/models/user.dart';
import '../domain/auth_repository.dart';

/// Development-only authentication.
///
/// Exists so Phase 1 can exercise the real session machine, route guards and
/// permission gating before the backend is wired in Phase 2. It never reaches a
/// production build: `AppConfig.environment` selects the implementation, and
/// this one is only registered outside production.
///
/// Any password is accepted; the **username** selects a permission profile, so
/// the permission-driven navigation and dashboard can be exercised for each
/// kind of employee.
class DevAuthRepository implements AuthRepository {
  DevAuthRepository(this._storage);

  final SecureStorage _storage;

  static const _delay = Duration(milliseconds: 600);

  /// Username → permission profile. Anything else gets the manager profile.
  static final _profiles = <String, _DevProfile>{
    'sales': _DevProfile(
      fullName: 'Somchai Vong',
      roles: ['SALES_ASSOCIATE'],
      permissions: [
        Permission.inventoryView,
        Permission.inventoryReserve,
        Permission.productView,
        Permission.saleView,
        Permission.customerView,
        Permission.customerManage,
        Permission.crmView,
        Permission.loyaltyView,
        Permission.metalView,
      ],
      branchIds: ['branch-vientiane'],
    ),
    'warehouse': _DevProfile(
      fullName: 'Bounma Sisouk',
      roles: ['WAREHOUSE_STAFF'],
      permissions: [
        Permission.inventoryView,
        Permission.inventoryTransfer,
        Permission.warehouseView,
        Permission.stockCountPerform,
        Permission.procurementView,
        Permission.procurementReceive,
      ],
      branchIds: ['branch-vientiane', 'branch-warehouse'],
    ),
    'repair': _DevProfile(
      fullName: 'Nok Phimmasone',
      roles: ['REPAIR_TECHNICIAN'],
      permissions: [
        Permission.inventoryView,
        Permission.repairView,
        Permission.repairEstimate,
        Permission.repairProcess,
        Permission.customerView,
        Permission.fileUpload,
      ],
      branchIds: ['branch-vientiane'],
    ),
    'manager': _DevProfile(
      fullName: 'Khamla Rattana',
      roles: ['BRANCH_MANAGER'],
      permissions: Permission.values,
      branchIds: ['branch-vientiane', 'branch-pakse', 'branch-warehouse'],
    ),
  };

  static final _branches = <Branch>[
    const Branch(
      id: 'branch-vientiane',
      companyId: 'company-abc',
      code: 'VTE',
      name: 'Vientiane Showroom',
      city: 'Vientiane',
      country: 'Laos',
      timezone: 'Asia/Vientiane',
      headOffice: true,
    ),
    const Branch(
      id: 'branch-pakse',
      companyId: 'company-abc',
      code: 'PKS',
      name: 'Pakse Showroom',
      city: 'Pakse',
      country: 'Laos',
      timezone: 'Asia/Vientiane',
    ),
    const Branch(
      id: 'branch-warehouse',
      companyId: 'company-abc',
      code: 'CWH',
      name: 'Central Warehouse',
      city: 'Vientiane',
      country: 'Laos',
      timezone: 'Asia/Vientiane',
    ),
  ];

  static const _company = Company(
    id: 'company-abc',
    code: 'ABC',
    name: 'ABC Jewellery',
  );

  @override
  Future<AppUser?> restore() async {
    final tokens = await _storage.readTokens();
    if (tokens == null) return null;

    // The dev token encodes the profile so a restart resumes the same user.
    final username = tokens.accessToken.split(':').last;
    return _userFor(username);
  }

  @override
  Future<AuthResult> signIn({
    required String username,
    required String password,
  }) async {
    await Future<void>.delayed(_delay);

    final user = _userFor(username);
    await _storage.writeTokens(
      TokenBundle(
        accessToken: 'dev-access:$username',
        refreshToken: 'dev-refresh:$username',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 8)),
      ),
    );

    return AuthResult(
      user: user,
      // Exercises the forced-password-change branch of the state machine.
      mustChangePassword: username.toLowerCase() == 'newuser',
    );
  }

  @override
  Future<void> signOut() async {
    await _storage.clearTokens();
    await _storage.delete(StorageKeys.selectedBranchId);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future<void>.delayed(_delay);
  }

  @override
  Future<List<Branch>> branchesFor(AppUser user) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _branches
        .where((branch) => user.branchIds.contains(branch.id))
        .toList(growable: false);
  }

  @override
  Future<List<BranchLocation>> locationsFor(String branchId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return [
      BranchLocation(
        id: '$branchId-showroom',
        branchId: branchId,
        code: 'SHW',
        name: 'Showroom Floor',
        type: LocationType.showroom,
      ),
      BranchLocation(
        id: '$branchId-counter-1',
        branchId: branchId,
        code: 'CTR1',
        name: 'Counter 1',
        type: LocationType.counter,
      ),
      BranchLocation(
        id: '$branchId-vault',
        branchId: branchId,
        code: 'VLT',
        name: 'Vault',
        type: LocationType.vault,
      ),
    ];
  }

  @override
  Future<Company?> companyFor(String companyId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return companyId == _company.id ? _company : null;
  }

  AppUser _userFor(String username) {
    final key = username.trim().toLowerCase();
    final profile = _profiles[key] ?? _profiles['manager']!;

    return AppUser(
      id: 'user-$key',
      username: key,
      fullName: profile.fullName,
      email: '$key@abcjewellery.la',
      employeeCode: 'EMP-${key.toUpperCase()}',
      primaryBranchId: profile.branchIds.first,
      branchIds: profile.branchIds,
      roles: profile.roles,
      permissions: PermissionSet.fromCodes(
        profile.permissions.map((permission) => permission.code),
      ),
      lastLoginAt: DateTime.now(),
    );
  }
}

class _DevProfile {
  const _DevProfile({
    required this.fullName,
    required this.roles,
    required this.permissions,
    required this.branchIds,
  });

  final String fullName;
  final List<String> roles;
  final List<Permission> permissions;
  final List<String> branchIds;
}
