import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_erp/shared/models/user.dart';
import 'package:jewellery_erp/core/constants/permissions.dart';
import 'package:jewellery_erp/features/authentication/data/auth_api.dart';
import 'package:jewellery_erp/shared/models/organization.dart';

void main() {
  group('AuthPayload', () {
    // Shaped exactly like the live backend's AuthResponse.
    final json = <String, dynamic>{
      'accessToken': 'access-abc',
      'refreshToken': 'refresh-def',
      'tokenType': 'Bearer',
      'accessTokenExpiresAt': '2026-09-01T17:30:00Z',
      'mustChangePassword': false,
      'user': {
        'id': '11111111-2222-3333-4444-555555555555',
        'username': 'admin',
        'fullName': 'System Administrator',
        'email': 'admin@example.com',
        'status': 'ACTIVE',
        'primaryBranchId': null,
        'branchIds': <String>[],
        'roles': ['SUPER_ADMIN'],
        'permissions': ['INVENTORY_VIEW', 'SALE_VIEW'],
        'lastLoginAt': '2026-09-01T15:45:00Z',
      },
    };

    test('parses tokens, expiry and the user', () {
      final payload = AuthPayload.fromJson(json);

      expect(payload.tokens.accessToken, 'access-abc');
      expect(payload.tokens.refreshToken, 'refresh-def');
      expect(payload.tokens.expiresAt, isNotNull);
      expect(payload.mustChangePassword, isFalse);
      expect(payload.user.username, 'admin');
      expect(payload.user.fullName, 'System Administrator');
    });

    test('parses permissions and detects the super-admin role', () {
      final payload = AuthPayload.fromJson(json);
      expect(payload.user.permissions.has(Permission.inventoryView), isTrue);
      // The backend grants everything to SUPER_ADMIN; the UI has to agree.
      expect(payload.user.permissions.superAdmin, isTrue);
      expect(payload.user.permissions.has(Permission.financeManage), isTrue);
    });

    test('survives a user with no branches', () {
      // The live admin account has none, which must not crash the parse.
      final payload = AuthPayload.fromJson(json);
      expect(payload.user.branchIds, isEmpty);
      expect(payload.user.hasNoBranch, isTrue);
      expect(payload.user.primaryBranchId, isNull);
    });

    test('tolerates missing optional fields', () {
      final sparse = AuthPayload.fromJson({
        'accessToken': 'a',
        'refreshToken': 'r',
        'user': {'id': 'x', 'username': 'u', 'fullName': 'U'},
      });
      expect(sparse.tokens.expiresAt, isNull);
      expect(sparse.mustChangePassword, isFalse);
      expect(sparse.user.permissions.isEmpty, isTrue);
    });
  });

  group('Organisation models', () {
    test('Branch parses the live BranchResponse shape', () {
      final branch = Branch.fromJson({
        'id': 'b1',
        'companyId': 'c1',
        'code': 'VTE',
        'name': 'Vientiane Showroom',
        'headOffice': true,
        'city': 'Vientiane',
        'country': 'Laos',
        'timezone': 'Asia/Vientiane',
        'status': 'ACTIVE',
      });

      expect(branch.code, 'VTE');
      expect(branch.headOffice, isTrue);
      // Reports must use the branch's day, not the device's.
      expect(branch.timezone, 'Asia/Vientiane');
    });

    test('Company carries the institution base currency', () {
      final company = Company.fromJson({
        'id': 'c1',
        'code': 'ABC',
        'name': 'ABC Jewellery',
        'baseCurrency': 'LAK',
      });
      expect(company.name, 'ABC Jewellery');
      expect(company.baseCurrency, 'LAK');
    });

    test('Location reads type and the dual-authorisation flag', () {
      final location = BranchLocation.fromJson({
        'id': 'l1',
        'branchId': 'b1',
        'code': 'VLT',
        'name': 'Vault',
        'type': 'VAULT',
        'dualAuthorization': true,
      });

      expect(location.type, LocationType.vault);
      // Consumed by the high-value flows in Phase 8.
      expect(location.dualAuthorization, isTrue);
    });

    test('an unrecognised location type does not throw', () {
      final location = BranchLocation.fromJson({
        'id': 'l2',
        'branchId': 'b1',
        'code': 'X',
        'name': 'New kind',
        'type': 'SOMETHING_NEW',
      });
      expect(location.type, LocationType.showroom);
    });
  });

  group('Tenant context', () {
    test('AppUser reads companyId and companyName when present', () {
      final user = AppUser.fromJson({
        'id': 'u1',
        'username': 'somchai',
        'fullName': 'Somchai',
        'permissions': <String>[],
        'companyId': 'c1',
        'companyName': 'Phimpha Jewellery',
      });
      expect(user.companyId, 'c1');
      expect(user.companyName, 'Phimpha Jewellery');
      expect(user.isPlatformUser, isFalse);
    });

    test('a user without a company is a platform user (older payloads too)', () {
      final user = AppUser.fromJson({
        'id': 'u1',
        'username': 'admin',
        'fullName': 'Admin',
        'permissions': <String>[],
      });
      expect(user.companyId, isNull);
      expect(user.isPlatformUser, isTrue);
    });
  });
}
