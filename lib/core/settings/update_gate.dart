import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/extensions/context_extensions.dart';
import '../../shared/widgets/app_dialogs.dart';
import '../../shared/widgets/app_inputs.dart';
import '../theme/app_spacing.dart';
import 'app_version_service.dart';

/// Sits above the router and enforces the backend's version policy.
///
/// - `forceUpdate` → the whole app is replaced by [ForceUpdateScreen]. Nothing
///   underneath is reachable, which is the point: a build the backend has
///   retired must not be able to write a sale.
/// - a newer `latest` → one snackbar per session, dismissible.
/// - unknown / failed check → nothing. A version check that cannot complete
///   never blocks the app.
class UpdateGate extends ConsumerWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(appUpdateProvider).valueOrNull;

    if (update == null) return child;

    if (update.isForced) {
      return ForceUpdateScreen(info: update);
    }

    if (update.status == UpdateStatus.updateAvailable &&
        !ref.read(updateNudgeShownProvider)) {
      ref.read(updateNudgeShownProvider.notifier).markShown();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        _showNudge(context, update);
      });
    }

    return child;
  }

  void _showNudge(BuildContext context, AppUpdateInfo info) {
    // The gate sits above MaterialApp's navigator, so the nearest messenger
    // may not exist yet on the very first frame; if so, skip quietly.
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final storeUrl = info.storeUrl;
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(
          info.message ??
              'Version ${info.latest} is available. Update when convenient.',
        ),
        action: storeUrl == null
            ? null
            : SnackBarAction(
                label: 'Update',
                onPressed: () => openStore(context, storeUrl),
              ),
      ),
    );
  }
}

/// Opens the store listing in the platform's store app or browser.
Future<void> openStore(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final opened =
      uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    showAppSnackBar(
      context,
      message: 'Could not open the store. Update from the store app instead.',
      tone: SnackTone.error,
    );
  }
}

/// Full-screen block. No back, no dismiss, no way through.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key, required this.info});

  final AppUpdateInfo info;

  @override
  Widget build(BuildContext context) {
    final storeUrl = info.storeUrl;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.system_update_outlined,
                      size: 64,
                      color: context.scheme.primary,
                    ),
                    AppSpacing.gapXl,
                    Text(
                      'Update required',
                      style: context.text.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.gapMd,
                    Text(
                      info.message ??
                          'This version of the app is no longer supported. '
                              'Install the latest version to continue.',
                      style: context.text.bodyMedium?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (info.currentVersion != null ||
                        info.minSupported != null) ...[
                      AppSpacing.gapLg,
                      Text(
                        [
                          if (info.currentVersion != null)
                            'Installed ${info.currentVersion}',
                          if (info.minSupported != null)
                            'Minimum ${info.minSupported}',
                          if (info.latest != null) 'Latest ${info.latest}',
                        ].join('  ·  '),
                        style: context.text.bodySmall?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    AppSpacing.gapXxl,
                    AppButton(
                      label: 'Update now',
                      icon: Icons.open_in_new,
                      // No store URL means the deployment has not published
                      // one yet; the screen still blocks, and says why.
                      onPressed: storeUrl == null
                          ? null
                          : () => openStore(context, storeUrl),
                    ),
                    if (storeUrl == null) ...[
                      AppSpacing.gapMd,
                      Text(
                        'Ask your administrator for the new build.',
                        style: context.text.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
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
