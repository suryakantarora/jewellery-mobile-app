import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Collect many tags and return them to the caller.
  bulk,
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
