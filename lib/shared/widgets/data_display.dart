import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_providers.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../extensions/context_extensions.dart';

/// A label/value row — the workhorse of every detail screen.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.valueWidget,
    this.numeric = false,
    this.onTap,
  });

  final String label;
  final String value;
  final Widget? valueWidget;

  /// Uses tabular figures, so stacked rows of weights and prices align.
  final bool numeric;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Under large text scaling a two-column row truncates badly, so it becomes
    // a stack instead of squeezing.
    final stacked = context.prefersLargeText;

    final labelWidget = Text(
      label,
      style: context.text.bodySmall?.copyWith(
        color: context.scheme.onSurfaceVariant,
      ),
    );

    final valueContent =
        valueWidget ??
        Text(
          value,
          style: numeric
              ? AppTypography.numeric(context, weight: FontWeight.w600)
              : context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          textAlign: stacked ? TextAlign.start : TextAlign.end,
        );

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, AppSpacing.gapXs, valueContent],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: labelWidget),
                AppSpacing.wGapMd,
                Expanded(
                  flex: 6,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: valueContent,
                  ),
                ),
              ],
            ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: content,
    );
  }
}

/// A headline figure with a caption — dashboard tiles and report summaries.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.trend,
    this.onTap,
    this.sensitive = false,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;

  /// Positive or negative change, rendered with an arrow.
  final double? trend;

  final VoidCallback? onTap;

  /// Monetary figures are marked sensitive so the "hide amounts" setting can
  /// blur them — useful when a customer can see the device across a counter.
  final bool sensitive;

  @override
  Widget build(BuildContext context) {
    return _StatTileBody(
      label: label,
      value: value,
      caption: caption,
      icon: icon,
      trend: trend,
      onTap: onTap,
      sensitive: sensitive,
    );
  }
}

class _StatTileBody extends ConsumerWidget {
  const _StatTileBody({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.trend,
    required this.onTap,
    required this.sensitive,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final double? trend;
  final VoidCallback? onTap;
  final bool sensitive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = sensitive && ref.watch(hideAmountsProvider);

    return Material(
      color: context.scheme.surfaceContainerLow,
      borderRadius: AppRadius.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: AppSpacing.card,
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: context.scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 15, color: context.scheme.primary),
                    AppSpacing.wGapXs,
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: context.text.labelMedium?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              AppSpacing.gapSm,
              HideableAmount(
                hidden: hidden,
                child: Text(
                  value,
                  style: AppTypography.numeric(
                    context,
                    size: 22,
                    weight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (caption != null || trend != null) ...[
                AppSpacing.gapXs,
                Row(
                  children: [
                    if (trend != null) ...[
                      Icon(
                        trend! >= 0 ? Icons.trending_up : Icons.trending_down,
                        size: 13,
                        color: trend! >= 0
                            ? context.colors.success
                            : context.colors.danger,
                      ),
                      AppSpacing.wGapXs,
                    ],
                    if (caption != null)
                      Flexible(
                        child: Text(
                          caption!,
                          style: context.text.bodySmall?.copyWith(
                            color: context.scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Blurs its child when amounts are hidden.
///
/// The value is still laid out at full size, so toggling privacy does not
/// reflow the screen.
class HideableAmount extends StatelessWidget {
  const HideableAmount({super.key, required this.child, required this.hidden});

  final Widget child;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.fast,
      child: hidden
          // The real value still occupies its space, so toggling privacy does
          // not reflow the screen around it.
          ? Stack(
              key: const ValueKey('hidden'),
              children: [
                Opacity(opacity: 0, child: child),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.7,
                      heightFactor: 0.6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : KeyedSubtree(key: const ValueKey('shown'), child: child),
    );
  }
}
