/// Every persisted key in one place, so nothing is stored under an ad-hoc
/// string and a wipe on logout can be exhaustive.
abstract final class StorageKeys {
  // --- Secure (tokens only; never anything else) ---------------------------
  static const accessToken = 'auth.access_token';
  static const refreshToken = 'auth.refresh_token';
  static const accessTokenExpiry = 'auth.access_token_expiry';

  // --- Preferences ---------------------------------------------------------
  static const themeMode = 'pref.theme_mode';
  static const themePalette = 'pref.theme_palette';
  static const locale = 'pref.locale';
  static const displayCurrency = 'pref.display_currency';
  static const hideAmounts = 'pref.hide_amounts';
  static const biometricEnabled = 'pref.biometric_enabled';
  static const lastUsername = 'pref.last_username';
  static const selectedBranchId = 'pref.selected_branch_id';
  static const quickActions = 'pref.quick_actions';
  static const environment = 'pref.environment';

  /// Set on first launch after an install.
  ///
  /// Preferences are wiped when an app is uninstalled but the iOS Keychain is
  /// **not** — so a reinstalled app can find credentials belonging to a
  /// previous installation. The absence of this flag is how a genuine first run
  /// is detected, so those stale credentials can be cleared.
  static const installMarker = 'pref.install_marker';

  /// Keys cleared on logout. Deliberately excludes theme, locale and currency —
  /// a shared showroom device should keep its display settings between shifts.
  static const clearedOnLogout = <String>[
    selectedBranchId,
    hideAmounts,
    quickActions,
  ];
}
