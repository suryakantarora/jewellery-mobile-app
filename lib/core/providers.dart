import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/authentication/data/api_auth_repository.dart';
import '../features/authentication/data/auth_api.dart';
import '../features/authentication/data/dev_auth_repository.dart';
import '../features/authentication/data/session_token_provider.dart';
import '../features/authentication/domain/auth_repository.dart';
import 'config/app_config.dart';
import 'connectivity/connectivity_controller.dart';
import 'connectivity/offline_guard.dart';
import 'network/api_client.dart';
import 'network/dio_client.dart';
import 'security/session_controller.dart';
import 'settings/settings_providers.dart';
import 'storage/local_store.dart';
import 'storage/secure_storage.dart';
import 'utils/formatters.dart';
import 'utils/logger.dart';

/// Overridden in `main()` once preferences have loaded, so no widget has to
/// await storage during build.
final localStoreProvider = Provider<LocalStore>(
  (ref) => throw UnimplementedError('localStoreProvider must be overridden'),
);

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final loggerProvider = Provider<AppLogger>((ref) => AppLogger());

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

/// Isolated client for the authentication endpoints.
///
/// Has no auth interceptor by design: login and refresh must never carry a
/// bearer token, and a refresh routed through the interceptor chain would
/// recurse into the very refresh it is performing.
final authApiProvider = Provider<AuthApi>((ref) {
  final config = ref.watch(appConfigProvider);
  return AuthApi(
    dio: AuthApi.createClient(
      baseUrl: config.apiRoot,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
    ),
  );
});

/// Holds credentials and performs single-flight refresh.
final tokenProviderProvider = Provider<SessionTokenProvider>((ref) {
  final provider = SessionTokenProvider(
    api: ref.watch(authApiProvider),
    storage: ref.watch(secureStorageProvider),
    logger: ref.watch(loggerProvider),
  );

  // Wired here rather than injected, so the token layer never imports the
  // session controller and there is no provider cycle.
  provider.onSessionLost = () =>
      ref.read(sessionControllerProvider.notifier).onAuthenticationLost();

  return provider;
});

/// The main authenticated client.
///
/// The branch reader is a callback so `core/network` stays free of any feature
/// import and reading the branch cannot create a cycle with the session.
final dioProvider = Provider<Dio>((ref) {
  return DioClient.create(
    config: ref.watch(appConfigProvider),
    logger: ref.watch(loggerProvider),
    tokenProvider: ref.watch(tokenProviderProvider),
    branchIdReader: () => ref.read(sessionControllerProvider).branch?.id,
  );
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(dioProvider)),
);

/// The real backend client, or the development stand-in.
///
/// `useDevAuth` is a build-time flag, not a runtime toggle, and it is ignored
/// in production — the development repository must never be reachable in a
/// release build.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);

  if (config.useDevAuth && !config.environment.isProduction) {
    return DevAuthRepository(ref.watch(secureStorageProvider));
  }

  return ApiAuthRepository(
    api: ref.watch(authApiProvider),
    tokens: ref.watch(tokenProviderProvider),
    client: ref.watch(apiClientProvider),
  );
});

/// Refuses mutating calls while the backend is unreachable.
///
/// Critical inventory and financial operations are never queued for replay —
/// the backend has no idempotent offline design, so a delayed replay would
/// create phantom stock. Repositories that mutate route through this.
final offlineGuardProvider = Provider<OfflineGuard>(
  (ref) => OfflineGuard(ref.watch(connectivityProvider)),
);

/// Locale-aware formatting for money, weight and dates.
final formattersProvider = Provider<Formatters>((ref) {
  final locale = ref.watch(localeProvider);
  return Formatters(locale.toLanguageTag());
});
