import 'dart:io';

import 'environment.dart';

/// Immutable runtime configuration.
///
/// Holds base URLs, timeouts and feature flags only. No secrets are ever
/// compiled into the application — anything sensitive stays server-side.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 30),
    this.sendTimeout = const Duration(seconds: 30),
    this.idleTimeout = const Duration(minutes: 15),
    this.pageSize = 20,
    this.searchDebounce = const Duration(milliseconds: 350),
    this.enableSharing = false,
    this.enableBiometrics = true,
    this.certificatePins = const [],
    this.useDevAuth = false,
  });

  final Environment environment;
  final String apiBaseUrl;

  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;

  /// Inactivity before the session locks. Business-tunable per deployment.
  final Duration idleTimeout;

  final int pageSize;
  final Duration searchDebounce;

  /// Sharing product details outbound is a disclosure of business data, so it
  /// is off unless a deployment turns it on.
  final bool enableSharing;

  final bool enableBiometrics;

  /// SHA-256 SPKI pins, applied in Phase 17. Empty disables pinning.
  final List<String> certificatePins;

  /// Uses the in-memory development authentication instead of the backend.
  ///
  /// Build-time only (`--dart-define=USE_DEV_AUTH=true`) and ignored in
  /// production, so the stand-in can never be reached in a release build.
  final bool useDevAuth;

  /// The API root including the version segment.
  String get apiRoot => '$apiBaseUrl/api/v1';

  static const _envName = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const _baseUrl = String.fromEnvironment('API_BASE_URL');
  static const _useDevAuth = bool.fromEnvironment('USE_DEV_AUTH');

  /// Reads configuration from `--dart-define` values, falling back to sensible
  /// development defaults so a fresh checkout runs without ceremony.
  factory AppConfig.fromEnvironment() {
    final environment = Environment.fromName(_envName);
    final base = _baseUrl.isNotEmpty ? _baseUrl : _defaultBaseUrl(environment);

    return AppConfig(
      environment: environment,
      apiBaseUrl: _stripTrailingSlash(base),
      enableSharing: !environment.isProduction,
      useDevAuth: _useDevAuth,
    );
  }

  static String _defaultBaseUrl(Environment environment) {
    switch (environment) {
      case Environment.dev:
        // 10.0.2.2 reaches the host machine from the Android emulator; an iOS
        // simulator shares the host's localhost.
        return Platform.isAndroid
            ? 'http://10.0.2.2:8081'
            : 'http://localhost:8081';
      case Environment.staging:
        return 'https://staging-api.example.com';
      case Environment.prod:
        return 'https://api.example.com';
    }
  }

  static String _stripTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  AppConfig copyWith({Environment? environment, String? apiBaseUrl}) {
    return AppConfig(
      environment: environment ?? this.environment,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      useDevAuth: useDevAuth,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      sendTimeout: sendTimeout,
      idleTimeout: idleTimeout,
      pageSize: pageSize,
      searchDebounce: searchDebounce,
      enableSharing: enableSharing,
      enableBiometrics: enableBiometrics,
      certificatePins: certificatePins,
    );
  }
}
