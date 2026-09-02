import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/permissions.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_timeline.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/data_display.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/repair_repository.dart';
import '../../domain/repair_models.dart';
import '../providers/repair_providers.dart';

/// The repair board.
///
/// The specification's status list is a board, so it renders as one — a status
/// tab bar with live counts, and "My jobs" as the default view for an artisan.
class RepairBoardScreen extends ConsumerWidget {
  const RepairBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(repairStatusProvider);
    final jobs = ref.watch(repairBoardProvider);
    final mine = ref.watch(myJobsOnlyProvider);
    final overdue = ref.watch(overdueRepairsProvider).valueOrNull ?? const [];

    return AppScaffold(
      title: context.l10n.screenRepairs,
      actions: [
        IconButton(
          tooltip: mine ? 'Showing my jobs' : 'Showing all jobs',
          icon: Icon(mine ? Icons.person : Icons.people_outline),
          onPressed: () => ref.read(myJobsOnlyProvider.notifier).toggle(),
        ),
      ],
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                for (final option in RepairStatus.board)
                  Padding(
                    padding: const EdgeInsets.only(
                      right: AppSpacing.sm,
                      top: AppSpacing.md,
                      bottom: AppSpacing.md,
                    ),
                    child: _StatusTab(
                      status: option,
                      selected: status == option,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Overdue work is pinned above everything: a promised repair that is
          // forgotten is a reputational event, not a queue entry.
          if (overdue.isNotEmpty)
            Container(
              width: double.infinity,
              color: context.colors.dangerContainer.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 16,
                    color: context.colors.danger,
                  ),
                  AppSpacing.wGapSm,
                  Expanded(
                    child: Text(
                      '${overdue.length} repair'
                      '${overdue.length == 1 ? '' : 's'} past the promised date',
                      style: context.text.labelMedium,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: AsyncValueView<List<RepairJob>>(
              value: jobs,
              onRetry: () => ref.invalidate(repairBoardProvider),
              isEmpty: (list) => list.isEmpty,
              empty: EmptyState(
                icon: Icons.build_outlined,
                title: 'Nothing in ${status.label.toLowerCase()}',
                message: mine
                    ? 'No jobs assigned to you at this stage.'
                    : 'Jobs at this stage will appear here.',
              ),
              data: (list) => RefreshIndicator(
                onRefresh: () async {
                  ref
                    ..invalidate(repairBoardProvider)
                    ..invalidate(overdueRepairsProvider);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) => _JobRow(job: list[index]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTab extends ConsumerWidget {
  const _StatusTab({required this.status, required this.selected});

  final RepairStatus status;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(repairStatusCountProvider(status)).valueOrNull;

    return ChoiceChip(
      selected: selected,
      onSelected: (_) => ref.read(repairStatusProvider.notifier).set(status),
      label: Text(count == null ? status.label : '${status.label} ($count)'),
    );
  }
}

class _JobRow extends ConsumerWidget {
  const _JobRow({required this.job});

  final RepairJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatters = ref.watch(formattersProvider);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              job.requestNumber,
              style: AppTypography.mono(context, size: 13),
            ),
          ),
          if (job.isOverdue)
            StatusBadge(label: 'Overdue', tone: StatusTone.danger, dense: true)
          else
            StatusBadge(
              label: job.status.label,
              tone: job.status.tone,
              dense: true,
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSpacing.gapXs,
          Text(
            job.itemDescription ?? 'Item',
            style: context.text.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (job.reportedProblem != null) ...[
            AppSpacing.gapXxs,
            Text(
              job.reportedProblem!,
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          AppSpacing.gapXs,
          Row(
            children: [
              if (job.estimatedCost != null) ...[
                Text(
                  formatters.money(job.estimatedCost, job.currency),
                  style: AppTypography.numeric(context, size: 12),
                ),
                Text('  ·  ', style: context.text.labelSmall),
              ],
              if (job.promisedDate != null)
                Text(
                  'Promised ${formatters.date(job.promisedDate)}',
                  style: context.text.labelSmall?.copyWith(
                    color: job.isOverdue
                        ? context.colors.danger
                        : context.scheme.onSurfaceVariant,
                  ),
                ),
              if (job.assignedTo != null) ...[
                const Spacer(),
                Text(
                  job.assignedTo!,
                  style: context.text.labelSmall?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      onTap: () => context.push(AppRoutes.repairPath(job.id)),
    );
  }
}

/// The job card, with one primary action for the current status.
class RepairJobScreen extends ConsumerStatefulWidget {
  const RepairJobScreen({super.key, required this.repairId});

  final String repairId;

  @override
  ConsumerState<RepairJobScreen> createState() => _RepairJobScreenState();
}

class _RepairJobScreenState extends ConsumerState<RepairJobScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      ref
        ..invalidate(repairDetailProvider(widget.repairId))
        ..invalidate(repairBoardProvider);
      if (mounted) {
        showAppSnackBar(context, message: success, tone: SnackTone.success);
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
    final job = ref.watch(repairDetailProvider(widget.repairId));

    return Scaffold(
      appBar: AppBar(title: const Text('Repair')),
      body: AsyncValueView<RepairJob>(
        value: job,
        loading: const Center(child: CircularProgressIndicator()),
        onRetry: () => ref.invalidate(repairDetailProvider(widget.repairId)),
        data: _body,
      ),
      bottomNavigationBar: job.maybeWhen(data: _actionBar, orElse: () => null),
    );
  }

  Widget _body(RepairJob job) {
    final formatters = ref.watch(formattersProvider);
    final delta = job.weightDelta;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.huge,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                job.requestNumber,
                style: AppTypography.mono(context, size: 16),
              ),
            ),
            StatusBadge(label: job.status.label, tone: job.status.tone),
          ],
        ),
        if (job.isOverdue) ...[
          AppSpacing.gapMd,
          AppCard(
            tone: context.colors.dangerContainer.withValues(alpha: 0.5),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 18, color: context.colors.danger),
                AppSpacing.wGapMd,
                Expanded(
                  child: Text(
                    'Promised ${formatters.date(job.promisedDate)} — overdue',
                    style: context.text.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
        AppSpacing.gapLg,

        AppCard(
          child: Column(
            children: [
              KeyValueRow(label: 'Item', value: job.itemDescription ?? '—'),
              KeyValueRow(
                label: 'Received',
                value: formatters.date(job.receivedDate),
              ),
              KeyValueRow(
                label: 'Promised',
                value: formatters.date(job.promisedDate),
              ),
              KeyValueRow(
                label: 'Weight in',
                value: formatters.weight(job.receivedWeight),
                numeric: true,
              ),
              if (job.deliveredWeight != null)
                KeyValueRow(
                  label: 'Weight out',
                  value: formatters.weight(job.deliveredWeight),
                  numeric: true,
                  // A gold item that comes back lighter is the first thing a
                  // customer checks, so any delta is called out in red.
                  valueWidget: delta != null && delta.abs() > 0.0005
                      ? Text(
                          '${formatters.weight(job.deliveredWeight)}  '
                          '(${delta > 0 ? '+' : ''}${delta.toStringAsFixed(3)})',
                          style: AppTypography.numeric(
                            context,
                            color: context.colors.danger,
                          ),
                        )
                      : null,
                ),
              if (job.assignedTo != null)
                KeyValueRow(label: 'Artisan', value: job.assignedTo!),
            ],
          ),
        ),
        AppSpacing.gapLg,

        SectionCard(
          title: 'Problem',
          icon: Icons.report_problem_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(job.reportedProblem ?? 'Not recorded'),
              if (job.conditionOnArrival != null) ...[
                AppSpacing.gapMd,
                Text(
                  'On arrival: ${job.conditionOnArrival}',
                  style: context.text.bodySmall?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),

        if (job.estimatedCost != null) ...[
          AppSpacing.gapLg,
          SectionCard(
            title: 'Estimate',
            icon: Icons.request_quote_outlined,
            child: Column(
              children: [
                KeyValueRow(
                  label: 'Cost',
                  value: formatters.money(job.estimatedCost, job.currency),
                  numeric: true,
                ),
                if (job.estimatedDays != null)
                  KeyValueRow(
                    label: 'Days',
                    value: '${job.estimatedDays}',
                    numeric: true,
                  ),
                KeyValueRow(
                  label: 'Customer',
                  value: job.customerApproved
                      ? 'Approved'
                      : job.declineReason != null
                      ? 'Declined'
                      : 'Awaiting decision',
                ),
                if (job.estimateNotes != null)
                  KeyValueRow(label: 'Notes', value: job.estimateNotes!),
              ],
            ),
          ),
        ],

        if (job.photos.isNotEmpty) ...[
          AppSpacing.gapLg,
          SectionCard(
            title: 'Photos (${job.photos.length})',
            icon: Icons.photo_library_outlined,
            subtitle: 'Evidence of condition on arrival and after work',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final photo in job.photos)
                  Chip(
                    avatar: const Icon(Icons.image_outlined, size: 16),
                    label: Text(photo.type),
                  ),
              ],
            ),
          ),
        ],

        AppSpacing.gapLg,
        SectionCard(
          title: 'History',
          icon: Icons.timeline,
          child: job.history.isEmpty
              ? Text(
                  'No transitions recorded.',
                  style: context.text.bodySmall?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                )
              : AppTimeline(
                  formatTimestamp: formatters.relative,
                  events: [
                    for (final entry in job.history.reversed)
                      TimelineEvent(
                        title: entry.toStatus?.label ?? 'Updated',
                        subtitle: entry.notes,
                        actor: entry.performedBy,
                        timestamp: entry.occurredAt,
                        tone: entry.toStatus?.tone ?? StatusTone.neutral,
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  /// One primary action per status.
  ///
  /// Derived from `allowedTransitions ∩ permissions`, so the app never guesses
  /// what a repair can do next. Repair staff should not have to choose between
  /// eight buttons on a bench.
  Widget? _actionBar(RepairJob job) {
    final permissions = ref.watch(permissionsProvider);
    final repository = ref.read(repairRepositoryProvider);

    final canProcess = permissions.has(Permission.repairProcess);
    final canEstimate = permissions.has(Permission.repairEstimate);

    final (label, icon, allowed, action) = switch (job.status) {
      RepairStatus.received => (
        'Start inspection',
        Icons.search,
        canProcess,
        () => _inspect(job, repository),
      ),
      RepairStatus.inspection => (
        'Add estimate',
        Icons.request_quote_outlined,
        canEstimate,
        () => _estimate(job, repository),
      ),
      RepairStatus.estimation || RepairStatus.approvalPending => (
        'Record decision',
        Icons.how_to_reg_outlined,
        canProcess,
        () => _decision(job, repository),
      ),
      RepairStatus.inProgress => (
        'Complete work',
        Icons.done_all,
        canProcess,
        () => _complete(job, repository),
      ),
      RepairStatus.qualityCheck => (
        'Pass quality check',
        Icons.verified_outlined,
        canProcess,
        () => _run(
          () => repository.qualityCheck(job.id, passed: true),
          'Quality check passed',
        ),
      ),
      RepairStatus.ready => (
        'Deliver',
        Icons.local_mall_outlined,
        canProcess,
        () => _deliver(job, repository),
      ),
      _ => (null, null, false, null),
    };

    if (label == null || action == null) return null;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainer,
        border: Border(top: BorderSide(color: context.scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Tooltip(
          message: allowed ? '' : context.l10n.stateNoPermission,
          child: AppButton(
            label: label,
            icon: icon,
            busy: _busy,
            onPressed: allowed ? action : null,
          ),
        ),
      ),
    );
  }

  Future<void> _inspect(RepairJob job, RepairRepository repository) async {
    final findings = await showReasonSheet(
      context,
      title: 'Inspection findings',
      hint: 'What did you find?',
    );
    if (findings == null) return;
    await _run(
      () => repository.inspect(job.id, findings: findings),
      'Inspection recorded',
    );
  }

  Future<void> _estimate(RepairJob job, RepairRepository repository) async {
    final result = await showAppBottomSheet<({double cost, int days})>(
      context,
      title: 'Estimate',
      builder: (context) => const _EstimateForm(),
    );
    if (result == null) return;
    await _run(
      () => repository.estimate(job.id, cost: result.cost, days: result.days),
      'Estimate recorded',
    );
  }

  Future<void> _decision(RepairJob job, RepairRepository repository) async {
    final approved = await showAppBottomSheet<bool>(
      context,
      title: 'Customer decision',
      subtitle: 'What did the customer say about the estimate?',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: 'Customer approved',
            icon: Icons.check,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          AppSpacing.gapMd,
          AppButton(
            label: 'Customer declined',
            variant: AppButtonVariant.outlined,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
    if (approved == null || !mounted) return;

    String? reason;
    if (!approved) {
      reason = await showReasonSheet(context, title: 'Reason for declining');
      if (reason == null) return;
    }

    await _run(
      () => repository.customerDecision(
        job.id,
        approved: approved,
        declineReason: reason,
      ),
      approved ? 'Approved by customer' : 'Declined by customer',
    );
  }

  Future<void> _complete(RepairJob job, RepairRepository repository) async {
    final notes = await showReasonSheet(
      context,
      title: 'Work completed',
      hint: 'What was done?',
    );
    if (notes == null) return;
    await _run(
      () => repository.completeWork(job.id, notes: notes),
      'Work completed',
    );
  }

  Future<void> _deliver(RepairJob job, RepairRepository repository) async {
    final recipient = await showReasonSheet(
      context,
      title: 'Delivered to',
      hint: 'Who collected it?',
    );
    if (recipient == null || !mounted) return;

    final confirmed = await showConfirmationDialog(
      context,
      title: 'Confirm delivery?',
      message: job.weightDelta != null && job.weightDelta!.abs() > 0.0005
          ? 'Weight changed by '
                '${job.weightDelta!.toStringAsFixed(3)} g since receipt.'
          : '${job.requestNumber} to $recipient.',
      tone: job.weightDelta != null && job.weightDelta!.abs() > 0.0005
          ? ConfirmTone.danger
          : ConfirmTone.normal,
    );
    if (!confirmed) return;

    await _run(
      () => repository.deliver(job.id, deliveredTo: recipient),
      'Delivered',
    );
  }
}

class _EstimateForm extends StatefulWidget {
  const _EstimateForm();

  @override
  State<_EstimateForm> createState() => _EstimateFormState();
}

class _EstimateFormState extends State<_EstimateForm> {
  final _cost = TextEditingController();
  final _days = TextEditingController(text: '3');

  @override
  void dispose() {
    _cost.dispose();
    _days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cost = double.tryParse(_cost.text);
    final days = int.tryParse(_days.text);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTextField(
          controller: _cost,
          label: 'Estimated cost',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          prefixIcon: Icons.payments_outlined,
          onChanged: (_) => setState(() {}),
        ),
        AppSpacing.gapMd,
        AppTextField(
          controller: _days,
          label: 'Estimated days',
          keyboardType: TextInputType.number,
          prefixIcon: Icons.schedule,
          onChanged: (_) => setState(() {}),
        ),
        AppSpacing.gapXl,
        AppButton(
          label: 'Save estimate',
          onPressed: (cost == null || cost <= 0 || days == null || days <= 0)
              ? null
              : () => Navigator.of(context).pop((cost: cost, days: days)),
        ),
      ],
    );
  }
}
