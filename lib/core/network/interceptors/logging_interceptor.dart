import 'package:dio/dio.dart';

import '../../utils/logger.dart';

/// Request/response logging for non-production builds.
///
/// Headers and bodies pass through [AppLogger.redact], so an Authorization
/// header or a password field can never reach the console or the diagnostics
/// buffer.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor(this._logger, {this.enabled = true});

  final AppLogger _logger;
  final bool enabled;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      _logger.debug(
        '→ ${options.method} ${options.uri}',
        context: {
          'headers': AppLogger.redact(options.headers),
          if (options.data != null) 'body': AppLogger.redact(options.data),
        },
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (enabled) {
      _logger.debug('← ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.warn(
      '✗ ${err.response?.statusCode ?? err.type.name} '
      '${err.requestOptions.uri}',
      context: AppLogger.redact(err.response?.data),
    );
    handler.next(err);
  }
}
