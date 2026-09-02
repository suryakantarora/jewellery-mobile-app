import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/permissions.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/models/organization.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../jewellery/presentation/providers/jewellery_providers.dart';
import '../../domain/warehouse_models.dart';
import '../providers/warehouse_providers.dart';
import '../../../jewellery/presentation/widgets/reference_gate.dart';

/// Warehouse and vault operations.
///
/// Issue and return are not built as a separate domain: they are
/// `MovementType.ISSUE` / `RETURN` on the movements endpoint, so they open the
/// transfer flow with the type preset rather than duplicating it.
class WarehouseScreen extends ConsumerWidget {
  const WarehouseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reference = ref.watch(referenceDataProvider);
    final counts = ref.watch(stockCountListProvider);
    final permissions = ref.watch(permissionsProvider);

    final storageLocations = reference.locations
        .where(
          (location) =>
              location.type == LocationType.vault ||
              location.type == LocationType.centralWarehouse ||
              location.type == LocationType.branchWarehouse ||
              location.type == LocationType.storeRoom,
        )
        .toList(growable: false);

    return AppScaffold(
      title: context.l10n.screenWarehouse,
      body: ReferenceGate(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          children: [
            Text('Storage locations', style: context.text.titleSmall),
            AppSpacing.gapMd,
            if (storageLocations.isEmpty)
              const EmptyState(
                icon: Icons.warehouse_outlined,
                title: 'No storage locations',
                message: 'This branch has no vault or warehouse configured.',
                compact: true,
              )
            else
              for (final location in storageLocations)
                _LocationCard(location: location),

            AppSpacing.gapXl,
            Row(
              children: [
                Expanded(
                  child: Text('Stock counts', style: context.text.titleSmall),
                ),
                if (permissions.has(Permission.stockCountPerform))
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New count'),
                    onPressed: () =>
                        _startCount(context, ref, storageLocations),
                  ),
              ],
            ),
            AppSpacing.gapSm,
            AsyncValueView<List<StockCount>>(
              value: counts,
              loading: const SizedBox.shrink(),
              onRetry: () => ref.invalidate(stockCountListProvider),
              isEmpty: (list) => list.isEmpty,
              empty: const EmptyState(
                icon: Icons.fact_check_outlined,
                title: 'No counts yet',
                message: 'Start a count to verify what is physically present.',
                compact: true,
              ),
              data: (list) => Column(
                children: [for (final count in list) _CountRow(count: count)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startCount(
    BuildContext context,
    WidgetRef ref,
    List<BranchLocation> locations,
  ) async {
    if (locations.isEmpty) return;

    final location = await showAppBottomSheet<BranchLocation>(
      context,
      title: 'Count which location?',
      subtitle: 'The backend returns the expected items for it.',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in locations)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                option.type == LocationType.vault
                    ? Icons.lock_outline
                    : Icons.warehouse_outlined,
              ),
              title: Text(option.name),
              subtitle: Text(option.type.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pop(option),
            ),
        ],
      ),
    );

    if (location == null || !context.mounted) return;

    try {
      final count = await ref
          .read(warehouseRepositoryProvider)
          .start(locationId: location.id);
      ref.invalidate(stockCountListProvider);
      if (context.mounted) {
        unawaited(context.push(AppRoutes.stockCountPath(count.id)));
      }
    } on AppException catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, message: error.message, tone: SnackTone.error);
      }
    }
  }
}

class _LocationCard extends ConsumerWidget {
  const _LocationCard({required this.location});

  final BranchLocation location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bins = ref.watch(binsProvider(location.id));

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        onTap: () => context.push(AppRoutes.vaultPath(location.id)),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: location.dualAuthorization
                    ? context.colors.vaultContainer
                    : context.scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                location.type == LocationType.vault
                    ? Icons.lock_outline
                    : Icons.warehouse_outlined,
                size: 20,
                color: location.dualAuthorization
                    ? context.colors.vault
                    : context.scheme.onSurfaceVariant,
              ),
            ),
            AppSpacing.wGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(location.name, style: context.text.titleSmall),
                  AppSpacing.gapXxs,
                  Text(
                    bins.maybeWhen(
                      data: (list) =>
                          '${location.type.label} · '
                          '${list.length} bin${list.length == 1 ? '' : 's'}',
                      orElse: () => location.type.label,
                    ),
                    style: context.text.bodySmall?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Surfaced because it changes what an operation will require.
            if (location.dualAuthorization)
              const StatusBadge(
                label: 'Dual auth',
                tone: StatusTone.vault,
                dense: true,
              ),
            AppSpacing.wGapSm,
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _CountRow extends ConsumerWidget {
  const _CountRow({required this.count});

  final StockCount count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reference = ref.watch(referenceDataProvider);
    final formatters = ref.watch(formattersProvider);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Expanded(
            child: Text(
              count.referenceNumber,
              style: AppTypography.mono(context, size: 13),
            ),
          ),
          StatusBadge(
            label: count.status.label,
            tone: count.status.tone,
            dense: true,
          ),
        ],
      ),
      subtitle: Text(
        [
          reference.location(count.locationId)?.name ?? 'Location',
          if (count.countedAt != null) formatters.relative(count.countedAt),
          if (count.hasVariance)
            '${count.missingCount} missing · ${count.unexpectedCount} extra',
        ].join('  ·  '),
        style: context.text.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoutes.stockCountPath(count.id)),
    );
  }
}
