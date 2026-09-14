import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_erp/features/dashboard/domain/dashboard_summary.dart';
import 'package:jewellery_erp/features/jewellery/data/jewellery_repository.dart';
import 'package:jewellery_erp/features/jewellery/domain/jewellery_item.dart';

void main() {
  group('DashboardSummary.fromJson', () {
    test('an omitted section is null, not an error', () {
      final summary = DashboardSummary.fromJson({
        'branchId': 'b1',
        'branchName': 'Main',
        'notifications': {'unread': 3},
        'inventory': {'totalItems': 120, 'availableItems': 100},
      });

      expect(summary.sales, isNull);
      expect(summary.inventoryValue, isNull);
      expect(summary.transfers, isNull);
      expect(summary.approvals, isNull);
      expect(summary.repairs, isNull);
      expect(summary.procurement, isNull);
      expect(summary.metalRates, isEmpty);
      expect(summary.inventory?.totalItems, 120);
      expect(summary.inventory?.availableItems, 100);
      expect(summary.inventory?.reservedItems, isNull);
      expect(summary.unreadNotifications, 3);
      expect(summary.isEmpty, isFalse);
    });

    test('money arrives as decimal strings or numbers', () {
      final summary = DashboardSummary.fromJson({
        'sales': {
          'todayCount': '4',
          'todayTotal': '12345.50',
          'currency': 'INR',
          'monthToDateTotal': 99000,
        },
        'inventoryValue': {'costValue': '1.5', 'retailValue': 2},
        'metalRates': [
          {
            'metalName': 'Gold',
            'purityCode': '22K',
            'rate': '6250.00',
            'currency': 'INR',
            'stale': true,
            'publishedAt': '2026-09-14T08:00:00Z',
          },
          {'metalName': 'Silver', 'rate': 80},
        ],
      });

      expect(summary.sales?.todayCount, 4);
      expect(summary.sales?.todayTotal, 12345.50);
      expect(summary.sales?.monthToDateTotal, 99000);
      expect(summary.inventoryValue?.costValue, 1.5);
      expect(summary.inventoryValue?.retailValue, 2);

      expect(summary.metalRates.length, 2);
      expect(summary.metalRates.first.label, '22K Gold');
      expect(summary.metalRates.first.rate, 6250);
      expect(summary.metalRates.first.stale, isTrue);
      expect(summary.metalRates.first.publishedAt, isNotNull);
      expect(summary.metalRates.last.label, 'Silver');
      expect(summary.metalRates.last.stale, isFalse);
    });

    test('approvals byType keeps only numeric counts', () {
      final summary = DashboardSummary.fromJson({
        'approvals': {
          'total': 7,
          'byType': {'TRANSFER': 5, 'PURCHASE_ORDER': '2', 'BROKEN': null},
        },
      });

      expect(summary.approvals?.total, 7);
      expect(summary.approvals?.byType, {'TRANSFER': 5, 'PURCHASE_ORDER': 2});
    });

    test('garbage numbers become null rather than throwing', () {
      expect(parseNum('abc'), isNull);
      expect(parseNum(null), isNull);
      expect(parseNum(' 12 '), 12);
      expect(parseInt('3.7'), 3);
    });
  });

  group('JewelleryItem display names', () {
    test('parses the server-supplied names and builds a material label', () {
      final item = JewelleryItem.fromJson({
        'id': 'i1',
        'itemCode': 'RNG-1',
        'productName': 'Solitaire',
        'productCode': 'SKU-1',
        'designName': 'Classic',
        'metalName': 'Gold',
        'purityCode': '22K',
        'currentLocationName': 'Counter 1',
        'currentBranchName': 'Main',
        'binCode': 'B-07',
        'supplierName': 'ACME',
      });

      expect(item.productName, 'Solitaire');
      expect(item.productCode, 'SKU-1');
      expect(item.designName, 'Classic');
      expect(item.currentLocationName, 'Counter 1');
      expect(item.currentBranchName, 'Main');
      expect(item.binCode, 'B-07');
      expect(item.supplierName, 'ACME');
      expect(item.materialLabel, '22K Gold');
    });

    test('older payloads leave the names null', () {
      final item = JewelleryItem.fromJson({'id': 'i1', 'itemCode': 'RNG-1'});
      expect(item.productName, isNull);
      expect(item.materialLabel, isNull);
    });
  });

  group('ItemSearchFilters price range', () {
    test('counts once, clears, and serialises both bounds', () {
      const filters = ItemSearchFilters(
        branchId: 'b1',
        status: ItemStatus.available,
        minPrice: 1000,
        maxPrice: 5000.5,
      );

      expect(filters.hasPriceRange, isTrue);
      expect(filters.activeCount, 2);
      expect(filters.toQuery(page: 0, size: 20), {
        'page': 0,
        'size': 20,
        'branchId': 'b1',
        'status': 'AVAILABLE',
        'minPrice': 1000,
        'maxPrice': 5000.5,
      });

      final cleared = filters.cleared();
      expect(cleared.hasPriceRange, isFalse);
      expect(cleared.activeCount, 0);
      expect(cleared.branchId, 'b1');
    });

    test('equality includes the bounds', () {
      const a = ItemSearchFilters(minPrice: 1);
      const b = ItemSearchFilters(minPrice: 1);
      const c = ItemSearchFilters(minPrice: 1, maxPrice: 2);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.copyWith(maxPrice: 2), c);
      expect(c.copyWith(minPrice: null, maxPrice: null).hasPriceRange, isFalse);
    });
  });
}
