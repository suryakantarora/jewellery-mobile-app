import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/extensions/widget_extensions.dart';
import '../../../../shared/navigation/nav_destinations.dart';
import '../../../../shared/navigation/nav_labels.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/status_badge.dart';

/// Secondary destinations, grouped and permission-filtered.
///
/// A group with no permitted entries disappears entirely rather than rendering
/// an empty heading.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionsProvider);
    final config = ref.watch(appConfigProvider);

    final groups = <NavGroup, List<SecondaryDestination>>{};
    for (final destination in secondaryDestinations) {
      if (!destination.isAllowed(permissions)) continue;
      groups.putIfAbsent(destination.group, () => []).add(destination);
    }

    var animationIndex = 0;

    return AppScaffold(
      title: context.l10n.navMore,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: [
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xs,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                navGroupLabel(context.l10n, entry.key.name),
                style: context.text.labelMedium?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
            ),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < entry.value.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: AppSpacing.huge),
                    _DestinationTile(destination: entry.value[i]),
                  ],
                ],
              ),
            ).entrance(index: animationIndex++),
            AppSpacing.gapXl,
          ],

          // The gallery is the review surface for the whole design system, so
          // it is reachable in non-production builds only.
          if (config.environment.allowsDeveloperTools)
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(
                  Icons.palette_outlined,
                  color: context.scheme.primary,
                ),
                title: Text(context.l10n.galleryTitle),
                subtitle: Text(
                  'Every shared component, in one place',
                  style: context.text.bodySmall,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.componentGallery),
              ),
            ).entrance(index: animationIndex++),
        ],
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({required this.destination});

  final SecondaryDestination destination;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(destination.icon, color: context.scheme.primary),
      title: Text(navLabel(context.l10n, destination.labelKey)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Unbuilt screens say so, so nobody mistakes a placeholder for a
          // broken feature.
          if (destination.phase != null)
            StatusBadge(
              label: 'Phase ${destination.phase}',
              tone: StatusTone.neutral,
              dense: true,
            ),
          AppSpacing.wGapSm,
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => context.push(destination.route),
    );
  }
}
