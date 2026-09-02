import 'package:flutter/material.dart';

import '../../../core/constants/permissions.dart';
import '../../../shared/widgets/status_badge.dart';

/// What kind of thing is waiting for a decision.
enum ApprovalKind {
  transfer(
    'Transfer',
    Icons.swap_horiz,
    Permission.inventoryTransferApprove,
    StatusTone.warning,
  ),
  purchaseOrder(
    'Purchase order',
    Icons.local_shipping_outlined,
    Permission.procurementApprove,
    StatusTone.info,
  ),
  requisition(
    'Requisition',
    Icons.assignment_outlined,
    Permission.procurementApprove,
    StatusTone.info,
  ),
  exchange(
    'Exchange / buyback',
    Icons.currency_exchange_outlined,
    Permission.exchangeApprove,
    StatusTone.vault,
  ),
  stockCount(
    'Stock count',
    Icons.fact_check_outlined,
    Permission.stockCountApprove,
    StatusTone.warning,
  );

  const ApprovalKind(this.label, this.icon, this.permission, this.tone);

  final String label;
  final IconData icon;
  final Permission permission;
  final StatusTone tone;
}

/// A pending decision, normalised across the five modules that produce them.
///
/// There is no unified approvals endpoint, so these are assembled client-side.
/// The normalised shape is what lets one screen present all of them, and is
/// also what a `GET /api/v1/approvals/pending` would return if it existed.
class ApprovalItem {
  const ApprovalItem({
    required this.kind,
    required this.id,
    required this.reference,
    required this.summary,
    this.requestedBy,
    this.requestedAt,
    this.amount,
    this.currency,
    this.detail,
    this.awaitingSecondApproval = false,
  });

  final ApprovalKind kind;
  final String id;
  final String reference;
  final String summary;
  final String? requestedBy;
  final DateTime? requestedAt;

  /// Present only where the decision carries money. Anything with an amount is
  /// forced through the detail screen before it can be decided.
  final double? amount;
  final String? currency;

  final String? detail;

  /// The backend models dual authorisation on movements and stock counts.
  final bool awaitingSecondApproval;

  /// How long someone has been blocked. The metric that actually matters in an
  /// approval queue.
  Duration? get age =>
      requestedAt == null ? null : DateTime.now().difference(requestedAt!);

  /// Money, or a vault-grade operation, is never a one-tap decision.
  bool get requiresDetailView =>
      amount != null || kind == ApprovalKind.exchange;
}
