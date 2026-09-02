import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../domain/notification_models.dart';

/// Notifications for the signed-in user.
///
/// Every call goes to `/notifications/mine`, which the backend scopes to the
/// caller from the security context. The app deliberately does not send a
/// recipient id: the admin `/notifications` search accepts an arbitrary one,
/// and routing the inbox through it would have let anyone holding
/// `NOTIFICATION_VIEW` read a colleague's mail.
///
/// Read state lives on the server (`readAt`), so opening a notification on one
/// device clears it on the others.
class NotificationRepository {
  NotificationRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  static const _inbox = '${ApiEndpoints.notifications}/mine';

  Future<List<AppNotification>> mine() async {
    final page = await _client.getPage<AppNotification>(
      _inbox,
      query: const {'size': 100},
      parseItem: AppNotification.fromJson,
    );

    // The backend already orders newest-first; sorting again keeps the list
    // stable if a caller ever hands us an unordered page.
    final items = page.content.toList()
      ..sort((a, b) {
        final left = a.occurredAt;
        final right = b.occurredAt;
        if (left == null && right == null) return 0;
        if (left == null) return 1;
        if (right == null) return -1;
        return right.compareTo(left);
      });

    return items;
  }

  Future<int> unreadCount() async {
    final value = await _client.get<int>(
      '$_inbox/unread-count',
      parse: (data) => data is num ? data.toInt() : 0,
    );
    return value;
  }

  Future<void> markRead(String id) =>
      _client.post<void>('$_inbox/$id/read', parse: (_) {});

  Future<void> markAllRead() =>
      _client.post<void>('$_inbox/read-all', parse: (_) {});
}
