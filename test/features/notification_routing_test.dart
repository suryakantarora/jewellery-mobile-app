import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_erp/features/notifications/domain/notification_models.dart';

AppNotification notification({String? type, String? id}) => AppNotification(
      id: 'n1',
      eventType: 'ITEM_TRANSFERRED',
      referenceType: type,
      referenceId: id,
    );

void main() {
  group('Notification deep linking', () {
    test('routes each known reference type to its screen', () {
      expect(
        NotificationRouter.routeFor(notification(type: 'MOVEMENT', id: 'm1')),
        '/transfers/m1',
      );
      expect(
        NotificationRouter.routeFor(
          notification(type: 'JEWELLERY_ITEM', id: 'i1'),
        ),
        '/inventory/item/i1',
      );
      expect(
        NotificationRouter.routeFor(notification(type: 'REPAIR', id: 'r1')),
        '/more/repairs/r1',
      );
      expect(
        NotificationRouter.routeFor(notification(type: 'EXCHANGE', id: 'e1')),
        '/more/exchange/e1',
      );
      expect(
        NotificationRouter.routeFor(notification(type: 'CUSTOMER', id: 'c1')),
        '/more/customers/c1',
      );
    });

    test('is case-insensitive about the reference type', () {
      expect(
        NotificationRouter.routeFor(notification(type: 'movement', id: 'm1')),
        '/transfers/m1',
      );
    });

    test('an unknown reference type has no destination', () {
      // Returning null is deliberate: the caller then shows the notification's
      // own detail, which is always better than a blank route or a crash. The
      // backend has not yet established a reference-type vocabulary.
      expect(
        NotificationRouter.routeFor(
          notification(type: 'SOMETHING_NEW', id: 'x1'),
        ),
        isNull,
      );
      expect(
        NotificationRouter.canOpen(
          notification(type: 'SOMETHING_NEW', id: 'x1'),
        ),
        isFalse,
      );
    });

    test('a missing reference id has no destination', () {
      expect(NotificationRouter.routeFor(notification(type: 'MOVEMENT')), isNull);
      expect(
        NotificationRouter.routeFor(notification(type: 'MOVEMENT', id: '')),
        isNull,
      );
    });

    test('a notification with no reference at all has no destination', () {
      expect(NotificationRouter.routeFor(notification()), isNull);
    });
  });

  group('Notification display', () {
    test('falls back to a readable title when there is no subject', () {
      const item = AppNotification(id: 'n', eventType: 'TRANSFER_APPROVED');
      expect(item.title, 'Transfer Approved');
    });

    test('prefers the subject when the backend supplies one', () {
      const item = AppNotification(
        id: 'n',
        eventType: 'TRANSFER_APPROVED',
        subject: 'Transfer TR-10024 approved',
      );
      expect(item.title, 'Transfer TR-10024 approved');
    });

    test('tones reflect the outcome', () {
      expect(
        const AppNotification(id: 'n', eventType: 'PO_REJECTED').tone.name,
        'danger',
      );
      expect(
        const AppNotification(id: 'n', eventType: 'REPAIR_READY').tone.name,
        'success',
      );
    });
  });
}
