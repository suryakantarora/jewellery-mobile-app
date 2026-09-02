import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jewellery_erp/core/storage/local_store.dart';
import 'package:jewellery_erp/core/storage/secure_storage.dart';
import 'package:jewellery_erp/core/utils/logger.dart';
import 'package:jewellery_erp/features/authentication/data/auth_api.dart';
import 'package:jewellery_erp/features/authentication/data/session_token_provider.dart';

/// Counts refresh calls and lets the test control when each one completes.
class _CountingAuthApi extends AuthApi {
  _CountingAuthApi({required this.shouldFail})
      : super(dio: Dio(BaseOptions(baseUrl: 'http://localhost')));

  final bool shouldFail;
  int refreshCalls = 0;
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<AuthPayload> refresh(String refreshToken) async {
    refreshCalls++;
    await _gate.future;
    if (shouldFail) throw Exception('refresh rejected');

    return AuthPayload.fromJson({
      'accessToken': 'new-access-$refreshCalls',
      'refreshToken': 'new-refresh-$refreshCalls',
      'accessTokenExpiresAt':
          DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String(),
      'user': {'id': 'u', 'username': 'u', 'fullName': 'U'},
    });
  }
}

void main() {
  setUp(() {
    // The plugin has no platform side in a unit test; an in-memory map stands in.
    FlutterSecureStorage.setMockInitialValues({});
  });

  SessionTokenProvider providerWith(_CountingAuthApi api) => SessionTokenProvider(
        api: api,
        storage: SecureStorage(),
        logger: AppLogger(minimumLevel: LogLevel.error),
      );

  test('concurrent refreshes collapse into a single call', () async {
    // Six parallel requests hitting an expired token must produce ONE refresh.
    // Six would race, and five would replay a refresh token the backend has
    // already rotated away — logging the user out mid-shift.
    final api = _CountingAuthApi(shouldFail: false);
    final provider = providerWith(api);

    await provider.store(
      TokenBundle(
        accessToken: 'old',
        refreshToken: 'old-refresh',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      ),
    );

    final futures = List.generate(6, (_) => provider.refresh());
    await Future<void>.delayed(Duration.zero);
    api.release();

    final results = await Future.wait(futures);

    expect(api.refreshCalls, 1);
    // Every caller gets the same new token.
    expect(results.every((t) => t?.accessToken == 'new-access-1'), isTrue);
  });

  test('a later expiry can refresh again', () async {
    // The guard must clear once settled, or the session could never recover.
    final api = _CountingAuthApi(shouldFail: false)..release();
    final provider = providerWith(api);

    await provider.store(
      const TokenBundle(accessToken: 'a', refreshToken: 'r'),
    );

    await provider.refresh();
    await provider.refresh();

    expect(api.refreshCalls, 2);
  });

  test('a failed refresh clears credentials and returns null', () async {
    // A spent or revoked refresh token is terminal; retrying only repeats it.
    final api = _CountingAuthApi(shouldFail: true)..release();
    final provider = providerWith(api);

    await provider.store(
      const TokenBundle(accessToken: 'a', refreshToken: 'r'),
    );

    final result = await provider.refresh();

    expect(result, isNull);
    expect(await provider.currentTokens(), isNull);
  });

  test('refresh without stored credentials does not call the API', () async {
    final api = _CountingAuthApi(shouldFail: false)..release();
    final provider = providerWith(api);

    expect(await provider.refresh(), isNull);
    expect(api.refreshCalls, 0);
  });

  test('stored tokens survive a reload from storage', () async {
    final api = _CountingAuthApi(shouldFail: false)..release();
    final provider = providerWith(api);

    final expiry = DateTime.now().toUtc().add(const Duration(hours: 2));
    await provider.store(
      TokenBundle(
        accessToken: 'persisted',
        refreshToken: 'persisted-refresh',
        expiresAt: expiry,
      ),
    );

    // A fresh provider reads them back, as on a cold start.
    final reloaded = providerWith(api);
    final tokens = await reloaded.currentTokens();

    expect(tokens?.accessToken, 'persisted');
    expect(tokens?.isExpired(), isFalse);
  });

  group('Fresh install', () {
    // iOS keeps Keychain items when an app is deleted, so a reinstalled app can
    // find credentials from a previous installation. Preferences *are* cleared,
    // which is what makes a genuine first run detectable.
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('wipes credentials left by a previous installation', () async {
      final storage = SecureStorage();
      await storage.writeTokens(
        const TokenBundle(accessToken: 'stale', refreshToken: 'stale-refresh'),
      );

      final store = await LocalStore.create();
      await storage.clearIfFreshInstall(store);

      expect(await storage.readTokens(), isNull);
    });

    test('leaves credentials alone on subsequent launches', () async {
      final storage = SecureStorage();
      final store = await LocalStore.create();

      // First launch sets the marker.
      await storage.clearIfFreshInstall(store);

      await storage.writeTokens(
        const TokenBundle(accessToken: 'live', refreshToken: 'live-refresh'),
      );

      // A later launch must not sign the user out.
      await storage.clearIfFreshInstall(store);

      expect((await storage.readTokens())?.accessToken, 'live');
    });
  });

  test('clear removes credentials', () async {
    final api = _CountingAuthApi(shouldFail: false)..release();
    final provider = providerWith(api);

    await provider.store(
      const TokenBundle(accessToken: 'a', refreshToken: 'r'),
    );
    await provider.clear();

    expect(await provider.currentTokens(), isNull);
  });
}
