import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/permissions.dart';
import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/data_display.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../jewellery/domain/jewellery_item.dart';
import '../../domain/sales_models.dart';
import '../providers/sales_providers.dart';

/// The price of an item, as the customer would be quoted it.
///
/// Every line is a field from the backend's breakdown. Nothing here is
/// computed, which is why the numbers cannot drift from what the POS charges.
void showPriceSheet(BuildContext context, JewelleryItem item) {
  showAppBottomSheet<void>(
    context,
    title: item.itemCode,
    subtitle: 'Price calculated by the backend',
    builder: (context) => _PriceBody(item: item),
  );
}

class _PriceBody extends ConsumerWidget {
  const _PriceBody({required this.item});

  final JewelleryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = ref.watch(itemPriceProvider(item.id));
    final formatters = ref.watch(formattersProvider);

    return AsyncValueView<PriceBreakdown>(
      value: price,
      loading: const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      ),
      onRetry: () => ref.invalidate(itemPriceProvider(item.id)),
      data: (breakdown) {
        final rate = (item.metalId != null && item.purityId != null)
            ? ref
                  .watch(
                    currentRateProvider((
                      metalId: item.metalId!,
                      purityId: item.purityId!,
                    )),
                  )
                  .valueOrNull
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppCard(
              child: Column(
                children: [
                  KeyValueRow(
                    label: 'Net metal weight',
                    value: formatters.weight(breakdown.netMetalWeight),
                    numeric: true,
                  ),
                  if (breakdown.metalRatePerUnit != null)
                    KeyValueRow(
                      label: 'Metal rate',
                      value:
                          '${formatters.money(breakdown.metalRatePerUnit, breakdown.currency)}/g',
                      numeric: true,
                    ),
                  KeyValueRow(
                    label: 'Metal value',
                    value: formatters.money(
                      breakdown.metalValue,
                      breakdown.currency,
                    ),
                    numeric: true,
                  ),
                  if ((breakdown.wastageValue ?? 0) > 0)
                    KeyValueRow(
                      label:
                          'Wastage '
                          '(${formatters.percent(breakdown.wastagePercentage)})',
                      value: formatters.money(
                        breakdown.wastageValue,
                        breakdown.currency,
                      ),
                      numeric: true,
                    ),
                  if ((breakdown.makingCharge ?? 0) > 0)
                    KeyValueRow(
                      label: 'Making charge',
                      value: formatters.money(
                        breakdown.makingCharge,
                        breakdown.currency,
                      ),
                      numeric: true,
                    ),
                  if ((breakdown.stoneValue ?? 0) > 0)
                    KeyValueRow(
                      label: 'Stones',
                      value: formatters.money(
                        breakdown.stoneValue,
                        breakdown.currency,
                      ),
                      numeric: true,
                    ),
                  const Divider(height: AppSpacing.xxl),
                  KeyValueRow(
                    label: 'Subtotal',
                    value: formatters.money(
                      breakdown.subTotal,
                      breakdown.currency,
                    ),
                    numeric: true,
                  ),
                  if ((breakdown.discountAmount ?? 0) > 0)
                    KeyValueRow(
                      label: breakdown.loyaltyTierCode == null
                          ? 'Discount'
                          : 'Discount (${breakdown.loyaltyTierCode})',
                      value:
                          '−${formatters.money(breakdown.discountAmount, breakdown.currency)}',
                      numeric: true,
                    ),
                  if ((breakdown.taxTotal ?? 0) > 0)
                    KeyValueRow(
                      label: 'Tax',
                      value: formatters.money(
                        breakdown.taxTotal,
                        breakdown.currency,
                      ),
                      numeric: true,
                    ),
                ],
              ),
            ),
            AppSpacing.gapLg,

            Row(
              children: [
                Expanded(child: Text('Total', style: context.text.titleMedium)),
                Text(
                  formatters.money(breakdown.finalPrice, breakdown.currency),
                  style: AppTypography.numeric(context, size: 24),
                ),
              ],
            ),

            if (breakdown.discountRequiresApproval) ...[
              AppSpacing.gapMd,
              const StatusBadge(
                label: 'Discount needs approval',
                tone: StatusTone.warning,
              ),
            ],

            if (rate != null) ...[
              AppSpacing.gapLg,
              Row(
                children: [
                  Icon(
                    isRateStale(rate)
                        ? Icons.warning_amber_outlined
                        : Icons.schedule,
                    size: 14,
                    color: isRateStale(rate)
                        ? context.colors.warning
                        : context.scheme.onSurfaceVariant,
                  ),
                  AppSpacing.wGapXs,
                  Expanded(
                    child: Text(
                      isRateStale(rate)
                          ? 'Rate published ${formatters.relative(rate.publishedAt)} '
                                '— confirm before quoting'
                          : 'Rate as of ${formatters.relative(rate.publishedAt)}',
                      style: context.text.labelSmall?.copyWith(
                        color: isRateStale(rate)
                            ? context.colors.warning
                            : context.scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Stock of the same product across the branches this user may see.
void showAvailabilitySheet(
  BuildContext context,
  String productId,
  String productName,
) {
  showAppBottomSheet<void>(
    context,
    title: 'Availability',
    subtitle: productName,
    builder: (context) => _AvailabilityBody(productId: productId),
  );
}

class _AvailabilityBody extends ConsumerWidget {
  const _AvailabilityBody({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(crossBranchAvailabilityProvider(productId));
    final currentBranch = ref.watch(currentBranchProvider);

    return AsyncValueView<List<BranchAvailability>>(
      value: availability,
      loading: const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      ),
      onRetry: () => ref.invalidate(crossBranchAvailabilityProvider(productId)),
      isEmpty: (list) => list.isEmpty,
      empty: const EmptyState(
        icon: Icons.storefront_outlined,
        title: 'No branch data',
        compact: true,
      ),
      data: (list) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in list)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                entry.inStock
                    ? Icons.check_circle_outline
                    : Icons.remove_circle_outline,
                color: entry.inStock
                    ? context.colors.success
                    : context.scheme.outline,
              ),
              title: Text(entry.branchName),
              subtitle: entry.branchId == currentBranch?.id
                  ? Text(
                      'This branch',
                      style: context.text.labelSmall?.copyWith(
                        color: context.scheme.primary,
                      ),
                    )
                  : null,
              trailing: Text(
                entry.inStock ? '${entry.available}' : '0',
                style: AppTypography.numeric(
                  context,
                  size: 18,
                  color: entry.inStock ? null : context.scheme.outline,
                ),
              ),
            ),
          AppSpacing.gapMd,
          Text(
            'Only branches you have access to are shown.',
            style: context.text.labelSmall?.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kept explicit so the passport screen can gate the price action.
const priceViewPermission = Permission.saleView;
