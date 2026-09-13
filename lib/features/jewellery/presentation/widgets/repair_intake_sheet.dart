import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../../customers/domain/customer_models.dart';
import '../../../repairs/domain/repair_models.dart';
import '../../../repairs/presentation/providers/repair_providers.dart';
import '../../domain/jewellery_item.dart';
import '../providers/jewellery_providers.dart';
import 'customer_picker_field.dart';

/// Books [item] in for repair. Resolves to the created [RepairJob], or null if
/// dismissed. The caller normally opens the job screen next.
Future<RepairJob?> showRepairIntakeSheet(
  BuildContext context,
  JewelleryItem item,
) {
  return showAppBottomSheet<RepairJob>(
    context,
    title: 'Repair ${item.itemCode}',
    subtitle: 'Opens a repair job and moves the item to Under repair.',
    builder: (context) => _RepairIntakeForm(item: item),
  );
}

class _RepairIntakeForm extends ConsumerStatefulWidget {
  const _RepairIntakeForm({required this.item});

  final JewelleryItem item;

  @override
  ConsumerState<_RepairIntakeForm> createState() => _RepairIntakeFormState();
}

class _RepairIntakeFormState extends ConsumerState<_RepairIntakeForm> {
  late final TextEditingController _description;
  final _problem = TextEditingController();

  Customer? _customer;
  DateTime? _promisedDate;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Seeded from the catalogue so staff do not retype what the passport
    // already knows; still editable, because an item in for repair often needs
    // a note about which part ("left earring, post bent").
    final product = ref
        .read(referenceDataProvider)
        .cachedProduct(widget.item.productId);
    _description = TextEditingController(
      text: product == null
          ? widget.item.itemCode
          : '${product.name} (${widget.item.itemCode})',
    );
  }

  @override
  void dispose() {
    _description.dispose();
    _problem.dispose();
    super.dispose();
  }

  bool get _valid =>
      _customer != null && _description.text.trim().isNotEmpty && !_busy;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _promisedDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _promisedDate = picked);
  }

  Future<void> _submit() async {
    final customer = _customer;
    final branch = ref.read(currentBranchProvider);
    if (customer == null || branch == null) return;

    setState(() => _busy = true);
    try {
      final job = await ref
          .read(repairRepositoryProvider)
          .receive(
            customerId: customer.id,
            branchId: branch.id,
            itemDescription: _description.text.trim(),
            jewelleryItemId: widget.item.id,
            receivedWeight: widget.item.grossWeight,
            reportedProblem: _problem.text.trim().isEmpty
                ? null
                : _problem.text.trim(),
            promisedDate: _promisedDate,
          );
      if (mounted) Navigator.of(context).pop(job);
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
    final formatters = ref.watch(formattersProvider);

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
        AppTextField(
          controller: _description,
          label: 'Item description',
          maxLength: 200,
          enabled: !_busy,
          onChanged: (_) => setState(() {}),
        ),
        AppSpacing.gapMd,
        AppTextField(
          controller: _problem,
          label: 'Reported problem',
          hint: 'What the customer says is wrong',
          maxLines: 3,
          maxLength: 500,
          enabled: !_busy,
        ),
        AppSpacing.gapMd,
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: const Text('Promised date'),
          subtitle: Text(
            _promisedDate == null ? 'Not set' : formatters.date(_promisedDate),
          ),
          trailing: _promisedDate == null
              ? const Icon(Icons.chevron_right)
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear date',
                  onPressed: () => setState(() => _promisedDate = null),
                ),
          onTap: _busy ? null : _pickDate,
        ),
        AppSpacing.gapLg,
        AppButton(
          label: 'Start repair',
          icon: Icons.build_outlined,
          busy: _busy,
          onPressed: _valid ? _submit : null,
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
