import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_erp/core/errors/app_exception.dart';
import 'package:jewellery_erp/core/errors/error_mapper.dart';

DioException _responseError(int status, Map<String, dynamic> body) {
  final options = RequestOptions(path: '/api/v1/inventory/items');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: body,
      headers: Headers.fromMap({
        'X-Correlation-Id': ['abc-123'],
      }),
    ),
  );
}

void main() {
  group('Backend error contract', () {
    test('maps VALIDATION_FAILED with its field errors', () {
      final mapped = ErrorMapper.map(
        _responseError(400, {
          'success': false,
          'code': 'VALIDATION_FAILED',
          'message': 'Request validation failed',
          'fieldErrors': [
            {'field': 'username', 'message': 'must not be blank'},
          ],
        }),
      );

      expect(mapped, isA<ValidationException>());
      final validation = mapped as ValidationException;
      expect(validation.messageFor('username'), 'must not be blank');
      expect(validation.messageFor('password'), isNull);
    });

    test('maps CONCURRENT_MODIFICATION so the caller can offer a reload', () {
      final mapped = ErrorMapper.map(
        _responseError(409, {
          'success': false,
          'code': 'CONCURRENT_MODIFICATION',
          'message': 'The record was modified by another user.',
        }),
      );
      expect(mapped, isA<ConcurrentModificationException>());
    });

    test('maps FORBIDDEN distinctly from a server failure', () {
      final mapped = ErrorMapper.map(
        _responseError(403, {'success': false, 'code': 'FORBIDDEN'}),
      );
      expect(mapped, isA<ForbiddenException>());
    });

    test('maps BUSINESS_RULE_VIOLATED and keeps the backend message', () {
      // The business message is the useful part; a generic string would lose it.
      final mapped = ErrorMapper.map(
        _responseError(422, {
          'success': false,
          'code': 'BUSINESS_RULE_VIOLATED',
          'message': 'Item is not available for transfer',
        }),
      );
      expect(mapped, isA<BusinessRuleException>());
      expect(mapped.message, 'Item is not available for transfer');
    });

    test('carries the correlation id through for support', () {
      final mapped = ErrorMapper.map(
        _responseError(500, {'success': false, 'code': 'INTERNAL_ERROR'}),
      );
      expect(mapped.correlationId, 'abc-123');
    });

    test('falls back to the status code when the body is unusable', () {
      final options = RequestOptions(path: '/x');
      final mapped = ErrorMapper.map(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: 404,
            data: '<html>not json</html>',
          ),
        ),
      );
      expect(mapped, isA<NotFoundException>());
    });
  });

  group('Transport failures', () {
    test('timeouts and connection errors are distinguishable', () {
      final options = RequestOptions(path: '/x');
      expect(
        ErrorMapper.map(DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        )),
        isA<TimeoutException>(),
      );
      expect(
        ErrorMapper.map(DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        )),
        isA<NetworkException>(),
      );
      expect(
        ErrorMapper.map(DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
        )),
        isA<CancelledException>(),
      );
    });
  });
}

