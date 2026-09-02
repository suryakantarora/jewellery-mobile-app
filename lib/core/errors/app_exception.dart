import 'error_code.dart';

/// A field-level validation message from the backend.
class FieldError {
  const FieldError({required this.field, required this.message});

  final String field;
  final String message;
}

/// Every failure the app can surface, as a closed set.
///
/// Screens switch on these rather than inspecting `DioException`, so transport
/// details never leak into presentation code.
sealed class AppException implements Exception {
  const AppException({
    required this.message,
    this.correlationId,
    this.statusCode,
  });

  /// A message safe to show to a user. Never a stack trace, never raw JSON.
  final String message;

  /// The backend's `X-Correlation-Id`, surfaced on error states so support can
  /// trace the exact request that failed.
  final String? correlationId;

  final int? statusCode;

  @override
  String toString() => '$runtimeType($message)';
}

/// No usable connection.
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'No connection. Check your network and try again.',
    super.correlationId,
  });
}

/// The request took too long.
class TimeoutException extends AppException {
  const TimeoutException({
    super.message = 'The request timed out. Try again.',
    super.correlationId,
  });
}

/// Cancelled deliberately — a superseded search, a closed screen. Usually
/// swallowed rather than shown.
class CancelledException extends AppException {
  const CancelledException({super.message = 'Request cancelled'});
}

/// 401. The session is no longer valid; the session layer handles the redirect.
class UnauthorizedException extends AppException {
  const UnauthorizedException({
    super.message = 'Your session has expired. Please sign in again.',
    super.correlationId,
    super.statusCode = 401,
  });
}

/// 403. The backend refused; the UI should explain rather than retry.
class ForbiddenException extends AppException {
  const ForbiddenException({
    super.message = 'You do not have permission to perform this action.',
    super.correlationId,
    super.statusCode = 403,
  });
}

class NotFoundException extends AppException {
  const NotFoundException({
    super.message = 'Not found.',
    super.correlationId,
    super.statusCode = 404,
  });
}

/// 400 with field errors attached.
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    this.fieldErrors = const [],
    super.correlationId,
    super.statusCode = 400,
  });

  final List<FieldError> fieldErrors;

  String? messageFor(String field) {
    for (final error in fieldErrors) {
      if (error.field == field) return error.message;
    }
    return null;
  }
}

/// 422 — the request was well-formed but the business rejected it.
class BusinessRuleException extends AppException {
  const BusinessRuleException({
    required super.message,
    super.correlationId,
    super.statusCode = 422,
  });
}

/// 409 from an optimistic-lock failure. The caller should offer a reload.
class ConcurrentModificationException extends AppException {
  const ConcurrentModificationException({
    super.message =
        'This record was changed by someone else. Reload and try again.',
    super.correlationId,
    super.statusCode = 409,
  });
}

/// Any other 409.
class ConflictException extends AppException {
  const ConflictException({
    required super.message,
    super.correlationId,
    super.statusCode = 409,
  });
}

/// 5xx, or anything that could not be classified.
class ServerException extends AppException {
  const ServerException({
    super.message = 'Something went wrong on the server. Try again shortly.',
    super.correlationId,
    super.statusCode,
    this.code = ApiErrorCode.internalError,
  });

  final ApiErrorCode code;
}

/// A mutating call attempted while offline. Deliberately distinct from
/// [NetworkException]: the app never queues inventory or financial operations,
/// so this is a refusal to act, not a transport failure to retry silently.
class OfflineActionException extends AppException {
  const OfflineActionException({
    super.message = "You're offline. This action needs a connection.",
  });
}
