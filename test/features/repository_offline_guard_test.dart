import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_erp/core/connectivity/connectivity_controller.dart';
import 'package:jewellery_erp/core/connectivity/offline_guard.dart';
import 'package:jewellery_erp/core/errors/app_exception.dart';
import 'package:jewellery_erp/core/network/api_client.dart';
import 'package:jewellery_erp/features/jewellery/data/jewellery_repository.dart';
import 'package:jewellery_erp/features/jewellery/domain/jewellery_item.dart';
import 'package:jewellery_erp/features/transfers/data/movement_repository.dart';
import 'package:jewellery_erp/features/transfers/domain/movement.dart';
import 'package:jewellery_erp/features/warehouse/data/warehouse_repository.dart';

/// Proves that a mutating repository call is refused before any request is
/// made while offline, and that reads still go through.
void main() {
  late Map<String, int> hits;
  late ApiClient client;

  setUp(() {
    hits = {};
    final dio = Dio(BaseOptions(baseUrl: 'http://stub/api/v1'));
    dio.httpClientAdapter = _CountingAdapter(hits);
    client = ApiClient(dio);
  });

  group('OfflineGuard.reading', () {
    test('consults the reader on every call, not at construction', () async {
      var state = ConnectivityState.offline;
      final guard = OfflineGuard.reading(() => state);

      expect(guard.allowsMutation, isFalse);
      state = ConnectivityState.online;
      expect(guard.allowsMutation, isTrue);
      expect(await guard.run(() async => 'ran'), 'ran');
    });
  });

  group('JewelleryRepository', () {
    test(
      'refuses a reservation while offline without hitting the network',
      () async {
        final repository = JewelleryRepository(
          client,
          offlineGuard: const OfflineGuard(ConnectivityState.offline),
        );

        await expectLater(
          repository.reserve(itemId: 'i1', customerId: 'c1'),
          throwsA(isA<OfflineActionException>()),
        );
        expect(hits, isEmpty);
      },
    );

    test('refuses a status change when the API is unreachable', () async {
      final repository = JewelleryRepository(
        client,
        offlineGuard: const OfflineGuard(ConnectivityState.degraded),
      );

      await expectLater(
        repository.changeStatus(
          itemId: 'i1',
          target: ItemStatus.available,
          reason: 'test',
        ),
        throwsA(isA<OfflineActionException>()),
      );
      expect(hits, isEmpty);
    });

    test('reads are never guarded', () async {
      final repository = JewelleryRepository(
        client,
        offlineGuard: const OfflineGuard(ConnectivityState.offline),
      );

      final item = await repository.byId('i1');
      expect(item.id, 'i1');
      expect(hits['/inventory/items/i1'], 1);
    });

    test('mutations go through when online', () async {
      final repository = JewelleryRepository(
        client,
        offlineGuard: const OfflineGuard(ConnectivityState.online),
      );

      await repository.reserve(itemId: 'i1', customerId: 'c1');
      expect(hits['/inventory/reservations'], 1);
    });

    test('a repository built without a guard behaves as before', () async {
      final repository = JewelleryRepository(client);
      await repository.reserve(itemId: 'i1', customerId: 'c1');
      expect(hits['/inventory/reservations'], 1);
    });
  });

  group('MovementRepository', () {
    test('refuses create, dispatch and receive while offline', () async {
      final repository = MovementRepository(
        client,
        offlineGuard: const OfflineGuard(ConnectivityState.offline),
      );

      await expectLater(
        repository.create(
          movementType: MovementType.transfer,
          toLocationId: 'l2',
          itemIds: const ['i1'],
        ),
        throwsA(isA<OfflineActionException>()),
      );
      await expectLater(
        repository.dispatch('m1'),
        throwsA(isA<OfflineActionException>()),
      );
      await expectLater(
        repository.receive('m1'),
        throwsA(isA<OfflineActionException>()),
      );
      expect(hits, isEmpty);
    });
  });

  group('WarehouseRepository', () {
    test('refuses a stock count submit while offline', () async {
      final repository = WarehouseRepository(
        client,
        offlineGuard: const OfflineGuard(ConnectivityState.offline),
      );

      await expectLater(
        repository.submit('sc1', foundItemIds: const ['i1']),
        throwsA(isA<OfflineActionException>()),
      );
      expect(hits, isEmpty);
    });
  });
}

class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter(this.hits);

  final Map<String, int> hits;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    hits[options.path] = (hits[options.path] ?? 0) + 1;
    final id = options.path.split('/').last;
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {
          'id': id == 'reservations' ? 'i1' : id,
          'itemCode': 'JW-1',
          'status': 'AVAILABLE',
          'allowedTransitions': <String>[],
          'grossWeight': 1.0,
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
