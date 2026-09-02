import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../extensions/context_extensions.dart';

/// A soft, slowly drifting gradient wash used behind session screens.
///
/// Restraint is the point: this is an enterprise tool, so the backdrop reads as
/// a finished surface rather than decoration, stays far below text contrast
/// thresholds, and is driven by the selected accent so it changes with the
/// theme instead of being a fixed brand image.
class AppBackdrop extends StatefulWidget {
  const AppBackdrop({
    super.key,
    required this.child,
    this.animate = true,
    this.intensity = 1,
  });

  final Widget child;

  /// Disabled automatically when the platform asks for reduced motion.
  final bool animate;

  /// Scales the wash; session screens use the full value, content screens less.
  final double intensity;

  @override
  State<AppBackdrop> createState() => _AppBackdropState();
}

class _AppBackdropState extends State<AppBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // Deliberately very slow — perceptible only if you look for it.
    duration: const Duration(seconds: 24),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = widget.animate && !MediaQuery.disableAnimationsOf(context);

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _BackdropPainter(
                progress: animate ? _controller.value : 0.35,
                accent: context.scheme.primary,
                secondary: context.scheme.tertiary,
                surface: context.scheme.surface,
                isDark: context.isDark,
                intensity: widget.intensity,
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({
    required this.progress,
    required this.accent,
    required this.secondary,
    required this.surface,
    required this.isDark,
    required this.intensity,
  });

  final double progress;
  final Color accent;
  final Color secondary;
  final Color surface;
  final bool isDark;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = surface);

    // Two large, very low-opacity radial blooms that drift in opposite
    // directions. Alpha stays low enough that body text over it keeps its
    // contrast ratio in both themes.
    final drift = math.sin(progress * math.pi * 2);
    final baseAlpha = (isDark ? 0.16 : 0.10) * intensity;

    _bloom(
      canvas,
      center: Offset(size.width * (0.18 + drift * 0.06), size.height * 0.12),
      radius: size.width * 0.85,
      color: accent.withValues(alpha: baseAlpha),
    );

    _bloom(
      canvas,
      center: Offset(size.width * (0.88 - drift * 0.05), size.height * 0.78),
      radius: size.width * 0.7,
      color: secondary.withValues(alpha: baseAlpha * 0.8),
    );
  }

  void _bloom(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.progress != progress ||
      old.accent != accent ||
      old.surface != surface ||
      old.intensity != intensity;
}

/// A swatch of an accent palette, for the theme picker.
class PaletteSwatch extends StatelessWidget {
  const PaletteSwatch({
    super.key,
    required this.palette,
    required this.selected,
    this.onTap,
    this.size = 44,
  });

  final AppPalette palette;
  final bool selected;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = palette.seedFor(Theme.of(context).brightness);

    return Semantics(
      button: true,
      selected: selected,
      label: palette.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? context.scheme.onSurface : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: selected
              ? Icon(
                  Icons.check,
                  size: size * 0.45,
                  // Chosen against the swatch itself, not the page.
                  color:
                      ThemeData.estimateBrightnessForColor(color) ==
                          Brightness.dark
                      ? Colors.white
                      : Colors.black,
                )
              : null,
        ),
      ),
    );
  }
}
