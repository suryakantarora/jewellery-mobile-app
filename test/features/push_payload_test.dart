import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_erp/features/notifications/data/push_registration_service.dart';
import 'package:jewellery_erp/features/notifications/domain/notification_models.dart';

void main() {
  group('NotificationRouter.pathFor (push reference types)', () {
    test('maps the backend reference type names exactly as written', () {
      expect(
        NotificationRouter.pathFor('InventoryMovement', 'm1'),
        '/transfers/m1',
      );
      expect(
        NotificationRouter.pathFor('PurchaseOrder', 'po1'),
        '/more/procurement/po/po1',
      );
      expect(
        NotificationRouter.pathFor('PURCHASE_ORDER', 'po1'),
        '/more/procurement/po/po1',
      );
      expect(
        NotificationRouter.pathFor('RepairRequest', 'r1'),
        '/more/repairs/r1',
      );
    });

    test('Sale has no detail route yet, so it resolves to nothing', () {
      expect(NotificationRouter.pathFor('Sale', 's1'), isNull);
    });

    test('missing pieces resolve to nothing', () {
      expect(NotificationRouter.pathFor(null, 'x'), isNull);
      expect(NotificationRouter.pathFor('InventoryMovement', null), isNull);
      expect(NotificationRouter.pathFor('InventoryMovement', ''), isNull);
    });
  });

  group('PushPayload', () {
    test('parses the FCM data map and resolves a path', () {
      final payload = PushPayload.fromData({
        'eventType': 'TRANSFER_APPROVED',
        'referenceType': 'InventoryMovement',
        'referenceId': 'm1',
        'notificationId': 'n1',
      }, title: 'Transfer approved');

      expect(payload.eventType, 'TRANSFER_APPROVED');
      expect(payload.notificationId, 'n1');
      expect(payload.path, '/transfers/m1');
      expect(payload.displayTitle, 'Transfer approved');
    });

    test('falls back to the inbox when the reference cannot be routed', () {
      final payload = PushPayload.fromData({
        'eventType': 'HIGH_VALUE_SALE',
        'referenceType': 'Sale',
        'referenceId': 's1',
      });
      expect(payload.path, '/more/notifications');
      // No OS title: the label for the event type is used instead.
      expect(payload.displayTitle, 'High-value sale');
    });

    test('an empty payload still lands on the inbox', () {
      expect(PushPayload.fromData(const {}).path, '/more/notifications');
      expect(PushPayload.fromData(const {}).displayTitle, 'New notification');
    });
  });

  group('NotificationEventTypes', () {
    test('labels and tones for the new staff events', () {
      expect(
        NotificationEventTypes.labelFor('TRANSFER_AWAITING_APPROVAL'),
        'Transfer awaiting approval',
      );
      expect(
        NotificationEventTypes.toneFor('TRANSFER_AWAITING_APPROVAL').name,
        'warning',
      );
      expect(
        NotificationEventTypes.toneFor('PURCHASE_ORDER_REJECTED').name,
        'danger',
      );
      expect(
        NotificationEventTypes.toneFor('REPAIR_READY_STAFF').name,
        'success',
      );
      expect(NotificationEventTypes.toneFor('HIGH_VALUE_SALE').name, 'warning');
      expect(NotificationEventTypes.toneFor('DISCOUNT_DECIDED').name, 'info');
    });

    test('unknown types get a title-cased label and keyword tone', () {
      expect(NotificationEventTypes.labelFor('SOMETHING_NEW'), 'Something New');
      expect(NotificationEventTypes.toneFor('THING_FAILED').name, 'danger');
    });
  });
}
