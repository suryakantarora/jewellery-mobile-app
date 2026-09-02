import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

/// The semantic meaning of a status, independent of which module it came from.
///
/// Modules map their own enums (`ItemStatus`, `MovementStatus`, `RepairStatus`…)
/// onto these, so "pending" looks identical whether it is a transfer awaiting
/// approval or a repair awaiting an estimate. Staff learn the colours once.
enum StatusTone { success, warning, danger, info, neutral, vault }

/// A compact status chip.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
    this.dense = false,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final (background, foreground) = switch (tone) {
      StatusTone.success => (colors.successContainer, colors.success),
      StatusTone.warning => (colors.warningContainer, colors.warning),
      StatusTone.danger => (colors.dangerContainer, colors.danger),
      StatusTone.info => (colors.infoContainer, colors.info),
      StatusTone.neutral => (colors.neutralContainer, colors.neutral),
      StatusTone.vault => (colors.vaultContainer, colors.vault),
    };

    // In dark mode the container colours are already dark, so the text takes
    // the vivid tone; in light mode the reverse. Both stay above 4.5:1.
    final textColor = context.isDark ? foreground : _darken(foreground);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? 2 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: textColor),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: (dense ? context.text.labelSmall : context.text.labelMedium)
                ?.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }

  static Color _darken(Color color) => HSLColor.fromColor(color)
      .withLightness(
        (HSLColor.fromColor(color).lightness - 0.12).clamp(0.0, 1.0),
      )
      .toColor();
}

/// A small coloured dot, for dense lists where a full chip is too heavy.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.tone, this.size = 8});

  final StatusTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = switch (tone) {
      StatusTone.success => colors.success,
      StatusTone.warning => colors.warning,
      StatusTone.danger => colors.danger,
      StatusTone.info => colors.info,
      StatusTone.neutral => colors.neutral,
      StatusTone.vault => colors.vault,
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
