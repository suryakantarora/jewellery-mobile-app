import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/storage/local_store.dart';
import '../../../scanner/domain/scan_session.dart';
import '../../data/warehouse_repository.dart';
import '../../domain/warehouse_models.dart';
import '../../../jewellery/domain/jewellery_item.dart';
import '../../../jewellery/presentation/providers/jewellery_providers.dart';

final warehouseRepositoryProvider = Provider<WarehouseRepository>(
  (ref) => WarehouseRepository(
    ref.watch(apiClientProvider),
    offlineGuard: ref.watch(offlineGuardProvider),
  ),
);

final stockCountListProvider = FutureProvider.autoDispose<List<StockCount>>((
  ref,
) async {
  final branch = ref.watch(currentBranchProvider);
  final page = await ref
      .watch(warehouseRepositoryProvider)
      .counts(branchId: branch?.id, size: 50);
  return page.content;
});

final stockCountDetailProvider = FutureProvider.autoDispose
    .family<StockCount, String>(
      (ref, id) => ref.watch(warehouseRepositoryProvider).byId(id),
    );

final binsProvider = FutureProvider.autoDispose
    .family<List<StorageBin>, String>(
      (ref, locationId) =>
          ref.watch(warehouseRepositoryProvider).bins(locationId),
    );

/// Persists an in-progress count across an app kill.
///
/// A 250-item vault count is a thirty-minute job. Losing it because the OS
/// reclaimed memory would be worse than not offering the workflow at all, so
/// every scan is written through to local storage immediately.
class StockCountSessionStore {
  StockCountSessionStore(this._store);

  final LocalStore _store;

  static String _key(String countId) => 'stockcount.session.$countId';

  ScanSession? restore(String countId, Set<String> expected) {
    final raw = _store.getString(_key(countId));
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      // Expected always comes from the server, never from the cached copy —
      // the count could have been amended while the app was closed.
      return ScanSession.fromJson({
        'expected': expected.toList(),
        'scanned': decoded['scanned'] ?? const <String>[],
      });
    } on FormatException {
      return null;
    }
  }

  Future<void> save(String countId, ScanSession session) =>
      _store.setString(_key(countId), jsonEncode({'scanned': session.scanned}));

  Future<void> clear(String countId) => _store.remove(_key(countId));
}

final stockCountSessionStoreProvider = Provider<StockCountSessionStore>(
  (ref) => StockCountSessionStore(ref.watch(localStoreProvider)),
);

/// The stock stored in one bin.
///
/// `autoDispose` because a tray's contents change as soon as anyone moves a
/// piece, and the list is only ever shown while a bin is expanded.
final binItemsProvider = FutureProvider.autoDispose
    .family<List<JewelleryItem>, String>((ref, binId) async {
      final page = await ref.watch(jewelleryRepositoryProvider).inBin(binId);
      return page.content;
    });
