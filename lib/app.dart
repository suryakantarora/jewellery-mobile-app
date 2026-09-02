import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/security/session_controller.dart';
import 'core/settings/settings_providers.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'shared/widgets/connectivity_banner.dart';

/// The application root.
///
/// Watches the theme, palette and locale so a settings change rebuilds the
/// whole tree, and wraps everything in an activity listener that keeps the
/// idle-timeout clock honest.
class JewelleryErpApp extends ConsumerWidget {
  const JewelleryErpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Jewellery ERP',
      debugShowCheckedModeBanner: false,
      routerConfig: router,

      theme: AppTheme.light(palette),
      darkTheme: AppTheme.dark(palette),
      themeMode: themeMode,

      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      builder: (context, child) {
        return _ActivityListener(
          child: MediaQuery.withClampedTextScaling(
            // Layouts are tested to 1.3×; beyond that dense enterprise screens
            // stop being usable, so scaling is capped rather than allowed to
            // break the interface.
            minScaleFactor: 0.85,
            maxScaleFactor: 1.3,
            // The connectivity banner sits above every screen, so no feature
            // has to remember to show it.
            child: Column(
              children: [
                const ConnectivityBanner(),
                Expanded(child: child ?? const SizedBox.shrink()),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Resets the inactivity timer on any interaction.
///
/// Placed at the root so no screen has to remember to report activity — a
/// session that locks while someone is actively working would be worse than no
/// lock at all.
class _ActivityListener extends ConsumerWidget {
  const _ActivityListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Listener(
      // Listening in the capture phase means the gesture still reaches the
      // widget beneath it.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) =>
          ref.read(sessionControllerProvider.notifier).registerActivity(),
      child: child,
    );
  }
}
