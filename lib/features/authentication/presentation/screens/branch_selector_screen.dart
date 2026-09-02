import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/extensions/widget_extensions.dart';
import '../../../../shared/models/organization.dart';
import '../../../../shared/widgets/app_backdrop.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_badge.dart';

/// Branches the signed-in user may act in.
final _userBranchesProvider = FutureProvider.autoDispose<List<Branch>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(authRepositoryProvider).branchesFor(user);
});

/// Branch selection, shown when a user has access to more than one.
///
/// Also reachable later from the context bar, which is why it renders as a
/// normal screen with a back affordance when a session already exists.
class BranchSelectorScreen extends ConsumerWidget {
  const BranchSelectorScreen({super.key, this.canDismiss = false});

  /// True when opened as a switcher rather than as a required step.
  final bool canDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(_userBranchesProvider);

    return Scaffold(
      appBar: canDismiss
          ? AppBar(title: Text(context.l10n.branchSwitch))
          : null,
      body: AppBackdrop(
        intensity: 0.6,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!canDismiss)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    AppSpacing.xxxl,
                    AppSpacing.xxl,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.branchSelectTitle,
                        style: context.text.headlineMedium,
                      ),
                      AppSpacing.gapSm,
                      Text(
                        context.l10n.branchSelectSubtitle,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: AsyncValueView<List<Branch>>(
                  value: branches,
                  onRetry: () => ref.invalidate(_userBranchesProvider),
                  isEmpty: (list) => list.isEmpty,
                  empty: EmptyState(
                    icon: Icons.storefront_outlined,
                    title: context.l10n.loginNoBranch,
                    // Without this the generic "it will appear here" copy shows,
                    // which reads as a loading state rather than a dead end.
                    message:
                        'Branch access is granted in the admin portal. '
                        'Until then there is nothing to work in.',
                    action: TextButton(
                      onPressed: () => ref
                          .read(sessionControllerProvider.notifier)
                          .signOut(),
                      child: Text(context.l10n.actionSignOut),
                    ),
                  ),
                  data: (list) => ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => AppSpacing.gapMd,
                    itemBuilder: (context, index) {
                      final branch = list[index];
                      final selected =
                          ref.watch(currentBranchProvider)?.id == branch.id;

                      return _BranchTile(
                        branch: branch,
                        selected: selected,
                        onTap: () async {
                          await ref
                              .read(sessionControllerProvider.notifier)
                              .selectBranch(branch);
                          if (canDismiss && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      ).entrance(index: index);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchTile extends StatelessWidget {
  const _BranchTile({
    required this.branch,
    required this.selected,
    required this.onTap,
  });

  final Branch branch;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? context.scheme.primaryContainer.withValues(alpha: 0.45)
          : context.scheme.surfaceContainerLow,
      borderRadius: AppRadius.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: AppSpacing.card,
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(
              color: selected
                  ? context.scheme.primary
                  : context.scheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: AppSizes.avatar,
                height: AppSizes.avatar,
                decoration: BoxDecoration(
                  color: context.scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                alignment: Alignment.center,
                child: Text(
                  branch.code,
                  style: context.text.labelMedium?.copyWith(
                    color: context.scheme.primary,
                  ),
                ),
              ),
              AppSpacing.wGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(branch.name, style: context.text.titleSmall),
                    if (branch.city != null) ...[
                      AppSpacing.gapXxs,
                      Text(
                        [
                          branch.city,
                          branch.country,
                        ].whereType<String>().join(', '),
                        style: context.text.bodySmall?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (branch.headOffice)
                StatusBadge(
                  label: context.l10n.branchHeadOffice,
                  tone: StatusTone.info,
                  dense: true,
                ),
              if (selected) ...[
                AppSpacing.wGapSm,
                Icon(
                  Icons.check_circle,
                  color: context.scheme.primary,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
