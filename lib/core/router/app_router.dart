import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/screens/branch_selector_screen.dart';
import '../../features/authentication/presentation/screens/change_password_screen.dart';
import '../../features/authentication/presentation/screens/lock_screen.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/splash_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/approvals/presentation/screens/approval_center_screen.dart';
import '../../features/customers/presentation/screens/customer_screens.dart';
import '../../features/dev/presentation/screens/component_gallery_screen.dart';
import '../../features/inventory/presentation/screens/inventory_screen.dart';
import '../../features/jewellery/presentation/screens/item_search_screen.dart';
import '../../features/jewellery/presentation/screens/item_passport_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/repairs/presentation/screens/repair_screens.dart';
import '../../features/scanner/presentation/providers/scanner_providers.dart';
import '../../features/exchange/presentation/screens/exchange_screens.dart';
import '../../features/notifications/presentation/screens/notification_center_screen.dart';
import '../../features/procurement/presentation/screens/goods_receiving_screen.dart';
import '../../features/procurement/presentation/screens/procurement_screen.dart';
import '../../features/scanner/presentation/screens/scan_screen.dart';
import '../../features/transfers/presentation/screens/transfer_detail_screen.dart';
import '../../features/transfers/presentation/screens/transfer_list_screen.dart';
import '../../features/transfers/presentation/screens/transfer_receive_screen.dart';
import '../../features/warehouse/presentation/screens/stock_count_session_screen.dart';
import '../../features/warehouse/presentation/screens/vault_screen.dart';
import '../../features/warehouse/presentation/screens/warehouse_screen.dart';
import '../../features/settings/presentation/screens/more_screen.dart';
import '../../features/settings/presentation/screens/profile_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../shared/navigation/app_shell.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../providers.dart';
import '../security/session_controller.dart';
import 'app_routes.dart';
import 'route_guards.dart';

/// The application router.
///
/// Tabs are `StatefulShellBranch`es so each keeps its own navigation stack —
/// a warehouse employee three screens deep in Transfers should still find that
/// stack intact after checking the dashboard.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(sessionRefreshProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: ref
        .watch(appConfigProvider)
        .environment
        .allowsDeveloperTools,

    // One redirect rule for the whole app, reading only the session state.
    redirect: (context, state) => sessionRedirect(
      ref.read(sessionControllerProvider),
      state.matchedLocation,
    ),

    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.changePassword,
        builder: (_, __) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.selectBranch,
        builder: (_, __) => const BranchSelectorScreen(),
      ),
      GoRoute(path: AppRoutes.lock, builder: (_, __) => const LockScreen()),
      GoRoute(
        path: AppRoutes.itemSearch,
        builder: (_, __) => const ItemSearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.componentGallery,
        builder: (_, __) => const ComponentGalleryScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (_, __) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.inventory,
                builder: (_, __) => const InventoryScreen(),
                routes: [
                  GoRoute(
                    path: 'item/:id',
                    builder: (_, state) =>
                        ItemPassportScreen(itemId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.scan,
                builder: (_, state) => ScanScreen(
                  request: state.extra is ScanRequest
                      ? state.extra! as ScanRequest
                      : const ScanRequest(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.transfers,
                builder: (_, __) => const TransferListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => TransferDetailScreen(
                      movementId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'receive',
                        builder: (_, state) => TransferReceiveScreen(
                          movementId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.more,
                builder: (_, __) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'warehouse',
                    builder: (_, __) => const WarehouseScreen(),
                    routes: [
                      GoRoute(
                        path: 'count/:id',
                        builder: (_, state) => StockCountSessionScreen(
                          countId: state.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: 'location/:id',
                        builder: (_, state) => VaultScreen(
                          locationId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'procurement',
                    builder: (_, __) => const ProcurementScreen(),
                    routes: [
                      GoRoute(
                        path: 'po/:id',
                        builder: (_, state) => PurchaseOrderDetailScreen(
                          orderId: state.pathParameters['id']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'receive',
                            builder: (_, state) => GoodsReceivingScreen(
                              orderId: state.pathParameters['id']!,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'sales',
                    builder: (_, __) => const PhasePlaceholderScreen(
                      title: 'Sales Assistance',
                      phase: 10,
                      icon: Icons.point_of_sale_outlined,
                    ),
                  ),
                  GoRoute(
                    path: 'customers',
                    builder: (_, __) => const CustomerSearchScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (_, state) => Customer360Screen(
                          customerId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'repairs',
                    builder: (_, __) => const RepairBoardScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (_, state) => RepairJobScreen(
                          repairId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'exchange',
                    builder: (_, __) => const ExchangeListScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (_, state) => ExchangeDetailScreen(
                          exchangeId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'approvals',
                    builder: (_, __) => const ApprovalCenterScreen(),
                  ),
                  GoRoute(
                    path: 'reports',
                    builder: (_, __) => const ReportsScreen(),
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (_, __) => const NotificationCenterScreen(),
                  ),
                  GoRoute(
                    path: 'profile',
                    builder: (_, __) => const ProfileScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (_, __) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 40),
              const SizedBox(height: 16),
              Text('No screen at ${state.uri.path}'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                child: const Text('Go to dashboard'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});
