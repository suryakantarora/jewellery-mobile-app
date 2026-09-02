import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/models/organization.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../jewellery/presentation/providers/jewellery_providers.dart';
import '../../domain/procurement_models.dart';
import '../providers/procurement_providers.dart';
import '../../../jewellery/presentation/widgets/reference_gate.dart';

/// One physical piece being received.
class ReceivedItemDraft {
  ReceivedItemDraft({
    required this.productId,
    required this.productName,
    required this.grossWeight,
    this.rfidTag,
    this.barcode,
    this.note,
    this.createdItemId,
  });

  final String productId;
  final String productName;
  final double grossWeight;
  String? rfidTag;
  String? barcode;
  String? note;

  /// Set once the item exists on the backend.
  String? createdItemId;

  bool get isCreated => createdItemId != null;
}

/// Goods receiving.
///
/// The backend takes `{purchaseOrderId, lines: [{jewelleryItemId}]}`, so items
/// must exist before the receipt references them. The flow therefore creates
/// each serialised piece first, then submits the receipt — and the whole draft
/// lives locally until submit, because receiving forty pieces is an hour's work
/// and a dropped connection must not lose the weights already captured.
class GoodsReceivingScreen extends ConsumerStatefulWidget {
  const GoodsReceivingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<GoodsReceivingScreen> createState() =>
      _GoodsReceivingScreenState();
}

class _GoodsReceivingScreenState extends ConsumerState<GoodsReceivingScreen> {
  final List<ReceivedItemDraft> _drafts = [];
  BranchLocation? _location;
  String? _deliveryNote;
  bool _busy = false;

  /// Generated once per receipt, not per retry — this endpoint honours
  /// `X-Idempotency-Key`, and a retried submit could otherwise duplicate stock.
  late final String _idempotencyKey = ref
      .read(procurementRepositoryProvider)
      .newIdempotencyKey();

  Future<void> _addItem(PurchaseOrder order) async {
    final reference = ref.read(referenceDataProvider);

    final draft = await showAppBottomSheet<ReceivedItemDraft>(
      context,
      title: 'Add received item',
      subtitle: 'One entry per physical piece.',
      builder: (context) => _AddItemForm(
        lines: order.lines,
        resolveProductName: (id) =>
            reference.cachedProduct(id)?.name ?? 'Product',
      ),
    );

    if (draft != null) setState(() => _drafts.add(draft));
  }

  Future<void> _submit(PurchaseOrder order) async {
    if (_location == null) {
      showAppSnackBar(
        context,
        message: 'Choose where the goods are being received',
        tone: SnackTone.error,
      );
      return;
    }

    final confirmed = await showConfirmationDialog(
      context,
      title: 'Submit receipt?',
      message:
          '${_drafts.length} items into ${_location!.name}.\n\n'
          'Each item is created in inventory, then the receipt is recorded. '
          'A separate quality-check step accepts or rejects it.',
      icon: Icons.inventory_2_outlined,
      confirmLabel: 'Submit receipt',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);

    try {
      // Items first: the receipt references them by id.
      for (final draft in _drafts.where((d) => !d.isCreated)) {
        final created = await client.post<Map<String, dynamic>>(
          ApiEndpoints.items,
          body: {
            'productId': draft.productId,
            'grossWeight': draft.grossWeight,
            'locationId': _location!.id,
            if (draft.rfidTag != null) 'rfidTag': draft.rfidTag,
            if (draft.barcode != null) 'barcode': draft.barcode,
            if (draft.note != null) 'notes': draft.note,
          },
          parse: (data) => data! as Map<String, dynamic>,
        );
        // Recorded on the draft so a partial failure does not recreate items
        // that already exist when the user retries.
        draft.createdItemId = created['id'] as String?;
      }

      await ref
          .read(procurementRepositoryProvider)
          .createReceipt(
            idempotencyKey: _idempotencyKey,
            body: {
              'purchaseOrderId': order.id,
              if (_deliveryNote != null) 'supplierDeliveryNote': _deliveryNote,
              'lines': [
                for (final draft in _drafts)
                  if (draft.createdItemId != null)
                    {'jewelleryItemId': draft.createdItemId},
              ],
            },
          );

      ref
        ..invalidate(purchaseOrderDetailProvider(order.id))
        ..invalidate(purchaseOrderListProvider)
        ..invalidate(goodsReceiptListProvider);

      if (mounted) {
        Navigator.of(context).pop();
        showAppSnackBar(
          context,
          message: 'Receipt submitted for quality check',
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
    final order = ref.watch(purchaseOrderDetailProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Receive goods')),
      body: ReferenceGate(
        child: AsyncValueView<PurchaseOrder>(
          value: order,
          loading: const Center(child: CircularProgressIndicator()),
          onRetry: () =>
              ref.invalidate(purchaseOrderDetailProvider(widget.orderId)),
          data: _body,
        ),
      ),
      bottomNavigationBar: order.maybeWhen(
        data: (data) => _bottomBar(data),
        orElse: () => null,
      ),
    );
  }

  Widget _body(PurchaseOrder order) {
    final reference = ref.watch(referenceDataProvider);
    final formatters = ref.watch(formattersProvider);

    final receivable = reference.locations
        .where((location) => location.type != LocationType.inTransit)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.huge,
      ),
      children: [
        Text(order.orderNumber, style: AppTypography.mono(context, size: 16)),
        AppSpacing.gapLg,

        SectionCard(
          title: 'Receiving into',
          icon: Icons.place_outlined,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final location in receivable)
                ChoiceChip(
                  label: Text(location.name),
                  selected: _location?.id == location.id,
                  onSelected: (selected) =>
                      setState(() => _location = selected ? location : null),
                ),
            ],
          ),
        ),
        AppSpacing.gapLg,

        SectionCard(
          title: 'Expected',
          icon: Icons.list_alt,
          child: Column(
            children: [
              for (final line in order.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          line.description ??
                              reference.cachedProduct(line.productId)?.name ??
                              'Line',
                          style: context.text.bodyMedium,
                        ),
                      ),
                      Text(
                        '${line.receivedQuantity}/${line.orderedQuantity}',
                        style: AppTypography.numeric(context, size: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        AppSpacing.gapLg,

        Row(
          children: [
            Expanded(
              child: Text(
                'Received items (${_drafts.length})',
                style: context.text.titleSmall,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              onPressed: () => _addItem(order),
            ),
          ],
        ),
        AppSpacing.gapSm,

        if (_drafts.isEmpty)
          AppCard(
            child: Text(
              'Add each physical piece as you weigh it. Nothing is sent until '
              'you submit.',
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (var i = 0; i < _drafts.length; i++)
            _DraftRow(
              draft: _drafts[i],
              weight: formatters.weight(_drafts[i].grossWeight),
              onRemove: () => setState(() => _drafts.removeAt(i)),
            ),
      ],
    );
  }

  Widget _bottomBar(PurchaseOrder order) {
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
          label: 'Submit receipt (${_drafts.length})',
          icon: Icons.check,
          busy: _busy,
          onPressed: _drafts.isEmpty ? null : () => _submit(order),
        ),
      ),
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.draft,
    required this.weight,
    required this.onRemove,
  });

  final ReceivedItemDraft draft;
  final String weight;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(draft.productName, style: context.text.titleSmall),
                  AppSpacing.gapXxs,
                  Text(
                    [
                      weight,
                      if (draft.rfidTag != null) 'RFID ${draft.rfidTag}',
                    ].join('  ·  '),
                    style: context.text.bodySmall?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (draft.isCreated)
              const StatusBadge(
                label: 'Created',
                tone: StatusTone.success,
                dense: true,
              )
            else
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

/// Weight entry for one piece.
///
/// Numeric keyboard, three decimals, one field in focus — this is the
/// highest-volume interaction in the whole receiving workflow.
class _AddItemForm extends ConsumerStatefulWidget {
  const _AddItemForm({required this.lines, required this.resolveProductName});

  final List<PurchaseOrderLine> lines;
  final String Function(String? productId) resolveProductName;

  @override
  ConsumerState<_AddItemForm> createState() => _AddItemFormState();
}

class _AddItemFormState extends ConsumerState<_AddItemForm> {
  final _weight = TextEditingController();
  final _rfid = TextEditingController();
  String? _productId;

  @override
  void initState() {
    super.initState();
    _productId = widget.lines.firstOrNull?.productId;
  }

  @override
  void dispose() {
    _weight.dispose();
    _rfid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weight = double.tryParse(_weight.text);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final option in widget.lines)
              if (option.productId != null)
                ChoiceChip(
                  label: Text(widget.resolveProductName(option.productId)),
                  selected: _productId == option.productId,
                  onSelected: (_) =>
                      setState(() => _productId = option.productId),
                ),
          ],
        ),
        AppSpacing.gapLg,
        AppTextField(
          controller: _weight,
          label: 'Gross weight (g)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
          ],
          autofocus: true,
          prefixIcon: Icons.scale_outlined,
          onChanged: (_) => setState(() {}),
        ),
        AppSpacing.gapMd,
        AppTextField(
          controller: _rfid,
          label: 'RFID tag (optional)',
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          prefixIcon: Icons.nfc,
        ),
        AppSpacing.gapXl,
        AppButton(
          label: 'Add item',
          onPressed: (weight == null || weight <= 0 || _productId == null)
              ? null
              : () => Navigator.of(context).pop(
                  ReceivedItemDraft(
                    productId: _productId!,
                    productName: widget.resolveProductName(_productId),
                    grossWeight: weight,
                    rfidTag: _rfid.text.trim().isEmpty
                        ? null
                        : _rfid.text.trim(),
                  ),
                ),
        ),
      ],
    );
  }
}
