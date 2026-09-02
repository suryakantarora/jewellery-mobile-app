import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

/// A shimmering placeholder block.
///
/// Skeletons rather than spinners: on a list screen a spinner tells the user
/// nothing, while a skeleton communicates the shape of what is arriving and
/// keeps the layout from jumping when it does.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppRadius.xs,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.colors.shimmerBase,
      highlightColor: context.colors.shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.colors.shimmerBase,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// A placeholder shaped like the item card used across inventory and search.
class SkeletonListItem extends StatelessWidget {
  const SkeletonListItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(
            width: AppSizes.listThumb,
            height: AppSizes.listThumb,
            radius: AppRadius.sm,
          ),
          AppSpacing.wGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 120, height: 15),
                AppSpacing.gapSm,
                const SkeletonBox(width: double.infinity, height: 12),
                AppSpacing.gapXs,
                const SkeletonBox(width: 160, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A list of skeleton rows, used as the first-load state of any list screen.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const Divider(indent: AppSpacing.lg),
      itemBuilder: (_, __) => const SkeletonListItem(),
    );
  }
}

/// A placeholder shaped like a dashboard stat tile.
class SkeletonStatTile extends StatelessWidget {
  const SkeletonStatTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerLow,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: context.scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SkeletonBox(width: 80, height: 12),
          AppSpacing.gapMd,
          const SkeletonBox(width: 120, height: 22),
          AppSpacing.gapSm,
          const SkeletonBox(width: 60, height: 11),
        ],
      ),
    );
  }
}
