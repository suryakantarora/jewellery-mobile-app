import '../../../shared/models/organization.dart';
import '../../../shared/models/user.dart';

/// The result of a successful authentication.
class AuthResult {
  const AuthResult({required this.user, required this.mustChangePassword});

  final AppUser user;
  final bool mustChangePassword;
}

/// Authentication as the rest of the app sees it.
///
/// Phase 1 ships a development implementation so the whole session and routing
/// machine is walkable; Phase 2 replaces it with the Spring Boot client without
/// any caller changing.
abstract interface class AuthRepository {
  /// Restores a session from stored credentials, or null if there are none.
  Future<AppUser?> restore();

  Future<AuthResult> signIn({
    required String username,
    required String password,
  });

  Future<void> signOut();

  /// Changes the signed-in user's own password.
  ///
  /// The backend requires the current password, so this is never a silent
  /// reset — and the app never stores either value.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Branches this user may act in.
  Future<List<Branch>> branchesFor(AppUser user);

  /// Locations inside a branch, for the context bar and pickers.
  Future<List<BranchLocation>> locationsFor(String branchId);

  /// The institution that owns a branch.
  ///
  /// `UserResponse` carries no company, so it is resolved from the branch's
  /// `companyId` and cached for the session.
  Future<Company?> companyFor(String companyId);
}
