// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Jewellery ERP';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionSave => 'Save';

  @override
  String get actionClose => 'Close';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionScan => 'Scan';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionSignIn => 'Sign in';

  @override
  String get actionSignOut => 'Sign out';

  @override
  String get actionContinue => 'Continue';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginSubtitle => 'Staff access to your branch operations';

  @override
  String get loginUsername => 'Username';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginFailed => 'Incorrect username or password';

  @override
  String get loginAccountLocked =>
      'Your account is locked. Contact your administrator.';

  @override
  String get loginNoBranch =>
      'No branch is assigned to you. Contact your administrator.';

  @override
  String get sessionExpired => 'Your session expired. Please sign in again.';

  @override
  String get branchSelectTitle => 'Select branch';

  @override
  String get branchSelectSubtitle =>
      'Choose the branch you are working in today';

  @override
  String get branchSwitch => 'Switch branch';

  @override
  String get branchHeadOffice => 'Head office';

  @override
  String get lockTitle => 'Session locked';

  @override
  String get lockSubtitle => 'Unlock to continue where you left off';

  @override
  String get lockUnlock => 'Unlock';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navInventory => 'Inventory';

  @override
  String get navScan => 'Scan';

  @override
  String get navTransfers => 'Transfers';

  @override
  String get navMore => 'More';

  @override
  String get sectionOperations => 'Operations';

  @override
  String get sectionCommercial => 'Commercial';

  @override
  String get sectionInsight => 'Insight';

  @override
  String get sectionAccount => 'Account';

  @override
  String get screenWarehouse => 'Warehouse & Vault';

  @override
  String get screenProcurement => 'Procurement';

  @override
  String get screenSales => 'Sales Assistance';

  @override
  String get screenCustomers => 'Customers';

  @override
  String get screenRepairs => 'Repairs';

  @override
  String get screenExchange => 'Exchange & Buyback';

  @override
  String get screenApprovals => 'Approvals';

  @override
  String get screenReports => 'Reports';

  @override
  String get screenCatalogue => 'Catalogue';

  @override
  String get screenNotifications => 'Notifications';

  @override
  String get screenProfile => 'Profile';

  @override
  String get screenSettings => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsThemeMode => 'Theme';

  @override
  String get settingsThemeSystem => 'Follow system';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsAccent => 'Accent';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsCurrency => 'Display currency';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsHideAmounts => 'Hide amounts';

  @override
  String get settingsHideAmountsHint => 'Blur monetary figures on screen';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsEnvironment => 'Environment';

  @override
  String get stateLoading => 'Loading…';

  @override
  String get stateEmptyTitle => 'Nothing here yet';

  @override
  String get stateEmptyMessage =>
      'When there is something to show, it will appear here.';

  @override
  String get stateErrorTitle => 'Something went wrong';

  @override
  String get stateOffline => 'You\'re offline';

  @override
  String get stateOfflineAction => 'This action needs a connection.';

  @override
  String get stateNoPermission => 'You do not have permission to view this.';

  @override
  String stateReferenceId(String id) {
    return 'Reference: $id';
  }

  @override
  String get phaseComingSoon => 'Coming in a later phase';

  @override
  String phaseComingSoonMessage(String feature) {
    return '$feature is part of the roadmap and is not built yet.';
  }

  @override
  String get galleryTitle => 'Component gallery';
}
