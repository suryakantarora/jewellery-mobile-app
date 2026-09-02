import '../../shared/models/organization.dart';
import '../../shared/models/user.dart';
import '../constants/permissions.dart';

/// Why a session ended, so the login screen can explain itself.
enum SignOutReason { userInitiated, sessionExpired, revoked, accountInactive }

/// The single source of truth for "who is signed in and what can they reach".
///
/// GoRouter redirects on this and nothing else, so no screen performs its own
/// authentication check and there is one place to reason about access.
sealed class SessionState {
  const SessionState();

  const factory SessionState.bootstrapping() = SessionBootstrapping;
  const factory SessionState.unauthenticated({SignOutReason? reason}) =
      SessionUnauthenticated;
  const factory SessionState.mustChangePassword(AppUser user) =
      SessionMustChangePassword;
  const factory SessionState.branchRequired(AppUser user) =
      SessionBranchRequired;
  const factory SessionState.authenticated({
    required AppUser user,
    required Branch branch,
    Company? company,
    List<BranchLocation> locations,
  }) = SessionAuthenticated;
  const factory SessionState.locked(AppUser user) = SessionLocked;

  /// The signed-in user, where one exists.
  AppUser? get user => switch (this) {
    SessionAuthenticated(:final user) => user,
    SessionBranchRequired(:final user) => user,
    SessionMustChangePassword(:final user) => user,
    SessionLocked(:final user) => user,
    _ => null,
  };

  /// Permissions currently in force. Anything other than a fully established
  /// session has none — a locked or branch-less session must not authorise
  /// anything.
  PermissionSet get permissions => switch (this) {
    SessionAuthenticated(:final user) => user.permissions,
    _ => PermissionSet.empty,
  };

  Branch? get branch => switch (this) {
    SessionAuthenticated(:final branch) => branch,
    _ => null,
  };

  /// The institution, once resolved from the branch's `companyId`.
  ///
  /// Null until that lookup completes, so callers fall back rather than wait.
  Company? get company => switch (this) {
    SessionAuthenticated(:final company) => company,
    _ => null,
  };

  bool get isAuthenticated => this is SessionAuthenticated;
  bool get isBootstrapping => this is SessionBootstrapping;
  bool get isLocked => this is SessionLocked;

  /// Whether credentials exist, even if the session is not currently usable.
  bool get hasCredentials => switch (this) {
    SessionBootstrapping() || SessionUnauthenticated() => false,
    _ => true,
  };
}

class SessionBootstrapping extends SessionState {
  const SessionBootstrapping();
}

class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated({this.reason});
  final SignOutReason? reason;
}

class SessionMustChangePassword extends SessionState {
  const SessionMustChangePassword(this.changingUser);
  final AppUser changingUser;

  @override
  AppUser get user => changingUser;
}

class SessionBranchRequired extends SessionState {
  const SessionBranchRequired(this.pendingUser);
  final AppUser pendingUser;

  @override
  AppUser get user => pendingUser;
}

class SessionAuthenticated extends SessionState {
  const SessionAuthenticated({
    required AppUser user,
    required Branch branch,
    this.company,
    this.locations = const [],
  }) : _user = user,
       _branch = branch;

  final AppUser _user;
  final Branch _branch;

  /// Resolved from `branch.companyId`; null until that lookup completes, so the
  /// header falls back to the branch name rather than showing a gap.
  @override
  final Company? company;

  final List<BranchLocation> locations;

  @override
  AppUser get user => _user;

  @override
  Branch get branch => _branch;

  SessionAuthenticated copyWith({
    Branch? branch,
    Company? company,
    List<BranchLocation>? locations,
  }) {
    return SessionAuthenticated(
      user: _user,
      branch: branch ?? _branch,
      company: company ?? this.company,
      locations: locations ?? this.locations,
    );
  }
}

class SessionLocked extends SessionState {
  const SessionLocked(this.lockedUser);
  final AppUser lockedUser;

  @override
  AppUser get user => lockedUser;
}
