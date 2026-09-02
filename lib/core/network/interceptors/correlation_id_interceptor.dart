import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../constants/app_constants.dart';

/// Stamps every request with a correlation id.
///
/// The backend echoes it on responses and includes it in error payloads, so a
/// failure a user reports on the shop floor can be traced to the exact server
/// request without guesswork.
class CorrelationIdInterceptor extends Interceptor {
  CorrelationIdInterceptor([Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[AppConstants.correlationIdHeader] ??= _uuid.v4();
    handler.next(options);
  }
}
