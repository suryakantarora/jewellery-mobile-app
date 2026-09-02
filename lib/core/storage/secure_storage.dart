import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'local_store.dart';
import 'storage_keys.dart';

/// Keychain / EncryptedSharedPreferences wrapper.
///
/// Holds authentication tokens and nothing else. Passwords are never written
/// here, or anywhere: they exist only for the duration of the login call.
class SecureStorage {
  SecureStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String? value) async {
    if (value == null) {
      await _storage.delete(key: key);
      return;
    }
    await _storage.write(key: key, value: value);
  }

  Future<void> delete(String key) => _storage.delete(key: key);

  /// Clears credentials left behind by a previous installation.
  ///
  /// iOS keeps Keychain items when an app is deleted, so a fresh install can
  /// otherwise resume someone else's session — or, more commonly, fail to
  /// restore a revoked one and show a confusing "session expired" on what the
  /// user experiences as a brand new install.
  ///
  /// Preferences *are* cleared on uninstall, so the absence of the marker is a
  /// reliable signal that this is a genuine first run.
  Future<void> clearIfFreshInstall(LocalStore store) async {
    if (store.getBool(StorageKeys.installMarker) ?? false) return;
    await clearTokens();
    await store.setBool(StorageKeys.installMarker, true);
  }

  Future<TokenBundle?> readTokens() async {
    final access = await read(StorageKeys.accessToken);
    final refresh = await read(StorageKeys.refreshToken);
    if (access == null || refresh == null) return null;

    final rawExpiry = await read(StorageKeys.accessTokenExpiry);
    final expiry = rawExpiry == null ? null : DateTime.tryParse(rawExpiry);
    return TokenBundle(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expiry,
    );
  }

  Future<void> writeTokens(TokenBundle tokens) async {
    await Future.wait([
      write(StorageKeys.accessToken, tokens.accessToken),
      write(StorageKeys.refreshToken, tokens.refreshToken),
      write(StorageKeys.accessTokenExpiry, tokens.expiresAt?.toIso8601String()),
    ]);
  }

  /// Wipes every credential. Called on logout and on an unrecoverable 401 —
  /// unconditionally, even if the server-side logout call failed.
  Future<void> clearTokens() async {
    await Future.wait([
      delete(StorageKeys.accessToken),
      delete(StorageKeys.refreshToken),
      delete(StorageKeys.accessTokenExpiry),
    ]);
  }
}

/// The credential set as stored on the device.
class TokenBundle {
  const TokenBundle({
    required this.accessToken,
    required this.refreshToken,
    this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime? expiresAt;

  /// True when the access token is past, or close to, its expiry.
  ///
  /// The skew makes the client refresh *before* a 401 rather than after —
  /// the backend returns `accessTokenExpiresAt`, so there is no reason to wait
  /// for a failure to discover what we already know.
  bool isExpired({Duration skew = const Duration(seconds: 60)}) {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return DateTime.now().toUtc().add(skew).isAfter(expiry.toUtc());
  }

  TokenBundle copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) {
    return TokenBundle(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
