import '../storage/secure_storage.dart';

/// The contract the network layer needs from authentication.
///
/// Defined here, implemented by the authentication feature, so `core/network`
/// never imports a feature. In Phase 1 a development implementation satisfies
/// it; Phase 2 swaps in the real one without touching the interceptors.
abstract interface class AuthTokenProvider {
  /// The credentials currently on the device, or null when signed out.
  Future<TokenBundle?> currentTokens();

  /// Exchanges the refresh token for a new access token.
  ///
  /// Implementations must be single-flight: several requests failing with 401
  /// at once have to produce one refresh call, not one per request.
  Future<TokenBundle?> refresh();

  /// Clears the session after an unrecoverable authentication failure.
  Future<void> onAuthenticationLost();
}
