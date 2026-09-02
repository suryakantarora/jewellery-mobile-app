import 'package:flutter/widgets.dart';

/// A 4pt spacing scale. Every gap, pad and radius in the app comes from here so
/// density stays consistent across fifteen feature modules built over time.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Standard horizontal page padding.
  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: lg);

  /// Padding inside a card or sheet.
  static const EdgeInsets card = EdgeInsets.all(lg);

  /// Vertical rhythm between stacked sections.
  static const SizedBox gapXxs = SizedBox(height: xxs);
  static const SizedBox gapXs = SizedBox(height: xs);
  static const SizedBox gapSm = SizedBox(height: sm);
  static const SizedBox gapMd = SizedBox(height: md);
  static const SizedBox gapLg = SizedBox(height: lg);
  static const SizedBox gapXl = SizedBox(height: xl);
  static const SizedBox gapXxl = SizedBox(height: xxl);

  static const SizedBox wGapXs = SizedBox(width: xs);
  static const SizedBox wGapSm = SizedBox(width: sm);
  static const SizedBox wGapMd = SizedBox(width: md);
  static const SizedBox wGapLg = SizedBox(width: lg);
}

/// Corner radii. Cards are 12; sheets and dialogs are larger; chips are pill.
abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
  static const BorderRadius fieldRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );
}

/// Minimum touch targets. Staff use this device one-handed at a counter, so
/// nothing interactive goes below 48dp.
abstract final class AppSizes {
  static const double minTouchTarget = 48;
  static const double buttonHeight = 48;
  static const double fieldHeight = 52;
  static const double appBarHeight = 56;
  static const double bottomNavHeight = 64;
  static const double listThumb = 56;
  static const double avatar = 40;
}

/// Layout breakpoints. Phone-first, with a two-pane layout on tablets — a
/// tablet in the vault or warehouse is a real deployment.
abstract final class Breakpoints {
  static const double compact = 600;
  static const double medium = 840;
  static const double expanded = 1200;

  static bool isCompact(double width) => width < compact;
  static bool isMedium(double width) => width >= compact && width < expanded;
  static bool isExpanded(double width) => width >= expanded;
}
