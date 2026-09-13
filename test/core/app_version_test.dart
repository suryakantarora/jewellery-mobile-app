import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_erp/core/settings/app_version_service.dart';

void main() {
  group('compareSemver', () {
    test('orders by major, minor, patch numerically', () {
      expect(compareSemver('1.2.3', '1.2.3'), 0);
      expect(compareSemver('1.2.3', '1.2.4'), lessThan(0));
      expect(compareSemver('1.3.0', '1.2.9'), greaterThan(0));
      expect(compareSemver('2.0.0', '1.99.99'), greaterThan(0));
      // Numeric, not lexical: 10 > 9.
      expect(compareSemver('1.10.0', '1.9.0'), greaterThan(0));
    });

    test('ignores build metadata', () {
      expect(compareSemver('1.2.0+45', '1.2.0'), 0);
      expect(compareSemver('1.2.0+45', '1.2.0+46'), 0);
      expect(compareSemver('1.2.0+45', '1.2.1'), lessThan(0));
    });

    test('a pre-release sorts below its release', () {
      expect(compareSemver('1.2.0-rc.1', '1.2.0'), lessThan(0));
      expect(compareSemver('1.2.0', '1.2.0-beta'), greaterThan(0));
      expect(compareSemver('1.2.0-rc.1', '1.2.0-rc.2'), lessThan(0));
      expect(compareSemver('1.2.0-alpha', '1.2.0-beta'), lessThan(0));
      // But above the previous patch.
      expect(compareSemver('1.2.0-rc.1', '1.1.9'), greaterThan(0));
    });

    test('tolerates short versions, a v prefix and whitespace', () {
      expect(compareSemver('1.2', '1.2.0'), 0);
      expect(compareSemver('1', '1.0.0'), 0);
      expect(compareSemver('v1.2.3', '1.2.3'), 0);
      expect(compareSemver(' 1.2.3 ', '1.2.3'), 0);
    });

    test('garbage segments count as zero rather than throwing', () {
      expect(compareSemver('1.x.3', '1.0.3'), 0);
      expect(compareSemver('', '0.0.0'), 0);
    });
  });

  group('AppUpdateInfo.evaluate', () {
    test('forceUpdate from the backend wins', () {
      final info = AppUpdateInfo.evaluate(
        json: {
          'minSupported': '1.0.0',
          'latest': '1.0.0',
          'forceUpdate': true,
          'storeUrl': 'https://example.com/store',
        },
        currentVersion: '1.0.0',
      );
      expect(info.status, UpdateStatus.forced);
      expect(info.isForced, isTrue);
      expect(info.storeUrl, 'https://example.com/store');
    });

    test('falls back to minSupported when the flag is absent', () {
      final forced = AppUpdateInfo.evaluate(
        json: {'minSupported': '1.2.0', 'latest': '1.3.0'},
        currentVersion: '1.1.0+7',
      );
      expect(forced.status, UpdateStatus.forced);

      final soft = AppUpdateInfo.evaluate(
        json: {'minSupported': '1.0.0', 'latest': '1.3.0'},
        currentVersion: '1.1.0+7',
      );
      expect(soft.status, UpdateStatus.updateAvailable);
      expect(soft.hasUpdate, isTrue);

      final current = AppUpdateInfo.evaluate(
        json: {'minSupported': '1.0.0', 'latest': '1.1.0'},
        currentVersion: '1.1.0+7',
      );
      expect(current.status, UpdateStatus.upToDate);
      expect(current.hasUpdate, isFalse);
    });

    test('an explicit forceUpdate=false is never escalated by the client', () {
      // The backend owns the policy. If it says "not forced", the app does not
      // second-guess it from minSupported.
      final info = AppUpdateInfo.evaluate(
        json: {
          'minSupported': '9.0.0',
          'latest': '9.0.0',
          'forceUpdate': false,
        },
        currentVersion: '1.0.0',
      );
      expect(info.status, UpdateStatus.updateAvailable);
    });
  });

  group('AppVersionService.check', () {
    test('parses the enveloped payload', () async {
      final service = AppVersionService(
        dio: _stubDio(
          (options) => _json({
            'success': true,
            'data': {
              'platform': 'ANDROID',
              'minSupported': '1.0.0',
              'latest': '1.4.0',
              'storeUrl': 'https://play.google.com/store/apps/details?id=x',
              'message': null,
              'forceUpdate': false,
            },
          }),
        ),
        platform: 'ANDROID',
      );

      final info = await service.check('1.2.0+3');
      expect(info.status, UpdateStatus.updateAvailable);
      expect(info.latest, '1.4.0');
      expect(info.currentVersion, '1.2.0+3');
    });

    test('sends platform and current version as query parameters', () async {
      RequestOptions? seen;
      final service = AppVersionService(
        dio: _stubDio((options) {
          seen = options;
          return _json({'success': true, 'data': <String, dynamic>{}});
        }),
        platform: 'IOS',
      );

      await service.check('2.0.0');
      expect(seen?.path, AppVersionService.path);
      expect(seen?.queryParameters['platform'], 'IOS');
      expect(seen?.queryParameters['current'], '2.0.0');
    });

    test('never throws: a 404 resolves to unknown', () async {
      final service = AppVersionService(
        dio: _stubDio((_) => ResponseBody.fromString('not found', 404)),
        platform: 'ANDROID',
      );
      expect((await service.check('1.0.0')).status, UpdateStatus.unknown);
    });

    test('never throws: a connection failure resolves to unknown', () async {
      final service = AppVersionService(
        dio: _stubDio((_) => throw const SocketExceptionLike()),
        platform: 'ANDROID',
      );
      expect((await service.check('1.0.0')).status, UpdateStatus.unknown);
    });

    test('never throws: a malformed body resolves to unknown', () async {
      final service = AppVersionService(
        dio: _stubDio((_) => ResponseBody.fromString('<html>', 200)),
        platform: 'ANDROID',
      );
      expect((await service.check('1.0.0')).status, UpdateStatus.unknown);
    });
  });
}

class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}

Dio _stubDio(ResponseBody Function(RequestOptions options) handler) {
  final dio = Dio(BaseOptions(baseUrl: 'http://stub/api/v1'));
  dio.httpClientAdapter = _StubAdapter(handler);
  return dio;
}

ResponseBody _json(Object body) => ResponseBody.fromString(
  jsonEncode(body),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);
}
