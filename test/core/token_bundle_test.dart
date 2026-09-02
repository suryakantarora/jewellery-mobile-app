import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_erp/core/storage/secure_storage.dart';

void main() {
  TokenBundle bundle(Duration fromNow) => TokenBundle(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.now().toUtc().add(fromNow),
      );

  group('Access token expiry', () {
    test('a token well inside its life is not expired', () {
      expect(bundle(const Duration(hours: 1)).isExpired(), isFalse);
    });

    test('a token past its expiry is expired', () {
      expect(bundle(const Duration(minutes: -1)).isExpired(), isTrue);
    });

    test('a token inside the skew window refreshes early', () {
      // The backend returns accessTokenExpiresAt, so there is no reason to wait
      // for a 401 to discover what we already know.
      expect(bundle(const Duration(seconds: 30)).isExpired(), isTrue);
      expect(bundle(const Duration(seconds: 90)).isExpired(), isFalse);
    });

    test('an unknown expiry is not treated as expired', () {
      // Refreshing on every request would be worse than letting the backend
      // answer with a 401 once.
      const unknown = TokenBundle(accessToken: 'a', refreshToken: 'r');
      expect(unknown.isExpired(), isFalse);
    });
  });
}
