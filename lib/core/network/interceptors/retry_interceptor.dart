import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

/// Retries transient failures on **idempotent requests only**.
///
/// GET and HEAD are safe to repeat. A POST is not — retrying a transfer
/// submission or a goods receipt could duplicate real inventory, so those are
/// left to fail and surface to the user. Endpoints that accept
/// `X-Idempotency-Key` could be retried safely, but that is an explicit,
/// per-call decision rather than something this interceptor assumes.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required Dio dio,
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 400),
  }) : _dio = dio;

  final Dio _dio;
  final int maxAttempts;
  final Duration baseDelay;

  static const _idempotentMethods = {'GET', 'HEAD'};
  static const _attemptKey = 'retry_attempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;

    if (!_shouldRetry(err)) {
      handler.next(err);
      return;
    }

    final attempt = (options.extra[_attemptKey] as int? ?? 0) + 1;
    if (attempt >= maxAttempts) {
      handler.next(err);
      return;
    }

    // Exponential backoff with jitter, so a flock of parallel dashboard calls
    // recovering from a dropped connection does not retry in lockstep.
    final backoff = baseDelay * pow(2, attempt - 1).toInt();
    final jitter = Duration(milliseconds: Random().nextInt(120));
    await Future<void>.delayed(backoff + jitter);

    options.extra[_attemptKey] = attempt;

    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _shouldRetry(DioException err) {
    if (!_idempotentMethods.contains(err.requestOptions.method.toUpperCase())) {
      return false;
    }

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode ?? 0;
        // 5xx and 429 are worth another attempt; 4xx will not change.
        return status >= 500 || status == 429;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.unknown:
        return false;
    }
  }
}
