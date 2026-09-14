import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/session_controller.dart';
import '../../../../core/settings/settings_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../domain/jewellery_item.dart';
import '../providers/jewellery_providers.dart';

/// Filters for the item list.
///
/// The price range is applied by the backend (`minPrice`/`maxPrice` on
/// `GET /inventory/items`), so the page shown and the count claimed always
/// describe the same result set. Bounds are validated here only for shape —
/// numeric, and min not above max — before they are sent.
Future<void> showItemFilterSheet(BuildContext context, WidgetRef ref) {
  return showAppBottomSheet<void>(
    context,
    title: 'Filters',
    builder: (context) => const _FilterBody(),
  );
}

class _FilterBody extends ConsumerStatefulWidget {
  const _FilterBody();

  @override
  ConsumerState<_FilterBody> createState() => _FilterBodyState();
}

class _FilterBodyState extends ConsumerState<_FilterBody> {
  late final TextEditingController _min;
  late final TextEditingController _max;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    final filters = ref.read(itemFiltersProvider);
    _min = TextEditingController(text: _text(filters.minPrice));
    _max = TextEditingController(text: _text(filters.maxPrice));
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  static String _text(num? value) => value == null ? '' : '$value';

  /// Parses and validates the price fields; commits them to the filter set and
  /// returns true, or shows why not and returns false.
  bool _applyPrice() {
    final minRaw = _min.text.trim();
    final maxRaw = _max.text.trim();
    final min = minRaw.isEmpty ? null : num.tryParse(minRaw);
    final max = maxRaw.isEmpty ? null : num.tryParse(maxRaw);

    String? error;
    if ((minRaw.isNotEmpty && min == null) ||
        (maxRaw.isNotEmpty && max == null)) {
      error = 'Enter numbers only';
    } else if ((min ?? 0) < 0 || (max ?? 0) < 0) {
      error = 'Prices cannot be negative';
    } else if (min != null && max != null && min > max) {
      error = 'Minimum is above maximum';
    }

    setState(() => _priceError = error);
    if (error != null) return false;

    ref.read(itemFiltersProvider.notifier).setPriceRange(min: min, max: max);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(itemFiltersProvider);
    final controller = ref.read(itemFiltersProvider.notifier);
    final reference = ref.watch(referenceDataProvider);
    final currency =
        ref.watch(sessionControllerProvider).company?.baseCurrency ??
        ref.watch(displayCurrencyProvider).code;

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
        _Group(
          label: 'Price ($currency)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _min,
                      label: 'Min',
                      hint: '0',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (_priceError != null) {
                          setState(() => _priceError = null);
                        }
                      },
                    ),
                  ),
                  AppSpacing.wGapMd,
                  Expanded(
                    child: AppTextField(
                      controller: _max,
                      label: 'Max',
                      hint: 'Any',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        if (_priceError != null) {
                          setState(() => _priceError = null);
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (_priceError != null) ...[
                AppSpacing.gapXs,
                Text(
                  _priceError!,
                  style: context.text.labelSmall?.copyWith(
                    color: context.scheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
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
                onPressed: () {
                  if (_applyPrice()) Navigator.of(context).pop();
                },
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
