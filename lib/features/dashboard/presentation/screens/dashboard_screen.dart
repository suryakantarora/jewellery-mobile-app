import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/permissions.dart';
import '../../../../core/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/settings/settings_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/extensions/widget_extensions.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/data_display.dart';
import '../../../../shared/widgets/skeletons.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../authentication/presentation/screens/branch_selector_screen.dart';
import '../../../jewellery/domain/jewellery_item.dart';
import '../../../jewellery/presentation/providers/jewellery_providers.dart';
import '../../../jewellery/presentation/widgets/reference_gate.dart';
import '../../domain/dashboard_summary.dart';
import '../providers/dashboard_providers.dart';

/// The role-aware dashboard.
///
/// Tiles are built only for the sections the summary endpoint returned — the
/// backend omits what a user may not see — and quick actions are filtered by
/// permission before the grid is built, never guarded inside it. A guard that
/// returns an empty widget still occupies its cell and leaves holes in the
/// layout.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return AppScaffold(
      titleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_greeting(), style: context.text.bodySmall),
          Text(
            user?.fullName ?? '',
            style: context.text.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      onBranchTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const FractionallySizedBox(
          heightFactor: 0.75,
          child: BranchSelectorScreen(canDismiss: true),
        ),
      ),
      actions: [
        IconButton(
          tooltip: context.l10n.settingsHideAmounts,
          icon: Icon(
            ref.watch(hideAmountsProvider)
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          onPressed: () => ref.read(hideAmountsProvider.notifier).toggle(),
        ),
        IconButton(
          tooltip: context.l10n.settingsThemeMode,
          icon: const Icon(Icons.brightness_6_outlined),
          onPressed: () => ref.read(themeModeProvider.notifier).cycle(),
        ),
      ],
      body: ReferenceGate(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(dashboardSummaryProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            children: [
              const _MetalRatesStrip(),
              const _StatGrid().entrance(index: 0),
              AppSpacing.gapXl,
              Text(
                'Quick actions',
                style: context.text.titleSmall,
              ).entrance(index: 1),
              AppSpacing.gapMd,
              const _QuickActions().entrance(index: 2),
              AppSpacing.gapXl,
              const _RecentItems().entrance(index: 3),
            ],
          ),
        ),
      ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

/// One figure on the grid. Built from a present section, never from a
/// permission guess.
class _Tile {
  const _Tile({
    required this.label,
    required this.icon,
    required this.value,
    this.caption,
    this.sensitive = false,
    this.route,
  });

  final String label;
  final IconData icon;
  final String value;
  final String? caption;
  final bool sensitive;
  final String? route;
}

class _StatGrid extends ConsumerWidget {
  const _StatGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    final columns = context.screenWidth >= 600 ? 4 : 2;

    return summary.when(
      // Keep the last figures visible under the refresh indicator rather than
      // collapsing the grid to skeletons on every pull.
      skipLoadingOnRefresh: true,
      loading: () => _grid(columns, [
        for (var i = 0; i < 4; i++) const SkeletonStatTile(),
      ]),
      error: (error, _) => ErrorState(
        error: error,
        compact: true,
        onRetry: () => ref.invalidate(dashboardSummaryProvider),
      ),
      data: (data) {
        final tiles = _tilesFor(context, ref, data);
        if (tiles.isEmpty) return const SizedBox.shrink();
        return _grid(columns, [
          for (final tile in tiles)
            StatTile(
              label: tile.label,
              icon: tile.icon,
              value: tile.value,
              caption: tile.caption,
              sensitive: tile.sensitive,
              onTap: tile.route == null ? null : () => context.go(tile.route!),
            ),
        ]);
      },
    );
  }

  Widget _grid(int columns, List<Widget> children) => GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: columns,
    crossAxisSpacing: AppSpacing.md,
    mainAxisSpacing: AppSpacing.md,
    childAspectRatio: 1.5,
    children: children,
  );

  /// Turns present sections into tiles.
  ///
  /// The permission check is secondary: the server already omitted anything
  /// the user may not see, so this only guards against a mis-scoped payload.
  List<_Tile> _tilesFor(
    BuildContext context,
    WidgetRef ref,
    DashboardSummary summary,
  ) {
    final permissions = ref.watch(permissionsProvider);
    final formatters = ref.watch(formattersProvider);
    // Summaries do not always echo a currency; the institution's base currency
    // is the right fallback. Showing "?" against a real figure reads as a bug.
    final fallbackCurrency =
        ref.watch(sessionControllerProvider).company?.baseCurrency ??
        ref.watch(displayCurrencyProvider).code;

    bool allowed(DashboardSection section) => section.isVisibleTo(permissions);
    String count(num? value) => value == null ? '—' : formatters.count(value);
    String money(num? value, String? currency) => value == null
        ? '—'
        : formatters.money(value, currency ?? fallbackCurrency, compact: true);

    final tiles = <_Tile>[];

    final sales = summary.sales;
    if (sales != null && allowed(DashboardSection.sales)) {
      tiles.add(
        _Tile(
          label: "Today's sales",
          icon: Icons.payments_outlined,
          value: money(sales.todayTotal, sales.currency),
          caption: sales.todayCount == null
              ? null
              : '${count(sales.todayCount)} sales',
          sensitive: true,
        ),
      );
      if (sales.monthToDateTotal != null) {
        tiles.add(
          _Tile(
            label: 'Month to date',
            icon: Icons.calendar_month_outlined,
            value: money(sales.monthToDateTotal, sales.currency),
            sensitive: true,
          ),
        );
      }
    }

    final inventory = summary.inventory;
    if (inventory != null && allowed(DashboardSection.inventory)) {
      tiles
        ..add(
          _Tile(
            label: 'Available',
            icon: Icons.check_circle_outline,
            value: count(inventory.availableItems),
            caption: inventory.reservedItems == null
                ? null
                : '${count(inventory.reservedItems)} reserved',
            route: AppRoutes.inventory,
          ),
        )
        ..add(
          _Tile(
            label: 'Total stock',
            icon: Icons.diamond_outlined,
            value: count(inventory.totalItems),
            route: AppRoutes.inventory,
          ),
        );
      if ((inventory.lowStockProducts ?? 0) > 0) {
        tiles.add(
          _Tile(
            label: 'Low stock',
            icon: Icons.trending_down,
            value: count(inventory.lowStockProducts),
            caption: 'locations at threshold',
            route: AppRoutes.inventory,
          ),
        );
      }
    }

    final value = summary.inventoryValue;
    if (value != null && allowed(DashboardSection.inventoryValue)) {
      tiles.add(
        _Tile(
          label: 'Stock value',
          icon: Icons.account_balance_wallet_outlined,
          value: money(value.retailValue ?? value.costValue, value.currency),
          caption: value.retailValue != null && value.costValue != null
              ? 'cost ${money(value.costValue, value.currency)}'
              : null,
          sensitive: true,
        ),
      );
    }

    final transfers = summary.transfers;
    if (transfers != null && allowed(DashboardSection.transfers)) {
      tiles
        ..add(
          _Tile(
            label: 'Awaiting approval',
            icon: Icons.pending_actions_outlined,
            value: count(transfers.pendingApproval),
            caption: (transfers.awaitingSecondApproval ?? 0) > 0
                ? '${count(transfers.awaitingSecondApproval)} need 2nd approval'
                : null,
            route: AppRoutes.transfers,
          ),
        )
        ..add(
          _Tile(
            label: 'To receive',
            icon: Icons.call_received,
            value: count(transfers.incoming),
            caption: transfers.outgoing == null
                ? null
                : '${count(transfers.outgoing)} outgoing',
            route: AppRoutes.transfers,
          ),
        );
    }

    final approvals = summary.approvals;
    if (approvals != null && allowed(DashboardSection.approvals)) {
      final types = approvals.byType.entries
          .where((entry) => entry.value > 0)
          .length;
      tiles.add(
        _Tile(
          label: 'Approvals',
          icon: Icons.fact_check_outlined,
          value: count(approvals.total),
          caption: types == 0
              ? null
              : 'across $types ${types == 1 ? 'type' : 'types'}',
          route: AppRoutes.approvals,
        ),
      );
    }

    final repairs = summary.repairs;
    if (repairs != null && allowed(DashboardSection.repairs)) {
      tiles
        ..add(
          _Tile(
            label: 'Repairs ready',
            icon: Icons.build_circle_outlined,
            value: count(repairs.ready),
            route: AppRoutes.repairs,
          ),
        )
        ..add(
          _Tile(
            label: 'Repairs in progress',
            icon: Icons.handyman_outlined,
            value: count(repairs.inProgress),
            caption: repairs.awaitingCustomer == null
                ? null
                : '${count(repairs.awaitingCustomer)} awaiting customer',
            route: AppRoutes.repairs,
          ),
        );
    }

    final procurement = summary.procurement;
    if (procurement != null && allowed(DashboardSection.procurement)) {
      tiles.add(
        _Tile(
          label: 'Purchase orders',
          icon: Icons.local_shipping_outlined,
          value: count(procurement.pendingOrders),
          caption: procurement.awaitingReceipt == null
              ? null
              : '${count(procurement.awaitingReceipt)} awaiting receipt',
          route: AppRoutes.procurement,
        ),
      );
    }

    return tiles;
  }
}

/// Published metal rates, one chip per metal and purity.
///
/// A stale rate is shown, not hidden — a counter still needs a number to talk
/// from — but it is visibly flagged so nobody quotes it as current.
class _MetalRatesStrip extends ConsumerWidget {
  const _MetalRatesStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rates = ref.watch(dashboardSummaryProvider).valueOrNull?.metalRates;
    final permissions = ref.watch(permissionsProvider);
    if (rates == null ||
        rates.isEmpty ||
        !DashboardSection.metalRates.isVisibleTo(permissions)) {
      return const SizedBox.shrink();
    }

    final formatters = ref.watch(formattersProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: rates.length,
          separatorBuilder: (_, __) => AppSpacing.wGapSm,
          itemBuilder: (context, index) {
            final rate = rates[index];
            final tone = rate.stale
                ? context.colors.warning
                : context.scheme.primary;
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: rate.stale
                    ? context.colors.warning.withValues(alpha: 0.08)
                    : context.scheme.surfaceContainerLow,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(
                  color: rate.stale
                      ? context.colors.warning.withValues(alpha: 0.6)
                      : context.scheme.outlineVariant,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rate.label.isEmpty ? 'Rate' : rate.label,
                        style: context.text.labelMedium?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      ),
                      if (rate.stale) ...[
                        AppSpacing.wGapXs,
                        Icon(Icons.schedule, size: 12, color: tone),
                        AppSpacing.wGapXs,
                        Text(
                          'stale',
                          style: context.text.labelSmall?.copyWith(color: tone),
                        ),
                      ],
                    ],
                  ),
                  AppSpacing.gapXxs,
                  Text(
                    '${formatters.money(rate.rate, rate.currency)}/g'
                    '${rate.rateType == null ? '' : ' · ${rate.rateType}'}',
                    style: context.text.titleSmall?.copyWith(
                      color: rate.stale ? tone : null,
                      decoration: rate.stale ? TextDecoration.underline : null,
                      decorationStyle: TextDecorationStyle.dotted,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  static const _actions =
      <({IconData icon, String label, String route, Permission permission})>[
        (
          icon: Icons.qr_code_scanner,
          label: 'Scan',
          route: AppRoutes.scan,
          permission: Permission.inventoryView,
        ),
        (
          icon: Icons.search,
          label: 'Search',
          route: AppRoutes.inventory,
          permission: Permission.inventoryView,
        ),
        (
          icon: Icons.swap_horiz,
          label: 'Transfer',
          route: AppRoutes.transfers,
          permission: Permission.inventoryTransfer,
        ),
        (
          icon: Icons.inventory_2_outlined,
          label: 'Receive',
          route: AppRoutes.procurement,
          permission: Permission.procurementReceive,
        ),
        (
          icon: Icons.person_add_outlined,
          label: 'Customer',
          route: AppRoutes.customers,
          permission: Permission.customerManage,
        ),
        (
          icon: Icons.build_outlined,
          label: 'Repair',
          route: AppRoutes.repairs,
          permission: Permission.repairProcess,
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionsProvider);
    final visible = _actions
        .where((action) => permissions.has(action.permission))
        .toList(growable: false);

    if (visible.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visible.length,
        separatorBuilder: (_, __) => AppSpacing.wGapMd,
        itemBuilder: (context, index) {
          final action = visible[index];
          return _QuickAction(
            icon: action.icon,
            label: action.label,
            onTap: () => context.go(action.route),
          );
        },
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      child: Material(
        color: context.scheme.surfaceContainerLow,
        borderRadius: AppRadius.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: context.scheme.outlineVariant),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: context.scheme.primary),
                AppSpacing.gapSm,
                Text(
                  label,
                  style: context.text.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Recently viewed items — the fastest way back to something just looked at.
class _RecentItems extends ConsumerWidget {
  const _RecentItems();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentItemsProvider);
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recently viewed', style: context.text.titleSmall),
        AppSpacing.gapMd,
        for (final item in recent.take(5)) _RecentRow(item: item),
      ],
    );
  }
}

class _RecentRow extends ConsumerWidget {
  const _RecentRow({required this.item});

  final JewelleryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productName =
        item.productName ??
        ref.watch(referenceDataProvider).cachedProduct(item.productId)?.name;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(Icons.history, size: 18, color: context.scheme.outline),
      title: Text(item.itemCode, style: context.text.bodyMedium),
      subtitle: productName == null ? null : Text(productName),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => context.push(AppRoutes.itemDetailPath(item.id)),
    );
  }
}
