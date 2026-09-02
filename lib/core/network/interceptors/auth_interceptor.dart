import 'dart:async';

import 'package:dio/dio.dart';

import '../../constants/api_endpoints.dart';
import '../auth_token_provider.dart';

/// Attaches the bearer token, refreshes it proactively, and recovers from a 401
/// exactly once per request.
///
/// The backend returns `accessTokenExpiresAt` on login and refresh, so the
/// common path refreshes *before* the token dies rather than discovering it
/// through a failure.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({required AuthTokenProvider tokenProvider, required Dio dio})
    : _tokens = tokenProvider,
      _dio = dio;

  final AuthTokenProvider _tokens;
  final Dio _dio;

  /// Paths that must never carry a bearer token or trigger a refresh.
  static const _unauthenticatedPaths = <String>{
    ApiEndpoints.login,
    ApiEndpoints.refresh,
  };

  static const _retriedKey = 'auth_retried';

  bool _isUnauthenticated(RequestOptions options) =>
      _unauthenticatedPaths.any((path) => options.path.endsWith(path));

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isUnauthenticated(options)) {
      handler.next(options);
      return;
    }

    var tokens = await _tokens.currentTokens();

    if (tokens != null && tokens.isExpired()) {
      tokens = await _tokens.refresh();
      if (tokens == null) {
        // Refresh failed; let the request proceed unauthenticated so the
        // backend produces the 401 and one code path handles session loss.
        handler.next(options);
        return;
      }
    }

    if (tokens != null) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = options.extra[_retriedKey] == true;

    if (!isUnauthorized || alreadyRetried || _isUnauthenticated(options)) {
      handler.next(err);
      return;
    }

    final refreshed = await _tokens.refresh();
    if (refreshed == null) {
      await _tokens.onAuthenticationLost();
      handler.next(err);
      return;
    }

    options.extra[_retriedKey] = true;
    options.headers['Authorization'] = 'Bearer ${refreshed.accessToken}';

    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
