import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../jewellery/data/jewellery_repository.dart';
import '../../../jewellery/domain/jewellery_item.dart';
import '../../../jewellery/presentation/providers/jewellery_providers.dart';
import '../../../jewellery/presentation/widgets/item_card.dart';
import '../../domain/warehouse_models.dart';
import '../providers/warehouse_providers.dart';
import '../../../jewellery/presentation/widgets/reference_gate.dart';

/// Contents of one storage location.
///
/// The bin hierarchy is listed as a directory rather than as a tree of items,
/// because **no endpoint assigns an item to a bin** — bins can be created and
/// listed, but nothing places stock in them. Until the backend adds a `binId`
/// on the item (or a bin-items endpoint), tray-level contents cannot be shown.
/// See BACKEND-GAPS.
final _locationItemsProvider = FutureProvider.autoDispose
    .family<List<JewelleryItem>, String>((ref, locationId) async {
      final page = await ref
          .watch(jewelleryRepositoryProvider)
          .search(ItemSearchFilters(locationId: locationId), size: 100);
      await ref
          .read(referenceDataProvider)
          .warmFor(page.content.map((item) => item.productId));
      return page.content;
    });

class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key, required this.locationId});

  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reference = ref.watch(referenceDataProvider);
    final location = reference.location(locationId);
    final items = ref.watch(_locationItemsProvider(locationId));
    final bins = ref.watch(binsProvider(locationId));

    return AppScaffold(
      title: location?.name ?? 'Location',
      showBranchBar: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_scanner),
          tooltip: context.l10n.actionScan,
          onPressed: () => context.push(AppRoutes.scan),
        ),
      ],
      body: ReferenceGate(
        child: AsyncValueView<List<JewelleryItem>>(
          value: items,
          onRetry: () => ref.invalidate(_locationItemsProvider(locationId)),
          isEmpty: (list) => list.isEmpty,
          empty: const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Nothing stored here',
            message: 'Items moved into this location will appear here.',
          ),
          data: (list) => ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${list.length}',
                              style: context.text.headlineMedium,
                            ),
                            Text(
                              'items stored',
                              style: context.text.bodySmall?.copyWith(
                                color: context.scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (location?.dualAuthorization ?? false)
                        const StatusBadge(
                          label: 'Dual authorisation',
                          tone: StatusTone.vault,
                        ),
                    ],
                  ),
                ),
              ),

              bins.maybeWhen(
                data: (binList) => binList.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: SectionCard(
                          title: 'Bins (${binList.length})',
                          icon: Icons.grid_view_outlined,
                          subtitle: 'Tap a bin to see what is stored in it',
                          child: Column(
                            children: [
                              for (final bin in binList) _BinTile(bin: bin),
                            ],
                          ),
                        ),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),

              const Divider(height: 1),
              for (final item in list)
                ItemCard(
                  item: item,
                  onTap: () {
                    ref.read(recentItemsProvider.notifier).record(item);
                    context.push(AppRoutes.itemDetailPath(item.id));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData iconFor(BinType type) => switch (type) {
    BinType.safe => Icons.lock_outline,
    BinType.tray => Icons.view_module_outlined,
    BinType.shelf => Icons.shelves,
    BinType.zone => Icons.map_outlined,
    BinType.bin || BinType.unknown => Icons.inventory_2_outlined,
  };
}

/// One bin, expanding to list the stock actually inside it.
///
/// Contents load only when opened. A vault can hold dozens of trays, and
/// fetching every tray's items to render a collapsed list would cost dozens of
/// requests for information nobody has asked to see yet.
class _BinTile extends ConsumerWidget {
  const _BinTile({required this.bin});

  final StorageBin bin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: EdgeInsets.zero,
      leading: Icon(VaultScreen.iconFor(bin.type), size: 20),
      title: Text('${bin.code} · ${bin.name}', style: context.text.bodyMedium),
      children: [
        Consumer(
          builder: (context, ref, _) => ref
              .watch(binItemsProvider(bin.id))
              .when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'Could not load this bin',
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.danger,
                    ),
                  ),
                ),
                data: (items) => items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          'Empty',
                          style: context.text.bodySmall?.copyWith(
                            color: context.scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (final item in items)
                            ItemCard(
                              item: item,
                              onTap: () => context.push(
                                AppRoutes.itemDetailPath(item.id),
                              ),
                            ),
                        ],
                      ),
              ),
        ),
      ],
    );
  }
}
