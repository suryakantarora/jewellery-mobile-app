import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/notification_models.dart';
import '../providers/notification_providers.dart';

/// The notification centre.
///
/// Functional against what the backend actually provides today, which is very
/// little: an outbound delivery log with no read state, no per-user inbox and
/// no push. The list, grouping, deep linking and read tracking are all built —
/// they simply have almost nothing to show until staff-directed events exist.
class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return AppScaffold(
      title: context.l10n.screenNotifications,
      showBranchBar: false,
      actions: [
        if (unread > 0)
          TextButton(
            onPressed: () async {
              await ref.read(notificationRepositoryProvider).markAllRead();
              ref.invalidate(notificationsProvider);
              unawaited(
                ref
                    .read(unreadNotificationCountControllerProvider.notifier)
                    .refresh(),
              );
            },
            child: const Text('Mark all read'),
          ),
      ],
      body: Column(
        children: [
          const _BackendNotice(),
          Expanded(
            child: AsyncValueView<List<AppNotification>>(
              value: notifications,
              onRetry: () => ref.invalidate(notificationsProvider),
              isEmpty: (list) => list.isEmpty,
              empty: const EmptyState(
                icon: Icons.notifications_none,
                title: 'No notifications',
                message:
                    'Transfers and stock alerts for your branch will '
                    'appear here.',
              ),
              data: (list) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(notificationsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _NotificationRow(notification: list[index]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// States the limitation plainly rather than presenting an empty list as if it
/// meant "nothing has happened".
/// Says only what is still missing.
///
/// Read state moved to the server with `/notifications/mine`, so the old
/// "stored on this device only" caveat had become untrue — and a stale caveat
/// is worse than none: it tells staff not to trust something that now works.
class _BackendNotice extends StatelessWidget {
  const _BackendNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AppCard(
        tone: context.colors.infoContainer.withValues(alpha: 0.4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: context.colors.info),
            AppSpacing.wGapMd,
            Expanded(
              child: Text(
                'New notifications appear when you open this screen. Push '
                'delivery is not available yet.',
                style: context.text.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  const _NotificationRow({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatters = ref.watch(formattersProvider);
    final canOpen = NotificationRouter.canOpen(notification);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      leading: StatusDot(
        tone: notification.read ? StatusTone.neutral : notification.tone,
        size: 10,
      ),
      title: Text(
        notification.title,
        style: context.text.titleSmall?.copyWith(
          fontWeight: notification.read ? FontWeight.w400 : FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notification.body != null) ...[
            AppSpacing.gapXxs,
            Text(
              notification.body!,
              style: context.text.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          AppSpacing.gapXs,
          Text(
            formatters.relative(notification.occurredAt),
            style: context.text.labelSmall?.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: canOpen ? const Icon(Icons.chevron_right) : null,
      onTap: () async {
        await ref
            .read(notificationRepositoryProvider)
            .markRead(notification.id);
        ref.invalidate(notificationsProvider);
        unawaited(
          ref
              .read(unreadNotificationCountControllerProvider.notifier)
              .refresh(),
        );

        final route = NotificationRouter.routeFor(notification);
        if (route != null && context.mounted) {
          unawaited(context.push(route));
        }
      },
    );
  }
}
