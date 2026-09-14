import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/data_display.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/approval_models.dart';
import '../providers/approval_providers.dart';

/// The approval centre.
///
/// One list from the unified approvals endpoint, oldest first, because the
/// metric that matters in a queue is how long someone has been blocked.
class ApprovalCenterScreen extends ConsumerWidget {
  const ApprovalCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingApprovalsProvider);
    final filtered = ref.watch(filteredApprovalsProvider);
    final counts =
        ref.watch(approvalCountsProvider).valueOrNull ?? ApprovalCounts.empty;
    final filter = ref.watch(approvalFilterProvider);

    void refresh() {
      ref
        ..invalidate(pendingApprovalsProvider)
        ..invalidate(approvalCountsProvider);
    }

    return AppScaffold(
      title: context.l10n.screenApprovals,
      body: Column(
        children: [
          if (counts.byKind.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                children: [
                  for (final entry in counts.byKind.entries)
                    Padding(
                      padding: const EdgeInsets.only(
                        right: AppSpacing.sm,
                        top: AppSpacing.sm,
                        bottom: AppSpacing.sm,
                      ),
                      child: ChoiceChip(
                        avatar: Icon(entry.key.icon, size: 16),
                        label: Text('${entry.key.label} (${entry.value})'),
                        selected: filter == entry.key,
                        onSelected: (selected) => ref
                            .read(approvalFilterProvider.notifier)
                            .set(selected ? entry.key : null),
                      ),
                    ),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: AsyncValueView<List<ApprovalItem>>(
              value: pending,
              onRetry: refresh,
              isEmpty: (_) => filtered.isEmpty,
              empty: const EmptyState(
                icon: Icons.check_circle_outline,
                title: 'Nothing waiting',
                message: 'Approvals you can act on will appear here.',
              ),
              data: (_) => RefreshIndicator(
                onRefresh: () async => refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _ApprovalRow(item: filtered[index]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalRow extends ConsumerStatefulWidget {
  const _ApprovalRow({required this.item});

  final ApprovalItem item;

  @override
  ConsumerState<_ApprovalRow> createState() => _ApprovalRowState();
}

class _ApprovalRowState extends ConsumerState<_ApprovalRow> {
  static const _uuid = Uuid();

  bool _busy = false;

  /// One key per decision the user expresses, minted when the row is built and
  /// replaced after each completed request. A retry of the same tap therefore
  /// carries the same key and cannot register twice.
  String _idempotencyKey = _uuid.v4();

  void _refresh() {
    ref
      ..invalidate(pendingApprovalsProvider)
      ..invalidate(approvalCountsProvider);
  }

  /// Approves, after re-reading and confirming.
  ///
  /// Anything carrying an amount, and anything vault-grade, cannot be approved
  /// from the list without a confirmation restating the figures — a mis-tap
  /// must not authorise a payout.
  Future<void> _approve() async {
    final item = widget.item;
    final formatters = ref.read(formattersProvider);

    final confirmed = await showConfirmationDialog(
      context,
      title: 'Approve ${item.kind.label.toLowerCase()}?',
      message: item.reference,
      tone: item.requiresDetailView ? ConfirmTone.danger : ConfirmTone.normal,
      icon: item.kind.icon,
      confirmLabel: 'Approve',
      detail: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppCard(
            child: Column(
              children: [
                KeyValueRow(label: 'Reference', value: item.reference),
                KeyValueRow(label: 'Summary', value: item.summary),
                if (item.branchName != null)
                  KeyValueRow(label: 'Branch', value: item.branchName!),
                if (item.requestedBy != null)
                  KeyValueRow(label: 'Requested by', value: item.requestedBy!),
                if (item.amount != null)
                  KeyValueRow(
                    label: 'Amount',
                    value: formatters.money(item.amount, item.currency),
                    numeric: true,
                  ),
              ],
            ),
          ),
          AppSpacing.gapMd,
          InformationThread(item: item),
        ],
      ),
    );

    if (!confirmed || !mounted) return;
    await _decide(ApprovalDecision.approve, success: 'approved');
  }

  Future<void> _reject() async {
    final reason = await showReasonSheet(
      context,
      title: 'Reason for rejection',
      hint: 'The requester sees this.',
    );
    if (reason == null || !mounted) return;
    await _decide(ApprovalDecision.reject, reason: reason, success: 'rejected');
  }

  Future<void> _requestInfo() async {
    final reason = await showReasonSheet(
      context,
      title: 'What do you need to know?',
      hint: 'The requester is asked to answer before you decide.',
    );
    if (reason == null || !mounted) return;
    await _decide(
      ApprovalDecision.requestInfo,
      reason: reason,
      success: 'information requested',
    );
  }

  Future<void> _decide(
    ApprovalDecision decision, {
    String? reason,
    required String success,
  }) async {
    final item = widget.item;
    setState(() => _busy = true);
    try {
      await ref
          .read(approvalRepositoryProvider)
          .decide(
            item,
            decision: decision,
            reason: reason,
            idempotencyKey: _idempotencyKey,
          );
      _idempotencyKey = _uuid.v4();
      _refresh();
      if (mounted) {
        showAppSnackBar(
          context,
          message: '${item.reference} $success',
          tone: SnackTone.success,
        );
      }
    } on ConflictException catch (error) {
      // The dual-authorisation path lands here when the same person tries to
      // approve twice; the backend's message is the clearest explanation.
      _idempotencyKey = _uuid.v4();
      if (mounted) {
        showAppSnackBar(context, message: error.message, tone: SnackTone.error);
      }
      _refresh();
    } on AppException catch (error) {
      if (mounted) {
        showAppSnackBar(context, message: error.message, tone: SnackTone.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openThread() {
    final item = widget.item;
    return showAppBottomSheet<void>(
      context,
      title: 'Information requests',
      subtitle: item.reference,
      builder: (_) => InformationThread(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final formatters = ref.watch(formattersProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.kind.icon, size: 16, color: context.scheme.primary),
              AppSpacing.wGapSm,
              Text(
                item.kind.label.toUpperCase(),
                style: context.text.labelSmall?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (item.infoRequested) ...[
                const StatusBadge(
                  label: 'Info requested',
                  tone: StatusTone.info,
                  icon: Icons.help_outline,
                  dense: true,
                ),
                AppSpacing.wGapSm,
              ],
              if (item.awaitingSecondApproval)
                const StatusBadge(
                  label: '1 of 2',
                  tone: StatusTone.vault,
                  dense: true,
                ),
            ],
          ),
          AppSpacing.gapSm,
          Text(item.reference, style: AppTypography.mono(context, size: 14)),
          AppSpacing.gapXxs,
          Text(item.summary, style: context.text.bodyMedium),
          if (item.detail != null && item.detail!.isNotEmpty) ...[
            AppSpacing.gapXxs,
            Text(
              item.detail!,
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ],

          if (item.amount != null) ...[
            AppSpacing.gapXs,
            Text(
              formatters.money(item.amount, item.currency),
              style: AppTypography.numeric(context, size: 16),
            ),
          ],

          AppSpacing.gapXs,
          Row(
            children: [
              if (item.branchName != null) ...[
                Text(
                  item.branchName!,
                  style: context.text.labelSmall?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                ),
                Text('  ·  ', style: context.text.labelSmall),
              ],
              if (item.requestedBy != null)
                Text(
                  item.requestedBy!,
                  style: context.text.labelSmall?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                ),
              if (item.requestedAt != null) ...[
                Text('  ·  ', style: context.text.labelSmall),
                Text(
                  formatters.relative(item.requestedAt),
                  style: context.text.labelSmall?.copyWith(
                    // Age is the queue metric that matters, so an old item
                    // reads differently from a fresh one.
                    color: (item.age?.inHours ?? 0) > 24
                        ? context.colors.danger
                        : context.scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),

          AppSpacing.gapMd,
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Approve',
                  icon: Icons.check,
                  busy: _busy,
                  onPressed: _approve,
                ),
              ),
              AppSpacing.wGapMd,
              AppButton(
                label: 'Reject',
                variant: AppButtonVariant.outlined,
                expand: false,
                onPressed: _busy ? null : _reject,
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                enabled: !_busy,
                onSelected: (value) => switch (value) {
                  'info' => _requestInfo(),
                  _ => _openThread(),
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'info',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.help_outline),
                      title: Text('Request information'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'thread',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.forum_outlined),
                      title: Text('View thread'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The question-and-answer thread on one pending item.
///
/// Approvers read it; holders of the type's *create* permission — the
/// requester's side — get an inline answer field on each open question.
class InformationThread extends ConsumerWidget {
  const InformationThread({super.key, required this.item});

  final ApprovalItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (kind: item.kind, id: item.id);
    final thread = ref.watch(approvalInformationProvider(key));
    final canAnswer = ref
        .watch(permissionsProvider)
        .has(item.kind.createPermission);
    final formatters = ref.watch(formattersProvider);

    return AsyncValueView<List<InformationRequest>>(
      value: thread,
      loading: const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      onRetry: () => ref.invalidate(approvalInformationProvider(key)),
      isEmpty: (list) => list.isEmpty,
      empty: const EmptyState(
        icon: Icons.forum_outlined,
        title: 'No questions asked',
        compact: true,
      ),
      data: (requests) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final request in requests) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          [
                            request.requestedBy ?? 'Approver',
                            if (request.requestedAt != null)
                              formatters.relative(request.requestedAt),
                          ].join(' · '),
                          style: context.text.labelSmall?.copyWith(
                            color: context.scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      StatusBadge(
                        label: request.open ? 'Open' : 'Answered',
                        tone: request.open
                            ? StatusTone.warning
                            : StatusTone.success,
                        dense: true,
                      ),
                    ],
                  ),
                  AppSpacing.gapXs,
                  Text(request.message, style: context.text.bodyMedium),
                  if (request.answer != null) ...[
                    AppSpacing.gapSm,
                    Text(
                      [
                        request.answeredBy ?? 'Requester',
                        if (request.answeredAt != null)
                          formatters.relative(request.answeredAt),
                      ].join(' · '),
                      style: context.text.labelSmall?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                    ),
                    AppSpacing.gapXxs,
                    Text(request.answer!, style: context.text.bodyMedium),
                  ] else if (canAnswer) ...[
                    AppSpacing.gapSm,
                    _AnswerField(item: item, request: request),
                  ],
                ],
              ),
            ),
            AppSpacing.gapSm,
          ],
        ],
      ),
    );
  }
}

class _AnswerField extends ConsumerStatefulWidget {
  const _AnswerField({required this.item, required this.request});

  final ApprovalItem item;
  final InformationRequest request;

  @override
  ConsumerState<_AnswerField> createState() => _AnswerFieldState();
}

class _AnswerFieldState extends ConsumerState<_AnswerField> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final answer = _controller.text.trim();
    if (answer.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(approvalRepositoryProvider)
          .answer(
            widget.item.kind,
            widget.item.id,
            requestId: widget.request.id,
            answer: answer,
          );
      ref
        ..invalidate(
          approvalInformationProvider((
            kind: widget.item.kind,
            id: widget.item.id,
          )),
        )
        ..invalidate(pendingApprovalsProvider);
      if (mounted) {
        showAppSnackBar(
          context,
          message: 'Answer sent',
          tone: SnackTone.success,
        );
      }
    } on AppException catch (error) {
      if (mounted) {
        showAppSnackBar(context, message: error.message, tone: SnackTone.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: AppTextField(
            controller: _controller,
            hint: 'Answer',
            maxLines: 3,
            enabled: !_busy,
            onChanged: (_) => setState(() {}),
          ),
        ),
        AppSpacing.wGapSm,
        AppButton(
          label: 'Send',
          expand: false,
          busy: _busy,
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
        ),
      ],
    );
  }
}
