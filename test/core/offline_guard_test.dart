import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_erp/core/connectivity/connectivity_controller.dart';
import 'package:jewellery_erp/core/connectivity/offline_guard.dart';
import 'package:jewellery_erp/core/errors/app_exception.dart';

void main() {
  group('OfflineGuard', () {
    test('runs the action when the backend is reachable', () async {
      const guard = OfflineGuard(ConnectivityState.online);
      final result = await guard.run(() async => 'done');
      expect(result, 'done');
    });

    test('refuses while offline rather than queueing', () async {
      // The backend has no idempotent offline design — only three endpoints
      // accept an idempotency key, and nothing reconciles a replay. Queuing a
      // transfer for later would create phantom stock, so the app fails fast.
      const guard = OfflineGuard(ConnectivityState.offline);

      expect(
        () => guard.run(() async => 'should not run'),
        throwsA(isA<OfflineActionException>()),
      );
    });

    test('refuses when the network is up but the API is unreachable', () async {
      // The showroom case: wifi associates and resolves, but the server cannot
      // be reached. Treating this as online is what produces spinners that
      // never resolve and mutations that silently fail.
      const guard = OfflineGuard(ConnectivityState.degraded);

      expect(
        () => guard.run(() async => 'should not run'),
        throwsA(isA<OfflineActionException>()),
      );
      expect(guard.allowsMutation, isFalse);
    });

    test('the action is never invoked when refused', () async {
      const guard = OfflineGuard(ConnectivityState.offline);
      var invoked = false;

      try {
        await guard.run(() async {
          invoked = true;
          return null;
        });
      } on OfflineActionException {
        // Expected.
      }

      expect(invoked, isFalse);
    });

    test('an offline refusal is distinct from a transport failure', () {
      // A user needs to know "this needs a connection", not "the request
      // failed" — one is actionable, the other invites a pointless retry.
      const offline = OfflineActionException();
      const network = NetworkException();

      expect(offline, isNot(isA<NetworkException>()));
      expect(network, isNot(isA<OfflineActionException>()));
      expect(offline.message, contains('needs a connection'));
    });
  });

  group('Connectivity states', () {
    test('only online permits reaching the backend', () {
      expect(ConnectivityState.online.canReachBackend, isTrue);
      for (final state in ConnectivityState.values) {
        if (state == ConnectivityState.online) continue;
        expect(
          state.canReachBackend,
          isFalse,
          reason: '${state.name} must not be treated as reachable',
        );
      }
    });

    test('the four spec states are all modelled', () {
      // ONLINE / OFFLINE / SYNCING / SYNC FAILED, plus degraded.
      final names = ConnectivityState.values.map((s) => s.name).toSet();
      expect(names, containsAll(['online', 'offline', 'syncing', 'syncFailed']));
    });
  });

  group('Offline policy is documented in code', () {
    test('critical operations are listed as never queued', () {
      expect(OfflineGuard.neverQueued, contains('sale'));
      expect(OfflineGuard.neverQueued, contains('payment'));
      expect(
        OfflineGuard.neverQueued,
        contains('transfer submit / dispatch / receive'),
      );
      expect(OfflineGuard.neverQueued, contains('approval of anything'));
    });

    test('the safe local-accumulation workflows all submit once', () {
      // Each is safe precisely because no server state changes until a single
      // atomic submit — nothing to reconcile, nothing to replay.
      for (final workflow in OfflineGuard.safeToAccumulateLocally) {
        expect(workflow, contains('submits once'));
      }
    });
  });
}
