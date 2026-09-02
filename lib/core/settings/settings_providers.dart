import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/currencies.dart';
import '../providers.dart';
import '../storage/storage_keys.dart';
import '../theme/app_palette.dart';

/// Locales the application ships with. English is the source of truth; Lao and
/// Thai are first-class, and the list is designed to grow without code changes
/// beyond a new ARB file.
const supportedLocales = <Locale>[Locale('en'), Locale('lo'), Locale('th')];

/// Display names in each language's own script — a language picker that lists
/// "Lao" in English is useless to someone who only reads Lao.
const localeLabels = <String, String>{
  'en': 'English',
  'lo': 'ລາວ',
  'th': 'ไทย',
};

/// Light / dark / follow the system.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref
        .read(localStoreProvider)
        .getString(StorageKeys.themeMode);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref
        .read(localStoreProvider)
        .setString(StorageKeys.themeMode, mode.name);
  }

  /// Cycles system → light → dark, for the quick toggle in the app bar.
  Future<void> cycle() async {
    final next = switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await set(next);
  }
}

/// The selected accent identity.
class PaletteController extends Notifier<AppPalette> {
  @override
  AppPalette build() {
    final stored = ref
        .read(localStoreProvider)
        .getString(StorageKeys.themePalette);
    return AppPalette.fromName(stored);
  }

  Future<void> set(AppPalette palette) async {
    state = palette;
    await ref
        .read(localStoreProvider)
        .setString(StorageKeys.themePalette, palette.name);
  }
}

/// Active language. Defaults to the device locale when it is one we support,
/// otherwise English.
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    final stored = ref.read(localStoreProvider).getString(StorageKeys.locale);
    if (stored != null) {
      final match = supportedLocales
          .where((locale) => locale.languageCode == stored)
          .firstOrNull;
      if (match != null) return match;
    }

    final device = WidgetsBinding.instance.platformDispatcher.locale;
    return supportedLocales.firstWhere(
      (locale) => locale.languageCode == device.languageCode,
      orElse: () => const Locale('en'),
    );
  }

  Future<void> set(Locale locale) async {
    state = locale;
    await ref
        .read(localStoreProvider)
        .setString(StorageKeys.locale, locale.languageCode);
  }
}

/// The currency used where the app has to pick one itself — totals across
/// mixed records, and empty states. Individual amounts always use the currency
/// the backend sent with them.
class DisplayCurrencyController extends Notifier<AppCurrency> {
  @override
  AppCurrency build() {
    final stored = ref
        .read(localStoreProvider)
        .getString(StorageKeys.displayCurrency);
    return AppCurrency.fromCode(stored) ?? AppCurrency.primary;
  }

  Future<void> set(AppCurrency currency) async {
    state = currency;
    await ref
        .read(localStoreProvider)
        .setString(StorageKeys.displayCurrency, currency.code);
  }
}

/// Blurs monetary figures on screen.
///
/// Genuinely useful on a shop floor where a customer can see the staff device
/// over the counter, and cheap to support because every amount already renders
/// through one widget.
class HideAmountsController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(localStoreProvider).getBool(StorageKeys.hideAmounts) ?? false;

  Future<void> toggle() async {
    state = !state;
    await ref.read(localStoreProvider).setBool(StorageKeys.hideAmounts, state);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

final paletteProvider = NotifierProvider<PaletteController, AppPalette>(
  PaletteController.new,
);

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

final displayCurrencyProvider =
    NotifierProvider<DisplayCurrencyController, AppCurrency>(
      DisplayCurrencyController.new,
    );

final hideAmountsProvider = NotifierProvider<HideAmountsController, bool>(
  HideAmountsController.new,
);
