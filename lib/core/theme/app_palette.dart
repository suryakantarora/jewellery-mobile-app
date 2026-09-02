import 'package:flutter/material.dart';

/// The selectable accent identities of the application.
///
/// A jewellery business is a brand before it is a system, so the accent is a
/// user (later tenant) choice rather than a constant. Each palette supplies its
/// own light and dark seed so contrast stays correct in both modes.
enum AppPalette {
  champagneGold(
    label: 'Champagne Gold',
    lightSeed: Color(0xFFB08D2F),
    darkSeed: Color(0xFFD9B44A),
    accent: Color(0xFFC9A227),
  ),
  royalEmerald(
    label: 'Royal Emerald',
    lightSeed: Color(0xFF1F6B4A),
    darkSeed: Color(0xFF3FA97B),
    accent: Color(0xFF2E8B62),
  ),
  midnightSapphire(
    label: 'Midnight Sapphire',
    lightSeed: Color(0xFF23477E),
    darkSeed: Color(0xFF5A8AD6),
    accent: Color(0xFF2F5EA8),
  ),
  roseGold(
    label: 'Rose Gold',
    lightSeed: Color(0xFFB2685E),
    darkSeed: Color(0xFFE0918A),
    accent: Color(0xFFC77C71),
  ),
  platinum(
    label: 'Platinum',
    lightSeed: Color(0xFF4A5560),
    darkSeed: Color(0xFF98A6B4),
    accent: Color(0xFF6B7887),
  ),
  ruby(
    label: 'Ruby',
    lightSeed: Color(0xFF9B2233),
    darkSeed: Color(0xFFD9566A),
    accent: Color(0xFFB32D40),
  );

  const AppPalette({
    required this.label,
    required this.lightSeed,
    required this.darkSeed,
    required this.accent,
  });

  /// Human-readable name shown in the theme picker.
  final String label;

  /// Seed used to derive the light [ColorScheme].
  final Color lightSeed;

  /// Seed for the dark [ColorScheme]; lighter than [lightSeed] so it keeps its
  /// chroma against a dark surface.
  final Color darkSeed;

  /// Brand colour for swatches and non-scheme decoration.
  final Color accent;

  Color seedFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSeed : lightSeed;

  static AppPalette fromName(String? name) => values.firstWhere(
    (p) => p.name == name,
    orElse: () => AppPalette.champagneGold,
  );
}
