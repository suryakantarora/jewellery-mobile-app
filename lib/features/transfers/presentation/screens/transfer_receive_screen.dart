import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../jewellery/domain/jewellery_item.dart';
import '../../../scanner/domain/scan_session.dart';
import '../../../scanner/presentation/providers/scanner_providers.dart';
import '../../../scanner/presentation/screens/scan_screen.dart';
import '../../data/movement_repository.dart';
import '../../domain/movement.dart';
import '../providers/transfer_providers.dart';

/// Receiving a dispatched transfer.
///
/// The receiver scans what physically arrived; the app reconciles that against
/// what was dispatched. Progress is **local until confirm** — nothing is
/// reported to the backend until the receiver commits, and a short receipt is
/// allowed but never silent.
class TransferReceiveScreen extends ConsumerStatefulWidget {
  const TransferReceiveScreen({super.key, required this.movementId});

  final String movementId;

  @override
  ConsumerState<TransferReceiveScreen> createState() =>
      _TransferReceiveScreenState();
}

class _TransferReceiveScreenState extends ConsumerState<TransferReceiveScreen> {
  ScanSession? _session;
  final Map<String, String> _notes = {};

  /// Items the scanner resolved, keyed by item code, so rows can name what was
  /// scanned rather than echo a barcode.
  final Map<String, JewelleryItem> _items = {};
  bool _busy = false;

  ScanSession _sessionFor(Movement movement) {
    return _session ??= ScanSession(
      expected: movement.lines.map((line) => line.itemCode).toSet(),
    );
  }

  Future<void> _scan(Movement movement) async {
    final session = _sessionFor(movement);

    final result = await Navigator.of(context).push<BulkScanResult>(
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          request: ScanRequest(
            intent: ScanIntent.bulk,
            title: 'Receiving ${movement.referenceNumber}',
            expected: session.expected,
          ),
        ),
      ),
    );

    if (result == null) return;
    setState(() {
      _items.addAll(result.itemsByCode);
      // Canonical codes: a barcode that resolved to an item on this transfer
      // counts as that item, not as an unexpected string.
      for (final tag in result.canonicalTags) {
        session.record(tag);
      }
    });
  }

  Future<void> _confirm(Movement movement) async {
    final session = _sessionFor(movement);
    final missing = session.missing;
    final unexpected = session.unexpected;

    // A clean receipt is one tap. A short one spells out the consequence,
    // because it is recorded against both the sender and the receiver.
    final confirmed = await showConfirmationDialog(
      context,
      title: missing.isEmpty && unexpected.isEmpty
          ? 'Confirm receipt?'
          : 'Confirm short receipt?',
      message: missing.isEmpty && unexpected.isEmpty
          ? 'All ${movement.itemCount} items scanned and matched.'
          : '${missing.length} missing, ${unexpected.length} unexpected. '
                'This discrepancy is recorded against this transfer.',
      tone: missing.isEmpty && unexpected.isEmpty
          ? ConfirmTone.normal
          : ConfirmTone.danger,
      icon: Icons.inventory_2_outlined,
      confirmLabel: 'Confirm receipt',
    );

    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      final byCode = {
        for (final line in movement.lines) line.itemCode: line.jewelleryItemId,
      };

      await ref
          .read(movementRepositoryProvider)
          .receive(
            movement.id,
            lines: [
              for (final line in movement.lines)
                ReceivedLine(
                  jewelleryItemId: line.jewelleryItemId,
                  discrepancyNote: session.missing.contains(line.itemCode)
                      ? (_notes[line.itemCode] ?? 'Not received')
                      : _notes[line.itemCode],
                ),
              // Unexpected items are reported too, where the code resolves.
              for (final code in session.unexpected)
                if (byCode.containsKey(code))
                  ReceivedLine(
                    jewelleryItemId: byCode[code]!,
                    discrepancyNote: 'Unexpected in this shipment',
                  ),
            ],
            notes: missing.isEmpty && unexpected.isEmpty
                ? null
                : '${missing.length} missing, ${unexpected.length} unexpected',
          );

      ref
        ..invalidate(movementDetailProvider(movement.id))
        ..invalidate(transferListProvider);

      if (mounted) {
        Navigator.of(context).pop();
        showAppSnackBar(
          context,
          message: 'Receipt confirmed',
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
    final movement = ref.watch(movementDetailProvider(widget.movementId));

    return Scaffold(
      appBar: AppBar(title: const Text('Receive')),
      body: AsyncValueView<Movement>(
        value: movement,
        loading: const Center(child: CircularProgressIndicator()),
        onRetry: () =>
            ref.invalidate(movementDetailProvider(widget.movementId)),
        data: (data) => _body(data),
      ),
      bottomNavigationBar: movement.maybeWhen(
        data: (data) => _bottomBar(data),
        orElse: () => null,
      ),
    );
  }

  Widget _body(Movement movement) {
    final session = _sessionFor(movement);
    final formatters = ref.watch(formattersProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.huge,
      ),
      children: [
        Text(
          movement.referenceNumber,
          style: AppTypography.mono(context, size: 16),
        ),
        AppSpacing.gapLg,

        AppCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Counter(label: 'Expected', value: movement.itemCount),
              _Counter(
                label: 'Matched',
                value: session.matched.length,
                tone: context.colors.success,
              ),
              _Counter(
                label: 'Missing',
                value: session.missing.length,
                tone: context.colors.danger,
              ),
              _Counter(
                label: 'Unexpected',
                value: session.unexpected.length,
                tone: context.colors.warning,
              ),
            ],
          ),
        ),
        AppSpacing.gapLg,

        AppButton(
          label: session.scannedCount == 0 ? 'Scan items' : 'Continue scanning',
          icon: Icons.qr_code_scanner,
          variant: AppButtonVariant.secondary,
          onPressed: () => _scan(movement),
        ),
        AppSpacing.gapXl,

        SectionCard(
          title: 'Expected items',
          icon: Icons.checklist,
          child: Column(
            children: [
              for (final line in movement.lines)
                _ExpectedRow(
                  code: line.itemCode,
                  name: _items[line.itemCode]?.productName,
                  weight: formatters.weight(line.dispatchedWeight),
                  scanned: session.matched.contains(line.itemCode),
                  note: _notes[line.itemCode],
                  onNote: () async {
                    final note = await showReasonSheet(
                      context,
                      title: 'Note for ${line.itemCode}',
                      hint: 'Damaged, wrong item, not in package…',
                    );
                    if (note != null) {
                      setState(() => _notes[line.itemCode] = note);
                    }
                  },
                ),
            ],
          ),
        ),

        if (session.unexpected.isNotEmpty) ...[
          AppSpacing.gapLg,
          SectionCard(
            title: 'Unexpected (${session.unexpected.length})',
            icon: Icons.help_outline,
            subtitle: 'Scanned but not on this transfer',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final code in session.unexpected)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_outlined,
                          size: 16,
                          color: context.colors.warning,
                        ),
                        AppSpacing.wGapMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(code, style: AppTypography.mono(context)),
                              if (_items[code]?.productName case final name?)
                                Text(
                                  name,
                                  style: context.text.labelSmall?.copyWith(
                                    color: context.scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => session.remove(code)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _bottomBar(Movement movement) {
    final session = _sessionFor(movement);
    final complete = session.isComplete;

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
          label: complete
              ? 'Confirm receipt'
              : 'Confirm short receipt (${session.missing.length} missing)',
          icon: complete ? Icons.check : Icons.warning_amber_outlined,
          variant: complete
              ? AppButtonVariant.primary
              : AppButtonVariant.danger,
          busy: _busy,
          // Receiving changes inventory state, so it always needs a connection —
          // per Phase 17 this is never queued offline.
          onPressed: session.scannedCount == 0
              ? null
              : () => _confirm(movement),
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.value, this.tone});

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
          style: AppTypography.numeric(context, size: 20, color: tone),
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

class _ExpectedRow extends StatelessWidget {
  const _ExpectedRow({
    required this.code,
    required this.name,
    required this.weight,
    required this.scanned,
    required this.note,
    required this.onNote,
  });

  final String code;

  /// Known once the item has been scanned and resolved; null before that.
  final String? name;
  final String weight;
  final bool scanned;
  final String? note;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            scanned ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: scanned ? context.colors.success : context.scheme.outline,
          ),
          AppSpacing.wGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(code, style: AppTypography.mono(context)),
                if (name != null)
                  Text(
                    name!,
                    style: context.text.labelSmall?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (note != null)
                  Text(
                    note!,
                    style: context.text.labelSmall?.copyWith(
                      color: context.colors.warning,
                    ),
                  ),
              ],
            ),
          ),
          Text(weight, style: AppTypography.numeric(context, size: 13)),
          if (!scanned)
            IconButton(
              icon: const Icon(Icons.edit_note, size: 20),
              tooltip: 'Add a note',
              onPressed: onNote,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// Kept visible so the reconciliation vocabulary is shared with Phase 8.
const receiveStatusTone = StatusTone.warning;
