import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../errors/app_exception.dart';
import '../errors/error_mapper.dart';
import 'api_response.dart';

/// Typed wrapper over [Dio] that unwraps the backend's `ApiResponse` envelope.
///
/// Callers receive the payload directly and never see `{success, data, ...}`,
/// and every failure arrives as an [AppException].
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Dio get raw => _dio;

  /// GET returning a single object.
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Object? data) parse,
    CancelToken? cancelToken,
  }) async {
    return _send(
      () => _dio.get<dynamic>(
        path,
        queryParameters: _clean(query),
        cancelToken: cancelToken,
      ),
      parse,
    );
  }

  /// GET returning a page. The backend wraps `PageResponse` inside the standard
  /// envelope, so this unwraps both layers.
  Future<PageResponse<T>> getPage<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Map<String, dynamic> item) parseItem,
    CancelToken? cancelToken,
  }) async {
    return _send<PageResponse<T>>(
      () => _dio.get<dynamic>(
        path,
        queryParameters: _clean(query),
        cancelToken: cancelToken,
      ),
      (data) => data is Map<String, dynamic>
          ? PageResponse<T>.fromJson(data, parseItem)
          : PageResponse.empty<T>(),
    );
  }

  /// GET returning raw bytes, for files served outside the JSON envelope.
  ///
  /// Goes through Dio rather than `Image.network` so the request carries the
  /// auth interceptor's token — and so an expired token is refreshed and the
  /// request retried, which a widget holding a hand-built header map could
  /// never do.
  Future<List<int>> getBytes(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        queryParameters: _clean(query),
        cancelToken: cancelToken,
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? const [];
    } on DioException catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  /// Multipart upload of one file, for `POST /files`.
  ///
  /// The bytes go up as a `file` part; the response is enveloped like every
  /// other JSON endpoint, so [parse] receives the unwrapped payload.
  Future<T> upload<T>(
    String path, {
    required List<int> bytes,
    required String fileName,
    String? contentType,
    Map<String, dynamic>? fields,
    required T Function(Object? data) parse,
    CancelToken? cancelToken,
  }) async {
    final form = FormData.fromMap({
      ...?fields,
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: contentType == null
            ? null
            : DioMediaType.parse(contentType),
      ),
    });
    return _send(
      () => _dio.post<dynamic>(path, data: form, cancelToken: cancelToken),
      parse,
    );
  }

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required T Function(Object? data) parse,
    String? idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    return _send(
      () => _dio.post<dynamic>(
        path,
        data: body,
        queryParameters: _clean(query),
        cancelToken: cancelToken,
        options: _idempotent(idempotencyKey),
      ),
      parse,
    );
  }

  Future<T> put<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required T Function(Object? data) parse,
    CancelToken? cancelToken,
  }) async {
    return _send(
      () => _dio.put<dynamic>(
        path,
        data: body,
        queryParameters: _clean(query),
        cancelToken: cancelToken,
      ),
      parse,
    );
  }

  Future<T> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required T Function(Object? data) parse,
    CancelToken? cancelToken,
  }) async {
    return _send(
      () => _dio.delete<dynamic>(
        path,
        data: body,
        queryParameters: _clean(query),
        cancelToken: cancelToken,
      ),
      parse,
    );
  }

  /// Endpoints that return no payload — logout, cancel, release.
  Future<void> send(
    String path, {
    String method = 'POST',
    Object? body,
    Map<String, dynamic>? query,
    String? idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    await _send<void>(
      () => _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: _clean(query),
        cancelToken: cancelToken,
        options: Options(
          method: method,
          headers: idempotencyKey == null
              ? null
              : {AppConstants.idempotencyKeyHeader: idempotencyKey},
        ),
      ),
      (_) {},
    );
  }

  Options? _idempotent(String? key) => key == null
      ? null
      : Options(headers: {AppConstants.idempotencyKeyHeader: key});

  Future<T> _send<T>(
    Future<Response<dynamic>> Function() request,
    T Function(Object? data) parse,
  ) async {
    try {
      final response = await request();
      final body = response.data;

      // Not every endpoint is enveloped (file download, for instance), so fall
      // back to the raw body rather than assuming the shape.
      if (body is Map<String, dynamic> && body.containsKey('success')) {
        return parse(body['data']);
      }
      return parse(body);
    } on DioException catch (error) {
      // The error interceptor has already mapped this; unwrap it.
      final mapped = error.error;
      throw mapped is AppException ? mapped : ErrorMapper.map(error);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  /// Drops null query parameters so the backend does not receive `?status=null`.
  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{};
    query.forEach((key, value) {
      if (value != null) cleaned[key] = value;
    });
    return cleaned.isEmpty ? null : cleaned;
  }
}
