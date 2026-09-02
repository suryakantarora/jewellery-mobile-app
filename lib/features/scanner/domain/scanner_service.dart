import 'dart:async';

/// How a value reached the app.
enum ScanSource { camera, rfid, manual }

/// The symbology a camera scan came from.
///
/// Barcode and QR are one pipeline with a format filter, because that is how
/// every decoder actually works — the specification's separate
/// "BarcodeScanner / QRScanner" branches are honoured here rather than by
/// duplicating a service.
enum ScanFormat { qr, barcode, dataMatrix, rfid, manual, unknown }

/// One decoded value.
class ScanResult {
  const ScanResult({
    required this.rawValue,
    required this.source,
    this.format = ScanFormat.unknown,
    this.timestampMs,
  });

  final String rawValue;
  final ScanSource source;
  final ScanFormat format;
  final int? timestampMs;

  @override
  bool operator ==(Object other) =>
      other is ScanResult && other.rawValue == rawValue;

  @override
  int get hashCode => rawValue.hashCode;
}

/// What a scanner implementation can do, so the UI adapts without knowing which
/// hardware is attached.
class ScannerCapabilities {
  const ScannerCapabilities({
    this.torch = false,
    this.zoom = false,
    this.continuous = false,
    this.bulk = false,
  });

  final bool torch;
  final bool zoom;
  final bool continuous;
  final bool bulk;
}

/// The common interface for every scanning source.
///
/// Camera, RFID and manual entry all satisfy it, so a workflow can consume
/// scans without knowing where they came from.
abstract interface class ScannerService {
  Stream<ScanResult> get scans;
  ScannerCapabilities get capabilities;
  bool get isAvailable;

  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}

/// The RFID contract.
///
/// Left unimplemented on purpose. When the retailer selects hardware (Zebra,
/// Chainway, TSL and so on), one class implements this and registers itself —
/// no screen changes. Hardcoding a vendor SDK now would only have to be undone.
abstract interface class RfidScannerService implements ScannerService {
  Future<bool> connect();
  Future<void> disconnect();
  bool get isConnected;

  /// Read power, where the hardware exposes it. A warehouse sweep wants high
  /// power; a counter read wants low, so it does not pick up the next tray.
  Future<void> setPower(int level);
}

/// Ships until real hardware exists. Reports unavailable rather than pretending.
class NoOpRfidScanner implements RfidScannerService {
  @override
  Stream<ScanResult> get scans => const Stream.empty();

  @override
  ScannerCapabilities get capabilities => const ScannerCapabilities();

  @override
  bool get isAvailable => false;

  @override
  bool get isConnected => false;

  @override
  Future<bool> connect() async => false;

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> setPower(int level) async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

/// Normalises a raw scan into the value the backend expects.
///
/// A QR encoding a URL — `https://example.com/item/JW-000241` — must be reduced
/// to the code before `by-tag` is called, or every QR scan fails as not-found.
/// The rules live here rather than scattered through the UI.
class TagNormaliser {
  const TagNormaliser({this.urlPathSegment = 'item'});

  /// The path segment preceding a code when a QR encodes a link.
  final String urlPathSegment;

  static final _surroundingQuotes = RegExp(
    r'^[\u0022\u0027]+|[\u0022\u0027]+$',
  );
  static final _trailingWhitespace = RegExp(r'\s+$');

  String normalise(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return value;

    // Strip a URL wrapper, keeping the meaningful segment.
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme && uri.pathSegments.isNotEmpty) {
      final segments = uri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .toList(growable: false);
      final index = segments.indexOf(urlPathSegment);
      value = index >= 0 && index + 1 < segments.length
          ? segments[index + 1]
          : segments.last;
    }

    // Some encoders wrap values in quotes or leave trailing whitespace.
    value = value.replaceAll(_surroundingQuotes, '');
    value = value.replaceAll(_trailingWhitespace, '');

    return value;
  }
}
