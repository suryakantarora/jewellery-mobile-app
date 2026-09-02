import 'package:flutter/material.dart';

import '../../core/constants/permissions.dart';
import '../../core/router/app_routes.dart';

/// A navigation destination and the permission it requires.
///
/// Navigation is declared as data, not as a widget tree, so the bottom bar and
/// the "More" screen filter from one list and cannot disagree about what a user
/// is allowed to see.
class NavDestination {
  const NavDestination({
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.labelKey,
    this.requires,
    this.requiresAny,
  });

  final String route;
  final IconData icon;
  final IconData selectedIcon;

  /// Resolved against the localisations at build time.
  final String labelKey;

  final Permission? requires;
  final List<Permission>? requiresAny;

  bool isAllowed(PermissionSet permissions) {
    if (requires != null && !permissions.has(requires!)) return false;
    if (requiresAny != null && !permissions.hasAny(requiresAny!)) return false;
    return true;
  }
}

/// The five primary tabs.
///
/// Dashboard and Scan carry no permission of their own: every employee needs a
/// landing screen, and the scanner is the fastest route to an item for anyone
/// who can view inventory at all.
const primaryDestinations = <NavDestination>[
  NavDestination(
    route: AppRoutes.dashboard,
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    labelKey: 'navDashboard',
  ),
  NavDestination(
    route: AppRoutes.inventory,
    icon: Icons.diamond_outlined,
    selectedIcon: Icons.diamond,
    labelKey: 'navInventory',
    requires: Permission.inventoryView,
  ),
  NavDestination(
    route: AppRoutes.scan,
    icon: Icons.qr_code_scanner_outlined,
    selectedIcon: Icons.qr_code_scanner,
    labelKey: 'navScan',
    requires: Permission.inventoryView,
  ),
  NavDestination(
    route: AppRoutes.transfers,
    icon: Icons.swap_horiz_outlined,
    selectedIcon: Icons.swap_horiz,
    labelKey: 'navTransfers',
    requiresAny: [
      Permission.inventoryTransfer,
      Permission.inventoryTransferApprove,
    ],
  ),
  NavDestination(
    route: AppRoutes.more,
    icon: Icons.more_horiz_outlined,
    selectedIcon: Icons.more_horiz,
    labelKey: 'navMore',
  ),
];

/// A grouped secondary destination, listed under "More".
class SecondaryDestination {
  const SecondaryDestination({
    required this.route,
    required this.icon,
    required this.labelKey,
    required this.group,
    this.requires,
    this.requiresAny,
    this.phase,
  });

  final String route;
  final IconData icon;
  final String labelKey;
  final NavGroup group;
  final Permission? requires;
  final List<Permission>? requiresAny;

  /// Set only while a destination is still a placeholder, so the badge can say
  /// so. Now that every destination is built, nothing sets it — a badge here
  /// would imply a screen is a stub when it is not.
  final int? phase;

  bool isAllowed(PermissionSet permissions) {
    if (requires != null && !permissions.has(requires!)) return false;
    if (requiresAny != null && !permissions.hasAny(requiresAny!)) return false;
    return true;
  }
}

enum NavGroup { operations, commercial, insight, account }

const secondaryDestinations = <SecondaryDestination>[
  SecondaryDestination(
    route: AppRoutes.warehouse,
    icon: Icons.warehouse_outlined,
    labelKey: 'screenWarehouse',
    group: NavGroup.operations,
    requiresAny: [Permission.warehouseView, Permission.stockCountPerform],
  ),
  SecondaryDestination(
    route: AppRoutes.procurement,
    icon: Icons.local_shipping_outlined,
    labelKey: 'screenProcurement',
    group: NavGroup.operations,
    requires: Permission.procurementView,
  ),
  SecondaryDestination(
    route: AppRoutes.repairs,
    icon: Icons.build_outlined,
    labelKey: 'screenRepairs',
    group: NavGroup.operations,
    requires: Permission.repairView,
  ),
  SecondaryDestination(
    route: AppRoutes.sales,
    icon: Icons.point_of_sale_outlined,
    labelKey: 'screenSales',
    group: NavGroup.commercial,
    requires: Permission.saleView,
  ),
  SecondaryDestination(
    route: AppRoutes.customers,
    icon: Icons.people_outline,
    labelKey: 'screenCustomers',
    group: NavGroup.commercial,
    requires: Permission.customerView,
  ),
  SecondaryDestination(
    route: AppRoutes.exchange,
    icon: Icons.currency_exchange_outlined,
    labelKey: 'screenExchange',
    group: NavGroup.commercial,
    requires: Permission.exchangeView,
  ),
  SecondaryDestination(
    route: AppRoutes.approvals,
    icon: Icons.approval_outlined,
    labelKey: 'screenApprovals',
    group: NavGroup.insight,
    requiresAny: [
      Permission.inventoryTransferApprove,
      Permission.procurementApprove,
      Permission.exchangeApprove,
      Permission.stockCountApprove,
    ],
  ),
  SecondaryDestination(
    route: AppRoutes.reports,
    icon: Icons.insights_outlined,
    labelKey: 'screenReports',
    group: NavGroup.insight,
    requires: Permission.reportView,
  ),
  // No permission required. NOTIFICATION_VIEW gates the admin delivery-queue
  // search, not a person's own mail: /notifications/mine is scoped to the
  // caller. Gating on it hid the inbox from exactly the staff the operational
  // broadcasts are written for — an inventory officer receives every transfer
  // notification and could not open the screen showing them.
  SecondaryDestination(
    route: AppRoutes.notifications,
    icon: Icons.notifications_outlined,
    labelKey: 'screenNotifications',
    group: NavGroup.insight,
  ),
  SecondaryDestination(
    route: AppRoutes.profile,
    icon: Icons.account_circle_outlined,
    labelKey: 'screenProfile',
    group: NavGroup.account,
  ),
  SecondaryDestination(
    route: AppRoutes.settings,
    icon: Icons.settings_outlined,
    labelKey: 'screenSettings',
    group: NavGroup.account,
  ),
];
