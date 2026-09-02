import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/permissions.dart';
import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/data_display.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/report_providers.dart';

/// Lightweight operational reports.
///
/// Deliberately small: the specification says not to reproduce the Admin BI
/// system. Finance and compliance reports are excluded — they are dense,
/// tabular and regulated, and belong in the portal.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionsProvider);

    if (!permissions.has(Permission.reportView)) {
      return AppScaffold(
        title: context.l10n.screenReports,
        body: const NoPermissionState(
          message: 'Reporting needs the REPORT_VIEW permission.',
        ),
      );
    }

    final period = ref.watch(reportPeriodProvider);

    return AppScaffold(
      title: context.l10n.screenReports,
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(salesReportProvider)
            ..invalidate(inventoryValuationReportProvider)
            ..invalidate(stockAgeingReportProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          children: [
            SegmentedButton<ReportPeriod>(
              segments: [
                for (final option in ReportPeriod.values)
                  ButtonSegment(value: option, label: Text(option.label)),
              ],
              selected: {period},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  ref.read(reportPeriodProvider.notifier).set(selection.first),
            ),
            AppSpacing.gapXl,
            const _SalesCard(),
            AppSpacing.gapLg,
            const _InventoryCard(),
            AppSpacing.gapLg,
            const _AgeingCard(),
          ],
        ),
      ),
    );
  }
}

class _SalesCard extends ConsumerWidget {
  const _SalesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(salesReportProvider);
    final formatters = ref.watch(formattersProvider);

    return SectionCard(
      title: 'Sales',
      icon: Icons.payments_outlined,
      subtitle: ref.watch(reportPeriodProvider).label,
      child: report.when(
        loading: () => const _CardLoading(),
        error: (_, __) => const _CardUnavailable(),
        data: (data) {
          if (data == null) return const _CardUnavailable();

          final net = (data['totalNet'] ?? data['netAmount']) as num?;
          final gross = (data['totalGross'] ?? data['grossAmount']) as num?;
          final count = (data['saleCount'] ?? data['count']) as num?;
          final currency = data['currency'] as String?;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HideableAmount(
                hidden: false,
                child: Text(
                  formatters.money(net ?? gross, currency),
                  style: AppTypography.numeric(context, size: 26),
                ),
              ),
              AppSpacing.gapSm,
              Text(
                count == null
                    ? 'No sales recorded'
                    : '${formatters.count(count)} sale'
                          '${count == 1 ? '' : 's'}',
                style: context.text.bodySmall?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InventoryCard extends ConsumerWidget {
  const _InventoryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(inventoryValuationReportProvider);
    final formatters = ref.watch(formattersProvider);
    final fallbackCurrency = ref
        .watch(sessionControllerProvider)
        .company
        ?.baseCurrency;

    return SectionCard(
      title: 'Inventory',
      icon: Icons.diamond_outlined,
      child: report.when(
        loading: () => const _CardLoading(),
        error: (_, __) => const _CardUnavailable(),
        data: (data) {
          if (data == null) return const _CardUnavailable();

          final value = (data['totalValue'] ?? data['totalCost']) as num?;
          final count = (data['itemCount'] ?? data['totalItems']) as num?;

          return Column(
            children: [
              KeyValueRow(
                label: 'Items',
                value: formatters.count(count),
                numeric: true,
              ),
              KeyValueRow(
                label: 'Value',
                value: formatters.money(
                  value,
                  (data['currency'] as String?) ?? fallbackCurrency,
                ),
                numeric: true,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Stock ageing, drawn as a horizontal bar chart.
///
/// One idea per chart: a phone-width chart with five series is unreadable, so
/// this shows counts per bucket and nothing else. Every bar is labelled with
/// its own number, so colour is never the only encoding — the chart and the
/// table say the same thing.
class _AgeingCard extends ConsumerWidget {
  const _AgeingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(stockAgeingReportProvider);

    return SectionCard(
      title: 'Stock ageing',
      icon: Icons.hourglass_bottom_outlined,
      subtitle: 'How long stock has been held',
      child: report.when(
        loading: () => const _CardLoading(),
        error: (_, __) => const _CardUnavailable(),
        data: (data) {
          final buckets = parseAgeingBuckets(data);
          if (buckets.isEmpty) {
            return Text(
              'No ageing data for this branch.',
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            );
          }

          final maximum = buckets
              .map((bucket) => bucket.count)
              .fold<int>(0, (a, b) => a > b ? a : b);

          return Column(
            children: [
              for (final bucket in buckets)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 78,
                        child: Text(
                          bucket.label,
                          style: context.text.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          child: LinearProgressIndicator(
                            value: maximum == 0 ? 0 : bucket.count / maximum,
                            minHeight: 10,
                            backgroundColor:
                                context.scheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                      AppSpacing.wGapMd,
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${bucket.count}',
                          textAlign: TextAlign.end,
                          style: AppTypography.numeric(context, size: 13),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CardLoading extends StatelessWidget {
  const _CardLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
    child: Center(
      child: SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

/// A report that could not be loaded.
///
/// Says so rather than showing a zero — a zero here would be read as "no
/// stock" or "no sales", which is a materially different and much worse claim.
class _CardUnavailable extends StatelessWidget {
  const _CardUnavailable();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        Icons.cloud_off_outlined,
        size: 16,
        color: context.scheme.onSurfaceVariant,
      ),
      AppSpacing.wGapSm,
      Text(
        'Unavailable',
        style: context.text.bodySmall?.copyWith(
          color: context.scheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}
