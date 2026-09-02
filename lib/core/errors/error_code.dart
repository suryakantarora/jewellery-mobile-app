/// Mirrors the backend's `ErrorCode` enum exactly.
enum ApiErrorCode {
  validationFailed('VALIDATION_FAILED'),
  businessRuleViolated('BUSINESS_RULE_VIOLATED'),
  notFound('NOT_FOUND'),
  unauthorized('UNAUTHORIZED'),
  forbidden('FORBIDDEN'),
  conflict('CONFLICT'),
  concurrentModification('CONCURRENT_MODIFICATION'),
  idempotencyConflict('IDEMPOTENCY_CONFLICT'),
  internalError('INTERNAL_ERROR'),

  /// Not a backend value — used when the payload could not be understood.
  unknown('UNKNOWN');

  const ApiErrorCode(this.code);

  final String code;

  static ApiErrorCode fromCode(String? code) {
    if (code == null) return ApiErrorCode.unknown;
    for (final value in values) {
      if (value.code == code) return value;
    }
    return ApiErrorCode.unknown;
  }
}
