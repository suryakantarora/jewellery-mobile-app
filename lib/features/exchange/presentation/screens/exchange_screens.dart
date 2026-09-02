import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/permissions.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/security/screen_guard.dart';
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
import '../../../jewellery/presentation/providers/jewellery_providers.dart';
import '../../data/exchange_repository.dart';
import '../../domain/exchange_models.dart';
import '../providers/exchange_providers.dart';
import '../../../jewellery/presentation/widgets/reference_gate.dart';

class ExchangeListScreen extends ConsumerWidget {
  const ExchangeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(exchangeListProvider);
    final type = ref.watch(exchangeTypeFilterProvider);

    return AppScaffold(
      title: context.l10n.screenExchange,
      body: ReferenceGate(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: SegmentedButton<ExchangeType?>(
                segments: const [
                  ButtonSegment(value: null, label: Text('All')),
                  ButtonSegment(
                    value: ExchangeType.exchange,
                    label: Text('Exchange'),
                  ),
                  ButtonSegment(
                    value: ExchangeType.buyback,
                    label: Text('Buyback'),
                  ),
                ],
                selected: {type},
                showSelectedIcon: false,
                onSelectionChanged: (selection) => ref
                    .read(exchangeTypeFilterProvider.notifier)
                    .set(selection.first),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: AsyncValueView<List<ExchangeRecord>>(
                value: records,
                onRetry: () => ref.invalidate(exchangeListProvider),
                isEmpty: (list) => list.isEmpty,
                empty: const EmptyState(
                  icon: Icons.currency_exchange_outlined,
                  title: 'No exchanges yet',
                  message:
                      'Old gold taken in for exchange or buyback appears here.',
                ),
                data: (list) => ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) => _Row(record: list[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.record});

  final ExchangeRecord record;

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
              record.referenceNumber,
              style: AppTypography.mono(context, size: 13),
            ),
          ),
          StatusBadge(
            label: record.status.label,
            tone: record.status.tone,
            dense: true,
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSpacing.gapXs,
          Text(
            '${record.exchangeType.label} · ${record.description ?? 'Item'}',
            style: context.text.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (record.netValuation != null) ...[
            AppSpacing.gapXs,
            Text(
              formatters.money(record.netValuation, record.currency),
              style: AppTypography.numeric(context, size: 13),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoutes.exchangePath(record.id)),
    );
  }
}

/// One exchange or buyback, step by step.
class ExchangeDetailScreen extends ConsumerStatefulWidget {
  const ExchangeDetailScreen({super.key, required this.exchangeId});

  final String exchangeId;

  @override
  ConsumerState<ExchangeDetailScreen> createState() =>
      _ExchangeDetailScreenState();
}

class _ExchangeDetailScreenState extends ConsumerState<ExchangeDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      ref
        ..invalidate(exchangeDetailProvider(widget.exchangeId))
        ..invalidate(exchangeListProvider);
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
    final record = ref.watch(exchangeDetailProvider(widget.exchangeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Exchange')),
      // Valuations and payout figures: keep them out of screenshots and the
      // task-switcher preview.
      body: ScreenGuard(
        child: AsyncValueView<ExchangeRecord>(
          value: record,
          loading: const Center(child: CircularProgressIndicator()),
          onRetry: () =>
              ref.invalidate(exchangeDetailProvider(widget.exchangeId)),
          data: _body,
        ),
      ),
      bottomNavigationBar: record.maybeWhen(
        data: _actionBar,
        orElse: () => null,
      ),
    );
  }

  Widget _body(ExchangeRecord record) {
    final formatters = ref.watch(formattersProvider);
    final reference = ref.watch(referenceDataProvider);

    /// Server-computed figures are tinted, so staff can never mistake an input
    /// for a calculated result.
    Widget computed(String label, String value) => Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: context.scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(value, style: AppTypography.numeric(context)),
    );

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
                record.referenceNumber,
                style: AppTypography.mono(context, size: 16),
              ),
            ),
            StatusBadge(label: record.status.label, tone: record.status.tone),
          ],
        ),
        AppSpacing.gapSm,
        Text(
          '${record.exchangeType.label} · ${record.description ?? ''}',
          style: context.text.bodyMedium,
        ),
        AppSpacing.gapLg,

        SectionCard(
          title: 'Weights',
          icon: Icons.scale_outlined,
          child: Column(
            children: [
              KeyValueRow(
                label: 'Gross weight',
                value: formatters.weight(record.grossWeight),
                numeric: true,
              ),
              KeyValueRow(
                label: 'Stone weight',
                value: formatters.weight(record.stoneWeight),
                numeric: true,
              ),
              KeyValueRow(
                label: 'Net metal weight',
                value: formatters.weight(record.netWeight),
                // Derived server-side, so it is marked as such.
                valueWidget: record.netWeight == null
                    ? null
                    : computed('net', formatters.weight(record.netWeight)),
              ),
              if (record.weighedBy != null)
                KeyValueRow(label: 'Weighed by', value: record.weighedBy!),
            ],
          ),
        ),
        AppSpacing.gapLg,

        SectionCard(
          title: 'Purity',
          icon: Icons.science_outlined,
          child: Column(
            children: [
              KeyValueRow(
                label: 'Declared',
                value: reference.purity(record.declaredPurityId)?.code ?? '—',
              ),
              KeyValueRow(
                label: 'Tested',
                value: reference.purity(record.testedPurityId)?.code ?? '—',
              ),
              if (record.testMethod != null)
                KeyValueRow(label: 'Method', value: record.testMethod!),
              if (record.testedBy != null)
                KeyValueRow(label: 'Tested by', value: record.testedBy!),
            ],
          ),
        ),
        AppSpacing.gapLg,

        SectionCard(
          title: 'Valuation',
          icon: Icons.payments_outlined,
          subtitle: 'Calculated by the backend',
          child: record.netValuation == null
              ? Text(
                  'Awaiting valuation.',
                  style: context.text.bodySmall?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                )
              : Column(
                  children: [
                    KeyValueRow(
                      label: 'Rate',
                      value:
                          '${formatters.money(record.ratePerUnit, record.currency)}/g',
                      valueWidget: computed(
                        'rate',
                        '${formatters.money(record.ratePerUnit, record.currency)}/g',
                      ),
                    ),
                    KeyValueRow(
                      label: 'Pure weight',
                      value: formatters.weight(record.pureWeight),
                      valueWidget: computed(
                        'pure',
                        formatters.weight(record.pureWeight),
                      ),
                    ),
                    KeyValueRow(
                      label: 'Gross valuation',
                      value: formatters.money(
                        record.grossValuation,
                        record.currency,
                      ),
                      valueWidget: computed(
                        'gross',
                        formatters.money(
                          record.grossValuation,
                          record.currency,
                        ),
                      ),
                    ),
                    KeyValueRow(
                      label:
                          'Deduction '
                          '(${formatters.percent(record.deductionPercentage)})',
                      value: formatters.money(
                        record.deductionAmount,
                        record.currency,
                      ),
                      numeric: true,
                    ),
                    const Divider(height: AppSpacing.xxl),
                    KeyValueRow(
                      label: 'Net payable',
                      value: formatters.money(
                        record.netValuation,
                        record.currency,
                      ),
                      valueWidget: Text(
                        formatters.money(record.netValuation, record.currency),
                        style: AppTypography.numeric(context, size: 20),
                      ),
                    ),
                    if (record.valuedBy != null) ...[
                      AppSpacing.gapMd,
                      Text(
                        'Valued by ${record.valuedBy}',
                        style: context.text.labelSmall?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
        ),

        if (record.approvedBy != null) ...[
          AppSpacing.gapLg,
          AppCard(
            child: Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: context.colors.success,
                ),
                AppSpacing.wGapMd,
                Expanded(
                  child: Text(
                    'Approved by ${record.approvedBy} '
                    '${formatters.relative(record.approvedAt)}',
                    style: context.text.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],

        if (record.rejectionReason != null) ...[
          AppSpacing.gapLg,
          AppCard(
            tone: context.colors.dangerContainer.withValues(alpha: 0.4),
            child: Text(
              'Rejected: ${record.rejectionReason}',
              style: context.text.bodySmall,
            ),
          ),
        ],
      ],
    );
  }

  Widget? _actionBar(ExchangeRecord record) {
    final permissions = ref.watch(permissionsProvider);
    final repository = ref.read(exchangeRepositoryProvider);
    final formatters = ref.watch(formattersProvider);

    final canProcess = permissions.has(Permission.exchangeProcess);
    final canValue = permissions.has(Permission.exchangeValue);
    final canApprove = permissions.has(Permission.exchangeApprove);

    final (label, icon, allowed, action) = switch (record.status) {
      ExchangeStatus.received => (
        'Weigh',
        Icons.scale_outlined,
        canProcess,
        () => _weigh(record, repository),
      ),
      ExchangeStatus.weighed => (
        'Test purity',
        Icons.science_outlined,
        canProcess,
        () => _testPurity(record, repository),
      ),
      ExchangeStatus.purityTested => (
        'Request valuation',
        Icons.calculate_outlined,
        canValue,
        () => _value(record, repository),
      ),
      ExchangeStatus.valued || ExchangeStatus.pendingApproval => (
        'Approve',
        Icons.check,
        canApprove,
        () => _approve(record, repository, formatters),
      ),
      ExchangeStatus.approved => (
        'Complete',
        Icons.done_all,
        canProcess,
        () => _run(() => repository.complete(record.id), 'Completed'),
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

  Future<void> _weigh(
    ExchangeRecord record,
    ExchangeRepository repository,
  ) async {
    final result = await showAppBottomSheet<({double gross, double stone})>(
      context,
      title: 'Weigh',
      subtitle: 'Net metal weight is calculated by the backend.',
      builder: (context) => const _WeighForm(),
    );
    if (result == null) return;
    await _run(
      () => repository.weigh(
        record.id,
        grossWeight: result.gross,
        stoneWeight: result.stone,
      ),
      'Weights recorded',
    );
  }

  Future<void> _testPurity(
    ExchangeRecord record,
    ExchangeRepository repository,
  ) async {
    final purities = ref
        .read(referenceDataProvider)
        .puritiesFor(record.metalId);

    final purityId = await showAppBottomSheet<String>(
      context,
      title: 'Tested purity',
      builder: (context) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final purity in purities)
            ActionChip(
              label: Text(purity.code),
              onPressed: () => Navigator.of(context).pop(purity.id),
            ),
        ],
      ),
    );
    if (purityId == null) return;

    await _run(
      () => repository.testPurity(
        record.id,
        testedPurityId: purityId,
        testMethod: 'TOUCHSTONE',
      ),
      'Purity recorded',
    );
  }

  Future<void> _value(
    ExchangeRecord record,
    ExchangeRepository repository,
  ) async {
    final deduction = await showAppBottomSheet<double>(
      context,
      title: 'Deduction',
      subtitle:
          'Refining loss or wear. Everything else is calculated by the '
          'backend from the rate and the tested purity.',
      builder: (context) => const _DeductionForm(),
    );
    if (deduction == null) return;

    await _run(
      () => repository.value(record.id, deductionPercentage: deduction),
      'Valuation requested',
    );
  }

  Future<void> _approve(
    ExchangeRecord record,
    ExchangeRepository repository,
    dynamic formatters,
  ) async {
    // Approving a payout restates the whole picture first: this is money
    // leaving the business against metal coming in.
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Approve ${record.exchangeType.label.toLowerCase()}?',
      message:
          '${record.referenceNumber}\n'
          'Net metal ${formatters.weight(record.netWeight)}\n'
          'Net payable ${formatters.money(record.netValuation, record.currency)}',
      tone: ConfirmTone.danger,
      icon: Icons.verified_user_outlined,
      confirmLabel: 'Approve payout',
    );
    if (!confirmed) return;

    await _run(() => repository.approve(record.id), 'Approved');
  }
}

class _WeighForm extends StatefulWidget {
  const _WeighForm();

  @override
  State<_WeighForm> createState() => _WeighFormState();
}

class _WeighFormState extends State<_WeighForm> {
  final _gross = TextEditingController();
  final _stone = TextEditingController(text: '0');

  @override
  void dispose() {
    _gross.dispose();
    _stone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gross = double.tryParse(_gross.text);
    final stone = double.tryParse(_stone.text) ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTextField(
          controller: _gross,
          label: 'Gross weight (g)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          prefixIcon: Icons.scale_outlined,
          onChanged: (_) => setState(() {}),
        ),
        AppSpacing.gapMd,
        AppTextField(
          controller: _stone,
          label: 'Stone weight (g)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: Icons.diamond_outlined,
          onChanged: (_) => setState(() {}),
        ),
        AppSpacing.gapXl,
        AppButton(
          label: 'Record weights',
          onPressed: (gross == null || gross <= 0 || stone > gross)
              ? null
              : () => Navigator.of(context).pop((gross: gross, stone: stone)),
        ),
      ],
    );
  }
}

class _DeductionForm extends StatefulWidget {
  const _DeductionForm();

  @override
  State<_DeductionForm> createState() => _DeductionFormState();
}

class _DeductionFormState extends State<_DeductionForm> {
  double _value = 2;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_value.toStringAsFixed(1)}%',
          style: AppTypography.numeric(context, size: 28),
        ),
        Slider(
          value: _value,
          max: 20,
          divisions: 40,
          label: '${_value.toStringAsFixed(1)}%',
          onChanged: (value) => setState(() => _value = value),
        ),
        AppSpacing.gapLg,
        AppButton(
          label: 'Request valuation',
          onPressed: () => Navigator.of(context).pop(_value),
        ),
      ],
    );
  }
}
