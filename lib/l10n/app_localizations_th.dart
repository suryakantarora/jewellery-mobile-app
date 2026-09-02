// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppL10nTh extends AppL10n {
  AppL10nTh([String locale = 'th']) : super(locale);

  @override
  String get appName => 'ระบบ ERP เครื่องประดับ';

  @override
  String get actionRetry => 'ลองใหม่';

  @override
  String get actionCancel => 'ยกเลิก';

  @override
  String get actionConfirm => 'ยืนยัน';

  @override
  String get actionSave => 'บันทึก';

  @override
  String get actionClose => 'ปิด';

  @override
  String get actionSearch => 'ค้นหา';

  @override
  String get actionScan => 'สแกน';

  @override
  String get actionClear => 'ล้าง';

  @override
  String get actionSignIn => 'เข้าสู่ระบบ';

  @override
  String get actionSignOut => 'ออกจากระบบ';

  @override
  String get actionContinue => 'ดำเนินการต่อ';

  @override
  String get loginTitle => 'เข้าสู่ระบบ';

  @override
  String get loginSubtitle => 'สำหรับพนักงานเข้าถึงการดำเนินงานของสาขา';

  @override
  String get loginUsername => 'ชื่อผู้ใช้';

  @override
  String get loginPassword => 'รหัสผ่าน';

  @override
  String get loginFailed => 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง';

  @override
  String get loginAccountLocked => 'บัญชีของคุณถูกล็อก กรุณาติดต่อผู้ดูแลระบบ';

  @override
  String get loginNoBranch => 'ยังไม่ได้กำหนดสาขาให้คุณ กรุณาติดต่อผู้ดูแลระบบ';

  @override
  String get sessionExpired => 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบอีกครั้ง';

  @override
  String get branchSelectTitle => 'เลือกสาขา';

  @override
  String get branchSelectSubtitle => 'เลือกสาขาที่คุณปฏิบัติงานวันนี้';

  @override
  String get branchSwitch => 'เปลี่ยนสาขา';

  @override
  String get branchHeadOffice => 'สำนักงานใหญ่';

  @override
  String get lockTitle => 'เซสชันถูกล็อก';

  @override
  String get lockSubtitle => 'ปลดล็อกเพื่อดำเนินการต่อ';

  @override
  String get lockUnlock => 'ปลดล็อก';

  @override
  String get navDashboard => 'แดชบอร์ด';

  @override
  String get navInventory => 'สินค้าคงคลัง';

  @override
  String get navScan => 'สแกน';

  @override
  String get navTransfers => 'การโอน';

  @override
  String get navMore => 'เพิ่มเติม';

  @override
  String get sectionOperations => 'การดำเนินงาน';

  @override
  String get sectionCommercial => 'การค้า';

  @override
  String get sectionInsight => 'รายงาน';

  @override
  String get sectionAccount => 'บัญชี';

  @override
  String get screenWarehouse => 'คลังสินค้าและตู้นิรภัย';

  @override
  String get screenProcurement => 'การจัดซื้อ';

  @override
  String get screenSales => 'ช่วยการขาย';

  @override
  String get screenCustomers => 'ลูกค้า';

  @override
  String get screenRepairs => 'งานซ่อม';

  @override
  String get screenExchange => 'แลกเปลี่ยนและรับซื้อคืน';

  @override
  String get screenApprovals => 'การอนุมัติ';

  @override
  String get screenReports => 'รายงาน';

  @override
  String get screenCatalogue => 'แคตตาล็อก';

  @override
  String get screenNotifications => 'การแจ้งเตือน';

  @override
  String get screenProfile => 'โปรไฟล์';

  @override
  String get screenSettings => 'การตั้งค่า';

  @override
  String get settingsAppearance => 'รูปลักษณ์';

  @override
  String get settingsThemeMode => 'ธีม';

  @override
  String get settingsThemeSystem => 'ตามระบบ';

  @override
  String get settingsThemeLight => 'สว่าง';

  @override
  String get settingsThemeDark => 'มืด';

  @override
  String get settingsAccent => 'สีหลัก';

  @override
  String get settingsLanguage => 'ภาษา';

  @override
  String get settingsCurrency => 'สกุลเงินที่แสดง';

  @override
  String get settingsPrivacy => 'ความเป็นส่วนตัว';

  @override
  String get settingsHideAmounts => 'ซ่อนจำนวนเงิน';

  @override
  String get settingsHideAmountsHint => 'เบลอตัวเลขจำนวนเงินบนหน้าจอ';

  @override
  String get settingsAbout => 'เกี่ยวกับ';

  @override
  String get settingsVersion => 'เวอร์ชัน';

  @override
  String get settingsEnvironment => 'สภาพแวดล้อม';

  @override
  String get stateLoading => 'กำลังโหลด…';

  @override
  String get stateEmptyTitle => 'ยังไม่มีข้อมูล';

  @override
  String get stateEmptyMessage => 'เมื่อมีข้อมูล จะแสดงที่นี่';

  @override
  String get stateErrorTitle => 'เกิดข้อผิดพลาด';

  @override
  String get stateOffline => 'คุณออฟไลน์อยู่';

  @override
  String get stateOfflineAction => 'การดำเนินการนี้ต้องใช้การเชื่อมต่อ';

  @override
  String get stateNoPermission => 'คุณไม่มีสิทธิ์ดูข้อมูลนี้';

  @override
  String stateReferenceId(String id) {
    return 'รหัสอ้างอิง: $id';
  }

  @override
  String get phaseComingSoon => 'จะมาในเฟสถัดไป';

  @override
  String phaseComingSoonMessage(String feature) {
    return '$feature อยู่ในแผนงานและยังไม่ได้สร้าง';
  }

  @override
  String get galleryTitle => 'คลังคอมโพเนนต์';
}
