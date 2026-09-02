import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The exchange and buyback module must never compute a financial value.
///
/// The specification is explicit: *"the mobile app must never independently
/// calculate or approve financial values if the backend provides the
/// authoritative calculation."* The backend does — `ValuationRequest` accepts
/// only a deduction percentage, and returns the rate, pure weight, gross
/// valuation, deduction amount and net payable.
///
/// A convention alone would erode. This test reads the source and fails the
/// build if arithmetic appears on a monetary or weight-derived field, so the
/// rule survives every future edit.
void main() {
  group('Exchange module has no client-side financial arithmetic', () {
    /// Fields whose value must always come from the server.
    const guarded = [
      'netValuation',
      'grossValuation',
      'deductionAmount',
      'ratePerUnit',
      'pureWeight',
      'netWeight',
      'testedFineness',
    ];

    late List<({String path, String source})> sources;

    setUpAll(() {
      final directory = Directory('lib/features/exchange');
      sources = directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => (path: file.path, source: file.readAsStringSync()))
          .toList();
    });

    test('the module has source files to check', () {
      expect(sources, isNotEmpty);
    });

    test('no guarded field appears next to an arithmetic operator', () {
      final violations = <String>[];

      for (final entry in sources) {
        final lines = entry.source.split('\n');

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];

          // Comments describe the rule; they are not code.
          final trimmed = line.trimLeft();
          if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;

          for (final field in guarded) {
            if (!line.contains(field)) continue;

            // Any use of the field in an expression combined with * / + -
            // would mean the app was deriving a figure of its own.
            final arithmetic = RegExp(
              r'(' + field + r')\s*[\*\/\+\-]|[\*\/\+\-]\s*\w*\.?(' +
                  field +
                  r')\b',
            );

            if (arithmetic.hasMatch(line)) {
              violations.add('${entry.path}:${i + 1}  ${line.trim()}');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'A financial figure is being computed on the client:\n'
            '${violations.join('\n')}\n\n'
            'These values must come from the backend. Post the inputs and '
            'render what comes back.',
      );
    });

    test('the repository sends only a deduction percentage for valuation', () {
      final repository = sources
          .firstWhere((entry) => entry.path.endsWith('exchange_repository.dart'))
          .source;

      // Anchored on the declaration, not on a formatted call expression: an
      // earlier version keyed off "_step(id, 'valuation'" and silently broke
      // the moment the formatter wrapped that call across lines.
      final start = repository.indexOf('Future<ExchangeRecord> value(');
      final end = repository.indexOf('Future<ExchangeRecord> approve');
      expect(start, isNonNegative, reason: 'valuation method not found');
      expect(end, greaterThan(start));

      final valuationBody = repository.substring(start, end);

      // Anything else in the body would mean the client had a say in the price.
      expect(valuationBody, contains('deductionPercentage'));
      expect(valuationBody.contains('netValuation'), isFalse);
      expect(valuationBody.contains('grossValuation'), isFalse);
      expect(valuationBody.contains('ratePerUnit'), isFalse);
    });
  });
}
