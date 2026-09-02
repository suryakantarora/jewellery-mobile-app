/// Every backend path in one place, mirroring the Spring Boot controllers.
///
/// Paths are relative to `AppConfig.apiRoot` (`{base}/api/v1`).
abstract final class ApiEndpoints {
  // --- Authentication (AuthController) -------------------------------------
  static const login = '/auth/login';
  static const refresh = '/auth/refresh';
  static const logout = '/auth/logout';
  static const logoutAll = '/auth/logout-all';
  static const changePassword = '/auth/change-password';
  static const me = '/auth/me';

  // --- Organisation (OrganizationController) -------------------------------
  static const companies = '/companies';
  static String company(String id) => '/companies/$id';
  static const branches = '/branches';

  /// The caller's own branches. Needs no permission, unlike [branches], which
  /// requires ORGANIZATION_VIEW — a permission a sales executive has no reason
  /// to hold and without which they could not sign in at all.
  static const myBranches = '/branches/mine';
  static String branch(String id) => '/branches/$id';
  static String branchLocations(String branchId) =>
      '/branches/$branchId/locations';
  static String location(String id) => '/locations/$id';

  // --- Inventory (JewelleryItemController) ---------------------------------
  static const items = '/inventory/items';
  static String item(String id) => '/inventory/items/$id';
  static const itemByTag = '/inventory/items/by-tag';
  static String itemPassport(String id) => '/inventory/items/$id/passport';
  static String itemTags(String id) => '/inventory/items/$id/tags';
  static String itemRelease(String id) => '/inventory/items/$id/release';
  static String itemStatus(String id) => '/inventory/items/$id/status';
  static const reservations = '/inventory/reservations';
  static String releaseReservation(String id) =>
      '/inventory/items/$id/release-reservation';

  // --- Movements / transfers (InventoryMovementController) -----------------
  static const transfers = '/inventory/transfers';
  static String transfer(String id) => '/inventory/transfers/$id';
  static String transferApprove(String id) =>
      '/inventory/transfers/$id/approve';
  static String transferReject(String id) => '/inventory/transfers/$id/reject';
  static String transferDispatch(String id) =>
      '/inventory/transfers/$id/dispatch';
  static String transferReceive(String id) =>
      '/inventory/transfers/$id/receive';
  static String transferCancel(String id) => '/inventory/transfers/$id/cancel';

  // --- Warehouse (WarehouseController) -------------------------------------
  static const bins = '/warehouse/bins';
  static const stockCounts = '/warehouse/stock-counts';
  static String stockCount(String id) => '/warehouse/stock-counts/$id';
  static String stockCountSubmit(String id) =>
      '/warehouse/stock-counts/$id/submit';
  static String stockCountApprove(String id) =>
      '/warehouse/stock-counts/$id/approve';
  static String stockCountCancel(String id) =>
      '/warehouse/stock-counts/$id/cancel';

  // --- Procurement (ProcurementController) ---------------------------------
  static const requisitions = '/procurement/requisitions';
  static const purchaseOrders = '/procurement/purchase-orders';
  static String purchaseOrder(String id) => '/procurement/purchase-orders/$id';
  static const goodsReceipts = '/procurement/goods-receipts';
  static const suppliers = '/suppliers';

  // --- Product & master data -----------------------------------------------
  static const products = '/products';
  static const designs = '/designs';
  static const productCategories = '/product-categories';
  static const productTypes = '/product-types';
  static const brands = '/brands';
  static const collections = '/collections';
  static const sizes = '/sizes';

  // --- Metal & gemstone -----------------------------------------------------
  static const metals = '/metals';
  static String metalPurities(String metalId) => '/metals/$metalId/purities';
  static const metalRates = '/metal-rates';
  static const currentMetalRates = '/metal-rates/current';
  static const gemstones = '/gemstones';
  static const stoneCertificates = '/stone-certificates';
  static String itemStones(String itemId) => '/jewellery-items/$itemId/stones';

  // --- Sales, pricing, payment ---------------------------------------------
  static const sales = '/sales';
  static const quotations = '/quotations';
  static const dailyClosing = '/sales/daily-closing';
  static const pricingCalculate = '/pricing/calculate';
  static const discountPolicies = '/pricing/discount-policies';
  static const payments = '/payments';

  // --- Customer & CRM -------------------------------------------------------
  static const customers = '/customers';
  static String customer(String id) => '/customers/$id';
  static const customerByPhone = '/customers/by-phone';
  static String customer360(String id) => '/crm/customers/$id/360';
  static const activities = '/crm/activities';
  static const followUps = '/crm/follow-ups';
  static const myFollowUps = '/crm/follow-ups/mine';
  static String loyaltyAccount(String customerId) =>
      '/loyalty/accounts/$customerId';

  // --- Repair, exchange -----------------------------------------------------
  static const repairs = '/repairs';
  static String repair(String id) => '/repairs/$id';
  static const overdueRepairs = '/repairs/overdue';
  static const exchanges = '/exchanges';
  static String exchange(String id) => '/exchanges/$id';

  /// Customer-facing stock: names resolved and priced by the server, with no
  /// cost, supplier or location data in the response at all.
  static const catalogueItems = '/catalogue/items';

  // --- Notifications, reports, files ---------------------------------------
  static const notifications = '/notifications';
  static const salesReport = '/reports/sales';
  static const inventoryValuation = '/reports/inventory-valuation';
  static const stockAgeing = '/reports/stock-ageing';
  static const files = '/files';
}
