import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../../jewellery/data/jewellery_repository.dart';
import '../../../jewellery/domain/jewellery_item.dart';
import '../../../jewellery/presentation/providers/jewellery_providers.dart';
import '../../data/movement_repository.dart';
import '../../domain/movement.dart';

final movementRepositoryProvider = Provider<MovementRepository>(
  (ref) => MovementRepository(ref.watch(apiClientProvider)),
);

/// Which slice of the transfer list is showing.
///
/// Tabs are framed around the job a person came to do, not around statuses —
/// a dispatcher thinks "what am I sending", a receiver thinks "what is arriving".
enum TransferTab {
  incoming('Incoming'),
  outgoing('Outgoing'),
  all('All');

  const TransferTab(this.label);
  final String label;
}

final transferTabProvider =
    NotifierProvider<TransferTabController, TransferTab>(
      TransferTabController.new,
    );

class TransferTabController extends Notifier<TransferTab> {
  @override
  TransferTab build() => TransferTab.incoming;

  void set(TransferTab tab) => state = tab;
}

/// Status filter, applied on top of the tab.
final transferStatusFilterProvider =
    NotifierProvider<TransferStatusController, MovementStatus?>(
      TransferStatusController.new,
    );

class TransferStatusController extends Notifier<MovementStatus?> {
  @override
  MovementStatus? build() => null;

  void set(MovementStatus? status) => state = status;
}

/// The transfer list for the active tab.
///
/// The backend filters by a single location, not by branch, so "incoming" and
/// "outgoing" are expressed through the branch's locations. With no location
/// selected the list falls back to a status-only query, which is still scoped
/// server-side by the caller's branch access.
final transferListProvider = FutureProvider.autoDispose<List<Movement>>((
  ref,
) async {
  final tab = ref.watch(transferTabProvider);
  final status = ref.watch(transferStatusFilterProvider);
  final repository = ref.watch(movementRepositoryProvider);

  // Rebuild when the branch changes, so one branch's transfers never linger.
  ref.watch(currentBranchProvider);

  final page = await repository.search(
    status:
        status ??
        // The default per tab is the status that tab exists to act on.
        switch (tab) {
          TransferTab.incoming => MovementStatus.dispatched,
          TransferTab.outgoing => null,
          TransferTab.all => null,
        },
    size: 50,
  );

  final locations = ref
      .read(referenceDataProvider)
      .locations
      .map((location) => location.id)
      .toSet();

  if (locations.isEmpty || tab == TransferTab.all) return page.content;

  return page.content
      .where((movement) {
        return switch (tab) {
          TransferTab.incoming => locations.contains(movement.toLocationId),
          TransferTab.outgoing => locations.contains(movement.fromLocationId),
          TransferTab.all => true,
        };
      })
      .toList(growable: false);
});

final movementDetailProvider = FutureProvider.autoDispose
    .family<Movement, String>(
      (ref, id) => ref.watch(movementRepositoryProvider).byId(id),
    );

/// Items eligible to be moved out of a location.
///
/// Only `AVAILABLE` stock can be picked: reserved, in-transit and sold items
/// are not the dispatcher's to move, and the backend would reject them anyway.
final transferrableItemsProvider = FutureProvider.autoDispose
    .family<List<JewelleryItem>, String>((ref, locationId) async {
      final page = await ref
          .watch(jewelleryRepositoryProvider)
          .search(
            ItemSearchFilters(
              branchId: ref.watch(currentBranchProvider)?.id,
              locationId: locationId,
              status: ItemStatus.available,
            ),
            size: 100,
          );
      return page.content;
    });
