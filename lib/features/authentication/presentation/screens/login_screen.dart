import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/security/session_state.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/extensions/widget_extensions.dart';
import '../../../../core/security/screen_guard.dart';
import '../../../../shared/widgets/app_backdrop.dart';
import '../../../../shared/widgets/app_inputs.dart';
import 'splash_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Staff sign in on the same device every day; remembering the username
    // saves a step without weakening anything.
    _usernameController.text =
        ref.read(localStoreProvider).getString(StorageKeys.lastUsername) ?? '';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
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
          .signIn(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          );
      // On success the session state changes and the router redirects; this
      // screen is disposed, so there is nothing to do here.
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) setState(() => _error = context.l10n.loginFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A session that ended on its own should say so, rather than silently
    // presenting a fresh login form.
    final session = ref.watch(sessionControllerProvider);
    final expiredMessage =
        session is SessionUnauthenticated &&
            session.reason == SignOutReason.sessionExpired
        ? context.l10n.sessionExpired
        : null;

    return Scaffold(
      // Credentials on screen: block screenshots and the task-switcher preview.
      body: ScreenGuard(
        child: AppBackdrop(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: ConstrainedBox(
                  // Keeps the form readable on a tablet instead of stretching it
                  // across the full width.
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Square-constrained: the painter lays out from its
                        // width, so an unbounded box would stretch the mark flat.
                        Center(
                          child: SizedBox.square(
                            dimension: 64,
                            child: CustomPaint(
                              painter: BrandMarkPainter(
                                primary: context.scheme.primary,
                                secondary: context.scheme.tertiary,
                              ),
                            ),
                          ),
                        ).entrance(index: 0),
                        AppSpacing.gapXl,
                        Text(
                          context.l10n.loginTitle,
                          style: context.text.displaySmall,
                          textAlign: TextAlign.center,
                        ).entrance(index: 1),
                        AppSpacing.gapSm,
                        Text(
                          context.l10n.loginSubtitle,
                          style: context.text.bodyMedium?.copyWith(
                            color: context.scheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ).entrance(index: 2),
                        AppSpacing.gapXxl,

                        if (expiredMessage != null && _error == null) ...[
                          _Notice(message: expiredMessage),
                          AppSpacing.gapLg,
                        ],
                        if (_error != null) ...[
                          _Notice(message: _error!, isError: true),
                          AppSpacing.gapLg,
                        ],

                        AppTextField(
                          controller: _usernameController,
                          label: context.l10n.loginUsername,
                          prefixIcon: Icons.person_outline,
                          enabled: !_busy,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          textCapitalization: TextCapitalization.none,
                          onSubmitted: (_) => _passwordFocus.requestFocus(),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? context.l10n.loginUsername
                              : null,
                        ).entrance(index: 3),
                        AppSpacing.gapLg,
                        AppPasswordField(
                          controller: _passwordController,
                          label: context.l10n.loginPassword,
                          enabled: !_busy,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          validator: (value) => (value == null || value.isEmpty)
                              ? context.l10n.loginPassword
                              : null,
                        ).entrance(index: 4),
                        AppSpacing.gapXxl,
                        AppButton(
                          label: context.l10n.actionSignIn,
                          busy: _busy,
                          onPressed: _submit,
                        ).entrance(index: 5),
                        AppSpacing.gapXl,
                        const _DevCredentialsHint().entrance(index: 6),
                      ],
                    ),
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

class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final tone = isError ? context.colors.danger : context.colors.info;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            size: 18,
            color: tone,
          ),
          AppSpacing.wGapSm,
          Expanded(child: Text(message, style: context.text.bodySmall)),
        ],
      ),
    );
  }
}

/// Build context for non-production builds.
///
/// Shows the development sign-in profiles only when the build is actually using
/// the in-memory authentication. Against a real backend it shows the API it is
/// pointed at instead — claiming "any password" while talking to a live server
/// would send someone chasing a login failure that was never a bug.
class _DevCredentialsHint extends ConsumerWidget {
  const _DevCredentialsHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    if (!config.environment.allowsDeveloperTools) {
      return const SizedBox.shrink();
    }

    final usingDevAuth = config.useDevAuth;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.construction_outlined,
                size: 14,
                color: context.scheme.onSurfaceVariant,
              ),
              AppSpacing.wGapXs,
              Expanded(
                child: Text(
                  usingDevAuth
                      ? '${config.environment.label} build · offline sign-in'
                      : '${config.environment.label} build',
                  style: context.text.labelSmall?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.gapSm,
          if (usingDevAuth) ...[
            Text(
              'sales · warehouse · repair · manager',
              style: context.text.bodySmall,
            ),
            Text(
              'Any password. Each username loads a different permission profile.',
              style: context.text.labelSmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ] else
            Text(
              config.apiBaseUrl,
              style: AppTypography.mono(context, size: 11),
            ),
        ],
      ),
    );
  }
}
