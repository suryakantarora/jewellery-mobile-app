import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../../../shared/widgets/app_timeline.dart';
import '../../../../shared/widgets/data_display.dart';
import '../../../../shared/widgets/skeletons.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_badge.dart';

/// Every shared component on one screen.
///
/// This exists so the whole design system can be reviewed and regression-checked
/// in both themes, in all three languages and at large text sizes, before any
/// feature is built on top of it. Non-production builds only.
class ComponentGalleryScreen extends ConsumerWidget {
  const ComponentGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatters = ref.watch(formattersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.galleryTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.huge,
        ),
        children: [
          _Group(
            title: 'Typography',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Display small', style: context.text.displaySmall),
                Text('Headline medium', style: context.text.headlineMedium),
                Text('Title medium', style: context.text.titleMedium),
                Text(
                  'Body medium — the quick brown fox',
                  style: context.text.bodyMedium,
                ),
                Text('Label small', style: context.text.labelSmall),
                AppSpacing.gapMd,
                // Tabular figures are the reason these two lines align.
                Text(formatters.money(4250000, 'LAK')),
                Text(formatters.money(1111111, 'LAK')),
              ],
            ),
          ),

          _Group(
            title: 'Currency',
            child: Column(
              children: [
                KeyValueRow(
                  label: 'Lao Kip',
                  value: formatters.money(4250000, 'LAK'),
                  numeric: true,
                ),
                KeyValueRow(
                  label: 'US Dollar',
                  value: formatters.money(1980.5, 'USD'),
                  numeric: true,
                ),
                KeyValueRow(
                  label: 'Thai Baht',
                  value: formatters.money(68400.75, 'THB'),
                  numeric: true,
                ),
                KeyValueRow(
                  label: 'Indian Rupee',
                  value: formatters.money(164200.4, 'INR'),
                  numeric: true,
                ),
                KeyValueRow(
                  label: 'Gross weight',
                  value: formatters.weight(8.42),
                  numeric: true,
                ),
                KeyValueRow(
                  label: 'Total carat',
                  value: formatters.carat(1.25),
                  numeric: true,
                ),
              ],
            ),
          ),

          _Group(
            title: 'Status badges',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: const [
                StatusBadge(label: 'AVAILABLE', tone: StatusTone.success),
                StatusBadge(label: 'IN TRANSIT', tone: StatusTone.warning),
                StatusBadge(label: 'REJECTED', tone: StatusTone.danger),
                StatusBadge(label: 'DRAFT', tone: StatusTone.info),
                StatusBadge(label: 'CANCELLED', tone: StatusTone.neutral),
                StatusBadge(label: 'VAULT', tone: StatusTone.vault),
              ],
            ),
          ),

          _Group(
            title: 'Stat tiles',
            child: Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: "Today's sales",
                    value: formatters.money(12400000, 'LAK', compact: true),
                    caption: 'vs last week',
                    trend: 12,
                    icon: Icons.trending_up,
                    sensitive: true,
                  ),
                ),
                AppSpacing.wGapMd,
                Expanded(
                  child: StatTile(
                    label: 'Inventory',
                    value: formatters.count(1284),
                    caption: 'pieces',
                    icon: Icons.diamond_outlined,
                  ),
                ),
              ],
            ),
          ),

          _Group(
            title: 'Buttons',
            child: Column(
              children: [
                const AppButton(label: 'Primary', onPressed: _noop),
                AppSpacing.gapSm,
                const AppButton(
                  label: 'Secondary',
                  variant: AppButtonVariant.secondary,
                  onPressed: _noop,
                ),
                AppSpacing.gapSm,
                const AppButton(
                  label: 'Outlined',
                  icon: Icons.qr_code_scanner,
                  variant: AppButtonVariant.outlined,
                  onPressed: _noop,
                ),
                AppSpacing.gapSm,
                const AppButton(
                  label: 'Danger',
                  variant: AppButtonVariant.danger,
                  onPressed: _noop,
                ),
                AppSpacing.gapSm,
                const AppButton(label: 'Busy', busy: true, onPressed: _noop),
                AppSpacing.gapSm,
                const AppButton(label: 'Disabled'),
              ],
            ),
          ),

          _Group(
            title: 'Inputs',
            child: Column(
              children: [
                AppSearchField(onChanged: (_) {}, onScan: () {}),
                AppSpacing.gapMd,
                const AppTextField(label: 'Item code', prefixIcon: Icons.tag),
                AppSpacing.gapMd,
                const AppTextField(
                  label: 'With error',
                  errorText: 'This field is required',
                ),
                AppSpacing.gapMd,
                const AppPasswordField(label: 'Password'),
              ],
            ),
          ),

          _Group(
            title: 'Timeline',
            child: AppTimeline(
              formatTimestamp: formatters.relative,
              events: [
                TimelineEvent(
                  title: 'Received at counter',
                  subtitle: 'Vientiane Showroom',
                  actor: 'Somchai',
                  timestamp: DateTime.now().subtract(const Duration(hours: 2)),
                  tone: StatusTone.success,
                  icon: Icons.check,
                ),
                TimelineEvent(
                  title: 'In transit',
                  subtitle: 'Central Warehouse → Vientiane',
                  actor: 'Bounma',
                  timestamp: DateTime.now().subtract(const Duration(days: 1)),
                  tone: StatusTone.warning,
                ),
                TimelineEvent(
                  title: 'Approved',
                  actor: 'Khamla',
                  timestamp: DateTime.now().subtract(const Duration(days: 2)),
                  tone: StatusTone.info,
                ),
              ],
            ),
          ),

          _Group(
            title: 'Loading',
            child: const Column(
              children: [
                SkeletonStatTile(),
                AppSpacing.gapMd,
                SkeletonListItem(),
                SkeletonListItem(),
              ],
            ),
          ),

          _Group(
            title: 'Empty state',
            child: const SizedBox(height: 240, child: EmptyState()),
          ),

          _Group(
            title: 'Error state',
            child: SizedBox(
              height: 300,
              child: ErrorState(
                error: const ServerException(
                  message: 'The server did not respond in time.',
                  correlationId: 'a3f9-2c81-44de',
                ),
                onRetry: () {},
              ),
            ),
          ),

          _Group(
            title: 'Dialogs & sheets',
            child: Column(
              children: [
                AppButton(
                  label: 'Confirmation dialog',
                  variant: AppButtonVariant.outlined,
                  onPressed: () => showConfirmationDialog(
                    context,
                    title: 'Approve transfer?',
                    message:
                        'TR-10024 · 12 items to Vientiane Showroom. This cannot '
                        'be undone.',
                    tone: ConfirmTone.danger,
                    icon: Icons.warning_amber_outlined,
                  ),
                ),
                AppSpacing.gapSm,
                AppButton(
                  label: 'Reason sheet',
                  variant: AppButtonVariant.outlined,
                  onPressed: () => showReasonSheet(
                    context,
                    title: 'Reason for rejection',
                    hint: 'Explain why this is being rejected',
                  ),
                ),
                AppSpacing.gapSm,
                AppButton(
                  label: 'Snackbar',
                  variant: AppButtonVariant.outlined,
                  onPressed: () => showAppSnackBar(
                    context,
                    message: 'Transfer submitted for approval',
                    tone: SnackTone.success,
                  ),
                ),
              ],
            ),
          ),

          _Group(
            title: 'Expandable section',
            child: const ExpandableSection(
              title: 'Metal & purity',
              icon: Icons.workspaces_outlined,
              child: Column(
                children: [
                  KeyValueRow(label: 'Metal', value: 'Gold'),
                  KeyValueRow(label: 'Purity', value: '22K'),
                  KeyValueRow(
                    label: 'Net metal weight',
                    value: '7.220 g',
                    numeric: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _noop() {}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              title.toUpperCase(),
              style: context.text.labelSmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
          ),
          AppCard(child: child),
        ],
      ),
    );
  }
}
