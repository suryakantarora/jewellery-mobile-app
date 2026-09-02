/// Route names and paths. Nothing navigates with a string literal.
abstract final class AppRoutes {
  // --- Session ------------------------------------------------------------
  static const splash = '/splash';
  static const login = '/login';
  static const changePassword = '/change-password';
  static const selectBranch = '/select-branch';
  static const lock = '/lock';

  /// Routes reachable without an established session.
  static const sessionRoutes = <String>{
    splash,
    login,
    changePassword,
    selectBranch,
    lock,
  };

  // --- Shell tabs ---------------------------------------------------------
  static const dashboard = '/dashboard';
  static const inventory = '/inventory';
  static const scan = '/scan';
  static const transfers = '/transfers';
  static const more = '/more';

  // --- Details ------------------------------------------------------------
  /// Full-screen search, outside the tab shell so a scan can replace it.
  static const itemSearch = '/search';

  static const itemDetail = '/inventory/item/:id';
  static String itemDetailPath(String id) => '/inventory/item/$id';

  static const transferDetail = '/transfers/:id';
  static String transferDetailPath(String id) => '/transfers/$id';

  static const transferReceive = '/transfers/:id/receive';
  static String transferReceivePath(String id) => '/transfers/$id/receive';

  static const transferCreate = '/transfers/new';

  // --- Secondary destinations (under "More") ------------------------------
  static const warehouse = '/more/warehouse';
  static const stockCount = '/more/warehouse/count/:id';
  static String stockCountPath(String id) => '/more/warehouse/count/$id';
  static const vault = '/more/warehouse/location/:id';
  static String vaultPath(String id) => '/more/warehouse/location/$id';
  static const procurement = '/more/procurement';
  static const purchaseOrder = '/more/procurement/po/:id';
  static String purchaseOrderPath(String id) => '/more/procurement/po/$id';
  static const goodsReceive = '/more/procurement/po/:id/receive';
  static String goodsReceivePath(String id) =>
      '/more/procurement/po/$id/receive';
  static const sales = '/more/sales';
  static const customers = '/more/customers';
  static const customer = '/more/customers/:id';
  static String customerPath(String id) => '/more/customers/$id';
  static const repairs = '/more/repairs';
  static const repair = '/more/repairs/:id';
  static String repairPath(String id) => '/more/repairs/$id';
  static const exchange = '/more/exchange';
  static const exchangeDetail = '/more/exchange/:id';
  static String exchangePath(String id) => '/more/exchange/$id';
  static const approvals = '/more/approvals';
  static const reports = '/more/reports';
  static const notifications = '/more/notifications';
  static const profile = '/more/profile';
  static const settings = '/more/settings';

  // --- Development --------------------------------------------------------
  static const componentGallery = '/dev/components';
}
