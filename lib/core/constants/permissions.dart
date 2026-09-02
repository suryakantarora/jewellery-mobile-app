/// Permission codes, mirroring the `identity.permission` table exactly.
///
/// Verified against a live backend: 67 codes, matching one-for-one.
///
/// Unrecognised codes from the server are preserved rather than dropped, so the
/// backend can introduce a permission without a mobile release breaking.
///
/// The UI hides and disables; the backend remains the authority. A 403 is
/// always rendered as a clear state, never treated as impossible.
enum Permission {
  // Inventory
  inventoryView('INVENTORY_VIEW'),
  inventoryCreate('INVENTORY_CREATE'),
  inventoryAdjust('INVENTORY_ADJUST'),
  inventoryReserve('INVENTORY_RESERVE'),
  inventoryTransfer('INVENTORY_TRANSFER'),
  inventoryTransferApprove('INVENTORY_TRANSFER_APPROVE'),

  // Product & pricing
  productView('PRODUCT_VIEW'),
  productCreate('PRODUCT_CREATE'),
  productUpdate('PRODUCT_UPDATE'),
  priceChange('PRICE_CHANGE'),

  // Materials
  metalView('METAL_VIEW'),
  metalManage('METAL_MANAGE'),
  metalRatePublish('METAL_RATE_PUBLISH'),
  gemstoneView('GEMSTONE_VIEW'),
  gemstoneManage('GEMSTONE_MANAGE'),

  // Warehouse
  warehouseView('WAREHOUSE_VIEW'),
  warehouseManage('WAREHOUSE_MANAGE'),
  stockCountPerform('STOCK_COUNT_PERFORM'),
  stockCountApprove('STOCK_COUNT_APPROVE'),

  // Procurement
  procurementView('PROCUREMENT_VIEW'),
  procurementCreate('PROCUREMENT_CREATE'),
  procurementApprove('PROCUREMENT_APPROVE'),
  procurementReceive('PROCUREMENT_RECEIVE'),
  supplierView('SUPPLIER_VIEW'),
  supplierManage('SUPPLIER_MANAGE'),

  // Sales
  saleView('SALE_VIEW'),
  saleCreate('SALE_CREATE'),
  saleReturn('SALE_RETURN'),
  discountRequest('DISCOUNT_REQUEST'),
  discountApprove('DISCOUNT_APPROVE'),

  // Customer & CRM
  customerView('CUSTOMER_VIEW'),
  customerManage('CUSTOMER_MANAGE'),
  customerKycVerify('CUSTOMER_KYC_VERIFY'),
  crmView('CRM_VIEW'),
  crmManage('CRM_MANAGE'),
  campaignManage('CAMPAIGN_MANAGE'),

  // Loyalty
  loyaltyView('LOYALTY_VIEW'),
  loyaltyManage('LOYALTY_MANAGE'),
  loyaltyRedeem('LOYALTY_REDEEM'),
  loyaltyAdjust('LOYALTY_ADJUST'),

  // Repair
  repairView('REPAIR_VIEW'),
  repairEstimate('REPAIR_ESTIMATE'),
  repairProcess('REPAIR_PROCESS'),

  // Exchange & buyback
  exchangeView('EXCHANGE_VIEW'),
  exchangeValue('EXCHANGE_VALUE'),
  exchangeProcess('EXCHANGE_PROCESS'),
  exchangeApprove('EXCHANGE_APPROVE'),

  // Payment & finance
  paymentView('PAYMENT_VIEW'),
  paymentCollect('PAYMENT_COLLECT'),
  paymentRefund('PAYMENT_REFUND'),
  paymentReconcile('PAYMENT_RECONCILE'),
  financeView('FINANCE_VIEW'),
  financePost('FINANCE_POST'),
  financeManage('FINANCE_MANAGE'),

  // Reporting & audit
  reportView('REPORT_VIEW'),
  complianceReport('COMPLIANCE_REPORT'),
  auditView('AUDIT_VIEW'),

  // Notifications
  notificationView('NOTIFICATION_VIEW'),
  notificationManage('NOTIFICATION_MANAGE'),

  // Files
  fileUpload('FILE_UPLOAD'),
  fileDownload('FILE_DOWNLOAD'),

  // Organisation & identity
  organizationView('ORGANIZATION_VIEW'),
  organizationManage('ORGANIZATION_MANAGE'),
  userView('USER_VIEW'),
  userManage('USER_MANAGE'),
  roleView('ROLE_VIEW'),
  roleManage('ROLE_MANAGE');

  const Permission(this.code);

  /// The exact string the backend issues in the JWT and on `/auth/me`.
  final String code;

  static final Map<String, Permission> _byCode = {
    for (final permission in values) permission.code: permission,
  };

  /// Returns the matching permission, or `null` for a code this build does not
  /// know about. Callers keep the raw string so nothing is silently lost.
  static Permission? fromCode(String code) => _byCode[code];
}

/// The permissions a user holds, plus any codes this build did not recognise.
class PermissionSet {
  PermissionSet({
    required Set<Permission> granted,
    Set<String> unknownCodes = const {},
    this.superAdmin = false,
  }) : _granted = granted,
       _unknown = unknownCodes;

  factory PermissionSet.fromCodes(
    Iterable<String> codes, {
    bool superAdmin = false,
  }) {
    final granted = <Permission>{};
    final unknown = <String>{};

    for (final code in codes) {
      final permission = Permission.fromCode(code);
      if (permission != null) {
        granted.add(permission);
      } else {
        unknown.add(code);
      }
    }

    return PermissionSet(
      granted: granted,
      unknownCodes: unknown,
      superAdmin: superAdmin,
    );
  }

  static final empty = PermissionSet(granted: const {});

  final Set<Permission> _granted;
  final Set<String> _unknown;

  /// Mirrors the backend's super-admin bypass so the UI agrees with the server.
  final bool superAdmin;

  Set<Permission> get granted => Set.unmodifiable(_granted);

  /// Codes the server sent that this build does not model — surfaced in the
  /// profile screen's permission viewer rather than hidden.
  Set<String> get unknownCodes => Set.unmodifiable(_unknown);

  bool has(Permission permission) =>
      superAdmin || _granted.contains(permission);

  bool hasAny(Iterable<Permission> permissions) =>
      superAdmin || permissions.any(_granted.contains);

  bool hasAll(Iterable<Permission> permissions) =>
      superAdmin || permissions.every(_granted.contains);

  bool get isEmpty => _granted.isEmpty && !superAdmin;
}
