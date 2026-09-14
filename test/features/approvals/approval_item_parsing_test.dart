import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_erp/core/constants/permissions.dart';
import 'package:jewellery_erp/features/approvals/domain/approval_models.dart';

/// The unified approvals endpoint returns one shape for every type; this
/// pins the mapping from the backend's `type` codes to [ApprovalKind] for all
/// seven, plus the counts payload.
void main() {
  Map<String, dynamic> row(String type, {Map<String, dynamic>? extra}) => {
    'type': type,
    'id': 'id-$type',
    'reference': 'REF-$type',
    'summary': 'summary',
    'branchId': 'b1',
    'branchName': 'Vientiane',
    'requestedBy': 'Sone',
    'requestedAt': '2026-09-10T08:00:00Z',
    'amount': 1250000,
    'currency': 'LAK',
    'awaitingSecondApproval': false,
    'infoRequested': false,
    ...?extra,
  };

  group('ApprovalItem.fromJson', () {
    const expected = {
      'TRANSFER': ApprovalKind.transfer,
      'PURCHASE_ORDER': ApprovalKind.purchaseOrder,
      'REQUISITION': ApprovalKind.requisition,
      'EXCHANGE': ApprovalKind.exchange,
      'STOCK_COUNT': ApprovalKind.stockCount,
      'GOODS_RECEIPT': ApprovalKind.goodsReceipt,
      'DISCOUNT': ApprovalKind.discount,
    };

    for (final entry in expected.entries) {
      test('parses ${entry.key}', () {
        final item = ApprovalItem.fromJson(row(entry.key));
        expect(item, isNotNull);
        expect(item!.kind, entry.value);
        expect(item.id, 'id-${entry.key}');
        expect(item.reference, 'REF-${entry.key}');
        expect(item.branchName, 'Vientiane');
        expect(item.requestedBy, 'Sone');
        expect(item.requestedAt, DateTime.utc(2026, 9, 10, 8));
        expect(item.amount, 1250000);
        expect(item.currency, 'LAK');
      });
    }

    test('covers every kind the enum knows', () {
      expect(expected.values.toSet(), ApprovalKind.values.toSet());
    });

    test('returns null for a type this build does not know', () {
      expect(ApprovalItem.fromJson(row('LOYALTY_ADJUSTMENT')), isNull);
    });

    test('reads the dual-authorisation and info-requested flags', () {
      final item = ApprovalItem.fromJson(
        row(
          'STOCK_COUNT',
          extra: {'awaitingSecondApproval': true, 'infoRequested': true},
        ),
      );
      expect(item!.awaitingSecondApproval, isTrue);
      expect(item.infoRequested, isTrue);
    });

    test('tolerates a sparse payload', () {
      final item = ApprovalItem.fromJson({'type': 'TRANSFER', 'id': 't1'});
      expect(item!.reference, '');
      expect(item.requestedAt, isNull);
      expect(item.amount, isNull);
      expect(item.infoRequested, isFalse);
    });

    test('money and vault-grade decisions require the detail view', () {
      expect(
        ApprovalItem.fromJson({
          'type': 'DISCOUNT',
          'id': 'd',
        })!.requiresDetailView,
        isTrue,
      );
      expect(
        ApprovalItem.fromJson({
          'type': 'EXCHANGE',
          'id': 'e',
        })!.requiresDetailView,
        isTrue,
      );
      expect(
        ApprovalItem.fromJson({
          'type': 'TRANSFER',
          'id': 't',
        })!.requiresDetailView,
        isFalse,
      );
      expect(
        ApprovalItem.fromJson({
          'type': 'TRANSFER',
          'id': 't',
          'amount': 1,
        })!.requiresDetailView,
        isTrue,
      );
    });
  });

  group('ApprovalKind', () {
    test('answering an info request needs the create permission', () {
      expect(
        ApprovalKind.discount.createPermission,
        Permission.discountRequest,
      );
      expect(
        ApprovalKind.goodsReceipt.createPermission,
        Permission.procurementReceive,
      );
      expect(
        ApprovalKind.transfer.createPermission,
        Permission.inventoryTransfer,
      );
    });
  });

  group('ApprovalCounts.fromJson', () {
    test('maps byType and drops zeros and unknown types', () {
      final counts = ApprovalCounts.fromJson({
        'total': 5,
        'byType': {
          'TRANSFER': 2,
          'PURCHASE_ORDER': 0,
          'REQUISITION': 1,
          'EXCHANGE': 0,
          'STOCK_COUNT': 0,
          'GOODS_RECEIPT': 1,
          'DISCOUNT': 1,
          'SOMETHING_NEW': 4,
        },
      });
      expect(counts.total, 5);
      expect(counts.byKind, {
        ApprovalKind.transfer: 2,
        ApprovalKind.requisition: 1,
        ApprovalKind.goodsReceipt: 1,
        ApprovalKind.discount: 1,
      });
    });
  });

  group('ApprovalDecision', () {
    test('only an approval may omit the reason', () {
      expect(ApprovalDecision.approve.requiresReason, isFalse);
      expect(ApprovalDecision.reject.requiresReason, isTrue);
      expect(ApprovalDecision.requestInfo.requiresReason, isTrue);
      expect(ApprovalDecision.requestInfo.code, 'REQUEST_INFO');
    });
  });

  group('InformationRequest.fromJson', () {
    test('an unanswered question is open', () {
      final request = InformationRequest.fromJson({
        'id': 'q1',
        'message': 'Why this supplier?',
        'requestedBy': 'Manager',
      });
      expect(request.open, isTrue);
      expect(request.answer, isNull);
    });

    test('an answered question is closed', () {
      final request = InformationRequest.fromJson({
        'id': 'q1',
        'message': 'Why?',
        'answer': 'Because.',
        'answeredBy': 'Sone',
        'open': false,
      });
      expect(request.open, isFalse);
      expect(request.answer, 'Because.');
    });
  });
}
