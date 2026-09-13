import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/models/organization.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../../transfers/domain/movement.dart';
import '../../../transfers/presentation/providers/transfer_providers.dart';
import '../../domain/jewellery_item.dart';
import '../providers/jewellery_providers.dart';

/// Raises a single-item transfer from the passport screen.
///
/// Resolves to the created [Movement], or null if dismissed. The caller
/// decides where to go next (normally the transfer's detail screen, so the
/// dispatcher can approve and dispatch from there).
Future<Movement?> showTransferItemSheet(
  BuildContext context,
  JewelleryItem item,
) {
  return showAppBottomSheet<Movement>(
    context,
    title: 'Transfer ${item.itemCode}',
    subtitle:
        'Raises a transfer request. The item moves to In transit once '
        'it is approved and dispatched.',
    builder: (context) => _TransferForm(item: item),
  );
}

class _TransferForm extends ConsumerStatefulWidget {
  const _TransferForm({required this.item});

  final JewelleryItem item;

  @override
  ConsumerState<_TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends ConsumerState<_TransferForm> {
  final _notes = TextEditingController();

  /// One key per sheet instance, never per tap: a retry after a flaky
  /// connection must not create a second transfer of the same item.
  final _idempotencyKey = const Uuid().v4();

  BranchLocation? _destination;
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final destination = _destination;
    if (destination == null) return;

    setState(() => _busy = true);
    try {
      final movement = await ref
          .read(movementRepositoryProvider)
          .create(
            movementType: MovementType.transfer,
            toLocationId: destination.id,
            itemIds: [widget.item.id],
            fromLocationId: widget.item.currentLocationId,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            idempotencyKey: _idempotencyKey,
          );
      if (mounted) Navigator.of(context).pop(movement);
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
    final reference = ref.watch(referenceDataProvider);
    final branch = ref.watch(currentBranchProvider);
    final current = widget.item.currentLocationId;

    // The cache holds every branch the user can act in, so a cross-branch
    // destination is offered too — labelled, so nobody sends a tray to the
    // wrong city by picking a similarly named showroom.
    final destinations =
        reference.locations
            .where((location) => location.id != current)
            .toList(growable: false)
          ..sort((a, b) {
            final aHome = a.branchId == branch?.id ? 0 : 1;
            final bHome = b.branchId == branch?.id ? 0 : 1;
            if (aHome != bHome) return aHome.compareTo(bHome);
            return a.name.compareTo(b.name);
          });

    final from = reference.location(current);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (from != null) ...[
          _Label('From'),
          AppSpacing.gapXs,
          Text(from.name, style: context.text.bodyMedium),
          AppSpacing.gapXl,
        ],
        _Label('Destination'),
        AppSpacing.gapSm,
        if (destinations.isEmpty)
          Text(
            'No other locations are available to transfer to.',
            style: context.text.bodySmall?.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          )
        else
          DropdownButtonFormField<BranchLocation>(
            initialValue: _destination,
            isExpanded: true,
            decoration: const InputDecoration(hintText: 'Choose a location'),
            items: [
              for (final location in destinations)
                DropdownMenuItem(
                  value: location,
                  child: Text(
                    location.branchId == branch?.id
                        ? '${location.name} · ${location.type.label}'
                        : '${location.name} · ${location.type.label} '
                              '(other branch)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _destination = value),
          ),
        if (_destination?.dualAuthorization ?? false) ...[
          AppSpacing.gapSm,
          Text(
            'This location needs two approvals before dispatch.',
            style: context.text.bodySmall?.copyWith(
              color: context.colors.warning,
            ),
          ),
        ],
        AppSpacing.gapXl,
        AppTextField(
          controller: _notes,
          label: 'Notes',
          hint: 'Optional — why the item is moving',
          maxLines: 3,
          maxLength: 500,
          enabled: !_busy,
        ),
        AppSpacing.gapLg,
        AppButton(
          label: 'Raise transfer',
          icon: Icons.swap_horiz,
          busy: _busy,
          onPressed: _destination == null || _busy ? null : _submit,
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.text.labelMedium?.copyWith(
        color: context.scheme.onSurfaceVariant,
      ),
    );
  }
}
