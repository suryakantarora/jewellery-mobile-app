import 'package:flutter/material.dart';

/// Motion tokens. Animation here is functional — it explains where a thing came
/// from — so durations stay short and curves stay calm. Nothing bounces.
abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 360);
  static const Duration deliberate = Duration(milliseconds: 520);

  /// Default for most enter/exit transitions.
  static const Curve standard = Curves.easeOutCubic;

  /// Entering elements; slightly more deceleration.
  static const Curve enter = Curves.easeOutQuart;

  /// Leaving elements; quick, out of the way.
  static const Curve exit = Curves.easeInCubic;

  /// Emphasised movement for sheets and hero-like transitions.
  static const Curve emphasised = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Staggered list entrance delay, capped so a long list does not crawl.
  static Duration stagger(int index, {int cap = 8}) =>
      Duration(milliseconds: 40 * (index.clamp(0, cap)));
}
