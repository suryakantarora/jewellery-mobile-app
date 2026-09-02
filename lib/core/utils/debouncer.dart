import 'dart:async';

/// Delays an action until input settles — used by every search field so a
/// four-character query does not fire four requests.
class Debouncer {
  Debouncer({this.duration = const Duration(milliseconds: 350)});

  final Duration duration;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Runs immediately and drops any pending call.
  void flush(void Function() action) {
    _timer?.cancel();
    action();
  }

  void cancel() => _timer?.cancel();

  bool get isPending => _timer?.isActive ?? false;

  void dispose() => _timer?.cancel();
}
