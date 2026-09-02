/// Values that tune behaviour but are not environment-specific.
abstract final class AppConstants {
  static const appName = 'Jewellery ERP';

  /// Decimal places used for metal and stone weights throughout the app.
  static const weightDecimals = 3;

  /// Weight and carat units as the backend expresses them.
  static const weightUnit = 'g';
  static const caratUnit = 'ct';

  /// Correlation id header, echoed by the backend on every response.
  static const correlationIdHeader = 'X-Correlation-Id';

  /// Idempotency header; accepted today by sales, payments and goods receipts.
  static const idempotencyKeyHeader = 'X-Idempotency-Key';

  /// Branch context header, sent alongside the explicit branchId parameter the
  /// backend currently requires.
  static const branchIdHeader = 'X-Branch-Id';

  /// A scan of the same value inside this window is treated as a repeat read
  /// from the decoder rather than a second physical scan.
  static const scanDebounce = Duration(milliseconds: 1500);

  /// How long dashboard figures stay fresh before a refresh re-fetches them.
  static const dashboardCacheTtl = Duration(seconds: 60);

  /// How long report figures stay fresh.
  static const reportCacheTtl = Duration(minutes: 5);

  /// A metal rate older than this is flagged as stale before it is quoted.
  static const metalRateStaleAfter = Duration(hours: 4);
}
