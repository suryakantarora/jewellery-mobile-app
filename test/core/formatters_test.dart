import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_erp/core/utils/formatters.dart';

void main() {
  final formatters = Formatters('en');

  group('Money', () {
    test('Kip formats without decimals', () {
      // LAK is not quoted in subunits; showing ".00" would be wrong.
      expect(formatters.money(4250000, 'LAK'), contains('4,250,000'));
      expect(formatters.money(4250000, 'LAK'), isNot(contains('.00')));
    });

    test('USD, THB and INR keep two decimals', () {
      expect(formatters.money(1980.5, 'USD'), contains('1,980.50'));
      expect(formatters.money(68400.75, 'THB'), contains('68,400.75'));
      expect(formatters.money(164200.4, 'INR'), contains('164,200.40'));
    });

    test('an unknown currency shows its raw code rather than being coerced', () {
      // A data problem must stay visible instead of silently rendering as Kip.
      final result = formatters.money(100, 'XYZ');
      expect(result, contains('XYZ'));
    });

    test('null renders as an em dash, not zero', () {
      expect(formatters.money(null, 'LAK'), '—');
    });
  });

  group('Weight', () {
    test('always three decimals', () {
      // A gold weight shown to two decimals is a different number commercially.
      expect(formatters.weight(8.4), '8.400 g');
      expect(formatters.weight(8.4267), '8.427 g');
      expect(formatters.weight(0), '0.000 g');
    });

    test('carat uses two decimals', () {
      expect(formatters.carat(1.2), '1.20 ct');
    });
  });

  group('Masking', () {
    test('reveals only the last four characters', () {
      expect(formatters.masked('1234567890'), '•••• 7890');
    });

    test('leaves short values alone', () {
      expect(formatters.masked('12'), '12');
    });

    test('handles null and empty', () {
      expect(formatters.masked(null), '—');
      expect(formatters.masked(''), '—');
    });
  });

  group('Relative time', () {
    test('describes recent moments', () {
      final now = DateTime.now();
      expect(formatters.relative(now), 'just now');
      expect(
        formatters.relative(now.subtract(const Duration(hours: 3))),
        '3h ago',
      );
      expect(
        formatters.relative(now.subtract(const Duration(days: 2))),
        '2d ago',
      );
    });
  });
}
