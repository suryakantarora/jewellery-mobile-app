import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/extensions/widget_extensions.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../jewellery/presentation/providers/jewellery_providers.dart';
import '../../../jewellery/presentation/widgets/item_photo.dart';
import '../../domain/catalogue_item.dart';
import '../providers/catalogue_providers.dart';

/// The screen a salesperson turns around and hands to a customer.
///
/// Everything internal is absent by construction: the endpoint behind it
/// returns no cost, supplier, location or bin, so there is nothing here to
/// accidentally reveal. What is left is what a customer came to see — the
/// piece, what it is made of, and what it costs.
///
/// Deliberately image-led. A list of codes and weights is how staff find
/// stock; a customer chooses with their eyes.
class CatalogueScreen extends ConsumerWidget {
  const CatalogueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(catalogueProvider);
    final filters = ref.watch(catalogueFiltersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogue'),
        actions: [
          if (!filters.isEmpty)
            TextButton(
              onPressed: () =>
                  ref.read(catalogueFiltersProvider.notifier).clear(),
              child: Text(context.l10n.actionClear),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: AppSearchField(
              hint: 'Search the collection…',
              debounce: ref.watch(appConfigProvider).searchDebounce,
              onChanged: (value) =>
                  ref.read(catalogueFiltersProvider.notifier).setSearch(value),
            ),
          ),
          const _CategoryBar(),
          Expanded(
            child: AsyncValueView<List<CatalogueItem>>(
              value: items,
              onRetry: () => ref.invalidate(catalogueProvider),
              isEmpty: (list) => list.isEmpty,
              empty: const EmptyState(
                icon: Icons.diamond_outlined,
                title: 'Nothing to show yet',
                message: 'No available pieces match this selection.',
              ),
              data: (list) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(catalogueProvider),
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xxxl,
                  ),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    // Two columns on a phone, more on a tablet held out to a
                    // customer, without a breakpoint to maintain.
                    maxCrossAxisExtent: 260,
                    mainAxisSpacing: AppSpacing.lg,
                    crossAxisSpacing: AppSpacing.lg,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) => _CatalogueTile(
                    item: list[index],
                  ).entrance(index: index.clamp(0, 8)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Category chips, drawn from the reference cache the rest of the app uses.
class _CategoryBar extends ConsumerWidget {
  const _CategoryBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(referenceDataProvider).categories;
    if (categories.isEmpty) return const SizedBox.shrink();

    final selected = ref.watch(catalogueFiltersProvider).categoryId;
    final controller = ref.read(catalogueFiltersProvider.notifier);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(category.name),
                selected: selected == category.id,
                onSelected: (isSelected) =>
                    controller.setCategory(isSelected ? category.id : null),
              ),
            ),
        ],
      ),
    );
  }
}

class _CatalogueTile extends ConsumerWidget {
  const _CatalogueTile({required this.item});

  final CatalogueItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatters = ref.watch(formattersProvider);

    return InkWell(
      borderRadius: AppRadius.cardRadius,
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _CatalogueDetail(item: item),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadius.cardRadius,
              child: SizedBox.expand(
                child: ItemPhoto(
                  storageKey: item.displayImageKey,
                  size: 260,
                  radius: AppRadius.md,
                ),
              ),
            ),
          ),
          AppSpacing.gapSm,
          Text(
            item.productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            item.material,
            style: context.text.labelSmall?.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.gapXs,
          Text(
            // "Ask in store" rather than a zero: a missing metal rate is not a
            // free ring, and a customer must never be shown a price the shop
            // cannot honour.
            item.price == null
                ? 'Ask in store'
                : formatters.money(item.price, item.currency),
            style: context.text.titleSmall?.copyWith(
              color: context.scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The full piece, shown large.
class _CatalogueDetail extends ConsumerWidget {
  const _CatalogueDetail({required this.item});

  final CatalogueItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatters = ref.watch(formattersProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: ItemPhoto(
                storageKey: item.displayImageKey,
                size: 240,
                radius: AppRadius.lg,
              ),
            ),
            AppSpacing.gapXl,
            Text(item.productName, style: context.text.headlineSmall),
            AppSpacing.gapXs,
            Text(
              [
                item.categoryName,
                item.typeName,
              ].whereType<String>().join(' · '),
              style: context.text.bodyMedium?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
            AppSpacing.gapLg,
            Text(
              item.price == null
                  ? 'Ask in store'
                  : formatters.money(item.price, item.currency),
              style: context.text.headlineMedium?.copyWith(
                color: context.scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            AppSpacing.gapXl,
            _Spec(label: 'Metal', value: item.material),
            if (item.purityName != null)
              _Spec(label: 'Purity', value: item.purityName!),
            _Spec(label: 'Weight', value: formatters.weight(item.grossWeight)),
            if (item.stoneCount > 0)
              _Spec(
                label: 'Stones',
                value:
                    '${item.stoneCount}'
                    '${item.totalCarat == null ? '' : ' · ${item.totalCarat} ct'}',
              ),
            // A hallmark is the independent guarantee of purity, so it belongs
            // in front of a customer rather than buried in an internal record.
            if (item.hallmarkNumber != null)
              _Spec(label: 'Hallmark', value: item.hallmarkNumber!),
          ],
        ),
      ),
    );
  }
}

class _Spec extends StatelessWidget {
  const _Spec({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: context.text.bodyMedium?.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: context.text.bodyMedium),
        ],
      ),
    );
  }
}
