import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../domain/jewellery_item.dart';
import '../providers/jewellery_providers.dart';

/// Filters for the item list.
///
/// Deliberately omits a price range: `GET /inventory/items` exposes no
/// `minPrice`/`maxPrice`, and filtering a paged list client-side would show a
/// filtered page while claiming a full-result count — a quiet lie. The filter
/// returns as soon as the backend supports it.
Future<void> showItemFilterSheet(BuildContext context, WidgetRef ref) {
  return showAppBottomSheet<void>(
    context,
    title: 'Filters',
    builder: (context) => const _FilterBody(),
  );
}

class _FilterBody extends ConsumerWidget {
  const _FilterBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(itemFiltersProvider);
    final controller = ref.read(itemFiltersProvider.notifier);
    final reference = ref.watch(referenceDataProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Group(
          label: 'Status',
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final status in const [
                ItemStatus.available,
                ItemStatus.reserved,
                ItemStatus.inTransit,
                ItemStatus.underRepair,
                ItemStatus.draft,
                ItemStatus.sold,
              ])
                ChoiceChip(
                  label: Text(status.label),
                  selected: filters.status == status,
                  onSelected: (selected) =>
                      controller.setStatus(selected ? status : null),
                ),
            ],
          ),
        ),
        _Group(
          label: 'Metal',
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final metal in reference.metals)
                ChoiceChip(
                  label: Text(metal.name),
                  selected: filters.metalId == metal.id,
                  onSelected: (selected) =>
                      controller.setMetal(selected ? metal.id : null),
                ),
            ],
          ),
        ),
        // Purity only makes sense once a metal is chosen — 22K belongs to gold.
        if (filters.metalId != null)
          _Group(
            label: 'Purity',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final purity in reference.puritiesFor(filters.metalId))
                  ChoiceChip(
                    label: Text(purity.code),
                    selected: filters.purityId == purity.id,
                    onSelected: (selected) =>
                        controller.setPurity(selected ? purity.id : null),
                  ),
              ],
            ),
          ),
        _Group(
          label: 'Location',
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final location in reference.locations)
                ChoiceChip(
                  label: Text(location.name),
                  selected: filters.locationId == location.id,
                  onSelected: (selected) =>
                      controller.setLocation(selected ? location.id : null),
                ),
            ],
          ),
        ),
        AppSpacing.gapXl,
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: context.l10n.actionClear,
                variant: AppButtonVariant.outlined,
                onPressed: () {
                  controller.clearFilters();
                  Navigator.of(context).pop();
                },
              ),
            ),
            AppSpacing.wGapMd,
            Expanded(
              child: AppButton(
                label: 'Show results',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.gapSm,
          child,
        ],
      ),
    );
  }
}
