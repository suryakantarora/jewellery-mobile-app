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
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/data_display.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/procurement_models.dart';
import '../providers/procurement_providers.dart';

/// Purchase orders.
///
/// Read, approve and receive only — authoring a PO needs supplier terms and
/// pricing that belong in the Admin portal, not on a phone at a loading bay.
class ProcurementScreen extends ConsumerWidget {
  const ProcurementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(purchaseOrderListProvider);
    final status = ref.watch(poStatusFilterProvider);

    return AppScaffold(
      title: context.l10n.screenProcurement,
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                for (final option in const [
                  PurchaseOrderStatus.pendingApproval,
                  PurchaseOrderStatus.approved,
                  PurchaseOrderStatus.partiallyReceived,
                  PurchaseOrderStatus.received,
                ])
                  Padding(
                    padding: const EdgeInsets.only(
                      right: AppSpacing.sm,
                      top: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                    ),
                    child: ChoiceChip(
                      label: Text(option.label),
                      selected: status == option,
                      onSelected: (selected) => ref
                          .read(poStatusFilterProvider.notifier)
                          .set(selected ? option : null),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: AsyncValueView<List<PurchaseOrder>>(
              value: orders,
              onRetry: () => ref.invalidate(purchaseOrderListProvider),
              isEmpty: (list) => list.isEmpty,
              empty: const EmptyState(
                icon: Icons.local_shipping_outlined,
                title: 'No purchase orders',
                message: 'Orders raised in the Admin portal appear here.',
              ),
              data: (list) => RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(purchaseOrderListProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _OrderRow(order: list[index]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends ConsumerWidget {
  const _OrderRow({required this.order});

  final PurchaseOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatters = ref.watch(formattersProvider);
    final suppliers = ref.watch(suppliersProvider).valueOrNull;
    final supplier = suppliers?[order.supplierId]?.name;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              order.orderNumber,
              style: AppTypography.mono(context, size: 13),
            ),
          ),
          StatusBadge(
            label: order.status.label,
            tone: order.status.tone,
            dense: true,
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSpacing.gapXs,
          Text(supplier ?? 'Supplier', style: context.text.bodySmall),
          AppSpacing.gapXs,
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: LinearProgressIndicator(
                    value: order.receiptProgress,
                    minHeight: 4,
                    backgroundColor: context.scheme.surfaceContainerHighest,
                  ),
                ),
              ),
              AppSpacing.wGapSm,
              Text(
                '${order.receivedTotal}/${order.orderedTotal}',
                style: AppTypography.numeric(context, size: 11),
              ),
            ],
          ),
          if (order.isOverdue) ...[
            AppSpacing.gapXs,
            Text(
              'Expected ${formatters.date(order.expectedDeliveryDate)}',
              style: context.text.labelSmall?.copyWith(
                color: context.colors.danger,
              ),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoutes.purchaseOrderPath(order.id)),
    );
  }
}

/// One purchase order, with approval and receiving.
class PurchaseOrderDetailScreen extends ConsumerStatefulWidget {
  const PurchaseOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<PurchaseOrderDetailScreen> createState() =>
      _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState
    extends ConsumerState<PurchaseOrderDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      ref
        ..invalidate(purchaseOrderDetailProvider(widget.orderId))
        ..invalidate(purchaseOrderListProvider);
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
    final order = ref.watch(purchaseOrderDetailProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase order')),
      body: AsyncValueView<PurchaseOrder>(
        value: order,
        loading: const Center(child: CircularProgressIndicator()),
        onRetry: () =>
            ref.invalidate(purchaseOrderDetailProvider(widget.orderId)),
        data: _body,
      ),
      bottomNavigationBar: order.maybeWhen(data: _actions, orElse: () => null),
    );
  }

  Widget _body(PurchaseOrder order) {
    final formatters = ref.watch(formattersProvider);
    final permissions = ref.watch(permissionsProvider);
    final suppliers = ref.watch(suppliersProvider).valueOrNull;

    // Order values are commercial: a receiving clerk does not need them.
    final canSeeValue = permissions.hasAny([
      Permission.financeView,
      Permission.reportView,
      Permission.procurementApprove,
    ]);

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
                order.orderNumber,
                style: AppTypography.mono(context, size: 16),
              ),
            ),
            StatusBadge(label: order.status.label, tone: order.status.tone),
          ],
        ),
        AppSpacing.gapLg,
        AppCard(
          child: Column(
            children: [
              KeyValueRow(
                label: 'Supplier',
                value: suppliers?[order.supplierId]?.name ?? '—',
              ),
              KeyValueRow(
                label: 'Ordered',
                value: formatters.date(order.orderDate),
              ),
              KeyValueRow(
                label: 'Expected',
                value: formatters.date(order.expectedDeliveryDate),
                valueWidget: order.isOverdue
                    ? Text(
                        formatters.date(order.expectedDeliveryDate),
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.danger,
                        ),
                      )
                    : null,
              ),
              if (canSeeValue)
                KeyValueRow(
                  label: 'Estimated total',
                  value: formatters.money(order.estimatedTotal, order.currency),
                  numeric: true,
                ),
              KeyValueRow(
                label: 'Received',
                value: '${order.receivedTotal} of ${order.orderedTotal}',
                numeric: true,
              ),
            ],
          ),
        ),
        if (order.rejectionReason != null) ...[
          AppSpacing.gapLg,
          AppCard(
            tone: context.colors.dangerContainer.withValues(alpha: 0.4),
            child: Text(
              'Rejected: ${order.rejectionReason}',
              style: context.text.bodySmall,
            ),
          ),
        ],
        AppSpacing.gapLg,
        SectionCard(
          title: 'Lines',
          icon: Icons.list_alt,
          subtitle: '${order.lines.length} lines',
          child: Column(
            children: [
              for (final line in order.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      Icon(
                        line.isComplete
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 16,
                        color: line.isComplete
                            ? context.colors.success
                            : context.scheme.outline,
                      ),
                      AppSpacing.wGapMd,
                      Expanded(
                        child: Text(
                          line.description ?? 'Line',
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
      ],
    );
  }

  Widget? _actions(PurchaseOrder order) {
    final permissions = ref.watch(permissionsProvider);
    final repository = ref.read(procurementRepositoryProvider);
    final actions = <Widget>[];

    if (order.status == PurchaseOrderStatus.pendingApproval &&
        permissions.has(Permission.procurementApprove)) {
      actions.addAll([
        Expanded(
          child: AppButton(
            label: 'Approve',
            icon: Icons.check,
            busy: _busy,
            onPressed: () async {
              final confirmed = await showConfirmationDialog(
                context,
                title: 'Approve order?',
                message:
                    '${order.orderNumber} · '
                    '${order.orderedTotal} items',
              );
              if (confirmed) {
                await _run(
                  () => repository.approve(order.id),
                  'Order approved',
                );
              }
            },
          ),
        ),
        AppSpacing.wGapMd,
        AppButton(
          label: 'Reject',
          variant: AppButtonVariant.danger,
          expand: false,
          onPressed: () async {
            final reason = await showReasonSheet(
              context,
              title: 'Reason for rejection',
            );
            if (reason != null) {
              await _run(
                () => repository.reject(order.id, reason),
                'Order rejected',
              );
            }
          },
        ),
      ]);
    } else if (order.status.canReceive &&
        permissions.has(Permission.procurementReceive)) {
      actions.add(
        Expanded(
          child: AppButton(
            label: 'Receive goods',
            icon: Icons.inventory_2_outlined,
            onPressed: () => context.push(AppRoutes.goodsReceivePath(order.id)),
          ),
        ),
      );
    }

    if (actions.isEmpty) return null;

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
      child: SafeArea(top: false, child: Row(children: actions)),
    );
  }
}
