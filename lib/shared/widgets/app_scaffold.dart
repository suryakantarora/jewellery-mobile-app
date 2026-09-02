import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';
import 'branch_context_bar.dart';

/// The standard screen frame.
///
/// Every business screen uses this so the branch context bar cannot be
/// forgotten on one screen and present on the next.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showBranchBar = true,
    this.onBranchTap,
    this.leading,
    this.bottom,
    this.padded = false,
  });

  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool showBranchBar;
  final VoidCallback? onBranchTap;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: (title == null && titleWidget == null)
          ? null
          : AppBar(
              leading: leading,
              title: titleWidget ?? Text(title!),
              actions: actions,
              bottom: bottom,
            ),
      body: Column(
        children: [
          if (showBranchBar) ...[
            BranchContextBar(onTap: onBranchTap),
            const Divider(height: 1),
          ],
          Expanded(
            child: padded
                ? Padding(padding: AppSpacing.page, child: body)
                : body,
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// A placeholder for a screen a later phase will build.
///
/// Honest about what it is: it names the phase rather than pretending to be an
/// empty list, so a stakeholder walking the app is never misled into thinking a
/// feature is finished but broken.
class PhasePlaceholderScreen extends StatelessWidget {
  const PhasePlaceholderScreen({
    super.key,
    required this.title,
    required this.phase,
    required this.icon,
    this.description,
    this.showBranchBar = true,
  });

  final String title;
  final int phase;
  final IconData icon;
  final String? description;
  final bool showBranchBar;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      showBranchBar: showBranchBar,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: context.scheme.primaryContainer.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 34, color: context.scheme.primary),
              ),
              AppSpacing.gapXl,
              Text(title, style: context.text.headlineSmall),
              AppSpacing.gapSm,
              Text(
                description ?? context.l10n.phaseComingSoonMessage(title),
                style: context.text.bodyMedium?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapLg,
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: context.scheme.surfaceContainerHighest,
                  borderRadius: AppRadius.pillRadius,
                ),
                child: Text(
                  'Phase $phase',
                  style: context.text.labelSmall?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
