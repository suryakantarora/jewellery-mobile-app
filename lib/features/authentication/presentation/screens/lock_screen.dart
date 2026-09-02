import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_backdrop.dart';
import '../../../../shared/widgets/app_inputs.dart';

/// Shown when the session locks on inactivity.
///
/// Credentials are intact — this is a re-assertion of presence, not a re-login,
/// so unlocking returns the user exactly where they were. Signing out is
/// offered as a secondary action for a shared device.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _busy = false;

  Future<void> _unlock() async {
    setState(() => _busy = true);
    // Phase 2 puts a real credential or biometric check here; the state
    // machine and routing around it are already final.
    await ref.read(sessionControllerProvider.notifier).unlock();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 34,
                        backgroundColor: context.scheme.primaryContainer,
                        child: Text(
                          user?.initials ?? '?',
                          style: context.text.headlineSmall?.copyWith(
                            color: context.scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                    AppSpacing.gapLg,
                    Text(
                      user?.fullName ?? context.l10n.lockTitle,
                      style: context.text.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.gapXs,
                    Text(
                      context.l10n.lockSubtitle,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.gapXxl,
                    AppButton(
                      label: context.l10n.lockUnlock,
                      icon: Icons.lock_open_outlined,
                      busy: _busy,
                      onPressed: _unlock,
                    ),
                    AppSpacing.gapSm,
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => ref
                                .read(sessionControllerProvider.notifier)
                                .signOut(),
                      child: Text(context.l10n.actionSignOut),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
