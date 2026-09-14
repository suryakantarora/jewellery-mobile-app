import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/security/session_controller.dart';
import '../../../core/settings/app_version_service.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/widgets/app_dialogs.dart';
import '../domain/notification_models.dart';
import '../presentation/providers/notification_providers.dart';

/// Whether `Firebase.initializeApp()` succeeded in `main()`.
///
/// Overridden at start-up. Firebase is optional: a build without
/// `google-services.json` / `GoogleService-Info.plist` runs on polling alone,
/// and every Firebase call in this feature is behind this flag.
final firebaseReadyProvider = Provider<bool>((ref) => false);

/// What a push carries. No business data — the app fetches content after the
/// tap (docs/PHASE-15-DESIGN.md §4, payload rule).
class PushPayload {
  const PushPayload({
    this.eventType,
    this.referenceType,
    this.referenceId,
    this.notificationId,
    this.title,
    this.body,
  });

  final String? eventType;
  final String? referenceType;
  final String? referenceId;
  final String? notificationId;
  final String? title;
  final String? body;

  factory PushPayload.fromData(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) => PushPayload(
    eventType: data['eventType']?.toString(),
    referenceType: data['referenceType']?.toString(),
    referenceId: data['referenceId']?.toString(),
    notificationId: data['notificationId']?.toString(),
    title: title,
    body: body,
  );

  factory PushPayload.fromMessage(RemoteMessage message) =>
      PushPayload.fromData(
        message.data,
        title: message.notification?.title,
        body: message.notification?.body,
      );

  /// The screen a tap should open: the reference's route, else the inbox.
  ///
  /// Falling back to the inbox rather than nothing means a push for a type the
  /// router does not know (`Sale`, today) still lands somewhere useful.
  String get path =>
      NotificationRouter.pathFor(referenceType, referenceId) ??
      AppRoutes.notifications;

  /// Something readable for the in-app banner.
  String get displayTitle {
    final t = title;
    if (t != null && t.isNotEmpty) return t;
    final type = eventType;
    if (type != null && type.isNotEmpty) {
      return NotificationEventTypes.labelFor(type);
    }
    return 'New notification';
  }
}

/// Registers this device for push and reacts to messages.
///
/// Runs for the lifetime of the app (see [pushRegistrationProvider]) and
/// follows the session: register on sign-in, deregister on sign-out. Every
/// Firebase call is guarded — a missing config, a simulator without APNs, or a
/// device without Play Services must degrade to "no push", never to a crash.
class PushRegistrationService {
  PushRegistrationService({
    required ApiClient client,
    required AppLogger logger,
    required this.onForegroundMessage,
    required this.onOpened,
  }) : _client = client,
       _logger = logger;

  final ApiClient _client;
  final AppLogger _logger;

  /// A message received while the app is in the foreground.
  final void Function(PushPayload payload) onForegroundMessage;

  /// The user tapped an OS notification (background or terminated).
  final void Function(PushPayload payload) onOpened;

  static const _devices = '${ApiEndpoints.notifications}/devices';

  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  bool _listening = false;
  bool _loggedUnavailable = false;

  /// The token last registered with the backend, so sign-out can revoke it.
  String? _registeredToken;

  String? get registeredToken => _registeredToken;

  bool get _available => Firebase.apps.isNotEmpty;

  /// Idempotent: starts message listeners once, then (re)registers the token.
  Future<void> register() async {
    if (!_available) {
      _logUnavailableOnce();
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      // iOS and Android 13+ both need an explicit grant; a refusal is not an
      // error — the token still registers and the inbox keeps polling.
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _logger.info('Push permission denied; inbox stays poll-only');
      }

      _startListening(messaging);

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        _logger.warn('FCM returned no token; push not registered');
        return;
      }
      await _send(token);
    } on Object catch (error) {
      // Any Firebase failure leaves the app on polling. Logged once at warn
      // level so a misconfigured build is visible without spamming.
      _logger.warn('Push registration failed', context: error.toString());
    }
  }

  /// Revokes the device on the backend. Best-effort: the session may already
  /// be gone, in which case the server's token sweep cleans it up.
  Future<void> deregister() async {
    final token = _registeredToken;
    _registeredToken = null;
    if (token == null) return;

    try {
      await _client.send(
        '$_devices/${Uri.encodeComponent(token)}',
        method: 'DELETE',
      );
    } on Object {
      // Deliberately ignored.
    }

    if (_available) {
      try {
        // A new sign-in gets a fresh token, so a stale one can never be
        // re-associated with the previous user.
        await FirebaseMessaging.instance.deleteToken();
      } on Object {
        // Ignored for the same reason.
      }
    }
  }

  /// A tap on the notification that launched the app from a terminated state.
  Future<PushPayload?> initialMessage() async {
    if (!_available) return null;
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      return message == null ? null : PushPayload.fromMessage(message);
    } on Object {
      return null;
    }
  }

  void dispose() {
    _tokenRefresh?.cancel();
    _foreground?.cancel();
    _opened?.cancel();
    _listening = false;
  }

  void _startListening(FirebaseMessaging messaging) {
    if (_listening) return;
    _listening = true;

    _tokenRefresh = messaging.onTokenRefresh.listen(
      (token) => _send(token).catchError((Object error) {
        _logger.warn('Push re-registration failed', context: error.toString());
      }),
    );
    _foreground = FirebaseMessaging.onMessage.listen(
      (message) => onForegroundMessage(PushPayload.fromMessage(message)),
    );
    _opened = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => onOpened(PushPayload.fromMessage(message)),
    );
  }

  Future<void> _send(String token) async {
    final info = await PackageInfo.fromPlatform();
    await _client.post<void>(
      _devices,
      body: {
        'token': token,
        'platform': AppVersionService.platformName(),
        'appVersion': '${info.version}+${info.buildNumber}',
      },
      parse: (_) {},
    );
    _registeredToken = token;
    _logger.info('Push device registered');
  }

  void _logUnavailableOnce() {
    if (_loggedUnavailable) return;
    _loggedUnavailable = true;
    _logger.info(
      'Firebase not configured; push disabled, notifications poll only',
    );
  }
}

final pushRegistrationServiceProvider = Provider<PushRegistrationService>((
  ref,
) {
  final service = PushRegistrationService(
    client: ref.watch(apiClientProvider),
    logger: ref.watch(loggerProvider),
    onForegroundMessage: (payload) => _onForeground(ref, payload),
    onOpened: (payload) => _open(ref, payload.path),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Keeps push registration in step with the session.
///
/// Watched once from the app root so it lives as long as the app. Nothing
/// reads its value; it exists for its side effects.
final pushRegistrationProvider = Provider<void>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return;

  final service = ref.watch(pushRegistrationServiceProvider);
  final authenticated = ref.watch(
    sessionControllerProvider.select((s) => s.isAuthenticated),
  );

  if (authenticated) {
    unawaited(_onSignedIn(ref, service));
  } else {
    unawaited(service.deregister());
  }
});

/// A deep link that arrived before the session was ready (cold start from a
/// notification tap) is held here and pushed once the user is signed in.
String? _pendingPath;
bool _initialMessageConsumed = false;

Future<void> _onSignedIn(Ref ref, PushRegistrationService service) async {
  await service.register();

  if (!_initialMessageConsumed) {
    _initialMessageConsumed = true;
    final initial = await service.initialMessage();
    if (initial != null) _pendingPath = initial.path;
  }

  final pending = _pendingPath;
  if (pending != null) {
    _pendingPath = null;
    _open(ref, pending);
  }
}

void _open(Ref ref, String path) {
  if (!ref.read(sessionControllerProvider).isAuthenticated) {
    _pendingPath = path;
    return;
  }
  try {
    ref.read(routerProvider).push(path);
  } on Object catch (error) {
    ref.read(loggerProvider).warn('Push deep link failed', context: '$error');
  }
}

void _onForeground(Ref ref, PushPayload payload) {
  // The badge and the inbox both refresh: the count endpoint is the truth for
  // the badge, and an open inbox should show the new row without a pull.
  unawaited(
    ref.read(unreadNotificationCountControllerProvider.notifier).refresh(),
  );
  ref.invalidate(notificationsProvider);

  final context = ref
      .read(routerProvider)
      .routerDelegate
      .navigatorKey
      .currentContext;
  if (context == null || !context.mounted) return;

  final body = payload.body;
  showAppSnackBar(
    context,
    message: body == null || body.isEmpty
        ? payload.displayTitle
        : '${payload.displayTitle} — $body',
    actionLabel: 'View',
    onAction: () => _open(ref, payload.path),
  );
}

/// Exposed for tests: resets the module-level deferred link state.
@visibleForTesting
void resetPushDeepLinkState() {
  _pendingPath = null;
  _initialMessageConsumed = false;
}
