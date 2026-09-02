import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// What the app currently believes about its connection.
enum ConnectivityState {
  online('Online'),

  /// No transport at all.
  offline("You're offline"),

  /// Transport is up but the API is unreachable or very slow.
  ///
  /// This is the common case in a showroom: wifi that associates and resolves
  /// but cannot reach the server. Treating it as "online" is what produces
  /// spinners that never resolve.
  degraded('Connection problems'),

  syncing('Syncing'),
  syncFailed('Sync failed');

  const ConnectivityState(this.label);
  final String label;

  bool get canReachBackend => this == ConnectivityState.online;
}

/// Tracks connectivity, distinguishing "no network" from "network but no API".
///
/// `connectivity_plus` alone reports the transport, which is not enough — so a
/// cheap reachability probe against the API decides between offline and
/// degraded.
class ConnectivityController extends Notifier<ConnectivityState> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _probeTimer;

  @override
  ConnectivityState build() {
    final connectivity = Connectivity();

    _subscription = connectivity.onConnectivityChanged.listen(_onTransport);
    unawaited(connectivity.checkConnectivity().then(_onTransport));

    ref.onDispose(() {
      _subscription?.cancel();
      _probeTimer?.cancel();
    });

    return ConnectivityState.online;
  }

  void _onTransport(List<ConnectivityResult> results) {
    final hasTransport = results.any(
      (result) => result != ConnectivityResult.none,
    );

    if (!hasTransport) {
      _probeTimer?.cancel();
      state = ConnectivityState.offline;
      return;
    }

    unawaited(probe());
  }

  /// Confirms the API is actually reachable.
  ///
  /// Uses a short timeout: the point is to find out quickly whether requests
  /// will work, not to wait out a slow one.
  Future<void> probe() async {
    try {
      final dio = ref.read(dioProvider);
      await dio.get<dynamic>(
        '/auth/me',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
          // A 401 still proves the server answered, which is all this asks.
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      state = ConnectivityState.online;
    } on Object {
      state = ConnectivityState.degraded;
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _probeTimer?.cancel();
    _probeTimer = Timer(const Duration(seconds: 20), probe);
  }

  void reportSyncing() => state = ConnectivityState.syncing;
  void reportSyncFailed() => state = ConnectivityState.syncFailed;
}

final connectivityProvider =
    NotifierProvider<ConnectivityController, ConnectivityState>(
      ConnectivityController.new,
    );

final isOnlineProvider = Provider<bool>(
  (ref) => ref.watch(connectivityProvider).canReachBackend,
);
