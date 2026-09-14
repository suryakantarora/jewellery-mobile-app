import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/permissions.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/permission_widgets.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../customers/domain/customer_models.dart';
import '../../../customers/presentation/providers/customer_providers.dart';
import '../../../jewellery/data/jewellery_repository.dart';
import '../../../jewellery/domain/jewellery_item.dart';
import '../../../jewellery/presentation/providers/jewellery_providers.dart';
import '../../../jewellery/presentation/widgets/customer_picker_field.dart';
import '../../../scanner/presentation/providers/scanner_providers.dart';
import '../../../scanner/presentation/screens/scan_screen.dart';
import '../../domain/sales_models.dart';
import '../providers/sales_providers.dart';
import 'price_sheet.dart';

/// Sales assistance: the screen a salesperson holds while standing next to a
/// customer.
///
/// Find a piece (scan or search), then price it, see where else it is, put it
/// on a customer's wishlist, or ask for a discount. Assistance, not
/// transaction — payment and the sale itself stay in the POS, and every figure
/// shown here is the server's.
class SalesAssistanceScreen extends ConsumerStatefulWidget {
  const SalesAssistanceScreen({super.key});

  @override
  ConsumerState<SalesAssistanceScreen> createState() =>
      _SalesAssistanceScreenState();
}

class _SalesAssistanceScreenState extends ConsumerState<SalesAssistanceScreen> {
  final _debouncer = Debouncer();
  final _query = TextEditingController();

  List<JewelleryItem> _results = const [];
  JewelleryItem? _selected;
  bool _searching = false;
  String? _error;
  int _serial = 0;

  @override
  void dispose() {
    _debouncer.dispose();
    _query.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    final query = value.trim();
    if (query.length < 2) {
      _debouncer.cancel();
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debouncer.run(() => _search(query));
  }

  Future<void> _search(String query) async {
    final serial = ++_serial;
    try {
      final page = await ref
          .read(jewelleryRepositoryProvider)
          .search(
            ItemSearchFilters(
              search: query,
              branchId: ref.read(currentBranchProvider)?.id,
            ),
            size: 20,
          );
      if (!mounted || serial != _serial) return;
      setState(() {
        _results = page.content;
        _searching = false;
        _error = null;
      });
    } on AppException catch (error) {
      if (!mounted || serial != _serial) return;
      setState(() {
        _searching = false;
        _error = error.message;
      });
    }
  }

  /// Scans one tag and resolves it here, rather than letting the scanner open
  /// the passport, so the salesperson lands back on this screen with the piece
  /// selected.
  Future<void> _scan() async {
    final tags = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => const ScanScreen(
          request: ScanRequest(intent: ScanIntent.bulk, title: 'Scan a piece'),
        ),
      ),
    );
    final tag = tags?.firstOrNull;
    if (tag == null || !mounted) return;

    setState(() => _searching = true);
    try {
      final item = await ref.read(jewelleryRepositoryProvider).byTag(tag);
      if (!mounted) return;
      ref.read(recentItemsProvider.notifier).record(item);
      _select(item);
    } on AppException catch (error) {
      if (mounted) {
        showAppSnackBar(context, message: error.message, tone: SnackTone.error);
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _select(JewelleryItem item) => setState(() {
    _selected = item;
    _results = const [];
    _query.clear();
  });

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return AppScaffold(
      title: context.l10n.screenSales,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.huge,
        ),
        children: [
          AppSearchField(
            controller: _query,
            hint: 'Item code, tag or product',
            onChanged: _onQueryChanged,
            onScan: _scan,
          ),
          if (_searching) ...[
            AppSpacing.gapSm,
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (_error != null) ...[
            AppSpacing.gapSm,
            Text(
              _error!,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.danger,
              ),
            ),
          ],
          if (_results.isNotEmpty) ...[
            AppSpacing.gapSm,
            AppCard(
              child: Column(
                children: [
                  for (final item in _results)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.diamond_outlined),
                      title: Text(
                        item.itemCode,
                        style: AppTypography.mono(context, size: 14),
                      ),
                      subtitle: Text(item.status.label),
                      onTap: () => _select(item),
                    ),
                ],
              ),
            ),
          ] else if (!_searching &&
              _error == null &&
              _query.text.trim().length >= 2) ...[
            AppSpacing.gapSm,
            Text(
              'No piece matches.',
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ],
          AppSpacing.gapLg,

          if (selected == null)
            const EmptyState(
              icon: Icons.point_of_sale_outlined,
              title: 'Find a piece',
              message:
                  'Scan its tag or search by code to price it, check other '
                  'branches, add it to a wishlist or request a discount.',
              compact: true,
            )
          else
            _SelectedItemCard(
              item: selected,
              onClear: () => setState(() => _selected = null),
            ),

          AppSpacing.gapXl,
          const PermissionGuard(
            requires: Permission.discountRequest,
            child: _MyDiscountRequests(),
          ),
        ],
      ),
    );
  }
}

class _SelectedItemCard extends ConsumerWidget {
  const _SelectedItemCard({required this.item, required this.onClear});

  final JewelleryItem item;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionsProvider);
    final formatters = ref.watch(formattersProvider);
    final reference = ref.watch(referenceDataProvider);
    final product = reference.cachedProduct(item.productId);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemCode,
                      style: AppTypography.mono(context, size: 18),
                    ),
                    AppSpacing.gapXxs,
                    Text(
                      [
                        if (product != null) product.name,
                        reference.materialLabel(item.metalId, item.purityId),
                        formatters.weight(item.grossWeight),
                      ].join(' · '),
                      style: context.text.bodySmall?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: item.status.label,
                tone: item.status.tone,
                dense: true,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Clear',
                onPressed: onClear,
              ),
            ],
          ),
          if (item.currentPrice != null) ...[
            AppSpacing.gapSm,
            Text(
              formatters.money(item.currentPrice, item.currency),
              style: AppTypography.numeric(context, size: 22),
            ),
            Text(
              'List price — tap Price for the full breakdown',
              style: context.text.labelSmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ],
          AppSpacing.gapMd,
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.itemDetailPath(item.id)),
            icon: const Icon(Icons.badge_outlined, size: 18),
            label: const Text('Open passport'),
          ),
          const Divider(),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (permissions.has(priceViewPermission))
                ActionChip(
                  avatar: const Icon(Icons.sell_outlined, size: 18),
                  label: const Text('Price'),
                  onPressed: () => showPriceSheet(context, item),
                ),
              if (item.productId != null)
                ActionChip(
                  avatar: const Icon(Icons.storefront_outlined, size: 18),
                  label: const Text('Where else is it?'),
                  onPressed: () => showAvailabilitySheet(
                    context,
                    item.productId!,
                    product?.name ?? item.itemCode,
                  ),
                ),
              if (permissions.hasAny({
                Permission.customerManage,
                Permission.saleCreate,
              }))
                ActionChip(
                  avatar: const Icon(Icons.favorite_border, size: 18),
                  label: const Text('Add to wishlist'),
                  onPressed: () => _showWishlistSheet(context, item),
                ),
              if (permissions.has(Permission.discountRequest))
                ActionChip(
                  avatar: const Icon(Icons.percent_outlined, size: 18),
                  label: const Text('Request discount'),
                  onPressed: () => _showDiscountSheet(context, item),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Wishlist --------------------------------------------------------------

Future<void> _showWishlistSheet(BuildContext context, JewelleryItem item) {
  return showAppBottomSheet<void>(
    context,
    title: 'Add to wishlist',
    subtitle: item.itemCode,
    builder: (_) => _WishlistForm(item: item),
  );
}

class _WishlistForm extends ConsumerStatefulWidget {
  const _WishlistForm({required this.item});

  final JewelleryItem item;

  @override
  ConsumerState<_WishlistForm> createState() => _WishlistFormState();
}

class _WishlistFormState extends ConsumerState<_WishlistForm> {
  final _note = TextEditingController();
  Customer? _customer;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final customer = _customer;
    if (customer == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(customerRepositoryProvider)
          .addToWishlist(
            customer.id,
            jewelleryItemId: widget.item.id,
            note: _note.text.trim(),
            branchId: ref.read(currentBranchProvider)?.id,
          );
      ref.invalidate(customerWishlistProvider(customer.id));
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnackBar(
        context,
        message:
            '${widget.item.itemCode} added to ${customer.fullName}\'s '
            'wishlist',
        tone: SnackTone.success,
      );
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showAppSnackBar(context, message: error.message, tone: SnackTone.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomerPickerField(
          selected: _customer,
          autofocus: true,
          onSelected: (customer) => setState(() => _customer = customer),
        ),
        AppSpacing.gapMd,
        AppTextField(
          controller: _note,
          label: 'Note (optional)',
          hint: 'Size, occasion, budget…',
          maxLines: 2,
          maxLength: 200,
        ),
        AppSpacing.gapLg,
        AppButton(
          label: 'Add to wishlist',
          icon: Icons.favorite_border,
          busy: _busy,
          onPressed: _customer == null ? null : _submit,
        ),
      ],
    );
  }
}

// --- Discount requests -----------------------------------------------------

Future<void> _showDiscountSheet(BuildContext context, JewelleryItem item) {
  return showAppBottomSheet<void>(
    context,
    title: 'Request discount',
    subtitle: item.itemCode,
    builder: (_) => _DiscountRequestForm(item: item),
  );
}

enum _DiscountMode { percentage, amount }

class _DiscountRequestForm extends ConsumerStatefulWidget {
  const _DiscountRequestForm({required this.item});

  final JewelleryItem item;

  @override
  ConsumerState<_DiscountRequestForm> createState() =>
      _DiscountRequestFormState();
}

class _DiscountRequestFormState extends ConsumerState<_DiscountRequestForm> {
  static const _uuid = Uuid();

  final _value = TextEditingController();
  final _reason = TextEditingController();

  /// Minted once per sheet: a retried submit cannot raise two requests.
  final _idempotencyKey = _uuid.v4();

  _DiscountMode _mode = _DiscountMode.percentage;
  Customer? _customer;
  bool _busy = false;

  @override
  void dispose() {
    _value.dispose();
    _reason.dispose();
    super.dispose();
  }

  double? get _parsedValue {
    final value = double.tryParse(_value.text.trim().replaceAll(',', ''));
    if (value == null || value <= 0) return null;
    if (_mode == _DiscountMode.percentage && value > 100) return null;
    return value;
  }

  bool get _valid => _parsedValue != null && _reason.text.trim().length >= 3;

  Future<void> _submit() async {
    final branch = ref.read(currentBranchProvider);
    final value = _parsedValue;
    if (branch == null || value == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(salesRepositoryProvider)
          .createDiscountRequest(
            branchId: branch.id,
            reason: _reason.text.trim(),
            percentage: _mode == _DiscountMode.percentage ? value : null,
            amount: _mode == _DiscountMode.amount ? value : null,
            currency: _mode == _DiscountMode.amount
                ? widget.item.currency
                : null,
            customerId: _customer?.id,
            jewelleryItemId: widget.item.id,
            idempotencyKey: _idempotencyKey,
          );
      ref.invalidate(myDiscountRequestsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnackBar(
        context,
        message: 'Discount request sent for approval',
        tone: SnackTone.success,
      );
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showAppSnackBar(context, message: error.message, tone: SnackTone.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.item.currency ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<_DiscountMode>(
          segments: const [
            ButtonSegment(
              value: _DiscountMode.percentage,
              label: Text('Percentage'),
              icon: Icon(Icons.percent),
            ),
            ButtonSegment(
              value: _DiscountMode.amount,
              label: Text('Amount'),
              icon: Icon(Icons.payments_outlined),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (selection) => setState(() {
            _mode = selection.first;
            _value.clear();
          }),
        ),
        AppSpacing.gapMd,
        AppTextField(
          controller: _value,
          label: _mode == _DiscountMode.percentage
              ? 'Discount %'
              : 'Discount amount${currency.isEmpty ? '' : ' ($currency)'}',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          onChanged: (_) => setState(() {}),
        ),
        AppSpacing.gapMd,
        AppTextField(
          controller: _reason,
          label: 'Reason',
          hint: 'The approver sees this.',
          maxLines: 3,
          maxLength: 500,
          onChanged: (_) => setState(() {}),
        ),
        AppSpacing.gapMd,
        Text(
          'Customer (optional)',
          style: context.text.labelMedium?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
        AppSpacing.gapXs,
        CustomerPickerField(
          selected: _customer,
          onSelected: (customer) => setState(() => _customer = customer),
        ),
        AppSpacing.gapMd,
        Text(
          'The discounted price is calculated by the backend once the request '
          'is approved — nothing is estimated here.',
          style: context.text.labelSmall?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
        AppSpacing.gapLg,
        AppButton(
          label: 'Send for approval',
          icon: Icons.send_outlined,
          busy: _busy,
          onPressed: _valid ? _submit : null,
        ),
      ],
    );
  }
}

class _MyDiscountRequests extends ConsumerWidget {
  const _MyDiscountRequests();

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    DiscountRequest request,
  ) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Cancel discount request?',
      message: 'The approver will no longer see it.',
      confirmLabel: 'Cancel request',
      tone: ConfirmTone.danger,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(salesRepositoryProvider).cancelDiscountRequest(request.id);
      ref.invalidate(myDiscountRequestsProvider);
      if (context.mounted) {
        showAppSnackBar(
          context,
          message: 'Request cancelled',
          tone: SnackTone.success,
        );
      }
    } on AppException catch (error) {
      ref.invalidate(myDiscountRequestsProvider);
      if (context.mounted) {
        showAppSnackBar(context, message: error.message, tone: SnackTone.error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myDiscountRequestsProvider);
    final formatters = ref.watch(formattersProvider);

    return SectionCard(
      title: 'My discount requests',
      icon: Icons.percent_outlined,
      trailing: IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Refresh',
        onPressed: () => ref.invalidate(myDiscountRequestsProvider),
      ),
      child: AsyncValueView<List<DiscountRequest>>(
        value: requests,
        loading: const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
        onRetry: () => ref.invalidate(myDiscountRequestsProvider),
        isEmpty: (list) => list.isEmpty,
        empty: Text(
          'No discount requests yet.',
          style: context.text.bodySmall?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
        data: (list) => Column(
          children: [
            for (final request in list)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  request.isPercentage
                      ? '${formatters.percent(request.requestedPercentage)} off'
                      : '${formatters.money(request.requestedAmount, request.currency)} off',
                  style: AppTypography.numeric(context, size: 15),
                ),
                subtitle: Text(
                  [
                    if (request.reason != null) request.reason!,
                    if (request.requestedAt != null)
                      formatters.relative(request.requestedAt),
                    if (request.decisionNote != null &&
                        request.decisionNote!.isNotEmpty)
                      'Note: ${request.decisionNote}',
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusBadge(
                      label: request.status.label,
                      tone: request.status.tone,
                      dense: true,
                    ),
                    if (request.canCancel)
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Cancel request',
                        onPressed: () => _cancel(context, ref, request),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
