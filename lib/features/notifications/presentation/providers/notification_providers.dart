import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../data/notification_repository.dart';
import '../../domain/notification_models.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(client: ref.watch(apiClientProvider)),
);

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) async {
    // Watched, not read: signing out must empty the list rather than leave one
    // user's messages on screen for the next.
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];
    return ref.watch(notificationRepositoryProvider).mine();
  },
);

/// Unread count, for the badge.
///
/// Derived from the loaded list rather than fetched separately, so marking one
/// read updates the badge in the same frame as the row.
final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  final items = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return items.where((item) => !item.read).length;
});
