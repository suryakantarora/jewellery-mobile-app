import 'package:dio/dio.dart';

import '../../errors/error_mapper.dart';

/// Converts every transport failure into an [AppException] before it leaves the
/// network layer, so no `DioException` reaches a repository or a widget.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: ErrorMapper.map(err),
      ),
    );
  }
}
