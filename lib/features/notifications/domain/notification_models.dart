import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/status_badge.dart';

/// A notification record.
///
/// Backed by `GET /notifications/mine`, which is scoped to the caller from the
/// security context — the app never sends a recipient id, so it cannot ask for
/// someone else's mail. Read state is a server field (`readAt`), so marking one
/// read on the phone is reflected on every other device.
///
/// Push delivery is still absent: there is no device registration endpoint, so
/// the inbox is poll-on-open rather than pushed. See BACKEND-GAPS.
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

  StatusTone get tone => switch (eventType) {
    final type when type.contains('REJECT') || type.contains('FAIL') =>
      StatusTone.danger,
    final type when type.contains('APPROV') => StatusTone.success,
    final type when type.contains('READY') => StatusTone.success,
    _ => StatusTone.info,
  };

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
    'EXCHANGE': AppRoutes.exchangePath,
    'STOCK_COUNT': AppRoutes.stockCountPath,
    'CUSTOMER': AppRoutes.customerPath,
  };

  /// The route a notification should open, or null when it has no destination.
  ///
  /// An unknown `referenceType` returns null rather than guessing — the caller
  /// then shows the notification's own detail, which is always better than a
  /// blank route or a crash.
  static String? routeFor(AppNotification notification) {
    final type = notification.referenceType?.toUpperCase();
    final id = notification.referenceId;
    if (type == null || id == null || id.isEmpty) return null;

    final builder = _routes[type];
    return builder?.call(id);
  }

  static bool canOpen(AppNotification notification) =>
      routeFor(notification) != null;
}
