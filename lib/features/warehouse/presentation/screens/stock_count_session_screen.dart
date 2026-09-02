import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/constants/permissions.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../scanner/domain/scan_session.dart';
import '../../../scanner/presentation/providers/scanner_providers.dart';
import '../../../scanner/presentation/screens/scan_screen.dart';
import '../../domain/warehouse_models.dart';
import '../providers/warehouse_providers.dart';

/// A physical stock count in progress.
///
/// Scans accumulate locally and are written through to storage on every scan;
/// nothing reaches the backend until submit. That is what makes this the one
/// workflow in the app that is safe without a connection — no server state
/// changes until the counter commits.
class StockCountSessionScreen extends ConsumerStatefulWidget {
  const StockCountSessionScreen({super.key, required this.countId});

  final String countId;

  @override
  ConsumerState<StockCountSessionScreen> createState() =>
      _StockCountSessionScreenState();
}

class _StockCountSessionScreenState
    extends ConsumerState<StockCountSessionScreen> {
  ScanSession? _session;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // A count is done standing in a vault with the phone in one hand; the
    // screen must not sleep between scans.
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  ScanSession _sessionFor(StockCount count) {
    if (_session != null) return _session!;

    final expected = count.lines
        .where((line) => line.expected)
        .map((line) => line.itemCode)
        .toSet();

    // Resume a count interrupted by a crash or a killed app.
    final store = ref.read(stockCountSessionStoreProvider);
    return _session =
        store.restore(count.id, expected) ?? ScanSession(expected: expected);
  }

  Future<void> _scan(StockCount count) async {
    final session = _sessionFor(count);

    final scanned = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          request: ScanRequest(
            intent: ScanIntent.bulk,
            title: 'Counting ${count.referenceNumber}',
            expected: session.expected,
          ),
        ),
      ),
    );

    if (scanned == null) return;

    setState(() {
      for (final tag in scanned) {
        session.record(tag);
      }
    });

    await ref.read(stockCountSessionStoreProvider).save(count.id, session);
  }

  Future<void> _submit(StockCount count) async {
    final session = _sessionFor(count);

    final confirmed = await showConfirmationDialog(
      context,
      title: 'Submit count?',
      message: session.missing.isEmpty && session.unexpected.isEmpty
          ? 'All ${count.expectedCount} items accounted for.'
          : '${session.matched.length} matched, ${session.missing.length} '
                'missing, ${session.unexpected.length} unexpected.\n\n'
                'A supervisor reviews and approves this count; submitting does '
                'not change stock by itself.',
      tone: ConfirmTone.normal,
      icon: Icons.fact_check_outlined,
      confirmLabel: 'Submit for review',
    );

    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      // Codes map back to item ids; the backend reconciles from ids.
      final byCode = {
        for (final line in count.lines) line.itemCode: line.jewelleryItemId,
      };
      final found = session.scanned
          .map((code) => byCode[code])
          .whereType<String>()
          .toList(growable: false);

      await ref
          .read(warehouseRepositoryProvider)
          .submit(
            count.id,
            foundItemIds: found,
            notes: session.unexpected.isEmpty
                ? null
                : 'Unexpected: ${session.unexpected.join(', ')}',
          );

      await ref.read(stockCountSessionStoreProvider).clear(count.id);
      ref
        ..invalidate(stockCountDetailProvider(count.id))
        ..invalidate(stockCountListProvider);

      if (mounted) {
        Navigator.of(context).pop();
        showAppSnackBar(
          context,
          message: 'Count submitted for review',
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
    final count = ref.watch(stockCountDetailProvider(widget.countId));

    return Scaffold(
      appBar: AppBar(title: const Text('Stock count')),
      body: AsyncValueView<StockCount>(
        value: count,
        loading: const Center(child: CircularProgressIndicator()),
        onRetry: () => ref.invalidate(stockCountDetailProvider(widget.countId)),
        data: _body,
      ),
      bottomNavigationBar: count.maybeWhen(
        data: _bottomBar,
        orElse: () => null,
      ),
    );
  }

  Widget _body(StockCount count) {
    final session = _sessionFor(count);
    final inProgress = count.status == StockCountStatus.inProgress;

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
                count.referenceNumber,
                style: AppTypography.mono(context, size: 16),
              ),
            ),
            StatusBadge(label: count.status.label, tone: count.status.tone),
          ],
        ),
        AppSpacing.gapLg,

        // Big, glanceable counters — a counter looks at these, not at a list.
        AppCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BigCounter(label: 'Expected', value: session.expected.length),
              _BigCounter(
                label: 'Scanned',
                value: session.scannedCount,
                tone: context.scheme.primary,
              ),
            ],
          ),
        ),
        AppSpacing.gapMd,
        AppCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BigCounter(
                label: 'Matched',
                value: session.matched.length,
                tone: context.colors.success,
              ),
              _BigCounter(
                label: 'Missing',
                value: session.missing.length,
                tone: context.colors.danger,
              ),
              _BigCounter(
                label: 'Unexpected',
                value: session.unexpected.length,
                tone: context.colors.warning,
              ),
            ],
          ),
        ),
        AppSpacing.gapXl,

        if (inProgress)
          AppButton(
            label: session.scannedCount == 0
                ? 'Start scanning'
                : 'Continue scanning',
            icon: Icons.qr_code_scanner,
            variant: AppButtonVariant.secondary,
            onPressed: () => _scan(count),
          ),

        if (session.missing.isNotEmpty) ...[
          AppSpacing.gapXl,
          SectionCard(
            title: 'Missing (${session.missing.length})',
            icon: Icons.error_outline,
            subtitle: 'Expected here but not scanned',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final code in session.missing.take(50))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(code, style: AppTypography.mono(context)),
                  ),
                if (session.missing.length > 50)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      '+${session.missing.length - 50} more',
                      style: context.text.labelSmall?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],

        if (session.unexpected.isNotEmpty) ...[
          AppSpacing.gapLg,
          SectionCard(
            title: 'Unexpected (${session.unexpected.length})',
            icon: Icons.help_outline,
            subtitle: 'Found here but not expected',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final code in session.unexpected)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(code, style: AppTypography.mono(context)),
                  ),
              ],
            ),
          ),
        ],

        if (count.status == StockCountStatus.pendingReview) ...[
          AppSpacing.gapLg,
          _ReviewPanel(count: count),
        ],
      ],
    );
  }

  Widget? _bottomBar(StockCount count) {
    if (count.status != StockCountStatus.inProgress) return null;
    final session = _sessionFor(count);

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
        child: AppButton(
          label: 'Submit for review',
          icon: Icons.fact_check_outlined,
          busy: _busy,
          onPressed: session.scannedCount == 0 ? null : () => _submit(count),
        ),
      ),
    );
  }
}

/// Approval, gated by a separate permission.
///
/// The specification is explicit that employees must not silently modify stock
/// counts: the counter submits observations, and approving them is a different
/// permission that the counter may not hold.
class _ReviewPanel extends ConsumerStatefulWidget {
  const _ReviewPanel({required this.count});

  final StockCount count;

  @override
  ConsumerState<_ReviewPanel> createState() => _ReviewPanelState();
}

class _ReviewPanelState extends ConsumerState<_ReviewPanel> {
  bool _busy = false;

  Future<void> _approve() async {
    final count = widget.count;

    final confirmed = await showConfirmationDialog(
      context,
      title: 'Approve count?',
      message: count.hasVariance
          ? 'This records ${count.missingCount} missing and '
                '${count.unexpectedCount} unexpected items against stock.'
          : 'No variance to record.',
      tone: count.hasVariance ? ConfirmTone.danger : ConfirmTone.normal,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(warehouseRepositoryProvider).approve(count.id);
      ref
        ..invalidate(stockCountDetailProvider(count.id))
        ..invalidate(stockCountListProvider);
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
    final count = widget.count;
    final canApprove = ref
        .watch(permissionsProvider)
        .has(Permission.stockCountApprove);

    return SectionCard(
      title: 'Review',
      icon: Icons.verified_outlined,
      subtitle: count.hasVariance
          ? '${count.missingCount} missing · ${count.unexpectedCount} unexpected'
          : 'No variance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (count.awaitingSecondApproval) ...[
            const StatusBadge(
              label: '1 of 2 approvals',
              tone: StatusTone.vault,
            ),
            AppSpacing.gapMd,
          ],
          Text(
            canApprove
                ? 'Approving records the variance against stock.'
                : 'A supervisor with stock-count approval must review this.',
            style: context.text.bodySmall?.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.gapLg,
          AppButton(
            label: 'Approve count',
            icon: Icons.check,
            busy: _busy,
            onPressed: canApprove ? _approve : null,
          ),
        ],
      ),
    );
  }
}

class _BigCounter extends StatelessWidget {
  const _BigCounter({required this.label, required this.value, this.tone});

  final String label;
  final int value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: AppTypography.numeric(context, size: 28, color: tone),
        ),
        Text(
          label,
          style: context.text.labelSmall?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
