import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/permissions.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../domain/jewellery_item.dart';
import '../../../sales/presentation/screens/price_sheet.dart';
import '../providers/jewellery_providers.dart';
import 'repair_intake_sheet.dart';
import 'reserve_item_sheet.dart';
import 'transfer_item_sheet.dart';

/// One action available on an item.
class ItemAction {
  const ItemAction({
    required this.label,
    required this.icon,
    required this.permission,
    this.requiresStatus,
    this.requiresTransition,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final Permission permission;

  /// The item must currently be in one of these statuses.
  final Set<ItemStatus>? requiresStatus;

  /// The backend must list this as a legal next state.
  final ItemStatus? requiresTransition;

  final bool danger;
}

/// Resolves the actions an item offers.
///
/// The rule is `allowedTransitions ∩ permissions`: the backend's own state
/// machine decides what is legal, the user's permissions decide what they may
/// do, and the app never guesses either. An action the user lacks rights for is
/// shown disabled rather than hidden — inside a detail screen, a vanishing
/// button makes the screen look broken.
List<ItemAction> resolveItemActions(JewelleryItem item) {
  const catalogue = <ItemAction>[
    ItemAction(
      label: 'Transfer',
      icon: Icons.swap_horiz,
      permission: Permission.inventoryTransfer,
      requiresTransition: ItemStatus.inTransit,
    ),
    ItemAction(
      label: 'Reserve',
      icon: Icons.bookmark_add_outlined,
      permission: Permission.inventoryReserve,
      requiresTransition: ItemStatus.reserved,
    ),
    ItemAction(
      label: 'Release',
      icon: Icons.bookmark_remove_outlined,
      permission: Permission.inventoryReserve,
      requiresStatus: {ItemStatus.reserved},
    ),
    ItemAction(
      label: 'Start repair',
      icon: Icons.build_outlined,
      permission: Permission.repairProcess,
      requiresTransition: ItemStatus.underRepair,
    ),
    ItemAction(
      label: 'Price',
      icon: Icons.sell_outlined,
      permission: Permission.saleView,
    ),
    ItemAction(
      label: 'Availability',
      icon: Icons.storefront_outlined,
      permission: Permission.inventoryView,
    ),
    ItemAction(
      label: 'Change status',
      icon: Icons.edit_outlined,
      permission: Permission.inventoryAdjust,
      danger: true,
    ),
  ];

  return catalogue
      .where((action) {
        if (action.requiresStatus != null) {
          return action.requiresStatus!.contains(item.status);
        }
        if (action.requiresTransition != null) {
          return item.canTransitionTo(action.requiresTransition!);
        }
        return true;
      })
      .toList(growable: false);
}

/// The sticky action bar on the passport screen.
class ItemActionBar extends ConsumerStatefulWidget {
  const ItemActionBar({super.key, required this.item, this.onChanged});

  final JewelleryItem item;
  final VoidCallback? onChanged;

  @override
  ConsumerState<ItemActionBar> createState() => _ItemActionBarState();
}

class _ItemActionBarState extends ConsumerState<ItemActionBar> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      widget.onChanged?.call();
    } on ConcurrentModificationException catch (error) {
      if (mounted) {
        final reload = await showConfirmationDialog(
          context,
          title: 'Item changed',
          message: error.message,
          confirmLabel: 'Reload',
        );
        if (reload) widget.onChanged?.call();
      }
    } on AppException catch (error) {
      if (mounted) {
        showAppSnackBar(context, message: error.message, tone: SnackTone.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeStatus() async {
    final item = widget.item;
    final target = await showAppBottomSheet<ItemStatus>(
      context,
      title: 'Change status',
      subtitle: 'Only the transitions the backend allows are listed.',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final status in item.allowedTransitions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(status.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pop(status),
            ),
        ],
      ),
    );
    if (target == null || !mounted) return;

    // The backend requires a reason and audits it, so the UI must not offer a
    // path that skips one.
    final reason = await showReasonSheet(
      context,
      title: 'Reason for change',
      hint: 'Why is ${item.itemCode} moving to ${target.label}?',
    );
    if (reason == null || !mounted) return;

    await _run(() async {
      await ref
          .read(jewelleryRepositoryProvider)
          .changeStatus(itemId: item.id, target: target, reason: reason);
      if (mounted) {
        showAppSnackBar(
          context,
          message: 'Status changed to ${target.label}',
          tone: SnackTone.success,
        );
      }
    });
  }

  Future<void> _reserve() async {
    final reserved = await showReserveItemSheet(context, widget.item);
    if (!reserved || !mounted) return;
    showAppSnackBar(
      context,
      message: '${widget.item.itemCode} reserved',
      tone: SnackTone.success,
    );
    widget.onChanged?.call();
  }

  Future<void> _transfer() async {
    final movement = await showTransferItemSheet(context, widget.item);
    if (movement == null || !mounted) return;
    widget.onChanged?.call();
    // Straight to the request, so the dispatcher can approve and dispatch
    // without hunting for it in the list.
    unawaited(context.push(AppRoutes.transferDetailPath(movement.id)));
  }

  Future<void> _startRepair() async {
    final job = await showRepairIntakeSheet(context, widget.item);
    if (job == null || !mounted) return;
    widget.onChanged?.call();
    unawaited(context.push(AppRoutes.repairPath(job.id)));
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionsProvider);
    final actions = resolveItemActions(widget.item);
    if (actions.isEmpty) return const SizedBox.shrink();

    final primary = actions.first;
    final overflow = actions.skip(1).toList(growable: false);

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
        child: Row(
          children: [
            Expanded(
              child: Tooltip(
                message: permissions.has(primary.permission)
                    ? ''
                    : context.l10n.stateNoPermission,
                child: AppButton(
                  label: primary.label,
                  icon: primary.icon,
                  busy: _busy,
                  onPressed: permissions.has(primary.permission)
                      ? () => _handle(primary)
                      : null,
                ),
              ),
            ),
            if (overflow.isNotEmpty) ...[
              AppSpacing.wGapMd,
              PopupMenuButton<ItemAction>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'More actions',
                onSelected: _handle,
                itemBuilder: (context) => [
                  for (final action in overflow)
                    PopupMenuItem(
                      value: action,
                      // Shown but disabled, with the reason on hover — hiding
                      // it would leave staff unable to see what they'd need.
                      enabled: permissions.has(action.permission),
                      child: Row(
                        children: [
                          Icon(
                            action.icon,
                            size: 18,
                            color: action.danger ? context.colors.danger : null,
                          ),
                          AppSpacing.wGapMd,
                          Text(action.label),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handle(ItemAction action) {
    switch (action.label) {
      case 'Change status':
        _changeStatus();
      case 'Price':
        showPriceSheet(context, widget.item);
      case 'Availability':
        final productId = widget.item.productId;
        if (productId == null) {
          showAppSnackBar(
            context,
            message: 'This item has no product to compare against',
          );
          return;
        }
        showAvailabilitySheet(
          context,
          productId,
          ref.read(referenceDataProvider).cachedProduct(productId)?.name ??
              'Product',
        );
      case 'Release':
        _run(() async {
          await ref
              .read(jewelleryRepositoryProvider)
              .releaseReservation(widget.item.id);
          if (mounted) {
            showAppSnackBar(
              context,
              message: 'Reservation released',
              tone: SnackTone.success,
            );
          }
        });
      case 'Reserve':
        _reserve();
      case 'Transfer':
        _transfer();
      case 'Start repair':
        _startRepair();
    }
  }
}
