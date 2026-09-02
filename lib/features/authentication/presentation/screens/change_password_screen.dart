import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_backdrop.dart';
import '../../../../shared/widgets/app_inputs.dart';

/// Forced password change.
///
/// The route guard makes this unskippable — there is no back affordance and no
/// other route is reachable while the session is in this state, which matches
/// the backend's `mustChangePassword` flag being a precondition rather than a
/// suggestion.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .changePassword(
            currentPassword: _currentPassword.text,
            newPassword: _newPassword.text,
          );
      // On success the session advances and the router redirects away.
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.password_outlined,
                        size: 44,
                        color: context.scheme.primary,
                      ),
                      AppSpacing.gapLg,
                      Text(
                        'Set a new password',
                        style: context.text.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      AppSpacing.gapSm,
                      Text(
                        'Your administrator requires a password change before '
                        'you can continue.',
                        style: context.text.bodyMedium?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      AppSpacing.gapXxl,
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: context.colors.danger.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: AppRadius.cardRadius,
                            border: Border.all(
                              color: context.colors.danger.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 18,
                                color: context.colors.danger,
                              ),
                              AppSpacing.wGapSm,
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: context.text.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapLg,
                      ],
                      AppPasswordField(
                        controller: _currentPassword,
                        label: 'Current password',
                        enabled: !_busy,
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Enter your current password'
                            : null,
                      ),
                      AppSpacing.gapLg,
                      AppPasswordField(
                        controller: _newPassword,
                        label: 'New password',
                        enabled: !_busy,
                        validator: (value) => (value?.length ?? 0) < 8
                            ? 'Use at least 8 characters'
                            : null,
                      ),
                      AppSpacing.gapLg,
                      AppPasswordField(
                        controller: _confirmPassword,
                        label: 'Confirm new password',
                        enabled: !_busy,
                        validator: (value) => value != _newPassword.text
                            ? 'Passwords do not match'
                            : null,
                      ),
                      AppSpacing.gapXxl,
                      AppButton(
                        label: context.l10n.actionContinue,
                        busy: _busy,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
