import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../../customers/domain/customer_models.dart';
import '../../domain/jewellery_item.dart';
import '../providers/jewellery_providers.dart';
import 'customer_picker_field.dart';

/// Hold durations the sheet offers. The backend takes any `holdHours`; these
/// are the ones a counter actually uses.
const reservationHoldOptions = <int>[4, 24, 48, 72];

/// Reserves [item] for a customer. Resolves to `true` once the reservation is
/// recorded, `false` if dismissed.
Future<bool> showReserveItemSheet(BuildContext context, JewelleryItem item) {
  return showAppBottomSheet<bool>(
    context,
    title: 'Reserve ${item.itemCode}',
    subtitle:
        'The item is held for the customer and cannot be sold to '
        'anyone else until the hold lapses or is released.',
    builder: (context) => _ReserveForm(item: item),
  ).then((value) => value ?? false);
}

class _ReserveForm extends ConsumerStatefulWidget {
  const _ReserveForm({required this.item});

  final JewelleryItem item;

  @override
  ConsumerState<_ReserveForm> createState() => _ReserveFormState();
}

class _ReserveFormState extends ConsumerState<_ReserveForm> {
  final _notes = TextEditingController();
  Customer? _customer;
  int _holdHours = 24;
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final customer = _customer;
    if (customer == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(jewelleryRepositoryProvider)
          .reserve(
            itemId: widget.item.id,
            customerId: customer.id,
            holdHours: _holdHours,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Label('Customer'),
        AppSpacing.gapSm,
        CustomerPickerField(
          selected: _customer,
          autofocus: true,
          onSelected: (customer) => setState(() => _customer = customer),
        ),
        AppSpacing.gapXl,
        _Label('Hold for'),
        AppSpacing.gapSm,
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final hours in reservationHoldOptions)
              ChoiceChip(
                label: Text(_holdLabel(hours)),
                selected: _holdHours == hours,
                onSelected: _busy
                    ? null
                    : (_) => setState(() => _holdHours = hours),
              ),
          ],
        ),
        AppSpacing.gapXl,
        AppTextField(
          controller: _notes,
          label: 'Notes',
          hint: 'Optional — deposit taken, who to call, etc.',
          maxLines: 3,
          maxLength: 500,
          enabled: !_busy,
        ),
        AppSpacing.gapLg,
        AppButton(
          label: 'Reserve',
          icon: Icons.bookmark_add_outlined,
          busy: _busy,
          onPressed: _customer == null || _busy ? null : _submit,
        ),
      ],
    );
  }

  static String _holdLabel(int hours) =>
      hours < 24 ? '$hours h' : '${hours ~/ 24} day${hours == 24 ? '' : 's'}';
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
