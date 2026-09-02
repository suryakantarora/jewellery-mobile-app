import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_erp/features/scanner/domain/scan_session.dart';
import 'package:jewellery_erp/features/scanner/domain/scanner_service.dart';

void main() {
  group('ScanSession reconciliation', () {
    ScanSession session() => ScanSession(expected: {'A', 'B', 'C'});

    test('classifies a scan against what was expected', () {
      final s = session();
      expect(s.record('A'), ScanOutcome.matched);
      expect(s.record('Z'), ScanOutcome.unexpected);
    });

    test('a repeat read inside the debounce window changes nothing', () {
      // A decoder fires continuously while a tag stays in frame. Treating that
      // as a second scan would corrupt every count.
      final s = session();
      final now = DateTime(2026, 9, 1, 12);

      expect(s.record('A', now: now), ScanOutcome.matched);
      expect(
        s.record('A', now: now.add(const Duration(milliseconds: 300))),
        ScanOutcome.repeat,
      );
      expect(s.scannedCount, 1);
    });

    test('the same tag scanned again later is a duplicate, not a repeat', () {
      final s = session();
      final now = DateTime(2026, 9, 1, 12);

      s.record('A', now: now);
      expect(
        s.record('A', now: now.add(const Duration(seconds: 30))),
        ScanOutcome.duplicate,
      );
      // Still counted once — a duplicate must never inflate the total.
      expect(s.scannedCount, 1);
    });

    test('tracks matched, missing and unexpected', () {
      final s = session();
      s.record('A');
      s.record('B');
      s.record('Z');

      expect(s.matched, {'A', 'B'});
      expect(s.missing, {'C'});
      expect(s.unexpected, {'Z'});
      expect(s.isComplete, isFalse);
    });

    test('is complete only when nothing expected is missing', () {
      final s = session();
      s.record('A');
      s.record('B');
      expect(s.isComplete, isFalse);
      s.record('C');
      expect(s.isComplete, isTrue);
      // An unexpected extra does not make a count incomplete.
      s.record('Z');
      expect(s.isComplete, isTrue);
    });

    test('removing a mis-scan restores the counters', () {
      final s = session();
      s.record('Z');
      expect(s.unexpected, {'Z'});

      s.remove('Z');
      expect(s.unexpected, isEmpty);
      expect(s.scannedCount, 0);
    });

    test('an open-ended session accepts anything and reports no variance', () {
      // Transfer picking has no expected list — everything scanned is valid.
      final s = ScanSession();
      expect(s.record('anything'), ScanOutcome.accepted);
      expect(s.missing, isEmpty);
      expect(s.unexpected, isEmpty);
      expect(s.isComplete, isFalse);
    });

    test('survives serialisation, so a killed app resumes the count', () {
      // A 250-item vault count is a thirty-minute job; losing it would be
      // worse than not offering the workflow.
      final s = session();
      s.record('A');
      s.record('Z');

      final restored = ScanSession.fromJson(s.toJson());

      expect(restored.scanned, ['A', 'Z']);
      expect(restored.matched, {'A'});
      expect(restored.missing, {'B', 'C'});
      expect(restored.unexpected, {'Z'});
    });

    test('only counter-changing outcomes should trigger feedback', () {
      expect(ScanOutcome.matched.changedCount, isTrue);
      expect(ScanOutcome.accepted.changedCount, isTrue);
      expect(ScanOutcome.unexpected.changedCount, isTrue);
      // Silence on a repeat is deliberate: buzzing would train staff to
      // ignore the feedback entirely.
      expect(ScanOutcome.repeat.changedCount, isFalse);
      expect(ScanOutcome.duplicate.changedCount, isFalse);
    });
  });

  group('TagNormaliser', () {
    const normaliser = TagNormaliser();

    test('passes a plain code through unchanged', () {
      expect(normaliser.normalise('JW-000241'), 'JW-000241');
      expect(normaliser.normalise('RFID00000001'), 'RFID00000001');
    });

    test('reduces a QR that encodes a URL to the code', () {
      // Without this every URL-encoded QR resolves as not-found.
      expect(
        normaliser.normalise('https://abc.example/item/JW-000241'),
        'JW-000241',
      );
    });

    test('falls back to the last segment when the marker is absent', () {
      expect(
        normaliser.normalise('https://abc.example/tags/JW-000999'),
        'JW-000999',
      );
    });

    test('trims whitespace and stray quotes some encoders add', () {
      expect(normaliser.normalise('  JW-000241  '), 'JW-000241');
      expect(normaliser.normalise('"JW-000241"'), 'JW-000241');
    });

    test('leaves an empty scan empty rather than inventing a value', () {
      expect(normaliser.normalise('   '), '');
    });
  });
}
