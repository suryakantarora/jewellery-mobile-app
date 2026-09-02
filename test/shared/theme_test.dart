import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_erp/core/theme/app_colors.dart';
import 'package:jewellery_erp/core/theme/app_palette.dart';
import 'package:jewellery_erp/core/theme/app_theme.dart';

void main() {
  group('Theme construction', () {
    test('every palette builds in both brightnesses', () {
      // Six palettes × two brightnesses is the full matrix a user can select,
      // and a missing token would only surface when someone picked it.
      for (final palette in AppPalette.values) {
        for (final build in [AppTheme.light, AppTheme.dark]) {
          final theme = build(palette);
          expect(theme.colorScheme, isNotNull);
          expect(theme.extension<AppColors>(), isNotNull,
              reason: '${palette.name} is missing its semantic colours');
          expect(theme.textTheme.bodyMedium, isNotNull);
        }
      }
    });

    test('light and dark differ in brightness and surface', () {
      final light = AppTheme.light(AppPalette.champagneGold);
      final dark = AppTheme.dark(AppPalette.champagneGold);

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.scaffoldBackgroundColor,
          isNot(dark.scaffoldBackgroundColor));
    });

    test('body surfaces are opaque', () {
      // A transparent scaffold would borrow whatever is painted behind it.
      for (final palette in AppPalette.values) {
        expect(AppTheme.light(palette).scaffoldBackgroundColor.a, 1.0);
        expect(AppTheme.dark(palette).scaffoldBackgroundColor.a, 1.0);
      }
    });

    test('semantic colours are defined in both modes', () {
      // No colour may have its only definition in one brightness.
      const light = AppColors.light;
      const dark = AppColors.dark;
      expect(light.success, isNot(dark.success));
      expect(light.danger, isNot(dark.danger));
      expect(light.vault, isNot(dark.vault));
      expect(light.gold, isNot(dark.gold));
    });
  });

  group('Palette', () {
    test('resolves a stored name, falling back to the default', () {
      expect(AppPalette.fromName('royalEmerald'), AppPalette.royalEmerald);
      expect(AppPalette.fromName('nonsense'), AppPalette.champagneGold);
      expect(AppPalette.fromName(null), AppPalette.champagneGold);
    });

    test('dark seeds are lighter, so they keep chroma on dark surfaces', () {
      for (final palette in AppPalette.values) {
        final light = HSLColor.fromColor(palette.lightSeed).lightness;
        final dark = HSLColor.fromColor(palette.darkSeed).lightness;
        expect(dark, greaterThan(light),
            reason: '${palette.name} dark seed should be lighter');
      }
    });
  });
}
