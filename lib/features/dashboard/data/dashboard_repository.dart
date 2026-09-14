import '../../../core/network/api_client.dart';
import '../domain/dashboard_summary.dart';

class DashboardRepository {
  DashboardRepository(this._client);

  final ApiClient _client;

  /// The dashboard endpoint. Local rather than in `ApiEndpoints`, which other
  /// features are extending concurrently; only this repository calls it.
  static const summaryPath = '/dashboard/summary';

  /// One round trip for every figure the caller may see.
  ///
  /// The server caches for 30 s; [refresh] bypasses that cache and is what
  /// pull-to-refresh sends, so a deliberate refresh never returns the same
  /// numbers it just showed.
  Future<DashboardSummary> summary(String branchId, {bool refresh = false}) {
    return _client.get<DashboardSummary>(
      summaryPath,
      query: {'branchId': branchId, if (refresh) 'refresh': true},
      parse: (data) => DashboardSummary.fromJson(
        data is Map<String, dynamic> ? data : const {},
      ),
    );
  }
}
