import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import 'app_exception.dart';
import 'error_code.dart';

/// Translates transport failures into the app's [AppException] hierarchy.
///
/// The backend's error contract is consistent — `{success, code, message, path,
/// correlationId, fieldErrors, timestamp}` — so the mapper reads it directly
/// and falls back to the status code only when the body is unusable.
abstract final class ErrorMapper {
  static AppException map(Object error) {
    if (error is AppException) return error;
    if (error is DioException) return _fromDio(error);
    return const ServerException();
  }

  static AppException _fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutException();
      case DioExceptionType.cancel:
        return const CancelledException();
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badCertificate:
        return const NetworkException(
          message: 'The server certificate could not be verified.',
        );
      case DioExceptionType.transformTimeout:
        return const TimeoutException();
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    final response = error.response;
    if (response == null) return const NetworkException();

    final correlationId = _correlationId(response);
    final body = response.data;
    final status = response.statusCode;

    if (body is! Map) {
      return _fromStatus(status, correlationId, null);
    }

    final code = ApiErrorCode.fromCode(body['code'] as String?);
    final message = (body['message'] as String?)?.trim();
    final fields = _fieldErrors(body['fieldErrors']);

    switch (code) {
      case ApiErrorCode.validationFailed:
        return ValidationException(
          message: message ?? 'Please correct the highlighted fields.',
          fieldErrors: fields,
          correlationId: correlationId,
          statusCode: status,
        );
      case ApiErrorCode.businessRuleViolated:
        return BusinessRuleException(
          message: message ?? 'This action is not allowed right now.',
          correlationId: correlationId,
          statusCode: status,
        );
      case ApiErrorCode.notFound:
        return NotFoundException(
          message: message ?? 'Not found.',
          correlationId: correlationId,
          statusCode: status,
        );
      case ApiErrorCode.unauthorized:
        return UnauthorizedException(correlationId: correlationId);
      case ApiErrorCode.forbidden:
        return ForbiddenException(
          message:
              message ?? 'You do not have permission to perform this action.',
          correlationId: correlationId,
        );
      case ApiErrorCode.concurrentModification:
        return ConcurrentModificationException(correlationId: correlationId);
      case ApiErrorCode.idempotencyConflict:
      case ApiErrorCode.conflict:
        return ConflictException(
          message: message ?? 'That conflicts with the current state.',
          correlationId: correlationId,
          statusCode: status,
        );
      case ApiErrorCode.internalError:
      case ApiErrorCode.unknown:
        return _fromStatus(status, correlationId, message);
    }
  }

  static AppException _fromStatus(
    int? status,
    String? correlationId,
    String? message,
  ) {
    switch (status) {
      case 400:
        return ValidationException(
          message: message ?? 'The request was rejected.',
          correlationId: correlationId,
          statusCode: status,
        );
      case 401:
        return UnauthorizedException(correlationId: correlationId);
      case 403:
        return ForbiddenException(correlationId: correlationId);
      case 404:
        return NotFoundException(correlationId: correlationId);
      case 409:
        return ConflictException(
          message: message ?? 'That conflicts with the current state.',
          correlationId: correlationId,
        );
      default:
        return ServerException(
          message:
              message ??
              'Something went wrong on the server. Try again shortly.',
          correlationId: correlationId,
          statusCode: status,
        );
    }
  }

  static List<FieldError> _fieldErrors(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (entry) => FieldError(
            field: entry['field'] as String? ?? '',
            message: entry['message'] as String? ?? '',
          ),
        )
        .where((error) => error.field.isNotEmpty)
        .toList(growable: false);
  }

  static String? _correlationId(Response<dynamic> response) {
    final header = response.headers.value(AppConstants.correlationIdHeader);
    if (header != null && header.isNotEmpty) return header;

    final body = response.data;
    if (body is Map) return body['correlationId'] as String?;
    return null;
  }
}
