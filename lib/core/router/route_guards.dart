import '../security/session_state.dart';
import 'app_routes.dart';

/// The single redirect rule for the whole application.
///
/// Every access decision about *reaching* a screen lives here, so no screen
/// checks authentication for itself and there is one place to reason about the
/// order in which session requirements apply.
///
/// Takes a plain location rather than a `GoRouterState` so the whole decision
/// table can be exercised in a unit test without the router.
String? sessionRedirect(SessionState session, String location) {
  final isSessionRoute = AppRoutes.sessionRoutes.contains(location);

  return switch (session) {
    // Still reading storage: hold on the splash.
    SessionBootstrapping() =>
      location == AppRoutes.splash ? null : AppRoutes.splash,

    // Signed out: only the login screen is reachable.
    SessionUnauthenticated() =>
      location == AppRoutes.login ? null : AppRoutes.login,

    // Password change is mandatory and cannot be navigated away from.
    SessionMustChangePassword() =>
      location == AppRoutes.changePassword ? null : AppRoutes.changePassword,

    // A branch is required before any business screen makes sense — data is
    // branch-scoped, so a screen without one would be meaningless.
    SessionBranchRequired() =>
      location == AppRoutes.selectBranch ? null : AppRoutes.selectBranch,

    // Locked: credentials are intact, but nothing is reachable until unlock.
    SessionLocked() => location == AppRoutes.lock ? null : AppRoutes.lock,

    // Established: bounce away from the session screens, allow everything else.
    SessionAuthenticated() => isSessionRoute ? AppRoutes.dashboard : null,
  };
}
