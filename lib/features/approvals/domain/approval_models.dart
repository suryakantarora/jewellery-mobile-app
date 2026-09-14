import 'package:flutter/material.dart';

import '../../../core/constants/permissions.dart';
import '../../../shared/widgets/status_badge.dart';

/// What kind of thing is waiting for a decision.
///
/// [code] is the `type` the unified approvals endpoint uses in both its
/// payloads and its paths. [createPermission] is what lets a user *answer* an
/// information request on that type — the requester's side of the thread.
enum ApprovalKind {
  transfer(
    'TRANSFER',
    'Transfer',
    Icons.swap_horiz,
    Permission.inventoryTransferApprove,
    Permission.inventoryTransfer,
    StatusTone.warning,
  ),
  purchaseOrder(
    'PURCHASE_ORDER',
    'Purchase order',
    Icons.local_shipping_outlined,
    Permission.procurementApprove,
    Permission.procurementCreate,
    StatusTone.info,
  ),
  requisition(
    'REQUISITION',
    'Requisition',
    Icons.assignment_outlined,
    Permission.procurementApprove,
    Permission.procurementCreate,
    StatusTone.info,
  ),
  exchange(
    'EXCHANGE',
    'Exchange / buyback',
    Icons.currency_exchange_outlined,
    Permission.exchangeApprove,
    Permission.exchangeProcess,
    StatusTone.vault,
  ),
  stockCount(
    'STOCK_COUNT',
    'Stock count',
    Icons.fact_check_outlined,
    Permission.stockCountApprove,
    Permission.stockCountPerform,
    StatusTone.warning,
  ),
  goodsReceipt(
    'GOODS_RECEIPT',
    'Goods receipt',
    Icons.inventory_2_outlined,
    Permission.procurementApprove,
    Permission.procurementReceive,
    StatusTone.info,
  ),
  discount(
    'DISCOUNT',
    'Discount',
    Icons.percent_outlined,
    Permission.discountApprove,
    Permission.discountRequest,
    StatusTone.vault,
  );

  const ApprovalKind(
    this.code,
    this.label,
    this.icon,
    this.permission,
    this.createPermission,
    this.tone,
  );

  /// The backend's `type` discriminator.
  final String code;
  final String label;
  final IconData icon;

  /// Lets the holder decide.
  final Permission permission;

  /// Lets the holder answer an information request (the requester's side).
  final Permission createPermission;
  final StatusTone tone;

  /// Null for a type this build does not know, so a new backend type is
  /// skipped rather than crashing the queue.
  static ApprovalKind? fromCode(String? code) {
    for (final kind in values) {
      if (kind.code == code) return kind;
    }
    return null;
  }
}

/// What an approver can do with a pending item.
enum ApprovalDecision {
  approve('APPROVE'),
  reject('REJECT'),
  requestInfo('REQUEST_INFO');

  const ApprovalDecision(this.code);
  final String code;

  /// The backend insists on a reason for anything other than an approval.
  bool get requiresReason => this != ApprovalDecision.approve;
}

/// A pending decision, as returned by `GET /api/v1/approvals/pending`.
///
/// The backend normalises every module's pending state into this one shape and
/// already scopes the list to what the caller may approve, so the client no
/// longer infers that from permissions.
class ApprovalItem {
  const ApprovalItem({
    required this.kind,
    required this.id,
    required this.reference,
    required this.summary,
    this.branchId,
    this.branchName,
    this.requestedBy,
    this.requestedAt,
    this.amount,
    this.currency,
    this.detail,
    this.awaitingSecondApproval = false,
    this.infoRequested = false,
  });

  final ApprovalKind kind;
  final String id;
  final String reference;
  final String summary;
  final String? branchId;
  final String? branchName;
  final String? requestedBy;
  final DateTime? requestedAt;

  /// Present only where the decision carries money. Anything with an amount is
  /// forced through the detail screen before it can be decided.
  final double? amount;
  final String? currency;

  final String? detail;

  /// The backend models dual authorisation on movements and stock counts.
  final bool awaitingSecondApproval;

  /// An approver has asked the requester a question that is still open.
  final bool infoRequested;

  /// How long someone has been blocked. The metric that actually matters in an
  /// approval queue.
  Duration? get age =>
      requestedAt == null ? null : DateTime.now().difference(requestedAt!);

  /// Money, or a vault-grade operation, is never a one-tap decision.
  bool get requiresDetailView =>
      amount != null ||
      kind == ApprovalKind.exchange ||
      kind == ApprovalKind.discount;

  /// Null when the type is one this build does not know.
  static ApprovalItem? fromJson(Map<String, dynamic> json) {
    final kind = ApprovalKind.fromCode(json['type'] as String?);
    if (kind == null) return null;
    return ApprovalItem(
      kind: kind,
      id: json['id'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      branchId: json['branchId'] as String?,
      branchName: json['branchName'] as String?,
      requestedBy: json['requestedBy'] as String?,
      requestedAt: DateTime.tryParse(json['requestedAt'] as String? ?? ''),
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      detail: json['detail'] as String?,
      awaitingSecondApproval: json['awaitingSecondApproval'] as bool? ?? false,
      infoRequested: json['infoRequested'] as bool? ?? false,
    );
  }
}

/// `GET /api/v1/approvals/pending/count`.
class ApprovalCounts {
  const ApprovalCounts({required this.total, required this.byKind});

  final int total;
  final Map<ApprovalKind, int> byKind;

  static const empty = ApprovalCounts(total: 0, byKind: {});

  factory ApprovalCounts.fromJson(Map<String, dynamic> json) {
    final raw = json['byType'];
    final byKind = <ApprovalKind, int>{};
    if (raw is Map<String, dynamic>) {
      for (final entry in raw.entries) {
        final kind = ApprovalKind.fromCode(entry.key);
        final count = (entry.value as num?)?.toInt() ?? 0;
        if (kind != null && count > 0) byKind[kind] = count;
      }
    }
    return ApprovalCounts(
      total: (json['total'] as num?)?.toInt() ?? 0,
      byKind: byKind,
    );
  }
}

/// The outcome of `POST /approvals/{type}/{id}/decision`.
class ApprovalDecisionResult {
  const ApprovalDecisionResult({
    required this.id,
    required this.decision,
    this.status,
    this.decidedBy,
    this.decidedAt,
  });

  final String id;
  final String decision;
  final String? status;
  final String? decidedBy;
  final DateTime? decidedAt;

  factory ApprovalDecisionResult.fromJson(Map<String, dynamic> json) =>
      ApprovalDecisionResult(
        id: json['id'] as String? ?? '',
        decision: json['decision'] as String? ?? '',
        status: json['status'] as String?,
        decidedBy: json['decidedBy'] as String?,
        decidedAt: DateTime.tryParse(json['decidedAt'] as String? ?? ''),
      );
}

/// One question on an approval's information thread, and its answer if any.
class InformationRequest {
  const InformationRequest({
    required this.id,
    required this.message,
    this.requestedBy,
    this.requestedAt,
    this.answer,
    this.answeredBy,
    this.answeredAt,
    this.open = true,
  });

  final String id;
  final String message;
  final String? requestedBy;
  final DateTime? requestedAt;
  final String? answer;
  final String? answeredBy;
  final DateTime? answeredAt;
  final bool open;

  factory InformationRequest.fromJson(Map<String, dynamic> json) =>
      InformationRequest(
        id: json['id'] as String? ?? '',
        message: json['message'] as String? ?? '',
        requestedBy: json['requestedBy'] as String?,
        requestedAt: DateTime.tryParse(json['requestedAt'] as String? ?? ''),
        answer: json['answer'] as String?,
        answeredBy: json['answeredBy'] as String?,
        answeredAt: DateTime.tryParse(json['answeredAt'] as String? ?? ''),
        open: json['open'] as bool? ?? (json['answer'] == null),
      );
}
