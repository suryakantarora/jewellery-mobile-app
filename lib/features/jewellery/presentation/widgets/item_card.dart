import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/settings/settings_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/data_display.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/jewellery_item.dart';
import '../providers/jewellery_providers.dart';
import 'item_photo.dart';

/// The item row used by search, inventory and pickers.
///
/// Weights are always three decimals with tabular figures so a column of them
/// reads straight down. Names come from the reference cache, which is why the
/// row can render them synchronously.
class ItemCard extends ConsumerWidget {
  const ItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.selected,
    this.dense = false,
  });

  final JewelleryItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Non-null puts the row in multi-select mode.
  final bool? selected;

  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reference = ref.watch(referenceDataProvider);
    final formatters = ref.watch(formattersProvider);
    final hideAmounts = ref.watch(hideAmountsProvider);

    final product = reference.cachedProduct(item.productId);
    final material = reference.materialLabel(item.metalId, item.purityId);
    final location = reference.location(item.currentLocationId);

    return Material(
      color: selected == true
          ? context.scheme.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: dense ? AppSpacing.sm : AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selected != null) ...[
                Checkbox(value: selected, onChanged: (_) => onTap?.call()),
                AppSpacing.wGapSm,
              ] else ...[
                _Thumbnail(item: item),
                AppSpacing.wGapMd,
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.itemCode,
                            style: AppTypography.mono(context, size: 13),
                          ),
                        ),
                        AppSpacing.wGapSm,
                        StatusBadge(
                          label: item.status.label,
                          tone: item.status.tone,
                          dense: true,
                        ),
                      ],
                    ),
                    AppSpacing.gapXxs,
                    Text(
                      product?.name ?? 'Product —',
                      style: context.text.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.gapXxs,
                    Text(
                      [
                        if (material.isNotEmpty) material,
                        formatters.weight(item.grossWeight),
                      ].join(' · '),
                      style: context.text.bodySmall?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                    ),
                    if (item.currentPrice != null) ...[
                      AppSpacing.gapXs,
                      HideableAmount(
                        hidden: hideAmounts,
                        child: Text(
                          formatters.money(item.currentPrice, item.currency),
                          style: AppTypography.numeric(context, size: 14),
                        ),
                      ),
                    ],
                    if (location != null) ...[
                      AppSpacing.gapXs,
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 12,
                            color: context.scheme.onSurfaceVariant,
                          ),
                          AppSpacing.wGapXs,
                          Flexible(
                            child: Text(
                              location.name,
                              style: context.text.labelSmall?.copyWith(
                                color: context.scheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder thumbnail.
///
/// No image field exists on the item, product or design responses — files are
/// uploaded generically and referenced by storage key, but nothing links a key
/// to an item. Rather than leave a grey box, the tile carries the category icon
/// and the metal's colour, which at least distinguishes a gold ring from a
/// silver chain at a glance.
class _Thumbnail extends ConsumerWidget {
  const _Thumbnail({required this.item});

  final JewelleryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reference = ref.watch(referenceDataProvider);
    final metal = reference.metal(item.metalId);

    final tint = switch (metal?.code) {
      'GOLD' => context.colors.gold,
      'SILVER' => context.colors.silver,
      'PLATINUM' => context.colors.platinumMetal,
      _ => context.scheme.primary,
    };

    final product = reference.cachedProduct(item.productId);
    final category = reference.category(product?.categoryId);

    // A real photograph beats a category glyph for picking one ring out of a
    // tray of near-identical ones. The glyph stays for the majority of stock
    // that has no picture yet.
    if (item.primaryImageKey != null) {
      return ItemPhoto(
        storageKey: item.primaryImageKey,
        size: AppSizes.listThumb,
        radius: AppRadius.sm,
        fallbackIcon: _iconFor(category?.code),
      );
    }

    return Container(
      width: AppSizes.listThumb,
      height: AppSizes.listThumb,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: tint.withValues(alpha: 0.3)),
      ),
      child: Icon(_iconFor(category?.code), size: 22, color: tint),
    );
  }

  static IconData _iconFor(String? categoryCode) => switch (categoryCode) {
    'RING' => Icons.circle_outlined,
    'NECK' || 'CHAIN' => Icons.linear_scale,
    'EARR' => Icons.blur_circular_outlined,
    'BANG' => Icons.data_usage,
    'PEND' => Icons.change_history,
    _ => Icons.diamond_outlined,
  };
}
