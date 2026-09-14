import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/authentication/domain/auth_repository.dart';
import '../../shared/models/organization.dart';
import '../../shared/models/user.dart';
import '../providers.dart';
import '../storage/storage_keys.dart';
import '../../features/notifications/data/push_registration_service.dart';
import 'session_state.dart';

/// Owns every transition of [SessionState].
///
/// This is the only place that decides whether the app is signed in, which
/// branch is active, and whether the session has locked. GoRouter listens to
/// it, so navigation stays a consequence of state rather than a set of
/// scattered imperative pushes.
class SessionController extends Notifier<SessionState>
    with WidgetsBindingObserver {
  Timer? _idleTimer;
  DateTime? _backgroundedAt;

  @override
  SessionState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _idleTimer?.cancel();
    });

    // Restoration runs after the first frame so the splash renders immediately
    // rather than the app blocking on storage.
    scheduleMicrotask(restore);
    return const SessionState.bootstrapping();
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  /// Rebuilds the session from stored credentials on cold start.
  Future<void> restore() async {
    try {
      final user = await _auth.restore();
      if (user == null) {
        state = const SessionState.unauthenticated();
        return;
      }
      await _establish(user);
    } on Object {
      // A failed restore must never strand the user on a splash screen.
      state = const SessionState.unauthenticated();
    }
  }

  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    final result = await _auth.signIn(username: username, password: password);

    await ref
        .read(localStoreProvider)
        .setString(StorageKeys.lastUsername, username);

    if (result.mustChangePassword) {
      state = SessionState.mustChangePassword(result.user);
      return;
    }

    await _establish(result.user);
  }

  /// Performs a forced password change and then establishes the session.
  ///
  /// The backend requires the current password, so this is never a silent
  /// reset. Neither value is stored anywhere.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = state.user;
    if (user == null) return;

    await _auth.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    // Sign in again rather than carrying on with the tokens we arrived with.
    //
    // The backend revokes every token for the user on a credential change —
    // deliberately, so a stolen session dies with the old password. Continuing
    // on them meant the very next call (`/branches`, inside `_establish`) came
    // back 403, and the change screen reported "You do not have permission to
    // perform this action" for a password that had in fact just been changed.
    //
    // Worse than a wrong message: the user would retry with the old password,
    // which no longer works, and have no way to understand why. This is the
    // first thing every new member of staff does, so it had to be right.
    await signIn(username: user.username, password: newPassword);
  }

  /// Resolves branch context and moves to an authenticated session.
  ///
  /// A user with no branch cannot work, and a stored branch that is no longer
  /// granted must not be honoured — access can be revoked between sessions.
  Future<void> _establish(AppUser user) async {
    if (!user.canSignIn) {
      await signOut(reason: SignOutReason.accountInactive);
      return;
    }

    // A super admin carries an empty `branchIds` but may act in every branch,
    // so the branch list is the authority here — short-circuiting on
    // `branchIds` alone would lock every super admin out of the application.
    if (user.hasNoBranch && !user.permissions.superAdmin) {
      state = SessionState.branchRequired(user);
      return;
    }

    final branches = await _auth.branchesFor(user);
    if (branches.isEmpty) {
      state = SessionState.branchRequired(user);
      return;
    }

    final storedId = ref
        .read(localStoreProvider)
        .getString(StorageKeys.selectedBranchId);

    final remembered = branches.where((b) => b.id == storedId).firstOrNull;
    final primary = branches
        .where((b) => b.id == user.primaryBranchId)
        .firstOrNull;

    final resolved =
        remembered ?? (branches.length == 1 ? branches.single : primary);

    if (resolved == null) {
      state = SessionState.branchRequired(user);
      return;
    }

    await _activate(user, resolved);
  }

  /// Switches branch, from the picker or the context bar.
  Future<void> selectBranch(Branch branch) async {
    final user = state.user;
    if (user == null) return;
    await _activate(user, branch);
  }

  Future<void> _activate(AppUser user, Branch branch) async {
    state = SessionState.authenticated(user: user, branch: branch);

    await ref
        .read(localStoreProvider)
        .setString(StorageKeys.selectedBranchId, branch.id);

    _restartIdleTimer();

    // Company and locations enrich the header but must not gate entry, so they
    // load after the session is usable and failures are non-fatal.
    unawaited(_loadBranchContext(branch));
  }

  Future<void> _loadBranchContext(Branch branch) async {
    try {
      final results = await Future.wait([
        _auth.companyFor(branch.companyId),
        _auth.locationsFor(branch.id),
      ]);

      final current = state;
      // Guard against a branch switch landing while this was in flight.
      if (current is! SessionAuthenticated || current.branch.id != branch.id) {
        return;
      }

      state = current.copyWith(
        company: results[0] as Company?,
        locations: results[1] as List<BranchLocation>,
      );
    } on Object {
      // The header falls back to the branch name; nothing else depends on this.
    }
  }

  Future<void> signOut({
    SignOutReason reason = SignOutReason.userInitiated,
  }) async {
    _idleTimer?.cancel();
    _signingOut = true;

    // Revoke the push device while the bearer token is still valid; after
    // sign-out the DELETE would 401 and the device would keep receiving mail.
    try {
      await ref.read(pushRegistrationServiceProvider).deregister();
    } on Object {
      // Best-effort; the server sweeps dead tokens on the next failed send.
    }

    try {
      await _auth.signOut();
    } on Object {
      // Sign-out is not allowed to fail from the user's point of view: local
      // credentials are cleared regardless of what the server said.
    }

    await ref.read(localStoreProvider).clearSession();
    state = SessionState.unauthenticated(reason: reason);
    _signingOut = false;
  }

  /// Called by the network layer when the session can no longer be recovered.
  ///
  /// Ignored while a deliberate sign-out is in flight, and once the session is
  /// already over. The sign-out request itself is sent with the very token that
  /// may have expired, so its 401 used to land back here and relabel the
  /// user's own choice as "your session expired" — telling someone who had just
  /// tapped Sign out that something had gone wrong.
  Future<void> onAuthenticationLost() async {
    if (_signingOut || state is SessionUnauthenticated) return;
    await signOut(reason: SignOutReason.sessionExpired);
  }

  /// Guards against a failed sign-out request reclassifying the reason.
  bool _signingOut = false;

  // --- Locking -------------------------------------------------------------

  /// Locks the session without discarding credentials — unlocking is a
  /// biometric or password check, not a full sign-in.
  void lock() {
    final user = state.user;
    if (user == null || state is! SessionAuthenticated) return;
    _idleTimer?.cancel();
    state = SessionState.locked(user);
  }

  /// Restores an authenticated session after a successful unlock.
  Future<void> unlock() async {
    final user = state.user;
    if (user == null || state is! SessionLocked) return;
    await _establish(user);
  }

  /// Resets the inactivity countdown. Driven by a pointer listener at the app
  /// root, so any interaction anywhere keeps the session alive.
  void registerActivity() {
    if (state is! SessionAuthenticated) return;
    _restartIdleTimer();
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    final timeout = ref.read(appConfigProvider).idleTimeout;
    _idleTimer = Timer(timeout, lock);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // A timer does not run reliably in the background, so the elapsed time
        // is measured on return instead.
        _backgroundedAt = DateTime.now();
        _idleTimer?.cancel();
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since == null) return;

        final away = DateTime.now().difference(since);
        if (away >= ref.read(appConfigProvider).idleTimeout) {
          lock();
        } else {
          _restartIdleTimer();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Convenience selectors, so widgets watch the narrowest thing they need and
/// do not rebuild on unrelated session changes.
final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(sessionControllerProvider).user,
);

final currentBranchProvider = Provider<Branch?>(
  (ref) => ref.watch(sessionControllerProvider).branch,
);

final permissionsProvider = Provider(
  (ref) => ref.watch(sessionControllerProvider).permissions,
);

/// Bridges the session to `GoRouter.refreshListenable`.
class SessionRefreshNotifier extends ChangeNotifier {
  SessionRefreshNotifier(this._ref) {
    _ref.listen<SessionState>(
      sessionControllerProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;
}

final sessionRefreshProvider = Provider<SessionRefreshNotifier>((ref) {
  final notifier = SessionRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});
