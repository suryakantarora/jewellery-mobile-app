import '../../../core/constants/permissions.dart';
import '../../exchange/data/exchange_repository.dart';
import '../../exchange/domain/exchange_models.dart';
import '../../procurement/data/procurement_repository.dart';
import '../../procurement/domain/procurement_models.dart';
import '../../transfers/data/movement_repository.dart';
import '../../transfers/domain/movement.dart';
import '../../warehouse/data/warehouse_repository.dart';
import '../../warehouse/domain/warehouse_models.dart';
import '../domain/approval_models.dart';

/// Assembles the pending-approval queue from the modules that own it.
///
/// **There is no unified approvals endpoint.** Each module has its own pending
/// status and its own approve call, so this fans out to the ones the user can
/// actually act on and normalises the results.
///
/// Two consequences worth keeping in mind:
///  * A module the user cannot approve is **never queried** — that keeps the
///    queue honest and avoids a pile of 403s.
///  * A module that fails is skipped rather than failing the whole screen; a
///    partial queue is more useful than an error page.
///
/// `GET /api/v1/approvals/pending` would replace all of this with one call, and
/// would let the backend decide what a user may approve rather than the client
/// inferring it from permissions.
class ApprovalAggregator {
  ApprovalAggregator({
    required MovementRepository movements,
    required ProcurementRepository procurement,
    required ExchangeRepository exchanges,
    required WarehouseRepository warehouse,
  }) : _movements = movements,
       _procurement = procurement,
       _exchanges = exchanges,
       _warehouse = warehouse;

  final MovementRepository _movements;
  final ProcurementRepository _procurement;
  final ExchangeRepository _exchanges;
  final WarehouseRepository _warehouse;

  Future<List<ApprovalItem>> pending({
    required PermissionSet permissions,
    String? branchId,
  }) async {
    final results = await Future.wait([
      _transfers(permissions),
      _purchaseOrders(permissions),
      _exchangeRecords(permissions, branchId),
      _stockCounts(permissions, branchId),
    ]);

    final items = results.expand((list) => list).toList();

    // Oldest first: the queue metric that matters is how long someone has been
    // waiting, not what kind of thing it is.
    items.sort((a, b) {
      final left = a.requestedAt;
      final right = b.requestedAt;
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return left.compareTo(right);
    });

    return items;
  }

  Future<List<ApprovalItem>> _transfers(PermissionSet permissions) async {
    if (!permissions.has(Permission.inventoryTransferApprove)) return const [];

    try {
      final page = await _movements.search(
        status: MovementStatus.pendingApproval,
        size: 50,
      );
      return page.content
          .map(
            (movement) => ApprovalItem(
              kind: ApprovalKind.transfer,
              id: movement.id,
              reference: movement.referenceNumber,
              summary:
                  '${movement.itemCount} item'
                  '${movement.itemCount == 1 ? '' : 's'}',
              requestedBy: movement.createdBy,
              requestedAt: movement.createdAt,
              detail: movement.notes,
              awaitingSecondApproval: movement.awaitingSecondApproval,
            ),
          )
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<List<ApprovalItem>> _purchaseOrders(PermissionSet permissions) async {
    if (!permissions.has(Permission.procurementApprove)) return const [];

    try {
      final page = await _procurement.purchaseOrders(
        status: PurchaseOrderStatus.pendingApproval,
        size: 50,
      );
      return page.content
          .map(
            (order) => ApprovalItem(
              kind: ApprovalKind.purchaseOrder,
              id: order.id,
              reference: order.orderNumber,
              summary: '${order.orderedTotal} items',
              requestedBy: order.createdBy,
              requestedAt: order.createdAt,
              amount: order.estimatedTotal,
              currency: order.currency,
              detail: order.notes,
            ),
          )
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<List<ApprovalItem>> _exchangeRecords(
    PermissionSet permissions,
    String? branchId,
  ) async {
    if (!permissions.has(Permission.exchangeApprove)) return const [];

    try {
      final page = await _exchanges.search(
        status: ExchangeStatus.pendingApproval,
        branchId: branchId,
        size: 50,
      );
      return page.content
          .map(
            (record) => ApprovalItem(
              kind: ApprovalKind.exchange,
              id: record.id,
              reference: record.referenceNumber,
              summary:
                  '${record.exchangeType.label} · ${record.description ?? ''}',
              requestedBy: record.valuedBy,
              requestedAt: record.receivedDate,
              amount: record.netValuation,
              currency: record.currency,
            ),
          )
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<List<ApprovalItem>> _stockCounts(
    PermissionSet permissions,
    String? branchId,
  ) async {
    if (!permissions.has(Permission.stockCountApprove)) return const [];

    try {
      final page = await _warehouse.counts(
        status: StockCountStatus.pendingReview,
        branchId: branchId,
        size: 50,
      );
      return page.content
          .map(
            (count) => ApprovalItem(
              kind: ApprovalKind.stockCount,
              id: count.id,
              reference: count.referenceNumber,
              summary: count.hasVariance
                  ? '${count.missingCount} missing · '
                        '${count.unexpectedCount} unexpected'
                  : 'No variance',
              requestedBy: count.countedBy,
              requestedAt: count.countedAt,
              awaitingSecondApproval: count.awaitingSecondApproval,
            ),
          )
          .toList();
    } on Object {
      return const [];
    }
  }

  /// Approves one item by routing to the module that owns it.
  Future<void> approve(ApprovalItem item) async {
    switch (item.kind) {
      case ApprovalKind.transfer:
        await _movements.approve(item.id);
      case ApprovalKind.purchaseOrder:
      case ApprovalKind.requisition:
        await _procurement.approve(item.id);
      case ApprovalKind.exchange:
        await _exchanges.approve(item.id);
      case ApprovalKind.stockCount:
        await _warehouse.approve(item.id);
    }
  }

  Future<void> reject(ApprovalItem item, String reason) async {
    switch (item.kind) {
      case ApprovalKind.transfer:
        await _movements.reject(item.id, reason);
      case ApprovalKind.purchaseOrder:
      case ApprovalKind.requisition:
        await _procurement.reject(item.id, reason);
      case ApprovalKind.exchange:
        await _exchanges.reject(item.id, reason);
      case ApprovalKind.stockCount:
        await _warehouse.cancel(item.id, reason: reason);
    }
  }
}
