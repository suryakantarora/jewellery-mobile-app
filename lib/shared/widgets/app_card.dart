import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

/// The standard content surface.
///
/// Flat with a hairline border rather than elevated — a dense enterprise list
/// of shadowed cards reads as noise, and the border survives dark mode where a
/// shadow disappears.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = AppSpacing.card,
    this.margin = EdgeInsets.zero,
    this.tone,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final EdgeInsets margin;

  /// Optional background tint, for cards carrying a status meaning.
  final Color? tone;

  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);

    return Padding(
      padding: margin,
      child: Material(
        color: tone ?? context.scheme.surfaceContainerLow,
        borderRadius: AppRadius.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? _bordered(context, content)
            : InkWell(onTap: onTap, child: _bordered(context, content)),
      ),
    );
  }

  Widget _bordered(BuildContext context, Widget child) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: AppRadius.cardRadius,
      border: Border.all(color: borderColor ?? context.scheme.outlineVariant),
    ),
    child: child,
  );
}

/// A card with a titled header and an optional trailing action.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.trailing,
    this.margin = EdgeInsets.zero,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: margin,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: context.scheme.primary),
                  AppSpacing.wGapSm,
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.text.titleSmall),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: context.text.bodySmall?.copyWith(
                            color: context.scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: AppSpacing.card, child: child),
        ],
      ),
    );
  }
}

/// A section that can be collapsed, used by the digital passport in Phase 4.
class ExpandableSection extends StatefulWidget {
  const ExpandableSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.initiallyExpanded = false,
    this.trailing,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final bool initiallyExpanded;
  final Widget? trailing;

  @override
  State<ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<ExpandableSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 18, color: context.scheme.primary),
                    AppSpacing.wGapSm,
                  ],
                  Expanded(
                    child: Text(widget.title, style: context.text.titleSmall),
                  ),
                  if (widget.trailing != null) widget.trailing!,
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: AppMotion.fast,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: context.scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                const Divider(height: 1),
                Padding(padding: AppSpacing.card, child: widget.child),
              ],
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: AppMotion.normal,
            sizeCurve: AppMotion.standard,
          ),
        ],
      ),
    );
  }
}
