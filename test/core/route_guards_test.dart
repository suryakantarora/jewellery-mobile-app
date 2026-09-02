import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_erp/core/constants/permissions.dart';
import 'package:jewellery_erp/core/router/app_routes.dart';
import 'package:jewellery_erp/core/router/route_guards.dart';
import 'package:jewellery_erp/core/security/session_state.dart';
import 'package:jewellery_erp/shared/models/organization.dart';
import 'package:jewellery_erp/shared/models/user.dart';

void main() {
  final user = AppUser(
    id: 'u1',
    username: 'somchai',
    fullName: 'Somchai Vong',
    branchIds: const ['b1'],
    permissions: PermissionSet.fromCodes(const ['INVENTORY_VIEW']),
  );

  const branch = Branch(
    id: 'b1',
    companyId: 'c1',
    code: 'VTE',
    name: 'Vientiane',
  );

  group('Session redirects', () {
    test('bootstrapping holds on the splash', () {
      const session = SessionState.bootstrapping();
      expect(sessionRedirect(session, AppRoutes.dashboard), AppRoutes.splash);
      expect(sessionRedirect(session, AppRoutes.splash), isNull);
    });

    test('signed out sends everything to login', () {
      const session = SessionState.unauthenticated();
      expect(sessionRedirect(session, AppRoutes.dashboard), AppRoutes.login);
      expect(sessionRedirect(session, AppRoutes.inventory), AppRoutes.login);
      expect(sessionRedirect(session, AppRoutes.login), isNull);
    });

    test('a forced password change cannot be navigated away from', () {
      final session = SessionState.mustChangePassword(user);
      expect(
        sessionRedirect(session, AppRoutes.dashboard),
        AppRoutes.changePassword,
      );
      expect(sessionRedirect(session, AppRoutes.login), AppRoutes.changePassword);
      expect(sessionRedirect(session, AppRoutes.changePassword), isNull);
    });

    test('no branch means no business screen', () {
      // Nearly all data is branch-scoped, so a screen without one would be
      // meaningless rather than merely empty.
      final session = SessionState.branchRequired(user);
      expect(sessionRedirect(session, AppRoutes.dashboard), AppRoutes.selectBranch);
      expect(sessionRedirect(session, AppRoutes.selectBranch), isNull);
    });

    test('locked blocks everything until unlock', () {
      final session = SessionState.locked(user);
      expect(sessionRedirect(session, AppRoutes.dashboard), AppRoutes.lock);
      expect(sessionRedirect(session, AppRoutes.inventory), AppRoutes.lock);
      expect(sessionRedirect(session, AppRoutes.lock), isNull);
    });

    test('an established session bounces away from the session screens', () {
      final session = SessionState.authenticated(user: user, branch: branch);
      expect(sessionRedirect(session, AppRoutes.login), AppRoutes.dashboard);
      expect(sessionRedirect(session, AppRoutes.splash), AppRoutes.dashboard);
      expect(sessionRedirect(session, AppRoutes.dashboard), isNull);
      expect(sessionRedirect(session, AppRoutes.inventory), isNull);
    });
  });

  group('SessionState', () {
    test('only an established session carries permissions', () {
      // A locked or branch-less session must not authorise anything.
      expect(SessionState.locked(user).permissions.isEmpty, isTrue);
      expect(SessionState.branchRequired(user).permissions.isEmpty, isTrue);
      expect(
        SessionState.authenticated(user: user, branch: branch)
            .permissions
            .has(Permission.inventoryView),
        isTrue,
      );
    });

    test('credentials survive a lock', () {
      expect(SessionState.locked(user).hasCredentials, isTrue);
      expect(const SessionState.unauthenticated().hasCredentials, isFalse);
    });
  });

  group('Super admin branch access', () {
    // Verified against the live backend: the SUPER_ADMIN account carries
    // `branchIds: []` but holds all 67 permissions and may act in every
    // branch. Short-circuiting on branchIds alone would lock every super
    // admin out of the app the moment a branch exists.
    final superAdmin = AppUser(
      id: 'u0',
      username: 'admin',
      fullName: 'System Administrator',
      branchIds: const [],
      permissions: PermissionSet.fromCodes(
        const ['INVENTORY_VIEW'],
        superAdmin: true,
      ),
    );

    test('an empty branch list does not by itself block a super admin', () {
      expect(superAdmin.hasNoBranch, isTrue);
      expect(superAdmin.permissions.superAdmin, isTrue);

      // The guard the session controller applies.
      final blocked = superAdmin.hasNoBranch && !superAdmin.permissions.superAdmin;
      expect(blocked, isFalse);
    });

    test('an ordinary user with no branch is still blocked', () {
      final ordinary = AppUser(
        id: 'u2',
        username: 'nok',
        fullName: 'Nok',
        branchIds: const [],
        permissions: PermissionSet.fromCodes(const ['INVENTORY_VIEW']),
      );

      final blocked = ordinary.hasNoBranch && !ordinary.permissions.superAdmin;
      expect(blocked, isTrue);
    });
  });

  group('AppUser', () {
    test('derives initials defensively', () {
      expect(user.initials, 'SV');
      expect(
        AppUser(
          id: 'x',
          username: 'nok',
          fullName: 'Nok',
          permissions: PermissionSet.empty,
        ).initials,
        'N',
      );
    });
  });
}
