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
import '../../../authentication/presentation/screens/branch_selector_screen.dart';
import '../../../jewellery/domain/jewellery_item.dart';
import '../../../jewellery/presentation/providers/jewellery_providers.dart';
import '../providers/dashboard_providers.dart';
import '../../../jewellery/presentation/widgets/reference_gate.dart';

/// The role-aware dashboard.
///
/// Tiles and quick actions are filtered by permission before the grid is built,
/// never guarded inside it — a guard that returns an empty widget still
/// occupies its cell and leaves holes in the layout.
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
          onRefresh: () async {
            ref
              ..invalidate(todaySalesProvider)
              ..invalidate(inventoryCountProvider)
              ..invalidate(availableCountProvider)
              ..invalidate(inventoryValueProvider)
              ..invalidate(pendingTransfersProvider)
              ..invalidate(incomingTransfersProvider)
              ..invalidate(repairsReadyProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            children: [
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

class _StatGrid extends ConsumerWidget {
  const _StatGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionsProvider);
    final visible = DashboardTile.values
        .where((tile) => tile.isVisibleTo(permissions))
        .toList(growable: false);

    if (visible.isEmpty) return const SizedBox.shrink();

    final columns = context.screenWidth >= 600 ? 4 : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visible.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (context, index) => _MetricTile(tile: visible[index]),
    );
  }
}

/// One tile, with its own load and failure state.
///
/// Isolating them is the point: with no dashboard endpoint these are seven
/// separate requests, and one failing must not blank the other six.
class _MetricTile extends ConsumerWidget {
  const _MetricTile({required this.tile});

  final DashboardTile tile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatters = ref.watch(formattersProvider);
    final fallbackCurrency =
        ref.watch(sessionControllerProvider).company?.baseCurrency ??
        ref.watch(displayCurrencyProvider).code;

    final (metric, label, icon, isMoney, captionSuffix, route) = switch (tile) {
      DashboardTile.todaySales => (
        ref.watch(todaySalesProvider),
        "Today's sales",
        Icons.payments_outlined,
        true,
        'sales',
        null,
      ),
      DashboardTile.availableCount => (
        ref.watch(availableCountProvider),
        'Available',
        Icons.check_circle_outline,
        false,
        null,
        AppRoutes.inventory,
      ),
      DashboardTile.inventoryCount => (
        ref.watch(inventoryCountProvider),
        'Total stock',
        Icons.diamond_outlined,
        false,
        null,
        AppRoutes.inventory,
      ),
      DashboardTile.inventoryValue => (
        ref.watch(inventoryValueProvider),
        'Stock value',
        Icons.account_balance_wallet_outlined,
        true,
        'items',
        null,
      ),
      DashboardTile.pendingTransfers => (
        ref.watch(pendingTransfersProvider),
        'Awaiting approval',
        Icons.pending_actions_outlined,
        false,
        null,
        AppRoutes.transfers,
      ),
      DashboardTile.incomingTransfers => (
        ref.watch(incomingTransfersProvider),
        'To receive',
        Icons.call_received,
        false,
        null,
        AppRoutes.transfers,
      ),
      DashboardTile.repairsReady => (
        ref.watch(repairsReadyProvider),
        'Repairs ready',
        Icons.build_circle_outlined,
        false,
        null,
        AppRoutes.repairs,
      ),
    };

    return metric.when(
      loading: () => const SkeletonStatTile(),
      error: (_, __) => _UnavailableTile(label: label, icon: icon),
      data: (data) => StatTile(
        label: label,
        icon: icon,
        sensitive: isMoney,
        value: data.hasValue
            ? (isMoney
                  ? formatters.money(
                      data.value,
                      // Reports do not always echo a currency; the institution's
                      // base currency is the right fallback. Showing "?" against
                      // a real figure reads as a bug.
                      data.currency ?? fallbackCurrency,
                      compact: true,
                    )
                  : formatters.count(data.value))
            : '—',
        caption: data.secondary == null || captionSuffix == null
            ? null
            : '${formatters.count(data.secondary)} $captionSuffix',
        onTap: route == null ? null : () => context.go(route),
      ),
    );
  }
}

/// A figure that could not be loaded.
///
/// Says so plainly rather than showing a zero — a zero here would be read as
/// "no stock", which is a materially different and much worse claim.
class _UnavailableTile extends StatelessWidget {
  const _UnavailableTile({required this.label, required this.icon});

  final String label;
  final IconData icon;

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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: context.scheme.onSurfaceVariant),
              AppSpacing.wGapXs,
              Expanded(
                child: Text(
                  label,
                  style: context.text.labelMedium?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          AppSpacing.gapSm,
          Text(
            'Unavailable',
            style: context.text.bodySmall?.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
        ],
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
    final reference = ref.watch(referenceDataProvider);
    final product = reference.cachedProduct(item.productId);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(Icons.history, size: 18, color: context.scheme.outline),
      title: Text(item.itemCode, style: context.text.bodyMedium),
      subtitle: product == null ? null : Text(product.name),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => context.push(AppRoutes.itemDetailPath(item.id)),
    );
  }
}
