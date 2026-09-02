import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/security/session_controller.dart';
import '../../core/theme/app_motion.dart';
import '../extensions/context_extensions.dart';
import 'nav_destinations.dart';
import 'nav_labels.dart';

/// The tabbed shell.
///
/// Destinations are filtered by permission, so a warehouse-only employee never
/// sees a Transfers tab they cannot use. Because the visible set differs per
/// user, the selected index is derived from the current route rather than
/// stored — an index would mean something different for each user.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionsProvider);

    final visible = <({NavDestination destination, int branchIndex})>[];
    for (var i = 0; i < primaryDestinations.length; i++) {
      final destination = primaryDestinations[i];
      if (destination.isAllowed(permissions)) {
        visible.add((destination: destination, branchIndex: i));
      }
    }

    final selected = visible.indexWhere(
      (entry) => entry.branchIndex == navigationShell.currentIndex,
    );

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: visible.length < 2
          // A single destination does not warrant a bar.
          ? null
          : NavigationBar(
              selectedIndex: selected < 0 ? 0 : selected,
              onDestinationSelected: (index) {
                final target = visible[index].branchIndex;
                navigationShell.goBranch(
                  target,
                  // Tapping the current tab returns to its root — the standard
                  // expectation, and useful when several screens deep.
                  initialLocation: target == navigationShell.currentIndex,
                );
              },
              destinations: [
                for (final entry in visible)
                  NavigationDestination(
                    icon: Icon(entry.destination.icon),
                    selectedIcon: Icon(entry.destination.selectedIcon),
                    label: navLabel(context.l10n, entry.destination.labelKey),
                  ),
              ],
            ),
    );
  }
}

/// Wraps a tab's content so switching tabs cross-fades instead of cutting.
class TabTransition extends StatelessWidget {
  const TabTransition({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.fast,
    switchInCurve: AppMotion.enter,
    child: child,
  );
}
