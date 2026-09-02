import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_backdrop.dart';

/// Shown while the session is restored from storage.
///
/// Deliberately quiet: this screen should be visible for a few hundred
/// milliseconds, so it carries the brand mark and nothing that would reward
/// looking at it for longer.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackdrop(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _BrandMark(size: 72),
              AppSpacing.gapXl,
              Text(context.l10n.appName, style: context.text.titleLarge),
              AppSpacing.gapXxl,
              SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  backgroundColor: context.scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The application mark — a stylised faceted gem drawn in the accent colour.
///
/// Drawn rather than shipped as an asset so it always matches the selected
/// palette and stays crisp at any size.
class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: BrandMarkPainter(
          primary: context.scheme.primary,
          secondary: context.scheme.tertiary,
        ),
      ),
    );
  }
}

/// Paints the gem mark. Public so the login screen can reuse it.
class BrandMarkPainter extends CustomPainter {
  BrandMarkPainter({required this.primary, required this.secondary});

  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // A brilliant-cut silhouette: a shallow crown over a deep pavilion.
    final crownLeft = Offset(w * 0.12, h * 0.36);
    final crownRight = Offset(w * 0.88, h * 0.36);
    final topLeft = Offset(w * 0.28, h * 0.14);
    final topRight = Offset(w * 0.72, h * 0.14);
    final tip = Offset(w * 0.5, h * 0.9);

    final outline = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(crownRight.dx, crownRight.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(crownLeft.dx, crownLeft.dy)
      ..close();

    canvas.drawPath(
      outline,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, secondary],
        ).createShader(Offset.zero & size),
    );

    // Facet lines, drawn slightly translucent so they read as cut rather than
    // as separate shapes.
    final facet = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02
      ..color = Colors.white.withValues(alpha: 0.35);

    canvas
      ..drawLine(crownLeft, crownRight, facet)
      ..drawLine(topLeft, Offset(w * 0.36, h * 0.36), facet)
      ..drawLine(topRight, Offset(w * 0.64, h * 0.36), facet)
      ..drawLine(Offset(w * 0.36, h * 0.36), tip, facet)
      ..drawLine(Offset(w * 0.64, h * 0.36), tip, facet);
  }

  @override
  bool shouldRepaint(BrandMarkPainter old) =>
      old.primary != primary || old.secondary != secondary;
}
