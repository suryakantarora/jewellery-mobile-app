import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';

/// Shorthands for the things nearly every widget reaches for.
extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get scheme => Theme.of(this).colorScheme;

  /// Semantic business colours — status, metals, shimmer.
  AppColors get colors => Theme.of(this).extension<AppColors>()!;

  AppL10n get l10n => AppL10n.of(this);

  MediaQueryData get media => MediaQuery.of(this);
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  bool get isCompact => Breakpoints.isCompact(screenWidth);
  bool get isExpanded => Breakpoints.isExpanded(screenWidth);

  /// True when the user has increased text size enough that dense layouts need
  /// to relax into a vertical arrangement.
  bool get prefersLargeText => MediaQuery.textScalerOf(this).scale(14) > 18;
}
