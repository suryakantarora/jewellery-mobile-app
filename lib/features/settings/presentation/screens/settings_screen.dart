import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/currencies.dart';
import '../../../../core/providers.dart';
import '../../../../core/settings/app_version_service.dart';
import '../../../../core/settings/settings_providers.dart';
import '../../../../core/settings/update_gate.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/extensions/widget_extensions.dart';
import '../../../../shared/widgets/app_backdrop.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_scaffold.dart';

/// Appearance, language, currency and privacy.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);

    return AppScaffold(
      title: context.l10n.screenSettings,
      showBranchBar: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: [
          SectionCard(
            title: context.l10n.settingsAppearance,
            icon: Icons.palette_outlined,
            child: const Column(
              children: [
                _ThemeModeSelector(),
                AppSpacing.gapXl,
                _PaletteSelector(),
              ],
            ),
          ).entrance(index: 0),
          AppSpacing.gapLg,

          SectionCard(
            title: context.l10n.settingsLanguage,
            icon: Icons.translate_outlined,
            child: const _LanguageSelector(),
          ).entrance(index: 1),
          AppSpacing.gapLg,

          SectionCard(
            title: context.l10n.settingsCurrency,
            icon: Icons.payments_outlined,
            subtitle:
                'Used where the app has to choose; individual amounts '
                'always use the currency the record carries.',
            child: const _CurrencySelector(),
          ).entrance(index: 2),
          AppSpacing.gapLg,

          SectionCard(
            title: context.l10n.settingsPrivacy,
            icon: Icons.shield_outlined,
            child: const _PrivacySection(),
          ).entrance(index: 3),
          AppSpacing.gapLg,

          SectionCard(
            title: context.l10n.settingsAbout,
            icon: Icons.info_outline,
            child: Column(
              children: [
                const _VersionRow(),
                _AboutRow(
                  label: context.l10n.settingsEnvironment,
                  value: config.environment.label,
                ),
                _AboutRow(label: 'API', value: config.apiBaseUrl),
                const _CheckForUpdatesRow(),
              ],
            ),
          ).entrance(index: 4),
        ],
      ),
    );
  }
}

class _ThemeModeSelector extends ConsumerWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.settingsThemeMode,
          style: context.text.labelMedium?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
        AppSpacing.gapSm,
        SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(
              value: ThemeMode.system,
              icon: const Icon(Icons.brightness_auto_outlined, size: 18),
              label: Text(context.l10n.settingsThemeSystem),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              icon: const Icon(Icons.light_mode_outlined, size: 18),
              label: Text(context.l10n.settingsThemeLight),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: const Icon(Icons.dark_mode_outlined, size: 18),
              label: Text(context.l10n.settingsThemeDark),
            ),
          ],
          selected: {mode},
          showSelectedIcon: false,
          onSelectionChanged: (selection) =>
              ref.read(themeModeProvider.notifier).set(selection.first),
        ),
      ],
    );
  }
}

class _PaletteSelector extends ConsumerWidget {
  const _PaletteSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.settingsAccent,
          style: context.text.labelMedium?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
        AppSpacing.gapMd,
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final option in AppPalette.values)
              PaletteSwatch(
                palette: option,
                selected: option == palette,
                onTap: () => ref.read(paletteProvider.notifier).set(option),
              ),
          ],
        ),
        AppSpacing.gapSm,
        Text(
          palette.label,
          style: context.text.bodySmall?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LanguageSelector extends ConsumerWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return Column(
      children: [
        for (final option in supportedLocales)
          ListTile(
            contentPadding: EdgeInsets.zero,
            // Each language is named in its own script — a picker that lists
            // "Lao" in English is no help to someone who only reads Lao.
            title: Text(
              localeLabels[option.languageCode] ?? option.languageCode,
            ),
            trailing: option.languageCode == locale.languageCode
                ? Icon(Icons.check, color: context.scheme.primary)
                : null,
            onTap: () => ref.read(localeProvider.notifier).set(option),
          ),
      ],
    );
  }
}

class _CurrencySelector extends ConsumerWidget {
  const _CurrencySelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(displayCurrencyProvider);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final currency in AppCurrency.values)
          ChoiceChip(
            selected: currency == selected,
            label: Text('${currency.symbol}  ${currency.code}'),
            onSelected: (_) =>
                ref.read(displayCurrencyProvider.notifier).set(currency),
          ),
      ],
    );
  }
}

class _PrivacySection extends ConsumerWidget {
  const _PrivacySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      value: ref.watch(hideAmountsProvider),
      contentPadding: EdgeInsets.zero,
      title: Text(context.l10n.settingsHideAmounts),
      subtitle: Text(
        context.l10n.settingsHideAmountsHint,
        style: context.text.bodySmall,
      ),
      onChanged: (_) => ref.read(hideAmountsProvider.notifier).toggle(),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: context.text.bodySmall,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

/// The installed version and build number, straight from the platform.
class _VersionRow extends ConsumerWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(installedVersionProvider).valueOrNull;
    final value = info == null
        ? '—'
        : info.buildNumber.isEmpty
        ? info.version
        : '${info.version} (${info.buildNumber})';
    return _AboutRow(label: context.l10n.settingsVersion, value: value);
  }
}

/// Re-runs the version check on demand and reports the verdict.
///
/// A forced verdict is handled by the gate above the router, so this row only
/// ever has to speak about "up to date" and "newer available".
class _CheckForUpdatesRow extends ConsumerStatefulWidget {
  const _CheckForUpdatesRow();

  @override
  ConsumerState<_CheckForUpdatesRow> createState() =>
      _CheckForUpdatesRowState();
}

class _CheckForUpdatesRowState extends ConsumerState<_CheckForUpdatesRow> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    ref.invalidate(appUpdateProvider);
    final result = await ref.read(appUpdateProvider.future);
    if (!mounted) return;
    setState(() => _checking = false);

    switch (result.status) {
      case UpdateStatus.unknown:
        showAppSnackBar(
          context,
          message: 'Could not check for updates. Try again when online.',
        );
      case UpdateStatus.upToDate:
        showAppSnackBar(
          context,
          message: 'You have the latest version.',
          tone: SnackTone.success,
        );
      case UpdateStatus.updateAvailable:
      case UpdateStatus.forced:
        final storeUrl = result.storeUrl;
        showAppSnackBar(
          context,
          message: 'Version ${result.latest ?? ''} is available.',
          actionLabel: storeUrl == null ? null : 'Update',
          onAction: storeUrl == null
              ? null
              : () => openStore(context, storeUrl),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.system_update_outlined),
      title: const Text('Check for updates'),
      trailing: _checking
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: _checking ? null : _check,
    );
  }
}
