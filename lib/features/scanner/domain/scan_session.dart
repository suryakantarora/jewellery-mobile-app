import '../../../core/constants/app_constants.dart';

/// An accumulating set of scans, shared by every workflow that collects more
/// than one item.
///
/// Stock count (Phase 5), transfer picking and receiving (Phase 7) and physical
/// verification (Phase 8) all consume this rather than each writing their own
/// de-duplication and counting. That reuse is the main architectural point of
/// the scanning phase.
class ScanSession {
  ScanSession({this.expected = const {}, Duration? debounce})
    : _debounce = debounce ?? AppConstants.scanDebounce;

  /// Tags the workflow expects to see, where it knows in advance.
  ///
  /// Empty for an open-ended collection such as transfer picking.
  final Set<String> expected;

  final Duration _debounce;

  final List<String> _order = [];
  final Set<String> _seen = {};
  final Map<String, DateTime> _lastSeenAt = {};

  /// Every distinct value scanned, in the order first seen.
  List<String> get scanned => List.unmodifiable(_order);

  int get scannedCount => _order.length;

  /// Scanned values the workflow expected.
  Set<String> get matched =>
      expected.isEmpty ? {} : _seen.intersection(expected);

  /// Expected values not yet scanned.
  Set<String> get missing => expected.isEmpty ? {} : expected.difference(_seen);

  /// Scanned values that were not expected — a finding, not an error.
  Set<String> get unexpected =>
      expected.isEmpty ? {} : _seen.difference(expected);

  bool get isComplete => expected.isNotEmpty && missing.isEmpty;

  /// Records a scan and reports what it was.
  ///
  /// A decoder fires repeatedly while a tag stays in frame, so the same value
  /// inside the debounce window is a repeat read rather than a second physical
  /// scan. Distinguishing them is what lets the feedback tone be trusted.
  ScanOutcome record(String tag, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final last = _lastSeenAt[tag];

    if (last != null && at.difference(last) < _debounce) {
      _lastSeenAt[tag] = at;
      return ScanOutcome.repeat;
    }

    _lastSeenAt[tag] = at;

    if (_seen.contains(tag)) return ScanOutcome.duplicate;

    _seen.add(tag);
    _order.add(tag);

    if (expected.isEmpty) return ScanOutcome.accepted;
    return expected.contains(tag)
        ? ScanOutcome.matched
        : ScanOutcome.unexpected;
  }

  /// Removes a value, for the review step where a mis-scan is corrected.
  void remove(String tag) {
    _seen.remove(tag);
    _order.remove(tag);
    _lastSeenAt.remove(tag);
  }

  void clear() {
    _seen.clear();
    _order.clear();
    _lastSeenAt.clear();
  }

  /// Serialised for crash-safe local persistence.
  ///
  /// A half-finished 250-item vault count must survive the app being killed;
  /// losing it would mean starting a thirty-minute job again.
  Map<String, dynamic> toJson() => {
    'expected': expected.toList(),
    'scanned': _order,
  };

  factory ScanSession.fromJson(Map<String, dynamic> json) {
    final session = ScanSession(
      expected: ((json['expected'] as List?) ?? const [])
          .whereType<String>()
          .toSet(),
    );
    for (final tag
        in ((json['scanned'] as List?) ?? const []).whereType<String>()) {
      session._seen.add(tag);
      session._order.add(tag);
    }
    return session;
  }
}

/// What happened when a value was recorded.
enum ScanOutcome {
  /// Counted, and it was expected.
  matched,

  /// Counted, with no expectation to compare against.
  accepted,

  /// Counted, but the workflow did not expect it.
  unexpected,

  /// Already counted in this session.
  duplicate,

  /// The decoder re-read a tag still in frame; nothing changed.
  repeat,
}

extension ScanOutcomeX on ScanOutcome {
  /// Whether the counters changed — drives whether feedback should fire.
  bool get changedCount =>
      this == ScanOutcome.matched ||
      this == ScanOutcome.accepted ||
      this == ScanOutcome.unexpected;
}
