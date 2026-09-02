import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

/// Empty, error and permission states.
///
/// These exist once, in Phase 1, because every list and detail screen in the
/// remaining sixteen phases needs them and they are exactly the thing that gets
/// improvised inconsistently when each feature invents its own.

/// Nothing to show — and, importantly, distinguishable from "not permitted".
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    this.title,
    this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String? title;
  final String? message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 48 : 72,
              height: compact ? 48 : 72,
              decoration: BoxDecoration(
                color: context.scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: compact ? 24 : 32,
                color: context.scheme.onSurfaceVariant,
              ),
            ),
            AppSpacing.gapLg,
            Text(
              title ?? context.l10n.stateEmptyTitle,
              style: context.text.titleMedium,
              textAlign: TextAlign.center,
            ),
            AppSpacing.gapSm,
            Text(
              message ?? context.l10n.stateEmptyMessage,
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[AppSpacing.gapXl, action!],
          ],
        ),
      ),
    );
  }
}

/// A failure, with the correlation id shown so support can trace the exact
/// request rather than asking the user what they were doing.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final exception = error is AppException ? error as AppException : null;
    final isPermission = exception is ForbiddenException;
    final isOffline =
        exception is NetworkException || exception is OfflineActionException;

    final tone = isPermission
        ? context.colors.warning
        : isOffline
        ? context.colors.neutral
        : context.colors.danger;

    final icon = isPermission
        ? Icons.lock_outline
        : isOffline
        ? Icons.cloud_off_outlined
        : Icons.error_outline;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 48 : 72,
              height: compact ? 48 : 72,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: compact ? 24 : 32, color: tone),
            ),
            AppSpacing.gapLg,
            Text(
              isPermission
                  ? context.l10n.stateNoPermission
                  : context.l10n.stateErrorTitle,
              style: context.text.titleMedium,
              textAlign: TextAlign.center,
            ),
            AppSpacing.gapSm,
            Text(
              exception?.message ?? context.l10n.stateErrorTitle,
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (exception?.correlationId != null) ...[
              AppSpacing.gapMd,
              SelectableText(
                context.l10n.stateReferenceId(exception!.correlationId!),
                style: context.text.labelSmall?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
            ],
            // A permission failure is not retryable — offering a retry button
            // would invite the user to bang on a locked door.
            if (onRetry != null && !isPermission) ...[
              AppSpacing.gapXl,
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.actionRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A screen or section the user's permissions do not cover.
class NoPermissionState extends StatelessWidget {
  const NoPermissionState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.lock_outline,
    title: context.l10n.stateNoPermission,
    message: message,
  );
}
