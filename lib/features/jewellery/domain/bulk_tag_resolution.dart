import 'jewellery_item.dart';

/// One scanned value the server matched to an item.
typedef ResolvedTag = ({String tag, JewelleryItem item});

/// The outcome of `POST /inventory/items/by-tags`.
///
/// A bulk scan collects raw strings — RFID, QR, barcode or item code — and
/// the reconciliation flows need items: an id to submit and a name to show.
/// This is the bridge. Unresolved tags are a finding, not an error: a tag the
/// backend does not know is exactly what a stock count exists to surface.
class BulkTagResolution {
  const BulkTagResolution({
    this.resolved = const [],
    this.unresolved = const [],
  });

  static const empty = BulkTagResolution();

  final List<ResolvedTag> resolved;
  final List<String> unresolved;

  int get resolvedCount => resolved.length;
  int get unresolvedCount => unresolved.length;
  bool get hasUnresolved => unresolved.isNotEmpty;

  /// The matched items, in the order their tags were resolved.
  List<JewelleryItem> get items =>
      resolved.map((entry) => entry.item).toList(growable: false);

  /// Lookup from the scanned string to its item.
  Map<String, JewelleryItem> get byTag => {
    for (final entry in resolved) entry.tag: entry.item,
  };

  JewelleryItem? itemFor(String tag) {
    for (final entry in resolved) {
      if (entry.tag == tag) return entry.item;
    }
    return null;
  }

  /// Combines the results of chunked requests, preserving order.
  BulkTagResolution merge(BulkTagResolution other) => BulkTagResolution(
    resolved: [...resolved, ...other.resolved],
    unresolved: [...unresolved, ...other.unresolved],
  );

  factory BulkTagResolution.fromJson(Map<String, dynamic> json) {
    return BulkTagResolution(
      resolved: [
        for (final raw in (json['resolved'] as List?) ?? const [])
          if (raw is Map<String, dynamic>)
            if (raw['item'] is Map<String, dynamic>)
              (
                tag: raw['tag'] as String? ?? '',
                item: JewelleryItem.fromJson(
                  raw['item'] as Map<String, dynamic>,
                ),
              ),
      ],
      unresolved: ((json['unresolved'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}
