import 'package:intl/intl.dart';

import '../constants/app_constants.dart';
import '../constants/currencies.dart';

/// Formatting for money, weight, dates and identifiers.
///
/// Everything user-visible goes through here so a locale change reformats the
/// whole app, and so money never gets printed with `toString()`.
class Formatters {
  Formatters(this.locale);

  /// BCP-47 tag of the active locale, e.g. `en`, `lo`, `th`.
  final String locale;

  /// Money, using the currency's own decimal convention.
  ///
  /// An unknown currency code is rendered with the raw code rather than being
  /// silently coerced, so a data problem is visible instead of hidden.
  String money(num? amount, String? currencyCode, {bool compact = false}) {
    if (amount == null) return '—';

    final currency = AppCurrency.fromCode(currencyCode);
    final resolved = currency ?? AppCurrency.primary;
    final symbol = currency == null
        ? '${currencyCode ?? '?'} '
        : resolved.symbol;

    final pattern = compact
        ? NumberFormat.compactCurrency(
            locale: locale,
            symbol: symbol,
            decimalDigits: resolved.decimals == 0 ? 0 : 1,
          )
        : NumberFormat.currency(
            locale: locale,
            symbol: symbol,
            decimalDigits: resolved.decimals,
          );

    return pattern.format(amount);
  }

  /// Money with the ISO code instead of a symbol — used where several
  /// currencies appear together and symbols would be ambiguous.
  String moneyWithCode(num? amount, String? currencyCode) {
    if (amount == null) return '—';
    final resolved = AppCurrency.resolve(currencyCode);
    final number = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: resolved.decimals,
    );
    return '${number.format(amount)} ${currencyCode ?? resolved.code}';
  }

  /// Metal and stone weights — always three decimals, because a gold weight
  /// shown to two is a different number commercially.
  String weight(num? grams, {String unit = AppConstants.weightUnit}) {
    if (grams == null) return '—';
    final number = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: AppConstants.weightDecimals,
    );
    return '${number.format(grams)} $unit';
  }

  String carat(num? carats) {
    if (carats == null) return '—';
    final number = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 2,
    );
    return '${number.format(carats)} ${AppConstants.caratUnit}';
  }

  String count(num? value) {
    if (value == null) return '—';
    return NumberFormat.decimalPattern(locale).format(value);
  }

  String percent(num? value, {int decimals = 1}) {
    if (value == null) return '—';
    final number = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: decimals,
    );
    return '${number.format(value)}%';
  }

  String date(DateTime? value) =>
      value == null ? '—' : DateFormat.yMMMd(locale).format(value.toLocal());

  String dateTime(DateTime? value) => value == null
      ? '—'
      : DateFormat.yMMMd(locale).add_Hm().format(value.toLocal());

  String time(DateTime? value) =>
      value == null ? '—' : DateFormat.Hm(locale).format(value.toLocal());

  /// Compact relative age, for queues where "how long has this been waiting"
  /// is the number that matters.
  String relative(DateTime? value) {
    if (value == null) return '—';
    final difference = DateTime.now().difference(value.toLocal());

    if (difference.isNegative) return date(value);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return date(value);
  }

  /// Masks all but the last four characters of a sensitive identifier.
  String masked(String? value, {int visible = 4}) {
    if (value == null || value.isEmpty) return '—';
    if (value.length <= visible) return value;
    return '•••• ${value.substring(value.length - visible)}';
  }
}
