import 'dart:async';

import '../../../core/network/auth_token_provider.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/utils/logger.dart';
import 'auth_api.dart';

/// Supplies and refreshes credentials for the network layer.
///
/// The single-flight guard is the important part: a dashboard that fires six
/// parallel requests whose token has just expired must produce **one** refresh
/// call, not six. Six would race, and five would be replaying a refresh token
/// the backend has already rotated away.
class SessionTokenProvider implements AuthTokenProvider {
  SessionTokenProvider({
    required AuthApi api,
    required SecureStorage storage,
    required AppLogger logger,
  }) : _api = api,
       _storage = storage,
       _logger = logger;

  final AuthApi _api;
  final SecureStorage _storage;
  final AppLogger _logger;

  /// Invoked when the session cannot be recovered. Wired to the session
  /// controller at construction so this class stays free of Riverpod.
  Future<void> Function()? onSessionLost;

  /// In-memory copy, so the common path does not hit the keychain per request.
  TokenBundle? _cached;

  /// The refresh currently in progress, if any.
  Future<TokenBundle?>? _inFlight;

  @override
  Future<TokenBundle?> currentTokens() async {
    return _cached ??= await _storage.readTokens();
  }

  /// Records credentials after a successful login or refresh.
  Future<void> store(TokenBundle tokens) async {
    _cached = tokens;
    await _storage.writeTokens(tokens);
  }

  Future<void> clear() async {
    _cached = null;
    _inFlight = null;
    await _storage.clearTokens();
  }

  @override
  Future<TokenBundle?> refresh() {
    // Every caller awaits the same future; the guard is cleared once it settles
    // so a later expiry can refresh again.
    return _inFlight ??= _performRefresh().whenComplete(() => _inFlight = null);
  }

  Future<TokenBundle?> _performRefresh() async {
    final current = await currentTokens();
    if (current == null) return null;

    try {
      final payload = await _api.refresh(current.refreshToken);
      await store(payload.tokens);
      _logger.info('Access token refreshed');
      return payload.tokens;
    } on Object catch (error) {
      // A failed refresh is terminal: the refresh token is spent or revoked,
      // and retrying would only produce the same answer.
      _logger.warn('Token refresh failed', context: error.toString());
      await clear();
      return null;
    }
  }

  @override
  Future<void> onAuthenticationLost() async {
    await clear();
    await onSessionLost?.call();
  }
}
