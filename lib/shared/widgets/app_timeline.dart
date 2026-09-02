import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';
import 'status_badge.dart';

/// One node on a timeline.
class TimelineEvent {
  const TimelineEvent({
    required this.title,
    this.subtitle,
    this.actor,
    this.timestamp,
    this.tone = StatusTone.neutral,
    this.icon,
    this.detail,
  });

  final String title;
  final String? subtitle;

  /// Who performed it — the backend supplies `performedBy` / `approvedBy`, and
  /// on an audit trail the actor matters as much as the event.
  final String? actor;

  final DateTime? timestamp;
  final StatusTone tone;
  final IconData? icon;

  /// Optional expanded content, e.g. a rejection reason.
  final Widget? detail;
}

/// A vertical timeline.
///
/// Used by the digital passport lifecycle, transfer history, repair job cards,
/// exchange approval chains and customer activity — which is why it is built
/// once here rather than five times later.
class AppTimeline extends StatelessWidget {
  const AppTimeline({
    super.key,
    required this.events,
    this.formatTimestamp,
    this.shrinkWrap = true,
  });

  final List<TimelineEvent> events;

  /// Injected so the widget stays free of formatting and locale concerns.
  final String Function(DateTime)? formatTimestamp;

  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.zero,
      itemCount: events.length,
      itemBuilder: (context, index) => _TimelineNode(
        event: events[index],
        isFirst: index == 0,
        isLast: index == events.length - 1,
        formatTimestamp: formatTimestamp,
      ),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.event,
    required this.isFirst,
    required this.isLast,
    required this.formatTimestamp,
  });

  final TimelineEvent event;
  final bool isFirst;
  final bool isLast;
  final String Function(DateTime)? formatTimestamp;

  @override
  Widget build(BuildContext context) {
    final lineColor = context.scheme.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                // The connector above the first node is omitted so the timeline
                // reads as beginning rather than being cut off.
                SizedBox(
                  height: 6,
                  child: isFirst
                      ? null
                      : VerticalDivider(width: 1, color: lineColor),
                ),
                _Marker(tone: event.tone, icon: event.icon, filled: isFirst),
                Expanded(
                  child: isLast
                      ? const SizedBox.shrink()
                      : VerticalDivider(width: 1, color: lineColor),
                ),
              ],
            ),
          ),
          AppSpacing.wGapSm,
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 2,
                bottom: isLast ? 0 : AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: context.text.titleSmall,
                        ),
                      ),
                      if (event.timestamp != null)
                        Text(
                          formatTimestamp?.call(event.timestamp!) ??
                              event.timestamp!.toIso8601String(),
                          style: context.text.labelSmall?.copyWith(
                            color: context.scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  if (event.subtitle != null) ...[
                    AppSpacing.gapXs,
                    Text(
                      event.subtitle!,
                      style: context.text.bodySmall?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (event.actor != null) ...[
                    AppSpacing.gapXs,
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 12,
                          color: context.scheme.onSurfaceVariant,
                        ),
                        AppSpacing.wGapXs,
                        Text(
                          event.actor!,
                          style: context.text.labelSmall?.copyWith(
                            color: context.scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (event.detail != null) ...[
                    AppSpacing.gapSm,
                    event.detail!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.tone, required this.icon, required this.filled});

  final StatusTone tone;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = switch (tone) {
      StatusTone.success => colors.success,
      StatusTone.warning => colors.warning,
      StatusTone.danger => colors.danger,
      StatusTone.info => colors.info,
      StatusTone.neutral => colors.neutral,
      StatusTone.vault => colors.vault,
    };

    if (icon != null) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 13, color: color),
      );
    }

    return Container(
      width: 11,
      height: 11,
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color : context.scheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}
