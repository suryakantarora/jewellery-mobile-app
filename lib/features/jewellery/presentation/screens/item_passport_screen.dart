import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/permissions.dart';
import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/settings/settings_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_timeline.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/data_display.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/jewellery_item.dart';
import '../providers/jewellery_providers.dart';
import '../widgets/item_action_bar.dart';
import '../widgets/item_photo.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../warehouse/domain/warehouse_models.dart';
import '../../../warehouse/presentation/providers/warehouse_providers.dart';

/// The Digital Jewellery Passport.
///
/// Sections follow the specification: product, metal, gemstones, certificate,
/// location, identifiers, lifecycle and history. The lifecycle timeline is
/// rendered from the backend's real `LifecycleEvent` list rather than a
/// hardcoded ladder — real items skip and repeat steps.
class ItemPassportScreen extends ConsumerWidget {
  const ItemPassportScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passport = ref.watch(itemPassportProvider(itemId));

    // Every name on this screen comes from the reference cache, which is a
    // mutable service behind a plain Provider: filling its maps notifies
    // nobody. A passport built mid-prefetch therefore keeps whatever was
    // missing at that moment for the life of the route.
    //
    // That is not hypothetical. Purities load in a second wave, after the
    // metals they hang off, so scanning an item straight after sign-in showed
    // "Metal: Gold" beside "Purity: —" and never recovered. Waiting for the
    // cache costs a few frames and removes the whole class of bug.
    final reference = ref.watch(referenceDataReadyProvider);

    return Scaffold(
      body: reference.isLoading
          ? const Center(child: CircularProgressIndicator())
          : AsyncValueView<ItemPassport>(
              value: passport,
              onRetry: () => ref.invalidate(itemPassportProvider(itemId)),
              loading: const Center(child: CircularProgressIndicator()),
              data: (data) => _PassportBody(passport: data),
            ),
      // The action bar is driven by allowedTransitions ∩ permissions, so it
      // only appears once the item itself has loaded.
      bottomNavigationBar: passport.maybeWhen(
        data: (data) => ItemActionBar(
          item: data.item,
          onChanged: () => ref.invalidate(itemPassportProvider(itemId)),
        ),
        orElse: () => null,
      ),
    );
  }
}

class _PassportBody extends ConsumerWidget {
  const _PassportBody({required this.passport});

  final ItemPassport passport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = passport.item;
    final reference = ref.watch(referenceDataProvider);
    final formatters = ref.watch(formattersProvider);
    final permissions = ref.watch(permissionsProvider);
    final hideAmounts = ref.watch(hideAmountsProvider);

    final product = reference.cachedProduct(item.productId);
    final design = reference.cachedDesign(item.designId);
    final category = reference.category(product?.categoryId);
    final type = reference.productType(product?.productTypeId);
    final metal = reference.metal(item.metalId);
    final purity = reference.purity(item.purityId);
    final location = reference.location(item.currentLocationId);

    // Cost is a commercial secret: a salesperson sees price, never cost.
    final canSeeCost =
        permissions.has(Permission.reportView) ||
        permissions.has(Permission.financeView);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 200,
          flexibleSpace: FlexibleSpaceBar(
            background: _PassportHeader(item: item),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: context.l10n.actionRetry,
              onPressed: () => ref.invalidate(itemPassportProvider(item.id)),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.huge,
          ),
          sliver: SliverList.list(
            children: [
              // Identity block
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.itemCode,
                          style: AppTypography.mono(context, size: 16),
                        ),
                        AppSpacing.gapXs,
                        Text(
                          product?.name ?? 'Product —',
                          style: context.text.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.wGapMd,
                  StatusBadge(label: item.status.label, tone: item.status.tone),
                ],
              ),
              if (item.currentPrice != null) ...[
                AppSpacing.gapMd,
                HideableAmount(
                  hidden: hideAmounts,
                  child: Text(
                    formatters.money(item.currentPrice, item.currency),
                    style: AppTypography.numeric(context, size: 26),
                  ),
                ),
              ],
              if (item.isReserved && item.reservedUntil != null) ...[
                AppSpacing.gapMd,
                _Notice(
                  icon: Icons.lock_clock,
                  tone: context.colors.warning,
                  message:
                      'Reserved until ${formatters.dateTime(item.reservedUntil)}',
                ),
              ],
              AppSpacing.gapXl,

              ExpandableSection(
                title: 'Product',
                icon: Icons.category_outlined,
                initiallyExpanded: true,
                child: Column(
                  children: [
                    KeyValueRow(label: 'SKU', value: product?.sku ?? '—'),
                    KeyValueRow(
                      label: 'Design',
                      value: design == null
                          ? '—'
                          : '${design.designCode} · ${design.name}',
                    ),
                    KeyValueRow(
                      label: 'Category',
                      value: category?.name ?? '—',
                    ),
                    KeyValueRow(label: 'Type', value: type?.name ?? '—'),
                  ],
                ),
              ),
              AppSpacing.gapMd,

              ExpandableSection(
                title: 'Metal & weight',
                icon: Icons.workspaces_outlined,
                initiallyExpanded: true,
                child: Column(
                  children: [
                    KeyValueRow(label: 'Metal', value: metal?.name ?? '—'),
                    KeyValueRow(
                      label: 'Purity',
                      value: purity == null
                          ? '—'
                          : '${purity.code} · ${purity.name}',
                    ),
                    KeyValueRow(
                      label: 'Gross weight',
                      value: formatters.weight(item.grossWeight),
                      numeric: true,
                    ),
                    KeyValueRow(
                      label: 'Net metal weight',
                      value: formatters.weight(item.netMetalWeight),
                      numeric: true,
                    ),
                    KeyValueRow(
                      label: 'Stone weight',
                      value: formatters.weight(item.stoneWeight),
                      numeric: true,
                    ),
                    if (item.hallmarkNumber != null)
                      KeyValueRow(
                        label: 'Hallmark',
                        value: item.hallmarkNumber!,
                      ),
                  ],
                ),
              ),
              AppSpacing.gapMd,

              ExpandableSection(
                title: 'Gemstones (${passport.stones.length})',
                icon: Icons.diamond_outlined,
                child: passport.stones.isEmpty
                    ? Text(
                        'No stones recorded on this item.',
                        style: context.text.bodySmall?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      )
                    : Column(
                        children: [
                          KeyValueRow(
                            label: 'Stone count',
                            value: '${item.stoneCount}',
                            numeric: true,
                          ),
                          KeyValueRow(
                            label: 'Total carat',
                            value: formatters.carat(item.totalCarat),
                            numeric: true,
                          ),
                          const Divider(height: AppSpacing.xxl),
                          for (final stone in passport.stones)
                            _StoneRow(stone: stone, formatters: formatters),
                        ],
                      ),
              ),
              AppSpacing.gapMd,

              ExpandableSection(
                title: 'Location',
                icon: Icons.place_outlined,
                initiallyExpanded: true,
                child: Column(
                  children: [
                    KeyValueRow(
                      label: 'Branch',
                      value: ref.watch(currentBranchProvider)?.name ?? '—',
                    ),
                    KeyValueRow(
                      label: 'Location',
                      value: location?.name ?? '—',
                    ),
                    if (location != null)
                      KeyValueRow(label: 'Type', value: location.type.label),
                    _BinRow(item: item),
                    if (location?.dualAuthorization ?? false)
                      KeyValueRow(
                        label: 'Controls',
                        value: '',
                        valueWidget: const StatusBadge(
                          label: 'Dual authorisation',
                          tone: StatusTone.vault,
                          dense: true,
                        ),
                      ),
                  ],
                ),
              ),
              AppSpacing.gapMd,

              ExpandableSection(
                title: 'Identifiers',
                icon: Icons.qr_code_2,
                child: Column(
                  children: [
                    _CopyableRow(label: 'RFID', value: item.rfidTag),
                    _CopyableRow(label: 'QR code', value: item.qrCode),
                    _CopyableRow(label: 'Barcode', value: item.barcode),
                  ],
                ),
              ),
              AppSpacing.gapMd,

              if (canSeeCost) ...[
                ExpandableSection(
                  title: 'Cost',
                  icon: Icons.account_balance_wallet_outlined,
                  child: Column(
                    children: [
                      KeyValueRow(
                        label: 'Purchase cost',
                        value: formatters.money(
                          item.purchaseCost,
                          item.currency,
                        ),
                        numeric: true,
                      ),
                      KeyValueRow(
                        label: 'Making cost',
                        value: formatters.money(item.makingCost, item.currency),
                        numeric: true,
                      ),
                      KeyValueRow(
                        label: 'Total cost',
                        value: formatters.money(item.totalCost, item.currency),
                        numeric: true,
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapMd,
              ],

              SectionCard(
                title: 'Lifecycle',
                icon: Icons.timeline,
                subtitle: '${passport.history.length} events',
                child: passport.history.isEmpty
                    ? Text(
                        'No lifecycle events recorded.',
                        style: context.text.bodySmall?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      )
                    : AppTimeline(
                        formatTimestamp: formatters.relative,
                        events: [
                          // Newest first: the current state is what staff
                          // check, and history is read backwards from it.
                          for (final event in passport.history.reversed)
                            TimelineEvent(
                              title: event.label,
                              subtitle: event.notes,
                              actor: event.performedBy,
                              timestamp: event.occurredAt,
                              tone: event.tone,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Collapsing header. No image exists on any response, so this is a tinted
/// gradient carrying the metal's colour rather than a grey placeholder box.
class _PassportHeader extends ConsumerWidget {
  const _PassportHeader({required this.item});

  final JewelleryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metal = ref.watch(referenceDataProvider).metal(item.metalId);
    final tint = switch (metal?.code) {
      'GOLD' => context.colors.gold,
      'SILVER' => context.colors.silver,
      'PLATINUM' => context.colors.platinumMetal,
      _ => context.scheme.primary,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint.withValues(alpha: 0.28), context.scheme.surface],
        ),
      ),
      // A photographed piece shows itself; the metal-tinted gradient stays as
      // the backdrop so an item without a picture still reads as jewellery
      // rather than as a failed image.
      child: item.primaryImageKey == null
          ? Center(
              child: Icon(
                Icons.diamond_outlined,
                size: 64,
                color: tint.withValues(alpha: 0.55),
              ),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: ItemPhoto(
                  storageKey: item.primaryImageKey,
                  size: 150,
                  radius: 16,
                ),
              ),
            ),
    );
  }
}

class _StoneRow extends StatelessWidget {
  const _StoneRow({required this.stone, required this.formatters});

  final ItemStone stone;
  final dynamic formatters;

  @override
  Widget build(BuildContext context) {
    final detail = [
      stone.shape,
      if (stone.carat != null) formatters.carat(stone.carat) as String,
      stone.colour,
      stone.clarity,
      stone.cut,
    ].whereType<String>().where((part) => part.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.diamond, size: 16, color: context.colors.diamond),
          AppSpacing.wGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stone.stoneType ?? 'Stone',
                  style: context.text.titleSmall,
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: context.text.bodySmall?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (stone.count > 1)
            Text('×${stone.count}', style: context.text.labelMedium),
        ],
      ),
    );
  }
}

/// An identifier that can be copied — staff read these aloud across a counter.
class _CopyableRow extends StatelessWidget {
  const _CopyableRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return KeyValueRow(
      label: label,
      value: value ?? '—',
      valueWidget: value == null
          ? null
          : Text(value!, style: AppTypography.mono(context)),
      onTap: value == null
          ? null
          : () {
              Clipboard.setData(ClipboardData(text: value!));
              showAppSnackBar(
                context,
                message: '$label copied',
                tone: SnackTone.success,
              );
            },
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.tone,
    required this.message,
  });

  final IconData icon;
  final Color tone;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: tone.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tone),
          AppSpacing.wGapSm,
          Expanded(child: Text(message, style: context.text.bodySmall)),
        ],
      ),
    );
  }
}

/// The item's storage bin, with a way to change it.
///
/// Shown even when the item is in no bin: "not assigned" is the state most
/// stock is in, and hiding the row would leave staff with no way to put a piece
/// away from the screen they are already looking at.
class _BinRow extends ConsumerWidget {
  const _BinRow({required this.item});

  final JewelleryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationId = item.currentLocationId;
    final canAssign = ref
        .watch(permissionsProvider)
        .has(Permission.inventoryAdjust);
    final bins = locationId == null
        ? const AsyncValue<List<StorageBin>>.data([])
        : ref.watch(binsProvider(locationId));

    final current = bins.valueOrNull
        ?.where((bin) => bin.id == item.binId)
        .firstOrNull;

    return KeyValueRow(
      label: 'Bin',
      value: '',
      valueWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            current == null
                ? (item.binId == null ? 'Not assigned' : '—')
                : '${current.code} · ${current.name}',
            style: context.text.bodyMedium?.copyWith(
              color: item.binId == null
                  ? context.scheme.onSurfaceVariant
                  : null,
            ),
          ),
          if (canAssign && (bins.valueOrNull?.isNotEmpty ?? false)) ...[
            AppSpacing.wGapSm,
            InkWell(
              onTap: () => _pickBin(context, ref, bins.valueOrNull ?? const []),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: context.scheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickBin(
    BuildContext context,
    WidgetRef ref,
    List<StorageBin> bins,
  ) async {
    final chosen = await showModalBottomSheet<Object?>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('Not assigned'),
              onTap: () => Navigator.pop(sheetContext, _clearBin),
            ),
            const Divider(height: 1),
            for (final bin in bins)
              ListTile(
                leading: Icon(
                  bin.id == item.binId ? Icons.check : Icons.inbox_outlined,
                ),
                title: Text('${bin.code} · ${bin.name}'),
                onTap: () => Navigator.pop(sheetContext, bin.id),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;

    try {
      await ref
          .read(jewelleryRepositoryProvider)
          .assignBin(item.id, chosen == _clearBin ? null : chosen as String);
      ref.invalidate(itemPassportProvider(item.id));
      // The bin the piece left and the one it joined are both now wrong.
      ref.invalidate(binItemsProvider);
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  /// Distinguishes "chose to clear" from "dismissed the sheet", which a plain
  /// null return could not.
  static const _clearBin = Object();
}
