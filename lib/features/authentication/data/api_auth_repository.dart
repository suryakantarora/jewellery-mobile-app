import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/organization.dart';
import '../../../shared/models/user.dart';
import '../domain/auth_repository.dart';
import 'auth_api.dart';
import 'session_token_provider.dart';

/// The real authentication repository, backed by the Spring Boot API.
///
/// Replaces `DevAuthRepository` without any caller changing: the session
/// controller, route guards and permission gating built in Phase 1 are already
/// final and are not touched here.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({
    required AuthApi api,
    required SessionTokenProvider tokens,
    required ApiClient client,
  }) : _api = api,
       _tokens = tokens,
       _client = client;

  final AuthApi _api;
  final SessionTokenProvider _tokens;

  /// The authenticated client, for the organisation lookups that need a token.
  final ApiClient _client;

  @override
  Future<AppUser?> restore() async {
    final stored = await _tokens.currentTokens();
    if (stored == null) return null;

    // Tokens on disk are not proof of a live session — they may have been
    // revoked while the app was closed, so the profile is re-fetched rather
    // than trusted from a cache.
    var access = stored.accessToken;
    if (stored.isExpired()) {
      final refreshed = await _tokens.refresh();
      if (refreshed == null) return null;
      access = refreshed.accessToken;
    }

    try {
      return await _api.me(access);
    } on UnauthorizedException {
      await _tokens.clear();
      return null;
    }
  }

  @override
  Future<AuthResult> signIn({
    required String username,
    required String password,
  }) async {
    final payload = await _api.login(username: username, password: password);
    await _tokens.store(payload.tokens);

    return AuthResult(
      user: payload.user,
      mustChangePassword: payload.mustChangePassword,
    );
  }

  @override
  Future<void> signOut() async {
    final current = await _tokens.currentTokens();

    if (current != null) {
      try {
        await _api.logout(current.refreshToken);
      } on Object {
        // The server-side revocation is best effort. Local credentials are
        // cleared regardless — a user who signs out must end up signed out even
        // if the network is down.
      }
    }

    await _tokens.clear();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final tokens = await _tokens.currentTokens();
    if (tokens == null) {
      throw const UnauthorizedException();
    }

    await _api.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      accessToken: tokens.accessToken,
    );
  }

  @override
  Future<List<Branch>> branchesFor(AppUser user) async {
    final page = await _client.getPage<Branch>(
      ApiEndpoints.branches,
      query: {'size': 200},
      parseItem: Branch.fromJson,
    );

    // The backend is the authority on branch access, but a super admin can see
    // every branch, so the list is narrowed to what this user may act in.
    if (user.permissions.superAdmin) return page.content;

    return page.content
        .where((branch) => user.branchIds.contains(branch.id))
        .toList(growable: false);
  }

  @override
  Future<List<BranchLocation>> locationsFor(String branchId) async {
    return _client.get<List<BranchLocation>>(
      ApiEndpoints.branchLocations(branchId),
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(BranchLocation.fromJson)
                .toList(growable: false)
          : const [],
    );
  }

  @override
  Future<Company?> companyFor(String companyId) async {
    // `UserResponse` carries no company, so the institution shown in the header
    // is resolved from the selected branch's companyId.
    try {
      return await _client.get<Company>(
        ApiEndpoints.company(companyId),
        parse: (data) => Company.fromJson(data! as Map<String, dynamic>),
      );
    } on AppException {
      // The header falls back to the branch name; this must never block entry.
      return null;
    }
  }
}
