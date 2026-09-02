import 'package:flutter/material.dart';

/// Type system.
///
/// Faces are bundled as assets rather than fetched at runtime: this app has to
/// work in a warehouse on poor connectivity, and it must not make an unexpected
/// outbound request on launch.
///
/// Inter carries no Lao or Thai glyphs, so those scripts fall back to their
/// Noto families. Without that fallback, Lao and Thai text renders as empty
/// boxes on any device without a system face for them.
///
/// Every numeric style uses tabular figures so money and weight columns align
/// instead of jittering as digits change.
abstract final class AppTypography {
  static const _primary = 'Inter';
  static const _mono = 'RobotoMono';

  /// Applied to every style in the theme.
  static const scriptFallback = <String>['NotoSansThai', 'NotoSansLao'];

  static const _tabular = FontFeature.tabularFigures();
  static const _lining = FontFeature.liningFigures();

  static TextTheme textTheme(ColorScheme scheme) {
    TextStyle style({
      required double size,
      required FontWeight weight,
      double? height,
      double? spacing,
    }) {
      return TextStyle(
        fontFamily: _primary,
        fontFamilyFallback: scriptFallback,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
        color: scheme.onSurface,
        fontFeatures: const [_lining],
      );
    }

    return TextTheme(
      displayLarge: style(size: 40, weight: FontWeight.w300, spacing: -0.5),
      displayMedium: style(size: 32, weight: FontWeight.w300, spacing: -0.4),
      displaySmall: style(size: 28, weight: FontWeight.w400, spacing: -0.3),
      headlineLarge: style(size: 26, weight: FontWeight.w600, spacing: -0.3),
      headlineMedium: style(size: 22, weight: FontWeight.w600, spacing: -0.2),
      headlineSmall: style(size: 19, weight: FontWeight.w600, spacing: -0.1),
      titleLarge: style(size: 17, weight: FontWeight.w600, height: 1.3),
      titleMedium: style(size: 15, weight: FontWeight.w600, height: 1.3),
      titleSmall: style(size: 13, weight: FontWeight.w600, height: 1.3),
      bodyLarge: style(size: 15, weight: FontWeight.w400, height: 1.5),
      bodyMedium: style(size: 14, weight: FontWeight.w400, height: 1.5),
      bodySmall: style(size: 12, weight: FontWeight.w400, height: 1.45),
      labelLarge: style(size: 14, weight: FontWeight.w600, spacing: 0.1),
      labelMedium: style(size: 12, weight: FontWeight.w600, spacing: 0.2),
      labelSmall: style(size: 11, weight: FontWeight.w600, spacing: 0.4),
    );
  }

  /// Monetary and weight figures. Always tabular, slightly tighter tracking.
  static TextStyle numeric(
    BuildContext context, {
    double? size,
    FontWeight weight = FontWeight.w600,
    Color? color,
  }) {
    final base = Theme.of(context).textTheme.bodyMedium!;
    return base.copyWith(
      fontSize: size ?? base.fontSize,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.2,
      fontFeatures: const [_tabular, _lining],
    );
  }

  /// Identifiers — item codes, reference numbers, tags.
  ///
  /// Monospaced with wider tracking, because these get read aloud across a
  /// counter and compared character by character.
  static TextStyle mono(BuildContext context, {double? size, Color? color}) {
    final base = Theme.of(context).textTheme.bodyMedium!;
    return TextStyle(
      fontFamily: _mono,
      fontFamilyFallback: scriptFallback,
      fontSize: size ?? (base.fontSize! - 1),
      fontWeight: FontWeight.w500,
      color: color ?? base.color,
      letterSpacing: 0.2,
    );
  }
}
