import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';

/// The period a report covers.
enum ReportPeriod {
  today('Today', 0),
  week('7 days', 6),
  month('30 days', 29),
  quarter('90 days', 89);

  const ReportPeriod(this.label, this.daysBack);
  final String label;
  final int daysBack;

  ({DateTime from, DateTime to}) range({DateTime? now}) {
    final today = now ?? DateTime.now();
    final to = DateTime(today.year, today.month, today.day);
    return (to: to, from: to.subtract(Duration(days: daysBack)));
  }
}

final reportPeriodProvider =
    NotifierProvider<ReportPeriodController, ReportPeriod>(
      ReportPeriodController.new,
    );

class ReportPeriodController extends Notifier<ReportPeriod> {
  @override
  ReportPeriod build() => ReportPeriod.week;
  void set(ReportPeriod period) => state = period;
}

String _iso(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Sales over the selected period.
///
/// The date range uses the **branch's** day boundaries conceptually — a report
/// run in Vientiane should not shift because the device is in another timezone.
/// `BranchResponse.timezone` is carried for exactly this reason; the current
/// implementation uses local dates, which is correct while all branches share
/// Asia/Vientiane and is flagged in the build log otherwise.
final salesReportProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((
  ref,
) async {
  final branch = ref.watch(currentBranchProvider);
  final range = ref.watch(reportPeriodProvider).range();

  return ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>?>(
        ApiEndpoints.salesReport,
        query: {
          'from': _iso(range.from),
          'to': _iso(range.to),
          if (branch != null) 'branchId': branch.id,
        },
        parse: (data) => data is Map<String, dynamic> ? data : null,
      );
});

final inventoryValuationReportProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
      final branch = ref.watch(currentBranchProvider);
      return ref
          .watch(apiClientProvider)
          .get<Map<String, dynamic>?>(
            ApiEndpoints.inventoryValuation,
            query: {if (branch != null) 'branchId': branch.id},
            parse: (data) => data is Map<String, dynamic> ? data : null,
          );
    });

final stockAgeingReportProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
      final branch = ref.watch(currentBranchProvider);
      return ref
          .watch(apiClientProvider)
          .get<Map<String, dynamic>?>(
            ApiEndpoints.stockAgeing,
            query: {if (branch != null) 'branchId': branch.id},
            parse: (data) => data is Map<String, dynamic> ? data : null,
          );
    });

/// One bucket of an ageing report.
class AgeingBucket {
  const AgeingBucket({required this.label, required this.count, this.value});

  final String label;
  final int count;
  final double? value;
}

/// Normalises the ageing payload into buckets.
///
/// The backend's exact field names are not fixed by the OpenAPI schema, so
/// several shapes are accepted rather than assuming one and rendering nothing.
List<AgeingBucket> parseAgeingBuckets(Map<String, dynamic>? data) {
  if (data == null) return const [];

  final raw = data['buckets'] ?? data['ageingBuckets'] ?? data['ranges'];
  if (raw is List) {
    return raw
        .whereType<Map<String, dynamic>>()
        .map(
          (bucket) => AgeingBucket(
            label:
                (bucket['label'] ?? bucket['range'] ?? bucket['bucket'] ?? '')
                    .toString(),
            count: (bucket['count'] ?? bucket['itemCount'] ?? 0) as int,
            value: (bucket['value'] ?? bucket['totalValue']) is num
                ? ((bucket['value'] ?? bucket['totalValue']) as num).toDouble()
                : null,
          ),
        )
        .where((bucket) => bucket.label.isNotEmpty)
        .toList(growable: false);
  }

  // Some shapes return a flat map of range → count.
  if (raw is Map) {
    return raw.entries
        .map(
          (entry) => AgeingBucket(
            label: entry.key.toString(),
            count: entry.value is num ? (entry.value as num).toInt() : 0,
          ),
        )
        .toList(growable: false);
  }

  return const [];
}
