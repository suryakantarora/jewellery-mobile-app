/// The dashboard summary, mirroring `GET /dashboard/summary`.
///
/// Every section is nullable because the backend **omits** a section the
/// caller may not see. Absence means "not for you", never "failed" — a tile
/// is simply not rendered. Money fields arrive as decimal strings or numbers;
/// [parseNum] accepts both, and nothing here does arithmetic on them.
class DashboardSummary {
  const DashboardSummary({
    this.branchId,
    this.branchName,
    this.generatedAt,
    this.sales,
    this.inventory,
    this.inventoryValue,
    this.transfers,
    this.approvals,
    this.repairs,
    this.procurement,
    this.unreadNotifications,
    this.metalRates = const [],
  });

  final String? branchId;
  final String? branchName;
  final DateTime? generatedAt;

  final SalesSummary? sales;
  final InventorySummary? inventory;
  final InventoryValueSummary? inventoryValue;
  final TransfersSummary? transfers;
  final ApprovalsSummary? approvals;
  final RepairsSummary? repairs;
  final ProcurementSummary? procurement;

  /// Always present on the wire; kept for completeness. The badge elsewhere in
  /// the app owns unread rendering, so the dashboard does not show it.
  final int? unreadNotifications;

  /// Empty when the caller lacks `METAL_VIEW` or nothing is published.
  final List<MetalRateSummary> metalRates;

  bool get isEmpty =>
      sales == null &&
      inventory == null &&
      inventoryValue == null &&
      transfers == null &&
      approvals == null &&
      repairs == null &&
      procurement == null &&
      metalRates.isEmpty;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      branchId: json['branchId'] as String?,
      branchName: json['branchName'] as String?,
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? ''),
      sales: _section(json['sales'], SalesSummary.fromJson),
      inventory: _section(json['inventory'], InventorySummary.fromJson),
      inventoryValue: _section(
        json['inventoryValue'],
        InventoryValueSummary.fromJson,
      ),
      transfers: _section(json['transfers'], TransfersSummary.fromJson),
      approvals: _section(json['approvals'], ApprovalsSummary.fromJson),
      repairs: _section(json['repairs'], RepairsSummary.fromJson),
      procurement: _section(json['procurement'], ProcurementSummary.fromJson),
      unreadNotifications: parseInt(
        (json['notifications'] as Map<String, dynamic>?)?['unread'],
      ),
      metalRates: ((json['metalRates'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MetalRateSummary.fromJson)
          .toList(growable: false),
    );
  }

  static T? _section<T>(Object? raw, T Function(Map<String, dynamic>) from) =>
      raw is Map<String, dynamic> ? from(raw) : null;
}

/// Tolerant numeric parse: the backend serialises `BigDecimal` as a string in
/// some paths and a number in others.
num? parseNum(Object? raw) => switch (raw) {
  num n => n,
  String s => num.tryParse(s.trim()),
  _ => null,
};

int? parseInt(Object? raw) => parseNum(raw)?.toInt();

class SalesSummary {
  const SalesSummary({
    this.todayCount,
    this.todayTotal,
    this.currency,
    this.monthToDateTotal,
  });

  final int? todayCount;
  final num? todayTotal;
  final String? currency;
  final num? monthToDateTotal;

  factory SalesSummary.fromJson(Map<String, dynamic> json) => SalesSummary(
    todayCount: parseInt(json['todayCount']),
    todayTotal: parseNum(json['todayTotal']),
    currency: json['currency'] as String?,
    monthToDateTotal: parseNum(json['monthToDateTotal']),
  );
}

class InventorySummary {
  const InventorySummary({
    this.totalItems,
    this.availableItems,
    this.reservedItems,
    this.lowStockProducts,
  });

  final int? totalItems;
  final int? availableItems;
  final int? reservedItems;

  /// Monitored locations at or below their threshold.
  final int? lowStockProducts;

  factory InventorySummary.fromJson(Map<String, dynamic> json) =>
      InventorySummary(
        totalItems: parseInt(json['totalItems']),
        availableItems: parseInt(json['availableItems']),
        reservedItems: parseInt(json['reservedItems']),
        lowStockProducts: parseInt(json['lowStockProducts']),
      );
}

class InventoryValueSummary {
  const InventoryValueSummary({
    this.costValue,
    this.retailValue,
    this.currency,
  });

  final num? costValue;
  final num? retailValue;
  final String? currency;

  factory InventoryValueSummary.fromJson(Map<String, dynamic> json) =>
      InventoryValueSummary(
        costValue: parseNum(json['costValue']),
        retailValue: parseNum(json['retailValue']),
        currency: json['currency'] as String?,
      );
}

class TransfersSummary {
  const TransfersSummary({
    this.pendingApproval,
    this.awaitingSecondApproval,
    this.incoming,
    this.outgoing,
  });

  final int? pendingApproval;
  final int? awaitingSecondApproval;
  final int? incoming;
  final int? outgoing;

  factory TransfersSummary.fromJson(Map<String, dynamic> json) =>
      TransfersSummary(
        pendingApproval: parseInt(json['pendingApproval']),
        awaitingSecondApproval: parseInt(json['awaitingSecondApproval']),
        incoming: parseInt(json['incoming']),
        outgoing: parseInt(json['outgoing']),
      );
}

class ApprovalsSummary {
  const ApprovalsSummary({this.total, this.byType = const {}});

  final int? total;

  /// Keyed by approval type code (`TRANSFER`, `PURCHASE_ORDER`, ...). Only the
  /// types the caller may approve are present.
  final Map<String, int> byType;

  factory ApprovalsSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['byType'];
    return ApprovalsSummary(
      total: parseInt(json['total']),
      byType: raw is Map
          ? {
              for (final entry in raw.entries)
                if (parseInt(entry.value) case final count?)
                  entry.key.toString(): count,
            }
          : const {},
    );
  }
}

class RepairsSummary {
  const RepairsSummary({this.ready, this.inProgress, this.awaitingCustomer});

  final int? ready;
  final int? inProgress;
  final int? awaitingCustomer;

  factory RepairsSummary.fromJson(Map<String, dynamic> json) => RepairsSummary(
    ready: parseInt(json['ready']),
    inProgress: parseInt(json['inProgress']),
    awaitingCustomer: parseInt(json['awaitingCustomer']),
  );
}

class ProcurementSummary {
  const ProcurementSummary({this.pendingOrders, this.awaitingReceipt});

  final int? pendingOrders;
  final int? awaitingReceipt;

  factory ProcurementSummary.fromJson(Map<String, dynamic> json) =>
      ProcurementSummary(
        pendingOrders: parseInt(json['pendingOrders']),
        awaitingReceipt: parseInt(json['awaitingReceipt']),
      );
}

/// One published rate. [stale] is the server's verdict, so the app does not
/// re-derive freshness from a clock that may be wrong.
class MetalRateSummary {
  const MetalRateSummary({
    this.metalId,
    this.metalName,
    this.purityId,
    this.purityCode,
    this.rateType,
    this.rate,
    this.currency,
    this.publishedAt,
    this.stale = false,
  });

  final String? metalId;
  final String? metalName;
  final String? purityId;
  final String? purityCode;
  final String? rateType;
  final num? rate;
  final String? currency;
  final DateTime? publishedAt;
  final bool stale;

  /// "22K Gold", or whichever half is known.
  String get label =>
      [purityCode, metalName].whereType<String>().join(' ').trim();

  factory MetalRateSummary.fromJson(Map<String, dynamic> json) =>
      MetalRateSummary(
        metalId: json['metalId'] as String?,
        metalName: json['metalName'] as String?,
        purityId: json['purityId'] as String?,
        purityCode: json['purityCode'] as String?,
        rateType: json['rateType'] as String?,
        rate: parseNum(json['rate']),
        currency: json['currency'] as String?,
        publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
        stale: json['stale'] as bool? ?? false,
      );
}
