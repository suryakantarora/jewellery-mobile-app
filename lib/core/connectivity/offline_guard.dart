import '../connectivity/connectivity_controller.dart';
import '../errors/app_exception.dart';

/// Refuses a mutating call while offline.
///
/// The specification is explicit that critical financial and inventory
/// operations must **not** be queued for later replay unless the backend has an
/// idempotent offline design — and it does not. Only three endpoints accept
/// `X-Idempotency-Key`, and there is no reconciliation mechanism, so replaying
/// a transfer an hour later would create phantom stock.
///
/// So this fails fast with a clear message instead of pretending to succeed.
/// Every mutating repository call routes through here, which is what stops one
/// feature quietly inventing its own offline queue later.
class OfflineGuard {
  /// A guard over a fixed state. Used in tests and wherever a snapshot is fine.
  const OfflineGuard(ConnectivityState state) : _state = state, _read = null;

  /// A guard that consults [read] on every call.
  ///
  /// This is what the provider hands to repositories: the guard object never
  /// changes identity when connectivity flips, so a repository provider that
  /// depends on it is not rebuilt — and every `FutureProvider` watching that
  /// repository is not re-fetched — each time the wifi blinks.
  const OfflineGuard.reading(ConnectivityState Function() read)
    : _read = read,
      _state = null;

  final ConnectivityState? _state;
  final ConnectivityState Function()? _read;

  ConnectivityState get _current => _read?.call() ?? _state!;

  /// Runs [action], or throws [OfflineActionException] if the backend is
  /// unreachable.
  Future<T> run<T>(Future<T> Function() action) async {
    if (!_current.canReachBackend) {
      throw const OfflineActionException();
    }
    return action();
  }

  bool get allowsMutation => _current.canReachBackend;

  /// Operations that must never be queued offline, for reference at call sites
  /// and in review.
  static const neverQueued = <String>[
    'sale',
    'payment',
    'transfer submit / dispatch / receive',
    'goods receipt',
    'exchange or buyback step',
    'approval of anything',
    'reservation',
    'item status change',
    'stock count submit',
    'repair status change',
  ];

  /// The workflows that *are* safe to accumulate locally.
  ///
  /// All three share one property: no server state changes until a single
  /// atomic submit, so there is nothing to reconcile and nothing to replay.
  static const safeToAccumulateLocally = <String>[
    'stock count scanning (submits once)',
    'transfer receiving reconciliation (submits once)',
    'goods receipt draft (submits once)',
  ];
}
