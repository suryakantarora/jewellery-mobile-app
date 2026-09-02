import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/extensions/widget_extensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/data_display.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../authentication/presentation/screens/branch_selector_screen.dart';

/// The signed-in user, their branch access, and their effective permissions.
///
/// The permission viewer is deliberately included: when a user reports that
/// something is missing, the answer is nearly always a permission, and having
/// it visible on the device turns a support call into a glance.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final user = session.user;

    if (user == null) {
      return const AppScaffold(body: SizedBox.shrink(), showBranchBar: false);
    }

    final permissions = session.permissions;

    return AppScaffold(
      title: context.l10n.screenProfile,
      showBranchBar: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: [
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: context.scheme.primaryContainer,
                  child: Text(
                    user.initials,
                    style: context.text.titleLarge?.copyWith(
                      color: context.scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                AppSpacing.wGapLg,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: context.text.titleMedium),
                      AppSpacing.gapXxs,
                      Text(
                        user.username,
                        style: context.text.bodySmall?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      ),
                      if (user.roles.isNotEmpty) ...[
                        AppSpacing.gapSm,
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final role in user.roles)
                              StatusBadge(
                                label: role,
                                tone: StatusTone.info,
                                dense: true,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ).entrance(index: 0),
          AppSpacing.gapLg,

          SectionCard(
            title: 'Details',
            icon: Icons.badge_outlined,
            child: Column(
              children: [
                KeyValueRow(
                  label: 'Employee code',
                  value: user.employeeCode ?? '—',
                ),
                KeyValueRow(label: 'Email', value: user.email ?? '—'),
                KeyValueRow(label: 'Phone', value: user.phone ?? '—'),
                KeyValueRow(label: 'Status', value: user.status.code),
              ],
            ),
          ).entrance(index: 1),
          AppSpacing.gapLg,

          SectionCard(
            title: 'Branch access',
            icon: Icons.storefront_outlined,
            subtitle:
                '${user.branchIds.length} branch'
                '${user.branchIds.length == 1 ? '' : 'es'}',
            trailing: user.hasMultipleBranches
                ? TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => const FractionallySizedBox(
                        heightFactor: 0.75,
                        child: BranchSelectorScreen(canDismiss: true),
                      ),
                    ),
                    child: Text(context.l10n.branchSwitch),
                  )
                : null,
            child: KeyValueRow(
              label: 'Current branch',
              value: session.branch?.name ?? '—',
            ),
          ).entrance(index: 2),
          AppSpacing.gapLg,

          ExpandableSection(
            title: 'Permissions (${permissions.granted.length})',
            icon: Icons.key_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (permissions.superAdmin) ...[
                  const StatusBadge(
                    label: 'SUPER ADMIN',
                    tone: StatusTone.vault,
                  ),
                  AppSpacing.gapMd,
                ],
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final permission in permissions.granted)
                      StatusBadge(
                        label: permission.code,
                        tone: StatusTone.neutral,
                        dense: true,
                      ),
                  ],
                ),
                // Codes this build does not model are shown rather than
                // dropped, so a backend addition is visible in the field.
                if (permissions.unknownCodes.isNotEmpty) ...[
                  AppSpacing.gapLg,
                  Text(
                    'Not recognised by this app version',
                    style: context.text.labelSmall?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                    ),
                  ),
                  AppSpacing.gapSm,
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final code in permissions.unknownCodes)
                        StatusBadge(
                          label: code,
                          tone: StatusTone.warning,
                          dense: true,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ).entrance(index: 3),
          AppSpacing.gapXl,

          AppButton(
            label: context.l10n.actionSignOut,
            icon: Icons.logout,
            variant: AppButtonVariant.danger,
            onPressed: () async {
              final confirmed = await showConfirmationDialog(
                context,
                title: context.l10n.actionSignOut,
                message: 'You will need to sign in again to continue working.',
                confirmLabel: context.l10n.actionSignOut,
                tone: ConfirmTone.danger,
                icon: Icons.logout,
              );
              if (confirmed) {
                await ref.read(sessionControllerProvider.notifier).signOut();
              }
            },
          ).entrance(index: 4),
        ],
      ),
    );
  }
}
