import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../jewellery/domain/bulk_tag_resolution.dart';
import '../../../jewellery/domain/jewellery_item.dart';
import '../../data/camera_scanner_service.dart';
import '../../data/scan_feedback.dart';
import '../../domain/scanner_service.dart';

/// The camera scanner, disposed when no screen is using it.
///
/// Releasing the camera matters: holding it open in the background drains
/// battery on a device that has to last a full shift.
final cameraScannerProvider = Provider.autoDispose<CameraScannerService>((ref) {
  final service = CameraScannerService();
  ref.onDispose(service.dispose);
  return service;
});

/// The RFID source.
///
/// Ships as a no-op until the retailer selects hardware; one class implements
/// [RfidScannerService] and this provider returns it instead. Nothing else in
/// the app changes.
final rfidScannerProvider = Provider<RfidScannerService>(
  (ref) => NoOpRfidScanner(),
);

final scanFeedbackProvider = Provider<ScanFeedback>(
  (ref) => const ScanFeedback(),
);

/// Whether any RFID reader is currently usable, for the status chip.
final rfidAvailableProvider = Provider<bool>(
  (ref) => ref.watch(rfidScannerProvider).isAvailable,
);

/// What a screen wants back from the scanner.
enum ScanIntent {
  /// Resolve one tag and open its passport.
  lookup,

  /// Collect many tags, resolve them to items, and return both to the caller
  /// as a [BulkScanResult].
  bulk,
}

/// What a bulk scan hands back.
///
/// [tags] is every distinct value scanned, in order. [resolution] is the
/// server's mapping of those values to items, or null when the lookup itself
/// failed (offline, timeout) and the operator chose to keep the raw scans —
/// consumers must still work from tags alone in that case.
class BulkScanResult {
  const BulkScanResult({required this.tags, this.resolution});

  final List<String> tags;
  final BulkTagResolution? resolution;

  bool get isEmpty => tags.isEmpty;

  /// The values a reconciliation should record: an item's canonical code
  /// where the scan resolved, otherwise the raw string. A barcode that maps to
  /// item `RNG-0042` then matches an expected list built from item codes.
  List<String> get canonicalTags => [
    for (final tag in tags) resolution?.itemFor(tag)?.itemCode ?? tag,
  ];

  /// Items by their canonical code, for names and ids in consumer rows.
  Map<String, JewelleryItem> get itemsByCode => {
    for (final entry in resolution?.resolved ?? const <ResolvedTag>[])
      entry.item.itemCode: entry.item,
  };
}

/// Arguments passed into the scan route.
class ScanRequest {
  const ScanRequest({
    this.intent = ScanIntent.lookup,
    this.title,
    this.expected = const {},
  });

  final ScanIntent intent;
  final String? title;

  /// Tags the caller expects, for reconciliation flows.
  final Set<String> expected;
}
