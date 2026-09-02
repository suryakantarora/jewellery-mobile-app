import 'package:flutter/foundation.dart';

/// Severity levels, ordered.
enum LogLevel { debug, info, warn, error }

/// Application logger.
///
/// Redaction is the point: tokens, passwords and document numbers must never
/// reach a log sink, a crash report or a support bundle. Release builds keep
/// warnings and errors only.
class AppLogger {
  AppLogger({
    this.minimumLevel = kReleaseMode ? LogLevel.warn : LogLevel.debug,
  });

  final LogLevel minimumLevel;

  static final _redactedKeys = <String>{
    'authorization',
    'password',
    'currentpassword',
    'newpassword',
    'accesstoken',
    'refreshtoken',
    'token',
    'documentnumber',
    'idnumber',
    'secret',
    'apikey',
  };

  /// In-memory ring buffer, exportable from Settings → Diagnostics for support.
  /// Never uploaded automatically.
  final List<String> _buffer = <String>[];
  static const _bufferLimit = 300;

  List<String> get recentEntries => List.unmodifiable(_buffer);

  void debug(String message, {Object? context}) =>
      _log(LogLevel.debug, message, context);

  void info(String message, {Object? context}) =>
      _log(LogLevel.info, message, context);

  void warn(String message, {Object? context}) =>
      _log(LogLevel.warn, message, context);

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, error);
    if (!kReleaseMode && stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  void _log(LogLevel level, String message, Object? context) {
    if (level.index < minimumLevel.index) return;

    final line = StringBuffer('[${level.name.toUpperCase()}] $message');
    if (context != null) line.write(' | ${redact(context)}');

    final entry = line.toString();
    _buffer.add(entry);
    if (_buffer.length > _bufferLimit) _buffer.removeAt(0);

    if (!kReleaseMode) debugPrint(entry);
  }

  /// Replaces the value of any sensitive key, at any depth.
  static Object? redact(Object? value) {
    if (value is Map) {
      return value.map((key, inner) {
        final normalised = key.toString().toLowerCase().replaceAll('_', '');
        if (_redactedKeys.contains(normalised)) return MapEntry(key, '***');
        return MapEntry(key, redact(inner));
      });
    }
    if (value is List) return value.map(redact).toList();
    return value;
  }
}
