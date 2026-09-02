import '../../l10n/app_localizations.dart';

/// Resolves a destination's label key against the active localisations.
///
/// Navigation is declared as data, so the label has to be looked up rather than
/// held as a string — this keeps the registry free of BuildContext while still
/// translating into Lao and Thai.
String navLabel(AppL10n l10n, String key) => switch (key) {
  'navDashboard' => l10n.navDashboard,
  'navInventory' => l10n.navInventory,
  'navScan' => l10n.navScan,
  'navTransfers' => l10n.navTransfers,
  'navMore' => l10n.navMore,
  'screenWarehouse' => l10n.screenWarehouse,
  'screenProcurement' => l10n.screenProcurement,
  'screenSales' => l10n.screenSales,
  'screenCustomers' => l10n.screenCustomers,
  'screenRepairs' => l10n.screenRepairs,
  'screenExchange' => l10n.screenExchange,
  'screenApprovals' => l10n.screenApprovals,
  'screenReports' => l10n.screenReports,
  'screenCatalogue' => l10n.screenCatalogue,
  'screenNotifications' => l10n.screenNotifications,
  'screenProfile' => l10n.screenProfile,
  'screenSettings' => l10n.screenSettings,
  _ => key,
};

String navGroupLabel(AppL10n l10n, String group) => switch (group) {
  'operations' => l10n.sectionOperations,
  'commercial' => l10n.sectionCommercial,
  'insight' => l10n.sectionInsight,
  'account' => l10n.sectionAccount,
  _ => group,
};
