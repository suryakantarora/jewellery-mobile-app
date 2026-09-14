import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_erp/core/connectivity/connectivity_controller.dart';
import 'package:jewellery_erp/core/connectivity/offline_guard.dart';
import 'package:jewellery_erp/core/errors/app_exception.dart';
import 'package:jewellery_erp/core/network/api_client.dart';
import 'package:jewellery_erp/features/customers/data/customer_repository.dart';
import 'package:jewellery_erp/features/customers/domain/customer_models.dart';
import 'package:jewellery_erp/features/sales/data/sales_repository.dart';
import 'package:jewellery_erp/features/sales/domain/sales_models.dart';

void main() {
  group('DiscountRequest.fromJson', () {
    test('parses a percentage request', () {
      final request = DiscountRequest.fromJson({
        'id': 'dr1',
        'branchId': 'b1',
        'customerId': 'c1',
        'jewelleryItemId': 'i1',
        'requestedPercentage': 7.5,
        'currency': 'LAK',
        'reason': 'Repeat customer',
        'status': 'PENDING',
        'requestedBy': 'Sone',
        'requestedAt': '2026-09-12T03:00:00Z',
        'expiresAt': '2026-09-13T03:00:00Z',
      });
      expect(request.id, 'dr1');
      expect(request.isPercentage, isTrue);
      expect(request.requestedPercentage, 7.5);
      expect(request.requestedAmount, isNull);
      expect(request.status, DiscountRequestStatus.pending);
      expect(request.canCancel, isTrue);
      expect(request.requestedAt, DateTime.utc(2026, 9, 12, 3));
      expect(request.expiresAt, DateTime.utc(2026, 9, 13, 3));
    });

    test('parses an amount request with its decision', () {
      final request = DiscountRequest.fromJson({
        'id': 'dr2',
        'branchId': 'b1',
        'requestedAmount': 250000,
        'currency': 'LAK',
        'reason': 'Scratch on clasp',
        'status': 'APPROVED',
        'decidedBy': 'Manager',
        'decidedAt': '2026-09-12T04:00:00Z',
        'decisionNote': 'Fine',
        'consumedBySaleId': null,
      });
      expect(request.isPercentage, isFalse);
      expect(request.requestedAmount, 250000);
      expect(request.status, DiscountRequestStatus.approved);
      expect(request.canCancel, isFalse);
      expect(request.decidedBy, 'Manager');
      expect(request.decisionNote, 'Fine');
      expect(request.consumedBySaleId, isNull);
    });

    test('maps every status and keeps unknown ones safe', () {
      for (final code in [
        'PENDING',
        'APPROVED',
        'REJECTED',
        'CONSUMED',
        'EXPIRED',
        'CANCELLED',
      ]) {
        expect(DiscountRequestStatus.fromCode(code).code, code);
      }
      expect(
        DiscountRequestStatus.fromCode('SOMETHING'),
        DiscountRequestStatus.unknown,
      );
      expect(
        DiscountRequestStatus.fromCode(null),
        DiscountRequestStatus.unknown,
      );
    });
  });

  group('ProductAvailability.fromJson', () {
    test('keeps zero-stock branches, as the backend intends', () {
      final availability = ProductAvailability.fromJson({
        'productId': 'p1',
        'productName': 'Classic Solitaire',
        'branches': [
          {
            'branchId': 'b1',
            'branchName': 'Vientiane',
            'available': 2,
            'total': 3,
          },
          {'branchId': 'b2', 'branchName': 'Pakse', 'available': 0, 'total': 0},
        ],
      });
      expect(availability.productName, 'Classic Solitaire');
      expect(availability.branches, hasLength(2));
      expect(availability.branches.first.inStock, isTrue);
      expect(availability.branches.first.total, 3);
      expect(availability.branches.last.inStock, isFalse);
    });
  });

  group('WishlistEntry.fromJson', () {
    test('distinguishes a piece from a product-only wish', () {
      final piece = WishlistEntry.fromJson({
        'id': 'w1',
        'customerId': 'c1',
        'jewelleryItemId': 'i1',
        'itemCode': 'JW-1',
        'productName': 'Ring',
        'currentPrice': 100,
        'currency': 'LAK',
      });
      expect(piece.hasItem, isTrue);
      expect(piece.title, 'JW-1');

      final wish = WishlistEntry.fromJson({
        'id': 'w2',
        'customerId': 'c1',
        'productId': 'p1',
        'productName': 'Ring',
      });
      expect(wish.hasItem, isFalse);
      expect(wish.title, 'Ring');
    });
  });

  group('offline guard', () {
    late Map<String, int> hits;
    late ApiClient client;

    setUp(() {
      hits = {};
      final dio = Dio(BaseOptions(baseUrl: 'http://stub/api/v1'));
      dio.httpClientAdapter = _CountingAdapter(hits);
      client = ApiClient(dio);
    });

    test('SalesRepository refuses discount mutations while offline', () async {
      final repository = SalesRepository(
        client,
        offlineGuard: const OfflineGuard(ConnectivityState.offline),
      );
      await expectLater(
        repository.createDiscountRequest(
          branchId: 'b1',
          reason: 'test',
          percentage: 5,
        ),
        throwsA(isA<OfflineActionException>()),
      );
      await expectLater(
        repository.cancelDiscountRequest('dr1'),
        throwsA(isA<OfflineActionException>()),
      );
      await expectLater(
        repository.approveDiscountRequest('dr1'),
        throwsA(isA<OfflineActionException>()),
      );
      await expectLater(
        repository.rejectDiscountRequest('dr1', 'no'),
        throwsA(isA<OfflineActionException>()),
      );
      expect(hits, isEmpty);
    });

    test('SalesRepository reads still go through offline', () async {
      final repository = SalesRepository(
        client,
        offlineGuard: const OfflineGuard(ConnectivityState.offline),
      );
      final page = await repository.discountRequests(mine: true);
      expect(page.content, isEmpty);
      expect(hits, containsPair('/sales/discount-requests', 1));
    });

    test('CustomerRepository refuses wishlist mutations offline', () async {
      final repository = CustomerRepository(
        client,
        offlineGuard: const OfflineGuard(ConnectivityState.offline),
      );
      await expectLater(
        repository.addToWishlist('c1', jewelleryItemId: 'i1'),
        throwsA(isA<OfflineActionException>()),
      );
      await expectLater(
        repository.removeFromWishlist('c1', 'w1'),
        throwsA(isA<OfflineActionException>()),
      );
      await expectLater(
        repository.create(fullName: 'A', phone: '1'),
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
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {
          'content': <Object>[],
          'page': 0,
          'size': 20,
          'totalElements': 0,
          'totalPages': 0,
          'last': true,
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
