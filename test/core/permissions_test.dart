import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_erp/core/constants/permissions.dart';

void main() {
  group('Permission parsing', () {
    test('maps backend codes onto the enum', () {
      expect(Permission.fromCode('INVENTORY_VIEW'), Permission.inventoryView);
      expect(
        Permission.fromCode('INVENTORY_TRANSFER_APPROVE'),
        Permission.inventoryTransferApprove,
      );
      expect(Permission.fromCode('DISCOUNT_APPROVE'), Permission.discountApprove);
    });

    test('matches the live permission table exactly', () {
      // Verified against a running backend: identity.permission holds 67 rows
      // and the enum mirrors them one-for-one. A drift here means the mobile
      // build and the server disagree about what a user can do.
      expect(Permission.values, hasLength(67));
    });

    test('keeps unknown codes instead of dropping them', () {
      // The backend must be able to add a permission without a mobile release
      // silently discarding it.
      final permissions = PermissionSet.fromCodes([
        'INVENTORY_VIEW',
        'SOMETHING_NEW_FROM_BACKEND',
      ]);

      expect(permissions.has(Permission.inventoryView), isTrue);
      expect(permissions.unknownCodes, contains('SOMETHING_NEW_FROM_BACKEND'));
      expect(permissions.granted, hasLength(1));
    });

    test('does not grant a permission that was not sent', () {
      final permissions = PermissionSet.fromCodes(['INVENTORY_VIEW']);
      expect(permissions.has(Permission.inventoryTransfer), isFalse);
    });
  });

  group('PermissionSet', () {
    final set = PermissionSet.fromCodes([
      'INVENTORY_VIEW',
      'INVENTORY_TRANSFER',
    ]);

    test('hasAny requires at least one', () {
      expect(
        set.hasAny([Permission.repairView, Permission.inventoryTransfer]),
        isTrue,
      );
      expect(
        set.hasAny([Permission.repairView, Permission.saleCreate]),
        isFalse,
      );
    });

    test('hasAll requires every one', () {
      expect(
        set.hasAll([Permission.inventoryView, Permission.inventoryTransfer]),
        isTrue,
      );
      expect(
        set.hasAll([Permission.inventoryView, Permission.repairView]),
        isFalse,
      );
    });

    test('super admin mirrors the backend bypass', () {
      final admin = PermissionSet.fromCodes(const [], superAdmin: true);
      expect(admin.has(Permission.financeManage), isTrue);
      expect(admin.hasAll(Permission.values), isTrue);
    });

    test('empty set grants nothing', () {
      expect(PermissionSet.empty.has(Permission.inventoryView), isFalse);
      expect(PermissionSet.empty.isEmpty, isTrue);
    });
  });
}
