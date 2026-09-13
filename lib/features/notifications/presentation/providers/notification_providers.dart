import 'dart:async';

import 'package:flutter/widgets.dart';
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

/// How often the badge is refreshed while the app is in the foreground.
///
/// Push is not on device yet (see docs/NEXT-STEPS.md §3), so until FCM
/// registration lands this poll is what keeps the badge honest. Sixty seconds
/// is one small `GET` a minute — cheap enough for a showroom device, slow
/// enough not to matter on a metered connection.
const unreadCountPollInterval = Duration(seconds: 60);

/// The unread badge count, from `GET /notifications/mine/unread-count`.
///
/// Fetched on its own rather than derived from the inbox list: the list is
/// capped at 100 rows, so a derived count would silently plateau, and the
/// badge is needed on screens that never load the inbox at all.
///
/// Refreshes on app resume, on a timer while foregrounded, and whenever a
/// screen marks something read (via [refresh]). A failed fetch keeps the last
/// good value: a stale badge is better than one that flickers to zero.
class UnreadNotificationCountController extends AsyncNotifier<int>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  Future<int> build() async {
    final user = ref.watch(currentUserProvider);

    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _timer?.cancel();
    });

    if (user == null) return 0;

    _startPolling();
    return _fetch();
  }

  Future<int> _fetch() async {
    try {
      return await ref.read(notificationRepositoryProvider).unreadCount();
    } on Object {
      // Keep whatever is showing; the next poll or resume retries.
      return state.valueOrNull ?? 0;
    }
  }

  /// Re-fetches without dropping to a loading state, so the badge never
  /// disappears for a frame between a tap on "mark read" and the new count.
  Future<void> refresh() async {
    if (ref.read(currentUserProvider) == null) {
      state = const AsyncData(0);
      return;
    }
    state = AsyncData(await _fetch());
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(unreadCountPollInterval, (_) => refresh());
  }

  // The parameter shadows the notifier's `state` inside this method only; it
  // is never read or assigned here, so the shadowing is harmless.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Anything that arrived while the app was in the background is picked
        // up immediately rather than at the next tick.
        unawaited(refresh());
        _startPolling();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // No polling in the background: the OS would throttle it anyway, and
        // a request fired mid-suspend is a wasted battery hit.
        _timer?.cancel();
      case AppLifecycleState.inactive:
        break;
    }
  }
}

final unreadNotificationCountControllerProvider =
    AsyncNotifierProvider<UnreadNotificationCountController, int>(
      UnreadNotificationCountController.new,
    );

/// Unread count, for the badge. Zero while loading or signed out.
///
/// Same name and type as before, so existing consumers keep working; the
/// number now comes from the server's count endpoint instead of the inbox
/// list.
final unreadNotificationCountProvider = Provider.autoDispose<int>(
  (ref) =>
      ref.watch(unreadNotificationCountControllerProvider).valueOrNull ?? 0,
);

// Seam for push: when FCM registration lands, a `pushRegistrationProvider`
// (owned elsewhere) should call
// `ref.read(unreadNotificationCountControllerProvider.notifier).refresh()`
// on message receipt, and the poll interval can be lengthened or removed.
