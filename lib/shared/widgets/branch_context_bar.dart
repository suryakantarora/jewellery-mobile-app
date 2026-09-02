import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/session_controller.dart';
import '../../core/security/session_state.dart';
import '../../core/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

/// Institution › Branch › Location, shown persistently.
///
/// Phase 3 requires this on every screen, and it is a correctness feature as
/// much as a navigational one: nearly all data in this app is branch-scoped, so
/// the user must never be uncertain which branch they are acting in.
class BranchContextBar extends ConsumerWidget {
  const BranchContextBar({super.key, this.onTap, this.dense = false});

  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session is! SessionAuthenticated) return const SizedBox.shrink();

    final user = session.user;
    // The company is resolved from the branch's companyId, and that lookup
    // needs ORGANIZATION_VIEW — which a sales executive has no reason to hold.
    // When it is missing the bar shows the branch alone rather than repeating
    // it on both sides of the separator, which read as "Vientiane Showroom ›
    // Vientiane Showroom" and looked like a bug to anyone using the app.
    final institution = session.company?.name;
    final canSwitch = user.hasMultipleBranches;

    return Material(
      color: context.scheme.surfaceContainer,
      child: InkWell(
        onTap: canSwitch ? onTap : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: dense ? AppSpacing.sm : AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                Icons.storefront_outlined,
                size: 16,
                color: context.scheme.primary,
              ),
              AppSpacing.wGapSm,
              Expanded(
                child: Row(
                  children: [
                    if (institution != null) ...[
                      Flexible(
                        child: Text(
                          institution,
                          style: context.text.labelMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _Separator(),
                    ],
                    Flexible(
                      child: Text(
                        session.branch.name,
                        style: context.text.labelMedium?.copyWith(
                          color: institution == null
                              ? null
                              : context.scheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (canSwitch) ...[
                AppSpacing.wGapSm,
                Icon(
                  Icons.unfold_more,
                  size: 16,
                  color: context.scheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    child: Text(
      '›',
      style: context.text.labelMedium?.copyWith(color: context.scheme.outline),
    ),
  );
}
