import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_erp/core/network/api_client.dart';
import 'package:jewellery_erp/features/jewellery/data/reference_data_service.dart';

/// Serves canned master data and counts requests, so coalescing can be proved
/// rather than assumed.
Dio _stubDio({Map<String, int>? hits}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://stub'));
  dio.httpClientAdapter = _StubAdapter(hits ?? {});
  return dio;
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.hits);

  final Map<String, int> hits;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    hits[path] = (hits[path] ?? 0) + 1;

    // A small delay, so concurrent callers genuinely overlap.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    if (path.contains('/products/')) {
      final id = path.split('/').last;
      return _json({
        'success': true,
        'data': {'id': id, 'sku': 'SKU-$id', 'name': 'Product $id'},
      });
    }
    if (path.contains('/designs/')) {
      final id = path.split('/').last;
      return _json({
        'success': true,
        'data': {'id': id, 'designCode': 'D-$id', 'name': 'Design $id'},
      });
    }
    if (path.endsWith('/metals')) {
      return _json({
        'success': true,
        'data': [
          {'id': 'm1', 'code': 'GOLD', 'name': 'Gold'},
        ],
      });
    }
    if (path.contains('/purities')) {
      return _json({
        'success': true,
        'data': [
          {'id': 'p1', 'metalId': 'm1', 'code': '22K', 'name': '22 Karat'},
        ],
      });
    }
    if (path.endsWith('/product-categories') || path.endsWith('/product-types')) {
      return _json({'success': true, 'data': <Map<String, dynamic>>[]});
    }
    if (path.contains('/locations')) {
      return _json({'success': true, 'data': <Map<String, dynamic>>[]});
    }
    return _json({'success': true, 'data': null});
  }

  ResponseBody _json(Object body) => ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
}

void main() {
  group('Reference data loading', () {
    test('a product load completes rather than deadlocking', () async {
      // Regression: the in-flight entry used to be cleared with
      // `.whenComplete(() => map.remove(id))`. `Map.remove` returns the removed
      // value — the very future being chained — and `whenComplete` waits on a
      // Future its callback returns, so each load waited on itself and never
      // completed. Every list that awaited it hung forever on a screen full of
      // skeletons, with every request having returned 200.
      final service = ReferenceDataService(ApiClient(_stubDio()));

      final product = await service.product('abc').timeout(
            const Duration(seconds: 2),
            onTimeout: () => throw StateError('product() deadlocked'),
          );

      expect(product, isNotNull);
      expect(product!.name, 'Product abc');
    });

    test('a design load completes', () async {
      final service = ReferenceDataService(ApiClient(_stubDio()));
      final design = await service.design('xyz').timeout(
            const Duration(seconds: 2),
            onTimeout: () => throw StateError('design() deadlocked'),
          );
      expect(design?.name, 'Design xyz');
    });

    test('concurrent loads of the same id issue one request', () async {
      final hits = <String, int>{};
      final service = ReferenceDataService(ApiClient(_stubDio(hits: hits)));

      // Twenty rows referencing one product must produce one request.
      await Future.wait(List.generate(20, (_) => service.product('same')));

      expect(hits['/products/same'], 1);
    });

    test('warmFor resolves every distinct product exactly once', () async {
      final hits = <String, int>{};
      final service = ReferenceDataService(ApiClient(_stubDio(hits: hits)));

      // A page of twenty items referencing five products.
      final productIds = [
        for (var i = 0; i < 20; i++) 'p${i % 5}',
      ];

      await service.warmFor(productIds).timeout(
            const Duration(seconds: 3),
            onTimeout: () => throw StateError('warmFor deadlocked'),
          );

      for (var i = 0; i < 5; i++) {
        expect(hits['/products/p$i'], 1, reason: 'p$i should load once');
      }
      expect(service.cachedProduct('p0'), isNotNull);
    });

    test('a second call after completion is served from cache', () async {
      final hits = <String, int>{};
      final service = ReferenceDataService(ApiClient(_stubDio(hits: hits)));

      await service.product('cached');
      await service.product('cached');

      expect(hits['/products/cached'], 1);
    });

    test('prefetch populates metals and purities', () async {
      final service = ReferenceDataService(ApiClient(_stubDio()));
      await service.prefetch().timeout(const Duration(seconds: 3));

      expect(service.metals, hasLength(1));
      expect(service.materialLabel('m1', 'p1'), '22K Gold');
    });

    test('clear empties the cache so a branch switch cannot leak', () async {
      final service = ReferenceDataService(ApiClient(_stubDio()));
      await service.product('leak');
      expect(service.cachedProduct('leak'), isNotNull);

      service.clear();
      expect(service.cachedProduct('leak'), isNull);
    });
  });
}
