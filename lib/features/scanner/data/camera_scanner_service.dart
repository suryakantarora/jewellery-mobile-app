import 'dart:async';

import 'package:mobile_scanner/mobile_scanner.dart';

import '../domain/scanner_service.dart';

/// Camera-based barcode and QR scanning.
///
/// One implementation covers both symbologies — a decoder does not care which
/// it found, and neither does `GET /inventory/items/by-tag`, whose contract is
/// explicitly "RFID, QR, barcode or item code". The format is reported on the
/// result for display only.
class CameraScannerService implements ScannerService {
  CameraScannerService({TagNormaliser? normaliser})
    : _normaliser = normaliser ?? const TagNormaliser();

  final TagNormaliser _normaliser;
  final _controller = MobileScannerController(
    // Only the formats a jewellery tag actually uses. Narrowing the set makes
    // the decoder measurably faster, and this is the hottest path in the app.
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.dataMatrix,
    ],
    detectionSpeed: DetectionSpeed.normal,
    // Capped: full resolution slows decoding without improving hit rate on a
    // tag held 15cm from the lens.
    detectionTimeoutMs: 250,
  );

  MobileScannerController get controller => _controller;

  final _scans = StreamController<ScanResult>.broadcast();
  StreamSubscription<BarcodeCapture>? _subscription;
  bool _running = false;

  @override
  Stream<ScanResult> get scans => _scans.stream;

  @override
  ScannerCapabilities get capabilities => const ScannerCapabilities(
    torch: true,
    zoom: true,
    continuous: true,
    bulk: true,
  );

  @override
  bool get isAvailable => true;

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;

    _subscription = _controller.barcodes.listen((capture) {
      for (final barcode in capture.barcodes) {
        final raw = barcode.rawValue;
        if (raw == null || raw.isEmpty) continue;

        _scans.add(
          ScanResult(
            // A QR encoding a URL is reduced to the code here; without this
            // every such scan would resolve as not-found.
            rawValue: _normaliser.normalise(raw),
            source: ScanSource.camera,
            format: _formatOf(barcode.format),
            timestampMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
    });

    await _controller.start();
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    await _subscription?.cancel();
    _subscription = null;
    await _controller.stop();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _scans.close();
    await _controller.dispose();
  }

  Future<void> toggleTorch() => _controller.toggleTorch();

  static ScanFormat _formatOf(BarcodeFormat format) => switch (format) {
    BarcodeFormat.qrCode => ScanFormat.qr,
    BarcodeFormat.dataMatrix => ScanFormat.dataMatrix,
    BarcodeFormat.ean13 ||
    BarcodeFormat.ean8 ||
    BarcodeFormat.code128 ||
    BarcodeFormat.code39 => ScanFormat.barcode,
    _ => ScanFormat.unknown,
  };
}
