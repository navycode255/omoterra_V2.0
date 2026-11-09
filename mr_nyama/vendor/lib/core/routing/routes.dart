/// Route paths. The three main destinations are tabs; everything else opens
/// above the tabs without the navigation bar.
class MNRoutes {
  // Sign-in.
  static const splash = '/';
  static const login = '/ingia';
  static const pin = '/pin';
  static const activate = '/anzisha';
  static const createPin = '/pin-mpya';
  static const confirmPin = '/thibitisha-pin';
  static const forgotPin = '/umesahau-pin';
  static const suspended = '/imesimamishwa';

  /// Reachable without a session (the sign-in flow).
  static const signInFlow = [
    login,
    pin,
    activate,
    createPin,
    confirmPin,
    forgotPin,
  ];

  // Office (staff mode): its own screens, never the vendor tabs.
  static const officeSignIn = '/ofisi/ingia';
  static const officePin = '/ofisi/pin';
  static const officeCode = '/ofisi/namba';
  static const officeCreatePin = '/ofisi/pin-mpya';
  static const officeConfirmPin = '/ofisi/thibitisha-pin';
  static const officeSignInFlow = [
    officeSignIn,
    officePin,
    officeCode,
    officeCreatePin,
    officeConfirmPin,
    officeForgotPin,
  ];
  static const officeForgotPin = '/ofisi/umesahau-pin';
  static const officeChangePin = '/ofisi/badilisha-pin';
  // Notifications and "Ujumbe wa ofisi" (step 13A).
  static const officeNotifications = '/ofisi/taarifa';
  static const officeNewMessage = '/ofisi/taarifa/ujumbe';
  static const officeApprovals = '/ofisi/idhini';
  static const officeAlertSettings = '/ofisi/mipangilio/tahadhari';
  static const office = '/ofisi';
  static const officeManagement = '/ofisi/usimamizi';
  static const officeAccount = '/ofisi/akaunti';
  static const officeNewProduct = '/ofisi/bidhaa/mpya';
  static const officeVendors = '/ofisi/wauzaji';
  static const officeNewVendor = '/ofisi/wauzaji/mpya';
  static const officeVendorPattern = '/ofisi/wauzaji/:id';
  static String officeVendor(String id) => '/ofisi/wauzaji/$id';
  static const officeLostSalesPattern = '/ofisi/wauzaji/:id/mauzo-yaliyopotea';
  static String officeLostSales(String id) =>
      '/ofisi/wauzaji/$id/mauzo-yaliyopotea';
  static const officeLostSaleNewPattern =
      '/ofisi/wauzaji/:id/mauzo-yaliyopotea/mpya';
  static String officeLostSaleNew(String id) =>
      '/ofisi/wauzaji/$id/mauzo-yaliyopotea/mpya';
  static const officeStaff = '/ofisi/wafanyakazi';
  static const officeNewStaff = '/ofisi/wafanyakazi/mpya';
  static const officeStaffMemberPattern = '/ofisi/wafanyakazi/:id';
  static String officeStaffMember(String id) => '/ofisi/wafanyakazi/$id';
  static const officeMenuImport = '/ofisi/menyu/excel';
  static String officeStationMenu(String id) => '/ofisi/vituo/$id/menyu';
  static const officeProducts = '/ofisi/bidhaa';
  static const officeProductPattern = '/ofisi/bidhaa/:code';
  static String officeProduct(String code) =>
      '/ofisi/bidhaa/${Uri.encodeComponent(code)}';
  static const officeStaffStationsPattern = '/ofisi/wafanyakazi/:id/vituo';
  static String officeStaffStations(String id) =>
      '/ofisi/wafanyakazi/$id/vituo';
  static const officeStations = '/ofisi/vituo';
  static const officeStationPattern = '/ofisi/vituo/:id';
  static String officeStation(String id) =>
      '/ofisi/vituo/${Uri.encodeComponent(id)}';
  static const officeStationVendorPattern = '/ofisi/vituo/:id/wauzaji/:vendor';
  static String officeStationVendor(String id, String vendor) =>
      '/ofisi/vituo/${Uri.encodeComponent(id)}/wauzaji/${Uri.encodeComponent(vendor)}';
  static const officeIssuedCode = '/ofisi/namba-ya-kuingia';
  static const officeVerification = '/ofisi/uthibitisho';
  static const officeVerificationStationPattern = '/ofisi/uthibitisho/:id';
  static String officeVerificationStation(String id) =>
      '/ofisi/uthibitisho/${Uri.encodeComponent(id)}';
  static const officeVerificationProblemsPattern =
      '/ofisi/uthibitisho/:id/matatizo';
  static String officeVerificationProblems(String id) =>
      '/ofisi/uthibitisho/${Uri.encodeComponent(id)}/matatizo';
  // Missed-closing cases (MN031).
  static const officeClosingCasesPattern =
      '/ofisi/uthibitisho/:id/siku-zisizofungwa';
  static String officeClosingCases(String stationId) =>
      '/ofisi/uthibitisho/${Uri.encodeComponent(stationId)}/siku-zisizofungwa';
  static const officeClosingCasePattern = '/ofisi/siku-zisizofungwa/:id';
  static String officeClosingCase(String id, {String? stationId}) =>
      '/ofisi/siku-zisizofungwa/${Uri.encodeComponent(id)}'
      '${stationId == null ? '' : '?kituo=${Uri.encodeComponent(stationId)}'}';
  // Supply requests: approvals, money given, spending confirmed.
  static const officeSupplyRequests = '/ofisi/maombi-ya-mzigo';
  static const officeSupplyRequestPattern = '/ofisi/maombi-ya-mzigo/:id';
  static String officeSupplyRequest(String id) =>
      '/ofisi/maombi-ya-mzigo/${Uri.encodeComponent(id)}';
  static const officeAssets = '/ofisi/mali';
  static const officeAssetNew = '/ofisi/mali/mpya';
  static const officeAssetPattern = '/ofisi/mali/:id';
  static String officeAsset(String id) =>
      '/ofisi/mali/${Uri.encodeComponent(id)}';
  static const officeSyncConflicts = '/ofisi/kumbukumbu-za-simu';
  static const officeSyncConflictPattern = '/ofisi/kumbukumbu-za-simu/:id';
  static String officeSyncConflict(String opId) =>
      '/ofisi/kumbukumbu-za-simu/${Uri.encodeComponent(opId)}';
  // Finance books (Phase 12).
  static const officeFinance = '/ofisi/vitabu';
  static const officeFinanceAccounts = '/ofisi/vitabu/akaunti';
  static const officeFinanceMap = '/ofisi/vitabu/mpangilio';
  static const officeFinancePeriods = '/ofisi/vitabu/vipindi';
  static const officeFinanceJournal = '/ofisi/vitabu/daftari';
  static const officeFinanceReports = '/ofisi/vitabu/ripoti';
  static const officeVendorPayments = '/ofisi/malipo-wauzaji';
  static const officeVendorPayPattern = '/ofisi/malipo-wauzaji/:id';
  static String officeVendorPay(String id) =>
      '/ofisi/malipo-wauzaji/${Uri.encodeComponent(id)}';
  // Owner bonuses, verified-sale corrections, performance settings (Phase 9).
  static const officeBonuses = '/ofisi/bonasi';
  static const officeVendorBonusPattern = '/ofisi/bonasi/muuzaji/:vendor';
  static String officeVendorBonus(String vendorId,
      {String? period, String? date, String? day}) {
    final query = {
      if (period != null) 'period': period,
      if (date != null) 'date': date,
      if (day != null) 'day': day,
    };
    return Uri(
            path: '/ofisi/bonasi/muuzaji/${Uri.encodeComponent(vendorId)}',
            queryParameters: query.isEmpty ? null : query)
        .toString();
  }

  static const officeVerifiedSalesPattern = '/ofisi/bonasi/mauzo/:station';
  static String officeVerifiedSales(String stationId, {String? date}) => Uri(
          path: '/ofisi/bonasi/mauzo/${Uri.encodeComponent(stationId)}',
          queryParameters: date == null ? null : {'date': date})
      .toString();
  static const officePerformanceSettings = '/ofisi/mipangilio/utendaji';
  // Owner performance (Phase 9).
  static const officePerformance = '/ofisi/utendaji';
  static const officePerformanceAttentionPath = '/ofisi/utendaji/umakini';
  static String officePerformanceAttention({
    required String kind,
    required String stationId,
    required String vendorId,
    String? recordId,
    String? date,
    String? lastSyncedAt,
  }) =>
      Uri(
        path: officePerformanceAttentionPath,
        queryParameters: {
          'kind': kind,
          'station': stationId,
          'vendor': vendorId,
          if (recordId != null) 'record': recordId,
          if (date != null) 'date': date,
          if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
        },
      ).toString();
  static const officePerformanceVendorPattern = '/ofisi/utendaji/muuzaji/:id';
  static String officePerformanceVendor(String id) =>
      '/ofisi/utendaji/muuzaji/${Uri.encodeComponent(id)}';
  static const officePerformanceStaffPattern = '/ofisi/utendaji/mfanyakazi/:id';
  static String officePerformanceStaff(String id) =>
      '/ofisi/utendaji/mfanyakazi/${Uri.encodeComponent(id)}';
  static const officePerformanceStationPattern = '/ofisi/utendaji/kituo/:id';
  static String officePerformanceStation(String id) =>
      '/ofisi/utendaji/kituo/${Uri.encodeComponent(id)}';
  static const officeMoneyReport = '/ofisi/ripoti';
  static const officeMoney = '/ofisi/fedha';
  static const officeMoneySettings = '/ofisi/fedha/mipangilio';
  static const officeMoneyStationPattern = '/ofisi/fedha/:id';
  static String officeMoneyStation(String id) =>
      '/ofisi/fedha/${Uri.encodeComponent(id)}';
  static const officeMoneyVendorDayPattern = '/ofisi/fedha/:id/:date/:vendor';
  static String officeMoneyVendorDay(
          String stationId, String date, String vendorId) =>
      '/ofisi/fedha/${Uri.encodeComponent(stationId)}/$date/'
      '${Uri.encodeComponent(vendorId)}';
  static const officeVendorMoneyPattern = '/ofisi/fedha/muuzaji/:vendor';
  static String officeVendorMoney(String vendorId) =>
      '/ofisi/fedha/muuzaji/${Uri.encodeComponent(vendorId)}';
  static const officeStockPattern = '/ofisi/stoo/:id';
  static String officeStock(String stationId) =>
      '/ofisi/stoo/${Uri.encodeComponent(stationId)}';
  static const officeCreditPattern = '/ofisi/mkopo/kituo/:id';
  static String officeCredit(String stationId) =>
      '/ofisi/mkopo/kituo/${Uri.encodeComponent(stationId)}';
  static const officeCreditCustomerPattern = '/ofisi/mkopo/mteja/:id';
  static String officeCreditCustomer(String customerId) =>
      '/ofisi/mkopo/mteja/${Uri.encodeComponent(customerId)}';
  /// The office pages a seller who is an Outlet Lead opens while signed in
  /// (the lead office session, plan lane A): the station's money page
  /// (handovers and expenses sections), the station stock page (deliveries
  /// and receiving), damage verification and closing counts / cases. Tasks
  /// 6 and 12 may add more. A `:name` segment matches any one segment.
  static const leadOfficeRoutes = [
    officeMoneyStationPattern,
    officeMoneyVendorDayPattern,
    officeStockPattern,
    officeVerificationStationPattern,
    officeVerificationProblemsPattern,
    officeClosingCasesPattern,
    officeClosingCasePattern,
    officeSupplyRequests,
    officeSupplyRequestPattern,
    officeAssets,
    officeAssetPattern,
  ];

  /// Office pages that look like a lead page but are not (a literal beats a
  /// `:name` segment).
  static const _leadExcluded = [
    officeMoneySettings,
    officeVendorMoneyPattern,
    officeAssetNew,
  ];

  static bool _matches(String pattern, String path) {
    final a = pattern.split('/'), b = path.split('/');
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].startsWith(':') ? b[i].isEmpty : a[i] != b[i]) return false;
    }
    return true;
  }

  /// Whether the lead office session may open [path].
  static bool isLeadOfficePath(String path) =>
      !_leadExcluded.any((p) => _matches(p, path)) &&
      leadOfficeRoutes.any((p) => _matches(p, path));

  static const officeStockReturnPattern = '/ofisi/stoo/:id/rudisha';
  static String officeStockReturn(String stationId) =>
      '/ofisi/stoo/${Uri.encodeComponent(stationId)}/rudisha';
  static const officeRecipes = '/ofisi/mapishi';
  static const officeRecipePattern = '/ofisi/mapishi/:id';
  static String officeRecipe(String id) =>
      '/ofisi/mapishi/${Uri.encodeComponent(id)}';
  static const officeRecipeNewVersionPattern = '/ofisi/mapishi/:id/toleo-jipya';
  static String officeRecipeNewVersion(String id) =>
      '/ofisi/mapishi/${Uri.encodeComponent(id)}/toleo-jipya';
  static const officeOpening = '/ofisi/stoo-ya-mwanzo';
  static const officeOpeningNew = '/ofisi/stoo-ya-mwanzo/mpya';
  static const officeKitchens = '/ofisi/majiko';
  static const officeProduction = '/ofisi/uzalishaji';
  static const officeProductionNew = '/ofisi/uzalishaji/mpya';
  static const officeProductionRunPattern = '/ofisi/uzalishaji/:id';
  static String officeProductionRun(String id) =>
      '/ofisi/uzalishaji/${Uri.encodeComponent(id)}';

  // Main destinations (tabs).
  static const home = '/nyumbani';
  static const sales = '/mauzo';
  static const products = '/bidhaa';

  // Secondary destinations.
  static const expenses = '/gharama';
  static const handovers = '/makabidhiano';
  static const credit = '/mkopo';
  // Supply requests, "Maombi ya mzigo" (team roles plan, Part 2).
  static const supplyRequests = '/maombi-ya-mzigo';
  static const supplyRequestNew = '/maombi-ya-mzigo/mpya';
  static const supplyRequestPattern = '/maombi-ya-mzigo/:id';
  static String supplyRequest(String id) =>
      '/maombi-ya-mzigo/${Uri.encodeComponent(id)}';
  static const receive = '/pokea';
  static const deliveryPattern = '/pokea/:id';
  static String delivery(String id) => '/pokea/$id';
  static const receiptSavedPattern = '/pokea/:id/imehifadhiwa';
  static String receiptSaved(String id) => '/pokea/$id/imehifadhiwa';
  static const damaged = '/vimeharibika';
  static const newDamage = '/vimeharibika/mpya';
  static const history = '/historia';
  static const saleDetailPattern = '/historia/:id';
  static String saleDetail(String clientId) => '/historia/$clientId';
  static const closeDay = '/funga-siku';
  static const dayClosed = '/funga-siku/imefungwa';
  static const profile = '/wasifu';
  static const changePin = '/wasifu/pin';
  static const sync = '/wasifu/usawazishaji';
  static const cart = '/kikapu';
  static const notifications = '/taarifa';
  static const saleSavedPattern = '/imehifadhiwa/:id';
  static String saleSaved(String clientId) => '/imehifadhiwa/$clientId';

  static const tabs = [home, sales, products];

  /// Development-only component showcase; absent from release builds.
  static const showcase = '/dev/vipengele';
}
