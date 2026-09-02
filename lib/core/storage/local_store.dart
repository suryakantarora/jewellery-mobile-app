import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'storage_keys.dart';

/// Non-secret device preferences: theme, locale, currency, last branch.
///
/// Nothing sensitive goes here — no tokens, no customer data, no prices.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStore> create() async =>
      LocalStore(await SharedPreferences.getInstance());

  String? getString(String key) => _prefs.getString(key);
  bool? getBool(String key) => _prefs.getBool(key);
  int? getInt(String key) => _prefs.getInt(key);

  List<String> getStringList(String key) =>
      _prefs.getStringList(key) ?? const [];

  Map<String, dynamic>? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      // A corrupt preference must never crash startup; treat it as absent.
      return null;
    }
  }

  Future<void> setString(String key, String? value) async {
    if (value == null) {
      await _prefs.remove(key);
      return;
    }
    await _prefs.setString(key, value);
  }

  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  Future<void> setJson(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  Future<void> remove(String key) => _prefs.remove(key);

  /// Clears session-scoped preferences while keeping display settings, so a
  /// shared device does not reset its theme and language on every logout.
  Future<void> clearSession() async {
    for (final key in StorageKeys.clearedOnLogout) {
      await _prefs.remove(key);
    }
  }
}
