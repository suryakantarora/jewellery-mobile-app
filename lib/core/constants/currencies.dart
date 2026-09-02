/// Currencies the application formats natively.
///
/// LAK is the primary currency; USD, THB and INR are supported because the
/// business trades across the region. Amounts always carry their own currency
/// code from the backend — the app never assumes one.
enum AppCurrency {
  lak(
    code: 'LAK',
    symbol: '₭',
    label: 'Lao Kip',
    decimals: 0,
    symbolLeading: true,
  ),
  usd(
    code: 'USD',
    symbol: r'$',
    label: 'US Dollar',
    decimals: 2,
    symbolLeading: true,
  ),
  thb(
    code: 'THB',
    symbol: '฿',
    label: 'Thai Baht',
    decimals: 2,
    symbolLeading: true,
  ),
  inr(
    code: 'INR',
    symbol: '₹',
    label: 'Indian Rupee',
    decimals: 2,
    symbolLeading: true,
  );

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.label,
    required this.decimals,
    required this.symbolLeading,
  });

  /// ISO 4217 code, as the backend sends it.
  final String code;
  final String symbol;
  final String label;

  /// Kip is not quoted in subunits, so it formats without decimals.
  final int decimals;

  final bool symbolLeading;

  static const primary = AppCurrency.lak;

  static AppCurrency? fromCode(String? code) {
    if (code == null) return null;
    final upper = code.toUpperCase();
    for (final currency in values) {
      if (currency.code == upper) return currency;
    }
    return null;
  }

  /// Falls back to the primary currency for an unrecognised code, so an amount
  /// still renders rather than throwing — with the raw code shown by the
  /// formatter so the discrepancy is visible.
  static AppCurrency resolve(String? code) =>
      fromCode(code) ?? AppCurrency.primary;
}
