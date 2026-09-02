import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity/connectivity_controller.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

/// A persistent connectivity banner.
///
/// Shows nothing while online — a permanent "connected" badge is noise. The
/// distinction between offline and degraded matters to staff: one means walk
/// somewhere else, the other means the server is having trouble.
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectivityProvider);

    return AnimatedSize(
      duration: AppMotion.normal,
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      child: state == ConnectivityState.online
          ? const SizedBox(width: double.infinity)
          : _Banner(state: state),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.state});

  final ConnectivityState state;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (state) {
      ConnectivityState.offline => (
        context.colors.neutralContainer,
        context.colors.neutral,
        Icons.cloud_off_outlined,
      ),
      ConnectivityState.degraded => (
        context.colors.warningContainer,
        context.colors.warning,
        Icons.signal_wifi_statusbar_null_outlined,
      ),
      ConnectivityState.syncing => (
        context.colors.infoContainer,
        context.colors.info,
        Icons.sync,
      ),
      ConnectivityState.syncFailed => (
        context.colors.dangerContainer,
        context.colors.danger,
        Icons.sync_problem,
      ),
      ConnectivityState.online => (
        context.colors.successContainer,
        context.colors.success,
        Icons.cloud_done_outlined,
      ),
    };

    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(icon, size: 16, color: foreground),
            AppSpacing.wGapSm,
            Expanded(
              child: Text(switch (state) {
                ConnectivityState.offline =>
                  "You're offline — showing what was already loaded",
                ConnectivityState.degraded =>
                  'Trouble reaching the server — some actions may fail',
                ConnectivityState.syncing => 'Syncing…',
                ConnectivityState.syncFailed =>
                  'Sync failed — retry when you have a connection',
                ConnectivityState.online => 'Online',
              }, style: context.text.labelMedium),
            ),
          ],
        ),
      ),
    );
  }
}
