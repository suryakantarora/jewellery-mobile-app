import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/status_badge.dart';

/// A notification record.
///
/// Backed by `GET /notifications/mine`, which is scoped to the caller from the
/// security context — the app never sends a recipient id, so it cannot ask for
/// someone else's mail. Read state is a server field (`readAt`), so marking one
/// read on the phone is reflected on every other device.
///
/// Push delivery arrives through `PushRegistrationService` (FCM) when Firebase
/// is configured; the inbox still polls so nothing depends on it.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.eventType,
    this.subject,
    this.body,
    this.channel,
    this.status,
    this.referenceType,
    this.referenceId,
    this.sentAt,
    this.createdAt,
    this.readAt,
  });

  final String id;
  final String eventType;
  final String? subject;
  final String? body;
  final String? channel;
  final String? status;

  /// What the notification is about. Drives deep linking.
  final String? referenceType;
  final String? referenceId;

  final DateTime? sentAt;
  final DateTime? createdAt;

  /// When this user opened the notification. Server-held, so it is consistent
  /// across a user's devices.
  final DateTime? readAt;

  bool get read => readAt != null;

  DateTime? get occurredAt => sentAt ?? createdAt;

  String get title => subject?.isNotEmpty ?? false
      ? subject!
      : eventType
            .split('_')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0]}${word.substring(1).toLowerCase()}',
            )
            .join(' ');

  StatusTone get tone => NotificationEventTypes.toneFor(eventType);

  AppNotification copyWith({DateTime? readAt}) => AppNotification(
    id: id,
    eventType: eventType,
    subject: subject,
    body: body,
    channel: channel,
    status: status,
    referenceType: referenceType,
    referenceId: referenceId,
    sentAt: sentAt,
    createdAt: createdAt,
    readAt: readAt ?? this.readAt,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String? ?? '',
        eventType: json['eventType'] as String? ?? 'NOTIFICATION',
        subject: json['subject'] as String?,
        body: json['body'] as String?,
        channel: json['channel'] as String?,
        status: json['status'] as String?,
        referenceType: json['referenceType'] as String?,
        referenceId: json['referenceId'] as String?,
        sentAt: DateTime.tryParse(json['sentAt'] as String? ?? ''),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        readAt: DateTime.tryParse(json['readAt'] as String? ?? ''),
      );
}

/// The staff-facing event types the backend emits, with a display label and a
/// tone for each.
///
/// Unknown types still render: the label falls back to a title-cased event
/// name and the tone to a keyword match, so a new backend event never breaks
/// the inbox.
abstract final class NotificationEventTypes {
  static const labels = <String, String>{
    'ITEM_TRANSFERRED': 'Item transferred',
    'LOW_STOCK': 'Low stock',
    'TRANSFER_AWAITING_APPROVAL': 'Transfer awaiting approval',
    'TRANSFER_APPROVED': 'Transfer approved',
    'TRANSFER_REJECTED': 'Transfer rejected',
    'PURCHASE_ORDER_APPROVED': 'Purchase order approved',
    'PURCHASE_ORDER_REJECTED': 'Purchase order rejected',
    'REPAIR_READY_STAFF': 'Repair ready for collection',
    'HIGH_VALUE_SALE': 'High-value sale',
    'APPROVAL_INFO_REQUESTED': 'Information requested',
    'APPROVAL_INFO_ANSWERED': 'Information provided',
    'DISCOUNT_REQUESTED': 'Discount requested',
    'DISCOUNT_DECIDED': 'Discount decided',
  };

  static const _tones = <String, StatusTone>{
    'TRANSFER_AWAITING_APPROVAL': StatusTone.warning,
    'TRANSFER_APPROVED': StatusTone.success,
    'TRANSFER_REJECTED': StatusTone.danger,
    'PURCHASE_ORDER_APPROVED': StatusTone.success,
    'PURCHASE_ORDER_REJECTED': StatusTone.danger,
    'REPAIR_READY_STAFF': StatusTone.success,
    'HIGH_VALUE_SALE': StatusTone.warning,
    'APPROVAL_INFO_REQUESTED': StatusTone.warning,
    'APPROVAL_INFO_ANSWERED': StatusTone.info,
    'DISCOUNT_REQUESTED': StatusTone.warning,
    'DISCOUNT_DECIDED': StatusTone.info,
    'LOW_STOCK': StatusTone.warning,
  };

  static String labelFor(String eventType) =>
      labels[eventType.toUpperCase()] ??
      eventType
          .split('_')
          .map(
            (word) => word.isEmpty
                ? word
                : '${word[0]}${word.substring(1).toLowerCase()}',
          )
          .join(' ');

  static StatusTone toneFor(String eventType) {
    final upper = eventType.toUpperCase();
    final known = _tones[upper];
    if (known != null) return known;
    return switch (upper) {
      final type when type.contains('REJECT') || type.contains('FAIL') =>
        StatusTone.danger,
      final type when type.contains('APPROV') => StatusTone.success,
      final type when type.contains('READY') => StatusTone.success,
      _ => StatusTone.info,
    };
  }
}

/// Turns a notification's reference into a route.
///
/// The keys are the literal `referenceType` values `BusinessEventListener`
/// writes, matched case-insensitively. Customer-facing events are listed too,
/// because an administrator reading the delivery log sees them even though they
/// never reach a staff inbox.
abstract final class NotificationRouter {
  static const _routes = <String, String Function(String id)>{
    // Exactly as BusinessEventListener writes them.
    'INVENTORYMOVEMENT': AppRoutes.transferDetailPath,
    'REPAIRREQUEST': AppRoutes.repairPath,
    'MOVEMENT': AppRoutes.transferDetailPath,
    'TRANSFER': AppRoutes.transferDetailPath,
    'JEWELLERY_ITEM': AppRoutes.itemDetailPath,
    'ITEM': AppRoutes.itemDetailPath,
    'REPAIR': AppRoutes.repairPath,
    'PURCHASE_ORDER': AppRoutes.purchaseOrderPath,
    'PURCHASEORDER': AppRoutes.purchaseOrderPath,
    'EXCHANGE': AppRoutes.exchangePath,
    'STOCK_COUNT': AppRoutes.stockCountPath,
    'CUSTOMER': AppRoutes.customerPath,
  };

  /// The route a notification should open, or null when it has no destination.
  ///
  /// An unknown `referenceType` returns null rather than guessing — the caller
  /// then shows the notification's own detail, which is always better than a
  /// blank route or a crash.
  static String? routeFor(AppNotification notification) =>
      pathFor(notification.referenceType, notification.referenceId);

  /// The same resolution from a raw pair, as a push payload carries it.
  ///
  /// `Sale` is deliberately absent: the app has a sales list
  /// (`AppRoutes.sales`) but no sale detail route yet, so a `HIGH_VALUE_SALE`
  /// push opens the inbox rather than a wrong screen. Add a mapping here once
  /// a sale detail screen exists.
  static String? pathFor(String? referenceType, String? referenceId) {
    final type = referenceType?.toUpperCase();
    final id = referenceId;
    if (type == null || id == null || id.isEmpty) return null;

    final builder = _routes[type];
    return builder?.call(id);
  }

  static bool canOpen(AppNotification notification) =>
      routeFor(notification) != null;
}
