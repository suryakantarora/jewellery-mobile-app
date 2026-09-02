import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../utils/logger.dart';
import 'auth_token_provider.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/branch_context_interceptor.dart';
import 'interceptors/correlation_id_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

/// Assembles the configured [Dio] instance.
///
/// Interceptor order is deliberate:
///   correlation id → branch → auth → retry → logging → error
/// Correlation and branch stamp the request before anything can fail; auth sits
/// above retry so a refreshed token is used on the retried call; error maps
/// last so every other interceptor still sees the raw `DioException`.
abstract final class DioClient {
  static Dio create({
    required AppConfig config,
    required AppLogger logger,
    AuthTokenProvider? tokenProvider,
    BranchIdReader? branchIdReader,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.apiRoot,
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        sendTimeout: config.sendTimeout,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        // The app inspects status codes itself, so only transport-level
        // failures should throw before the error interceptor runs.
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    dio.interceptors.add(CorrelationIdInterceptor());

    if (branchIdReader != null) {
      dio.interceptors.add(BranchContextInterceptor(branchIdReader));
    }

    if (tokenProvider != null) {
      dio.interceptors.add(
        AuthInterceptor(tokenProvider: tokenProvider, dio: dio),
      );
    }

    dio.interceptors.add(RetryInterceptor(dio: dio));

    dio.interceptors.add(
      LoggingInterceptor(
        logger,
        enabled: config.environment.allowsDeveloperTools,
      ),
    );

    dio.interceptors.add(ErrorInterceptor());

    return dio;
  }
}
