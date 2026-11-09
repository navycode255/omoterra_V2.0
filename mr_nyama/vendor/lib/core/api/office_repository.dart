import 'dart:typed_data';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../auth/lead_session.dart' show OfficeLeadRepository;
import 'office_approvals.dart';
import 'office_balances.dart';
import 'office_catalogue.dart';
import 'office_closing_cases.dart';
import 'office_credit.dart';
import 'office_finance.dart';
import 'office_money.dart';
import 'office_production.dart';
import 'notifications.dart';
import 'push.dart';
import 'office_removal.dart';
import 'office_lost_sales.dart';
import 'office_outlet_lead.dart';
import 'office_sale_cancel.dart';
import 'office_setup.dart';
import 'office_stock.dart';
import 'office_assets.dart';
import 'supply_requests.dart';
import 'office_sync_review.dart';
import 'office_verification.dart';
import 'owner_bonuses.dart';
import 'owner_performance.dart';
import 'owner_reports.dart';
export 'office_balances.dart';
export 'office_outlet_lead.dart';
export 'owner_performance.dart';
export 'owner_bonuses.dart';
export 'office_catalogue.dart';
export 'office_closing_cases.dart';
export 'office_credit.dart';
export 'office_finance.dart';
export 'office_money.dart';
export 'office_verification.dart';
export 'office_production.dart';
export 'office_removal.dart';
export 'office_setup.dart';
export 'office_stock.dart';
export 'supply_requests.dart';
export 'office_sync_review.dart';
export 'owner_reports.dart';

import '../auth/device_sign_in.dart';
import '../auth/secure_store.dart';
import 'api_client.dart';
import 'vendor_repository.dart';

/// The office side of the app: staff accounts (owner, operations admin)
/// registering vendors and staff and issuing their one-time codes. Calls the
/// staff and admin API with a separate `mn-staff` session; every action is
/// permission-checked and audited on the server.

/// Staff roles the office can give, in the server's names.
class StaffRole {
  static const supervisor = 'supervisor';
  static const kitchen = 'kitchen_staff';
  static const finance = 'finance';
  static const operationsAdmin = 'operations_admin';
  static const owner = 'business_owner';

  /// Roles that may register people and issue codes.
  static const managers = {owner, operationsAdmin};

  /// Roles that verify sales, decide damage reports and confirm closing
  /// counts. The server checks the permission and the station.
  static const verifiers = {supervisor, finance, owner};

  /// Roles that also decide damage reports and confirm closing counts;
  /// finance verifies sales only.
  static const stockReviewers = {supervisor, owner};

  /// Roles that record cash handovers and office expenses and decide vendor
  /// expenses (a supervisor at their own stations).
  static const moneyHandlers = {supervisor, finance, owner};

  /// Roles that also confirm handovers (never ones they recorded) and
  /// reverse money records.
  static const moneySettlers = {finance, owner};
}

/// A kitchen on the person's active kitchen-staff grants (`/staff/me`).
class StaffKitchen {
  final String id, code, name;
  const StaffKitchen({required this.id, this.code = '', this.name = ''});
  Map<String, Object> toJson() => {'id': id, 'code': code, 'name': name};
}

class StaffProfile {
  final String id;
  final String name;
  final String phone;
  final List<String> roles;
  final String? profileImageUrl;

  /// Where this person records production; empty for everyone else, and
  /// when the server did not say (the sign-in answer leaves it out).
  final List<StaffKitchen> kitchens;
  const StaffProfile(
      {required this.id,
      required this.name,
      required this.phone,
      required this.roles,
      this.profileImageUrl,
      this.kitchens = const []});

  bool get canManagePeople => roles.any(StaffRole.managers.contains);
  bool get isOwner => roles.contains(StaffRole.owner);
  bool get canVerify => roles.any(StaffRole.verifiers.contains);
  bool get canReviewStock => roles.any(StaffRole.stockReviewers.contains);
  bool get canHandleMoney => roles.any(StaffRole.moneyHandlers.contains);
  bool get canSettleMoney => roles.any(StaffRole.moneySettlers.contains);

  /// Reads the business asset register (Mali za biashara): the owner, the
  /// operations administrator and supervisors (their own kituo).
  bool get canSeeAssets =>
      roles.any(const {
        StaffRole.owner,
        StaffRole.operationsAdmin,
        StaffRole.supervisor
      }.contains);

  /// Sees what assets cost; only the owner and the operations administrator.
  bool get canSeeAssetValues => roles.any(StaffRole.managers.contains);

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'roles': roles,
        'profile_image_url': profileImageUrl,
        'kitchens': [for (final k in kitchens) k.toJson()],
      };

  StaffProfile copyWith({String? profileImageUrl}) => StaffProfile(
      id: id,
      name: name,
      phone: phone,
      roles: roles,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      kitchens: kitchens);

  static StaffProfile fromJson(Map<String, dynamic> json) => StaffProfile(
          id: json['id'] as String,
          name: json['name'] as String,
          phone: json['phone'] as String? ?? '',
          profileImageUrl: json['profile_image_url'] as String?,
          roles: [
            for (final r in json['roles'] as List? ?? const []) '$r'
          ],
          kitchens: [
            for (final k in json['kitchens'] is List
                ? json['kitchens'] as List
                : const [])
              if (k is Map && k['id'] != null)
                StaffKitchen(
                    id: '${k['id']}',
                    code: '${k['code'] ?? ''}',
                    name: '${k['name'] ?? ''}')
          ]);
}

class OfficeVendor {
  final String id;
  final String name;
  final String phone;
  final String? stationName;
  final bool activated;
  final bool suspended;

  /// The vendor number (`V-…`), when the server sends it.
  final String? code;
  final String? stationId;

  /// Why the account is suspended or left, when the server says.
  final String? statusReason;

  /// The vendor has left the business; the record is read-only.
  final bool left;

  /// The station's code, and when the current station assignment started
  /// (`station.since`), when the server sends them.
  final String? stationCode;
  final DateTime? stationSince;

  /// A short-lived link to their profile photo, when they have one.
  final String? imageUrl;

  /// The seller is an Outlet Lead now (the server's open link).
  final bool isLead;
  const OfficeVendor(
      {required this.id,
      required this.name,
      required this.phone,
      this.stationName,
      required this.activated,
      required this.suspended,
      this.code,
      this.stationId,
      this.statusReason,
      this.left = false,
      this.stationCode,
      this.stationSince,
      this.imageUrl,
      this.isLead = false});

  /// One row of `GET /admin/vendors` (also the `PATCH` reply). Fields added
  /// later are optional so an older server still parses.
  factory OfficeVendor.fromJson(Map<String, dynamic> v) {
    final station = v['station'] as Map?;
    return OfficeVendor(
        id: v['id'] as String,
        name: v['name'] as String,
        phone: v['phone'] as String? ?? '',
        code: v['vendor_code'] as String?,
        stationId: station?['id'] as String?,
        stationName: station?['name'] as String?,
        stationCode: station?['code'] as String?,
        stationSince:
            DateTime.tryParse('${station?['since'] ?? ''}')?.toLocal(),
        activated: v['activation_state'] == 'activated',
        suspended: v['status'] == 'suspended',
        left: v['status'] == 'left',
        statusReason: v['status_reason'] as String?,
        imageUrl: v['profile_image_url'] as String?,
        isLead: v['outlet_lead'] != null);
  }
}

/// One active role grant; [id] is what a revoke names.
class OfficeRoleGrant {
  final String id;
  final String role;

  /// The kitchen a kitchen-staff grant places them at.
  final String? kitchenId;
  const OfficeRoleGrant(this.id, this.role, [this.kitchenId]);
}

class OfficeStaff {
  final String id;
  final String name;
  final String phone;
  final List<String> roles;
  final List<String> stationIds;
  final bool activated;
  final bool suspended;

  /// The staff number (`S-…`), when the server sends it.
  final String? code;
  final String? statusReason;
  final bool left;

  /// Active grants with their ids (empty from an older server).
  final List<OfficeRoleGrant> roleGrants;

  /// A short-lived link to their profile photo, when they have one.
  final String? imageUrl;
  const OfficeStaff(
      {required this.id,
      required this.name,
      required this.phone,
      required this.roles,
      this.stationIds = const [],
      required this.activated,
      required this.suspended,
      this.code,
      this.statusReason,
      this.left = false,
      this.roleGrants = const [],
      this.imageUrl});

  /// One row of `GET /admin/staff` (also the `PATCH` reply).
  factory OfficeStaff.fromJson(Map<String, dynamic> s) => OfficeStaff(
      id: s['id'] as String,
      name: s['name'] as String,
      phone: s['phone'] as String? ?? '',
      code: s['staff_code'] as String?,
      roles: [for (final r in s['roles'] as List? ?? const []) '$r'],
      stationIds: {
        for (final id in [
          ...?s['work_stations'] as List?,
          ...?s['stations'] as List?
        ])
          '$id'
      }.toList(),
      activated: s['activation_state'] == 'activated',
      suspended: s['status'] == 'suspended',
      left: s['status'] == 'left',
      statusReason: s['status_reason'] as String?,
      imageUrl: s['profile_image_url'] as String?,
      roleGrants: [
        for (final g in s['role_grants'] as List? ?? const [])
          if (g is Map && g['id'] != null && g['role'] != null)
            OfficeRoleGrant(
                '${g['id']}',
                '${g['role']}',
                g['kitchen_location_id'] == null
                    ? null
                    : '${g['kitchen_location_id']}')
      ]);
}

/// A status change for a vendor or staff account. [leave] is final.
enum StatusChange {
  suspend('suspend'),
  reinstate('reinstate'),
  leave('leave'),

  /// Only for someone added by mistake (no records); the server refuses
  /// anyone with history (owner decision 28 October 2026).
  delete('delete'),

  /// Undoes "left" when it was a mistake.
  returned('return');

  final String path;
  const StatusChange(this.path);
}

class OfficeStation {
  final String id;
  final String code;
  final String name;

  /// Vendors currently placed here; a station may have several, who share
  /// its stock (counted once per station per day).
  final int vendorCount;
  final String area, address, status;
  final String? stockLocationId;

  /// A short-lived link to the station's photo, when it has one.
  final String? imageUrl;

  /// [hasVendor] is shorthand for one vendor when [vendorCount] is not given.
  const OfficeStation(
      {required this.id,
      required this.code,
      required this.name,
      bool hasVendor = false,
      int? vendorCount,
      this.area = '',
      this.address = '',
      this.status = 'active',
      this.stockLocationId,
      this.imageUrl})
      : vendorCount = vendorCount ?? (hasVendor ? 1 : 0);
  bool get hasVendor => vendorCount > 0;
  factory OfficeStation.fromJson(Map<String, dynamic> s) => OfficeStation(
      id: s['id'] as String,
      code: s['code'] as String,
      name: s['name'] as String,
      // Older servers send only `vendor_id` (the first current vendor).
      vendorCount: (s['vendor_count'] as num?)?.toInt() ??
          (s['vendor_id'] != null ? 1 : 0),
      area: s['area'] as String? ?? '',
      address: s['address'] as String? ?? '',
      status: s['status'] as String? ?? 'active',
      stockLocationId: s['stock_location_id'] as String?,
      imageUrl: s['image_url'] as String?);
}

/// A one-time activation or PIN-reset code to hand over in person.
class IssuedCode {
  final String code;
  final int validHours;
  const IssuedCode(this.code, this.validHours);
}

enum OfficeErrorKind {
  /// The phone number or station code is already in use.
  duplicate,

  /// This account may not do that.
  forbidden,

  /// The server refused the values (for example a malformed phone).
  invalid,

  /// A business rule refused the change; [OfficeError.detail] says which
  /// (for example "the last owner cannot leave").
  refused,

  /// The person or record no longer exists.
  notFound,

  /// A lead acted on his own record (403 `own_record`).
  ownRecord,

  /// An Outlet Lead change was refused; [OfficeError.detail] is the code.
  lead,
}

class OfficeError implements Exception {
  final OfficeErrorKind kind;

  /// The server's explanation of a refusal, when it gave one.
  final String? detail;
  const OfficeError(this.kind, [this.detail]);
  @override
  String toString() => 'OfficeError($kind${detail == null ? '' : ', $detail'})';
}

abstract class OfficeRepository {
  Future<List<OfficeProduct>> products();
  Future<OfficeProduct> createProduct(
      {required String code,
      required String name,
      required String category,
      required String unit});
  Future<List<OfficeCategory>> categories();

  /// Units the business added; the built-in units are not listed.
  Future<List<OfficeUnit>> units();
  Future<List<OfficeStationPrice>> productPrices(String code);
  Future<void> updateProduct(String code,
      {required String name,
      required String category,
      required String unit,
      required bool available,
      required String status,
      required String? imageKey,
      required String reason});
  Future<void> setProductPrice(String code,
      {required int amount, String? stationId, required String reason});
  Future<String> uploadProductImage(Uint8List bytes);
  Future<void> placeStaff(String staffId,
      {required List<String> stationIds, required String reason});

  Future<bool> hasSession();
  Future<SignInStep> startSignIn(String phone);
  Future<StaffProfile> signIn({required String phone, required String pin});
  Future<String> verifyCode(
      {required String phone, required String code, bool reset = false});
  Future<StaffProfile> setPin(
      {required String setupToken, required String pin});
  Future<void> signOut();

  /// Changes the signed-in staff member's own PIN (current PIN required).
  Future<void> changePin({required String currentPin, required String newPin});

  Future<List<OfficeVendor>> vendors();
  Future<List<OfficeStaff>> staff();
  Future<List<OfficeStation>> stations();

  /// Creates the vendor and returns its id.
  Future<String> addVendor({required String name, required String phone});
  Future<void> assignVendor(
      {required String vendorId,
      required String stationId,
      required String reason});
  Future<IssuedCode> vendorCode(String vendorId, {bool reset = false});

  /// Creates the staff member and returns its id.
  Future<String> addStaff({required String name, required String phone});
  Future<void> grantRole(
      {required String staffId, required String role, required String reason});
  Future<void> assignSupervisor(
      {required String stationId,
      required String staffId,
      required String reason});
  Future<IssuedCode> staffCode(String staffId, {bool reset = false});

  Future<OfficeStation> addStation(
      {required String code, required String name});

  /// Changes a vendor's name and/or phone. A new phone ends their sessions
  /// and needs a new sign-in code.
  Future<OfficeVendor> updateVendor(String vendorId,
      {String? name, String? phone, required String reason});
  Future<OfficeStaff> updateStaff(String staffId,
      {String? name, String? phone, required String reason});
  Future<void> changeVendorStatus(String vendorId, StatusChange change,
      {required String reason});
  Future<void> changeStaffStatus(String staffId, StatusChange change,
      {required String reason});
  Future<void> revokeRole(
      {required String staffId,
      required String roleGrantId,
      required String reason});
  Future<OfficeCategory> createCategory(
      {required String code, required String name});
  Future<OfficeUnit> createUnit(
      {required String code,
      required String name,
      required bool allowsDecimal});

  // Verification (supervisor, finance, owner) ---------------------------------

  /// Stations the signed-in staff may access, with what waits there.
  Future<List<OfficeVerificationStation>> verificationQueue();

  /// A station's sales; [status] `reported` means not yet verified.
  Future<List<OfficeSale>> stationSales(String stationId,
      {String? businessDate, String? status});

  /// Verifies up to 500 sales by server id, all or nothing. Returns the ids
  /// the server verified; a refusal means none of them were.
  Future<List<String>> verifySales(List<String> saleIds);
  Future<List<OfficeDamageReport>> damageReports(
      {required String stationId, String status = 'reported'});

  /// Approve: a verified loss that removes stock. Reject: not a loss.
  Future<OfficeDamageReport> decideDamage(String reportId,
      {required bool approve, required String reason});
  Future<List<OfficeClosingCount>> closingCounts(
      {required String stationId, String status = 'recorded'});

  /// Refused (409, with the reason) while sales or damage reports wait.
  Future<OfficeClosingCount> confirmClosing(String closingId);
  Future<List<OfficeException>> exceptions(
      {required String stationId, String status = 'open'});

  // Money (supervisor, finance, owner) ----------------------------------------

  /// Each vendor-day's cash at a station on [businessDate] (`YYYY-MM-DD`).
  Future<List<OfficeMoneyDay>> moneyDays(
      {required String stationId, required String businessDate});

  /// Records cash a vendor handed over; the server answers with the row.
  Future<OfficeHandover> recordHandover(
      {required String vendorId,
      required String businessDate,
      required int amount,
      DateTime? receivedAt,
      String? note,
      String? clientId});
  Future<List<OfficeHandover>> handovers(
      {String? stationId,
      String? vendorId,
      String? from,
      String? to,
      String? status});

  /// Refused (409) for the person who recorded it.
  Future<OfficeHandover> confirmHandover(String handoverId);

  /// Adds a correcting row; the original stays.
  Future<OfficeHandover> reverseHandover(String handoverId,
      {required String reason});

  /// An office-paid expense (approved when recorded). Refused until the
  /// owner sets the expense categories.
  Future<OfficeExpense> recordExpense(
      {required String stationId,
      required String businessDate,
      required String category,
      String? item,
      required int amount,
      String? note,
      String? clientId});
  Future<List<OfficeExpense>> expenses(
      {String? stationId,
      String? from,
      String? to,
      String? status,
      String? paidBy});

  /// Approves or rejects a pending vendor-paid expense.
  Future<OfficeExpense> decideExpense(String expenseId,
      {required bool approve, required String reason});
  Future<OfficeExpense> reverseExpense(String expenseId,
      {required String reason});

  /// The money settings this account may read.
  Future<OfficeMoneySettings> moneySettings();

  /// Owner only. [value] is a list of names or an `HH:MM` string.
  Future<void> saveSetting(String key,
      {required Object value, required String reason});
}

abstract interface class MenuSetupRepository {
  Future<Uint8List> menuTemplate();
  Future<Map<String, dynamic>> previewMenu(Uint8List bytes);
  Future<Map<String, dynamic>> importMenu(Map<String, dynamic> body);
  Future<Map<String, dynamic>> stationMenu(String stationId);
  Future<Map<String, dynamic>> saveStationMenu(
      String stationId, Map<String, dynamic> body);
}

abstract interface class StationManagementRepository {
  Future<void> updateStation(String id,
      {required String name,
      required String area,
      required String address,
      required String reason});
  Future<void> uploadStationPhoto(String id, Uint8List bytes);
  Future<void> removeStationPhoto(String id);
  Future<List<Map<String, dynamic>>> stationStock(String locationId);
  Future<List<Map<String, dynamic>>> stationManifests(String stationId);
  Future<void> amendManifest(
      String id, List<Map<String, dynamic>> lines, String reason, int version);
  Future<void> cancelManifest(String id, String reason, int version);
  Future<void> endVendorStation(String id, String reason);
}

abstract interface class OfficeReceivingRepository {
  Future<List<Map<String, dynamic>>> receivingLocations();
  Future<List<Map<String, dynamic>>> receivingLots(String locationId);
  Future<Map<String, dynamic>> createExpectedDelivery(
      Map<String, dynamic> body);
}

/// Durable compensation commands; independent of station cash handovers.
abstract interface class OfficeVendorPayRepository {
  Future<Map<String, dynamic>> vendorPayOverview();
  Future<Map<String, dynamic>> vendorPayStatement(
      String vendor, String from, String to);
  Future<Map<String, dynamic>> vendorPayCommand(
      String vendor, String command, Map<String, dynamic> body);
}

abstract interface class OfficeMediaRepository {
  Future<String> uploadOwnProfileImage(Uint8List bytes);
}

class HttpOfficeRepository
    implements
        OfficeRepository,
        OfficeLeadRepository,
        StationManagementRepository,
        MenuSetupRepository,
        OfficeReceivingRepository,
        OfficeVendorPayRepository,
        OfficeStockRepository,
        OfficeStockMeasuresRepository,
        OfficeSetupRepository,
        OfficeProductionRepository,
        OwnerReportsRepository,
        OfficeSyncReviewRepository,
        OfficeCreditRepository,
        OfficeBalancesRepository,
        OwnerBonusesRepository,
        OfficeAutoVerifyRepository,
        OwnerPerformanceRepository,
        OfficeFinanceRepository,
        OfficeRemovalRepository,
        OfficeMediaRepository,
        OfficeDeviceKeyRepository,
        OfficeNotificationsRepository,
        OfficePushRepository,
        OfficeApprovalsRepository,
        OfficeClosingCasesRepository,
        OfficeSaleCancelRepository,
        OfficeLostSalesRepository,
        OfficeOutletLeadRepository,
        OfficeSupplyRepository,
        OfficeAssetsRepository {
  final ApiClient _c;
  late final SupplyApi _supply = SupplyApi(_c, '/staff');
  late final AssetsApi _assets = AssetsApi(_c);

  HttpOfficeRepository(
      {required String baseUrl, required KeyValueStore store, Dio? dio})
      : _c = ApiClient(
            baseUrl: baseUrl,
            store: store,
            audience: '/staff',
            keyPrefix: 'office',
            dio: dio);

  @override
  Future<OwnerMoneyOverview> moneyOverview(OwnerPeriod period,
          {String? date}) async =>
      OwnerMoneyOverview.fromJson(_ok(await _c.authed(
          'GET',
          Uri(path: '/owner/overview', queryParameters: {
            'period': period.wire,
            if (date != null) 'date': date,
          }).toString())));
  @override
  Future<NotificationPage> notifications(
      {required String lang, String? before}) async {
    final r = await _c.authed(
        'GET',
        Uri(path: '/staff/notifications', queryParameters: {
          'lang': lang,
          if (before != null) 'before': before,
        }).toString());
    // An older server without the route: nothing to show.
    if (r.statusCode == 404) return NotificationPage.empty;
    return NotificationPage.fromJson(_ok(r));
  }

  @override
  Future<int> markNotificationsRead(List<String>? ids) async =>
      ((_ok(await _c.authed('POST', '/staff/notifications/read',
              body: {if (ids != null) 'ids': ids}))['marked']) as num?)
          ?.toInt() ??
      0;
  @override
  Future<OfficeMessage> sendMessage(
          {required String clientId,
          required String body,
          String? stationId,
          String? vendorId}) async =>
      OfficeMessage.fromJson(
          _ok(await _c.authed('POST', '/staff/messages', body: {
        'client_id': clientId,
        'body': body,
        if (stationId != null) 'station_id': stationId,
        if (vendorId != null) 'vendor_id': vendorId,
      })));
  @override
  Future<List<OfficeMessage>> sentMessages() async => [
        for (final m
            in _ok(await _c.authed('GET', '/staff/messages'))['messages']
                    as List? ??
                const [])
          OfficeMessage.fromJson(Map<String, dynamic>.from(m as Map))
      ];
  @override
  Future<ResolveResult> resolveException(String id,
      {required String resolution, required String reason}) async {
    final r = await _c.authed(
        'POST', '/staff/exceptions/${Uri.encodeComponent(id)}/resolve',
        body: {'resolution': resolution, 'reason': reason});
    _checkVerification(r);
    final body = _c.json(r);
    return ResolveResult(
        resolved: body['status'] == 'resolved',
        tier: (body['tier'] as num).toInt());
  }

  @override
  Future<List<ApprovalItem>> approvals() async {
    final r = await _c.authed('GET', '/staff/approvals');
    _checkVerification(r);
    return [
      for (final item in r.data as List? ?? const [])
        ApprovalItem.fromJson(Map<String, dynamic>.from(item as Map))
    ];
  }

  @override
  Future<void> decideApproval(String id,
      {required bool approve, required String reason}) async {
    final r = await _c.authed(
        'POST', '/staff/approvals/${Uri.encodeComponent(id)}/decision',
        body: {'approve': approve, 'reason': reason});
    _checkVerification(r);
    _c.json(r);
  }

  @override
  Future<List<MissedDay>> missedDays({String? stationId}) async {
    final r = await _c.authed(
        'GET',
        Uri(
                path: '/staff/closing-cases',
                queryParameters:
                    stationId == null ? null : {'station_id': stationId})
            .toString());
    _checkVerification(r);
    return [
      for (final row in r.data as List? ?? const [])
        MissedDay.fromJson(Map<String, dynamic>.from(row as Map))
    ];
  }

  @override
  Future<ClosingCase> openClosingCase(
      {required String clientId,
      required String stationId,
      required String businessDate,
      required String outcome,
      required String basis,
      List<CaseLineDraft> lines = const []}) async {
    final r = await _c.authed('POST', '/staff/closing-cases', body: {
      'client_id': clientId,
      'station_id': stationId,
      'business_date': businessDate,
      'outcome': outcome,
      'basis': basis,
      'lines': [for (final l in lines) l.toJson()],
    });
    _checkVerification(r);
    return ClosingCase.fromJson(_c.json(r));
  }

  @override
  Future<ClosingCase> decideClosingCase(String id,
      {required bool approve, required String reason}) async {
    final r = await _c.authed(
        'POST', '/staff/closing-cases/${Uri.encodeComponent(id)}/decision',
        body: {'approve': approve, 'reason': reason});
    final data = r.data;
    if (r.statusCode == 409 &&
        data is Map &&
        data['unverified_sales'] != null) {
      throw ClosingCaseBlocked(
          unverifiedSales: (data['unverified_sales'] as num).toInt(),
          pendingDamage: (data['pending_damage'] as num?)?.toInt() ?? 0);
    }
    _checkVerification(r);
    return ClosingCase.fromJson(_c.json(r));
  }

  @override
  Future<List<LostSaleEntry>> lostSaleEntries(
      {String? stationId, String? vendorId, String? status}) async {
    final r = await _c.authed(
        'GET',
        Uri(path: '/staff/lost-sale-entries', queryParameters: {
          if (stationId != null) 'station_id': stationId,
          if (vendorId != null) 'vendor_id': vendorId,
          if (status != null) 'status': status,
        }).toString());
    _checkVerification(r);
    return [
      for (final row in r.data as List? ?? const [])
        LostSaleEntry.fromJson(Map<String, dynamic>.from(row as Map))
    ];
  }

  @override
  Future<LostSaleDay> lostSaleDay(String vendorId, String businessDate) async {
    final r = await _c.authed(
        'GET',
        Uri(path: '/staff/lost-sale-entries/day', queryParameters: {
          'vendor_id': vendorId,
          'business_date': businessDate,
        }).toString());
    _checkVerification(r);
    return LostSaleDay.fromJson(_c.json(r));
  }

  @override
  Future<LostSaleEntry> askLostSale(
      {required String clientId,
      required String vendorId,
      required String stationId,
      required String businessDate,
      required String paymentMethod,
      String? customerId,
      required Map<String, int> quantities,
      required String reason}) async {
    final r = await _c.authed('POST', '/staff/lost-sale-entries', body: {
      'client_id': clientId,
      'vendor_id': vendorId,
      'station_id': stationId,
      'business_date': businessDate,
      'payment_method': paymentMethod,
      if (customerId != null) 'customer_id': customerId,
      'lines': [
        for (final e in quantities.entries)
          {'product_code': e.key, 'quantity': e.value}
      ],
      'reason': reason,
    });
    _checkVerification(r);
    return LostSaleEntry.fromJson(_c.json(r));
  }

  @override
  Future<LostSaleEntry> decideLostSale(String id,
      {required bool approve, required String reason}) async {
    final r = await _c.authed(
        'POST', '/staff/lost-sale-entries/${Uri.encodeComponent(id)}/decision',
        body: {'approve': approve, 'reason': reason});
    _checkVerification(r);
    return LostSaleEntry.fromJson(_c.json(r));
  }

  @override
  Future<LostSaleEntry> withdrawLostSale(String id) async {
    final r = await _c.authed(
        'POST', '/staff/lost-sale-entries/${Uri.encodeComponent(id)}/withdraw');
    _checkVerification(r);
    return LostSaleEntry.fromJson(_c.json(r));
  }

  @override
  Future<void> endPhoneAccess(String vendorId, {required String reason}) async {
    final r = await _c.authed('POST',
        '/admin/vendors/${Uri.encodeComponent(vendorId)}/revoke-sessions',
        body: {'reason': reason});
    _checkVerification(r);
    _c.json(r);
  }

  @override
  Future<List<SaleCancellation>> saleCancellations(
      {String? stationId, String? status}) async {
    final r = await _c.authed(
        'GET',
        Uri(path: '/staff/sale-cancellations', queryParameters: {
          if (stationId != null) 'station_id': stationId,
          if (status != null) 'status': status,
        }).toString());
    _checkVerification(r);
    return [
      for (final row in r.data as List? ?? const [])
        SaleCancellation.fromJson(Map<String, dynamic>.from(row as Map))
    ];
  }

  @override
  Future<SaleCancellation> askToCancelSale(
      {required String clientId,
      required String saleId,
      required String reason}) async {
    final r = await _c.authed('POST', '/staff/sale-cancellations',
        body: {'client_id': clientId, 'sale_id': saleId, 'reason': reason});
    _checkVerification(r);
    return SaleCancellation.fromJson(_c.json(r));
  }

  @override
  Future<SaleCancellation> decideSaleCancellation(String id,
      {required bool approve, required String reason}) async {
    final r = await _c.authed(
        'POST', '/staff/sale-cancellations/${Uri.encodeComponent(id)}/decision',
        body: {'approve': approve, 'reason': reason});
    _checkVerification(r);
    return SaleCancellation.fromJson(_c.json(r));
  }

  @override
  Future<SaleCancellation> withdrawSaleCancellation(String id) async {
    final r = await _c.authed('POST',
        '/staff/sale-cancellations/${Uri.encodeComponent(id)}/withdraw');
    _checkVerification(r);
    return SaleCancellation.fromJson(_c.json(r));
  }

  @override
  Future<AlertSettings> alertSettings() async {
    final r = await _c.authed('GET', '/admin/settings');
    _checkVerification(r);
    return AlertSettings(_c.json(r));
  }

  @override
  Future<void> saveAlertSetting(String key,
      {required Object? value, required String reason}) async {
    final r = await _c.authed(
        'PUT', '/admin/settings/${Uri.encodeComponent(key)}',
        body: {'value': value, 'reason': reason});
    _checkVerification(r);
    _c.json(r);
  }

  @override
  Future<void> registerPushToken(String token, {required String lang}) async {
    final r = await _c.authed('POST', '/staff/push-token',
        body: {'token': token, 'lang': lang});
    if (r.statusCode != 204) _c.fail(r);
  }

  @override
  Future<Map<String, dynamic>> vendorPayOverview() async =>
      _ok(await _c.authed('GET', '/staff/vendor-payments'));
  @override
  Future<Map<String, dynamic>> vendorPayStatement(
          String vendor, String from, String to) async =>
      _ok(await _c.authed(
          'GET',
          Uri(
                  path: '/staff/vendor-payments/${Uri.encodeComponent(vendor)}',
                  queryParameters: {'period_from': from, 'period_to': to})
              .toString()));
  @override
  Future<Map<String, dynamic>> vendorPayCommand(
          String vendor, String command, Map<String, dynamic> body) =>
      _post('/staff/vendor-payments/${Uri.encodeComponent(vendor)}/$command',
          body: body);

  @override
  Future<List<Map<String, dynamic>>> receivingLocations() async => [
        for (final row in await _getRows('/admin/locations', const {}))
          Map<String, dynamic>.from(row as Map)
      ];
  @override
  Future<List<Map<String, dynamic>>> receivingLots(String locationId) async {
    final body = _ok(await _c.authed('GET',
        '/staff/stock/${Uri.encodeComponent(locationId)}?include_lots=true'));
    return [
      for (final row in body['lots'] as List? ?? const [])
        Map<String, dynamic>.from(row as Map)
    ];
  }

  @override
  Future<Map<String, dynamic>> createExpectedDelivery(
          Map<String, dynamic> body) =>
      _post('/staff/manifests', body: body);

  // Stock: returns, stock days, transit returns, late entries -----------------

  @override
  Future<List<OfficeStockLocation>> stockLocations() async => parseRows(
      await _getRows('/admin/locations', const {}),
      OfficeStockLocation.fromJson);

  @override
  Future<OfficeStockReturn> recordReturn(
          {required String clientId,
          required String stationId,
          required String businessDate,
          required String destinationLocationId,
          required String reason,
          required List<ReturnLineDraft> lines}) async =>
      OfficeStockReturn.fromJson(await _post('/staff/returns', body: {
        'client_id': clientId,
        'station_id': stationId,
        'business_date': businessDate,
        'destination_location_id': destinationLocationId,
        'reason': reason,
        'lines': [for (final l in lines) l.toJson()],
      }));

  @override
  Future<List<OfficeStockReturn>> stockReturns(
          {String? stationId, String? from, String? to}) async =>
      parseRows(
          await _getRows('/staff/returns',
              {'station_id': stationId, 'from': from, 'to': to}),
          OfficeStockReturn.fromJson);

  @override
  Future<List<OfficeStockMeasure>> stockMeasures(String stationId) async {
    final r = await _c.authed(
        'GET',
        Uri(
            path: '/staff/stock-measures',
            queryParameters: {'station_id': stationId}).toString());
    final rows = _c.json(r)['measures'];
    return parseRows(
        rows is List ? rows : const [], OfficeStockMeasure.fromJson);
  }

  @override
  Future<OfficeStockDays> stockDays(
      {required String stationId, String? from, String? to}) async {
    final params = {
      'station_id': stationId,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    };
    final r = await _c.authed('GET',
        Uri(path: '/staff/stock-days', queryParameters: params).toString());
    _checkVerification(r);
    return OfficeStockDays.fromJson(_c.json(r));
  }

  @override
  Future<ResolvedProblem> resolveTransit(String exceptionId,
          {required String resolution,
          required String reason,
          String? destinationLocationId}) async =>
      ResolvedProblem.fromJson(await _post(
          '/staff/receipt-mismatches/${Uri.encodeComponent(exceptionId)}/resolve',
          body: {
            'resolution': resolution,
            'reason': reason,
            if (destinationLocationId != null)
              'destination_location_id': destinationLocationId,
          }));

  @override
  Future<void> saveLateEntryHours(int? hours, {required String reason}) async {
    final r = await _c.authed('PUT',
        '/admin/settings/${Uri.encodeComponent(OfficeMoneySettings.lateEntryKey)}',
        body: {'value': hours, 'reason': reason});
    _checkVerification(r);
    _c.json(r);
  }

  // Opening stock, kitchens and stores ------------------------------------------

  @override
  Future<List<OfficeOpeningEntry>> openingEntries() async => parseRows(
      await _getRows('/staff/opening-entries', const {}),
      OfficeOpeningEntry.fromJson);

  @override
  Future<OfficeOpeningSettings> openingSettings() async {
    final r = await _c.authed('GET', '/admin/settings');
    _checkVerification(r);
    return OfficeOpeningSettings.fromJson(_c.json(r));
  }

  @override
  Future<OfficeOpeningEntry> draftOpening(
          {required String clientId,
          required String locationId,
          required String product,
          required int quantity,
          int? unitCost,
          required String asOf,
          required String reference}) async =>
      OfficeOpeningEntry.fromJson(await _post('/staff/opening-entries', body: {
        'client_id': clientId,
        'location_id': locationId,
        'product': product,
        'quantity': quantity,
        if (unitCost != null) 'unit_cost': unitCost,
        'as_of': asOf,
        'reference': reference,
        'evidence_ref': reference,
      }));

  @override
  Future<OfficeOpeningEntry> decideOpening(String id,
          {required bool approve, required String reason}) async =>
      OfficeOpeningEntry.fromJson(await _post(
          '/staff/opening-entries/${Uri.encodeComponent(id)}/decision',
          body: {'approve': approve, 'reason': reason}));

  @override
  Future<void> setOpeningDate(String date, {required String reason}) async {
    final r = await _c.authed('PUT', '/admin/settings/opening.date',
        body: {'value': date, 'reason': reason});
    _checkVerification(r);
    _c.json(r);
  }

  @override
  Future<void> closeOpening({required String reason}) async {
    final r = await _c.authed('PUT', '/admin/settings/opening.closed',
        body: {'value': true, 'reason': reason});
    _checkVerification(r);
    _c.json(r);
  }

  @override
  Future<List<OfficeStockLocation>> setupLocations() => stockLocations();

  @override
  Future<OfficeStockLocation> createLocation(
          {required String code,
          required String name,
          required String kind}) async =>
      OfficeStockLocation.fromJson(await _post('/admin/locations',
          body: {'code': code, 'name': name, 'kind': kind}));

  @override
  Future<void> grantKitchenRole(
      {required String staffId,
      required String kitchenLocationId,
      required String reason}) async {
    _ok(await _c.authed('POST', '/admin/staff/$staffId/roles', body: {
      'role': StaffRole.kitchen,
      'reason': reason,
      'kitchen_location_id': kitchenLocationId
    }));
  }

  // Recipes and production runs ------------------------------------------------

  Map<String, Object?> _recipeLine(RecipeLineDraft l, AllocationMethod? m) => {
        'product': l.product,
        'quantity': l.quantity,
        if (m != null && l.basis != null) m.basisField: l.basis,
      };

  @override
  Future<List<OfficeRecipe>> recipes() async => parseRows(
      await _getRows('/admin/recipes', const {}), OfficeRecipe.fromJson);

  @override
  Future<OfficeRecipe> recipe(String id) async {
    final r =
        await _c.authed('GET', '/admin/recipes/${Uri.encodeComponent(id)}');
    _checkVerification(r);
    return OfficeRecipe.fromJson(_c.json(r));
  }

  @override
  Future<OfficeRecipe> createRecipe(
          {required String name,
          required String product,
          required String reason}) async =>
      OfficeRecipe.fromJson(await _post('/admin/recipes',
          body: {'name': name, 'product': product, 'reason': reason}));

  @override
  Future<RecipeVersion> draftVersion(String recipeId,
          {required List<RecipeLineDraft> inputs,
          required List<RecipeLineDraft> outputs,
          required AllocationMethod method,
          required String wasteKind,
          required String wasteValue,
          required String maxOutputRatio,
          required String reason}) async =>
      RecipeVersion.fromJson(await _post(
          '/admin/recipes/${Uri.encodeComponent(recipeId)}/versions',
          body: {
            'inputs': [for (final l in inputs) _recipeLine(l, null)],
            'outputs': [for (final l in outputs) _recipeLine(l, method)],
            'allocation_method': method.wire,
            'waste_allowance': {'kind': wasteKind, 'value': wasteValue},
            'max_output_ratio': maxOutputRatio,
            'reason': reason,
          }));

  @override
  Future<RecipeVersion> decideVersion(String versionId,
          {required bool approve, required String reason}) async =>
      RecipeVersion.fromJson(await _post(
          '/admin/recipe-versions/${Uri.encodeComponent(versionId)}/decision',
          body: {'approve': approve, 'reason': reason}));

  @override
  Future<OfficeProductionRun> recordRun(
          {required String clientId,
          required String kitchenId,
          required String versionId,
          required List<RecipeLineDraft> inputs,
          required List<RecipeLineDraft> outputs,
          required Object wasteQuantity,
          DateTime? occurredAt,
          String? note}) async =>
      OfficeProductionRun.fromJson(await _post('/staff/production-runs', body: {
        'client_id': clientId,
        'kitchen_location_id': kitchenId,
        'recipe_version_id': versionId,
        'inputs': [for (final l in inputs) _recipeLine(l, null)],
        'outputs': [for (final l in outputs) _recipeLine(l, null)],
        'waste_quantity': wasteQuantity,
        // Left out for a run done now: the server stamps it.
        if (occurredAt != null)
          'occurred_at': occurredAt.toUtc().toIso8601String(),
        if (note != null) 'note': note,
      }));

  @override
  Future<List<OfficeProductionRun>> productionRuns(
          {String? kitchenId, String? from, String? to}) async =>
      parseRows(
          await _getRows('/staff/production-runs',
              {'kitchen_location_id': kitchenId, 'from': from, 'to': to}),
          OfficeProductionRun.fromJson);

  @override
  Future<OfficeProductionRun> productionRun(String id) async {
    final r = await _c.authed(
        'GET', '/staff/production-runs/${Uri.encodeComponent(id)}');
    _checkVerification(r);
    return OfficeProductionRun.fromJson(_c.json(r));
  }

  @override
  Future<void> updateStation(String id,
      {required String name,
      required String area,
      required String address,
      required String reason}) async {
    _ok(await _c.authed('PATCH', '/admin/stations/$id', body: {
      'name': name,
      'area': area,
      'address': address,
      'reason': reason
    }));
  }

  @override
  Future<void> uploadStationPhoto(String id, Uint8List bytes) async {
    _ok(await _c.authed('POST', '/admin/stations/$id/photo',
        body: bytes, contentType: 'image/jpeg'));
  }

  @override
  Future<void> removeStationPhoto(String id) async {
    _ok(await _c.authed('DELETE', '/admin/stations/$id/photo'));
  }

  @override
  Future<List<Map<String, dynamic>>> stationStock(String locationId) async => [
        for (final row in _ok(
                await _c.authed('GET', '/staff/stock/$locationId'))['products']
            as List)
          Map<String, dynamic>.from(row as Map)
      ];
  @override
  Future<List<Map<String, dynamic>>> stationManifests(String stationId) async =>
      [
        for (final row in _list(await _c.authed('GET',
            '/staff/manifests?status=all&station_id=${Uri.encodeQueryComponent(stationId)}')))
          Map<String, dynamic>.from(row as Map)
      ];
  @override
  Future<void> amendManifest(String id, List<Map<String, dynamic>> lines,
      String reason, int version) async {
    _ok(await _c.authed('POST', '/staff/manifests/$id/versions',
        body: {'lines': lines, 'reason': reason, 'expected_version': version}));
  }

  @override
  Future<void> cancelManifest(String id, String reason, int version) async {
    _ok(await _c.authed('POST', '/staff/manifests/$id/cancel',
        body: {'reason': reason, 'expected_version': version}));
  }

  @override
  Future<void> endVendorStation(String id, String reason) async {
    _ok(await _c.authed('POST', '/admin/vendors/$id/station/end',
        body: {'reason': reason}));
  }

  @override
  Future<OfficeProduct> createProduct(
          {required String code,
          required String name,
          required String category,
          required String unit}) async =>
      OfficeProduct.fromJson(
          _ok(await _c.authed('POST', '/admin/products', body: {
        'code': code,
        'name': name,
        'category': category,
        'unit': unit,
        'available': true,
      })));
  @override
  Future<List<OfficeProduct>> products() async => [
        for (final p in _list(await _c.authed('GET', '/admin/products')))
          OfficeProduct.fromJson(Map<String, dynamic>.from(p as Map))
      ];
  @override
  Future<List<OfficeCategory>> categories() async => [
        for (final p in _list(await _c.authed('GET', '/admin/categories')))
          OfficeCategory(p['code'] as String, p['name'] as String)
      ];
  @override
  Future<List<OfficeUnit>> units() async => [
        for (final u in _list(await _c.authed('GET', '/admin/units')))
          OfficeUnit.fromJson(Map<String, dynamic>.from(u as Map))
      ];
  @override
  Future<List<OfficeStationPrice>> productPrices(String code) async => [
        for (final p
            in _list(await _c.authed('GET', '/admin/products/$code/prices')))
          OfficeStationPrice(
              p['station_id'] as String,
              p['station_name'] as String,
              p['amount'] as int?,
              p['overridden'] == true)
      ];
  @override
  Future<void> updateProduct(String code,
      {required String name,
      required String category,
      required String unit,
      required bool available,
      required String status,
      required String? imageKey,
      required String reason}) async {
    _ok(await _c.authed('PATCH', '/admin/products/$code', body: {
      'name': name,
      'category': category,
      'unit': unit,
      'available': available,
      'status': status,
      'image_key': imageKey,
      'reason': reason
    }));
  }

  @override
  Future<void> setProductPrice(String code,
      {required int amount, String? stationId, required String reason}) async {
    _ok(await _c.authed('POST', '/admin/products/$code/prices',
        body: {'amount': amount, 'station_id': stationId, 'reason': reason}));
  }

  @override
  Future<Uint8List> menuTemplate() async => base64Decode(
      _ok(await _c.authed('GET', '/admin/menu/template'))['content_base64']
          as String);
  @override
  Future<Map<String, dynamic>> previewMenu(Uint8List bytes) async =>
      _ok(await _c.authed('POST', '/admin/menu/preview',
          body: bytes, contentType: 'application/octet-stream'));
  @override
  Future<Map<String, dynamic>> importMenu(Map<String, dynamic> body) async =>
      _ok(await _c.authed('POST', '/admin/menu/import', body: body));
  @override
  Future<Map<String, dynamic>> stationMenu(String stationId) async =>
      _ok(await _c.authed('GET', '/admin/stations/$stationId/menu'));
  @override
  Future<Map<String, dynamic>> saveStationMenu(
          String stationId, Map<String, dynamic> body) async =>
      _ok(await _c.authed('PUT', '/admin/stations/$stationId/menu',
          body: body));

  @override
  Future<String> uploadProductImage(Uint8List bytes) async =>
      _ok(await _c.authed('POST', '/admin/product-images',
          body: bytes,
          contentType: 'application/octet-stream'))['image_key'] as String;

  @override
  Future<String> uploadOwnProfileImage(Uint8List bytes) async =>
      _ok(await _c.authed('POST', '/staff/me/profile-image',
          body: bytes,
          contentType: 'image/jpeg'))['profile_image_url'] as String;
  @override
  Future<void> placeStaff(String staffId,
      {required List<String> stationIds, required String reason}) async {
    _ok(await _c.authed('PUT', '/admin/staff/$staffId/stations',
        body: {'station_ids': stationIds, 'reason': reason}));
  }

  /// Business refusals become [OfficeError]; everything else as for vendors.
  Map<String, dynamic> _ok(Response<dynamic> r) {
    _check(r);
    return _c.json(r);
  }

  List<dynamic> _list(Response<dynamic> r) {
    _check(r);
    if (r.statusCode != 200 || r.data is! List) _c.fail(r);
    return r.data as List;
  }

  void _check(Response<dynamic> r) {
    final code = ApiClient.errorCode(r);
    if (r.statusCode == 403 && code == 'own_record') {
      throw const OfficeError(OfficeErrorKind.ownRecord);
    }
    if (r.statusCode == 409 && leadRefusals.contains(code)) {
      throw OfficeError(OfficeErrorKind.lead, code);
    }
    // A delivery that names a supply request the server will not link.
    if (code != null && supplyLinkRefusals.contains(code)) {
      throw SupplyError(code, r.statusCode ?? 409);
    }
    switch (r.statusCode) {
      case 409:
        // A database constraint (a name such as `vendors_phone`) means the
        // value is taken; a rule's sentence is shown to the person as is.
        final detail = r.data is Map ? (r.data as Map)['detail'] : null;
        if (detail is String && detail.trim().contains(' ')) {
          throw OfficeError(OfficeErrorKind.refused, detail.trim());
        }
        throw OfficeError(
            OfficeErrorKind.duplicate, detail is String ? detail : null);
      case 403 when ApiClient.errorCode(r) == 'forbidden':
        throw const OfficeError(OfficeErrorKind.forbidden);
      case 404 when ApiClient.errorCode(r) == 'not_found':
        throw const OfficeError(OfficeErrorKind.notFound);
      case 422:
        throw const OfficeError(OfficeErrorKind.invalid);
    }
  }

  @override
  Future<bool> hasSession() => _c.hasSession;

  /// Keeps the tokens of a lead session (issued from the seller session).
  @override
  Future<void> keepLeadTokens(Map<String, dynamic> tokens) =>
      _c.saveTokens(tokens);

  @override
  Future<SignInStep> startSignIn(String phone) async {
    final body = _c.json(
        await _c.send('POST', '/staff/auth/start', body: {'phone': phone}));
    return body['next'] == 'pin' ? SignInStep.pin : SignInStep.activation;
  }

  // Fingerprint sign-in after sign-out (MN024) ----------------------------

  @override
  Future<String> issueDeviceKey() async =>
      _c.json(await _c.authed('POST', '/staff/auth/device-key',
          body: {'device_id': await _c.deviceId()}))['key'] as String;

  @override
  Future<void> forgetDeviceKey() async {
    final r = await _c.authed('POST', '/staff/auth/device-key/forget',
        body: {'device_id': await _c.deviceId()});
    if (r.statusCode != 204 && r.statusCode != 200) _c.fail(r);
  }

  @override
  Future<StaffProfile> deviceSignIn(String key) async {
    final body = _c.json(await _c.send('POST', '/staff/auth/device-sign-in',
        body: {'device_id': await _c.deviceId(), 'key': key}));
    await _c.saveTokens(body);
    return StaffProfile.fromJson(body['profile'] as Map<String, dynamic>);
  }

  @override
  Future<StaffProfile> signIn(
      {required String phone, required String pin}) async {
    final body = _c.json(await _c.send('POST', '/staff/auth/sign-in',
        body: {'phone': phone, 'pin': pin, 'device_id': await _c.deviceId()}));
    await _c.saveTokens(body);
    return StaffProfile.fromJson(body['profile'] as Map<String, dynamic>);
  }

  @override
  Future<String> verifyCode(
      {required String phone, required String code, bool reset = false}) async {
    final body = _c.json(await _c.send('POST', '/staff/auth/verify-code',
        body: {
          'phone': phone,
          'code': code,
          'purpose': reset ? 'pin_reset' : 'activation'
        }));
    return body['exchange_token'] as String;
  }

  @override
  Future<StaffProfile> setPin(
      {required String setupToken, required String pin}) async {
    final body = _c.json(await _c.send('POST', '/staff/auth/set-pin', body: {
      'exchange_token': setupToken,
      'pin': pin,
      'pin_confirmation': pin,
      'device_id': await _c.deviceId(),
    }));
    await _c.saveTokens(body);
    final me = _c.json(await _c.authed('GET', '/staff/me'));
    return StaffProfile.fromJson({...me, 'phone': ''});
  }

  @override
  Future<StaffProfile> staffMe() async {
    final r = await _c.authed('GET', '/staff/me');
    _checkVerification(r);
    return StaffProfile.fromJson({..._c.json(r), 'phone': ''});
  }

  @override
  Future<void> changePin(
      {required String currentPin, required String newPin}) async {
    final r = await _c.authed('POST', '/staff/auth/change-pin', body: {
      'current_pin': currentPin,
      'new_pin': newPin,
      'new_pin_confirmation': newPin,
    });
    if (r.statusCode != 204) _c.fail(r);
  }

  @override
  Future<void> signOut() async {
    try {
      await _c.authed('POST', '/staff/auth/sign-out');
    } on AuthFailure {
      // Signing out on the phone always succeeds.
    } finally {
      await _c.clearTokens();
    }
  }

  @override
  Future<List<OfficeVendor>> vendors() async => [
        for (final v in _list(await _c.authed('GET', '/admin/vendors')))
          OfficeVendor.fromJson(Map<String, dynamic>.from(v as Map)),
      ];

  @override
  Future<List<OfficeStaff>> staff() async => [
        for (final s in _list(await _c.authed('GET', '/admin/staff')))
          OfficeStaff.fromJson(Map<String, dynamic>.from(s as Map)),
      ];

  @override
  Future<List<OfficeStation>> stations() async => [
        for (final s in _list(await _c.authed('GET', '/admin/stations')))
          OfficeStation.fromJson(Map<String, dynamic>.from(s as Map)),
      ];

  @override
  Future<String> addVendor(
          {required String name, required String phone}) async =>
      _ok(await _c.authed('POST', '/admin/vendors',
          body: {'name': name, 'phone': phone}))['id'] as String;

  @override
  Future<void> assignVendor(
      {required String vendorId,
      required String stationId,
      required String reason}) async {
    _ok(await _c.authed('POST', '/admin/vendors/$vendorId/station',
        body: {'station_id': stationId, 'reason': reason}));
  }

  // Sync conflicts (MN014) ------------------------------------------------------

  @override
  Future<List<OfficeSyncConflict>> syncConflicts() async => parseRows(
      await _getRows('/staff/sync-conflicts', const {}),
      OfficeSyncConflict.fromJson);

  @override
  Future<OfficeConflictOutcome> retryConflict(String opId,
          {required String reason}) async =>
      OfficeConflictOutcome.fromJson(await _post(
          '/staff/sync-conflicts/${Uri.encodeComponent(opId)}/retry',
          body: {'reason': reason}));

  @override
  Future<OfficeConflictOutcome> rejectConflict(String opId,
          {required String reason}) async =>
      OfficeConflictOutcome.fromJson(await _post(
          '/staff/sync-conflicts/${Uri.encodeComponent(opId)}/reject',
          body: {'reason': reason}));

  @override
  Future<void> assignVendorPastDay(
      {required String vendorId,
      required String stationId,
      required String businessDate,
      required String reason}) async {
    _ok(await _c.authed('POST',
        '/admin/vendors/${Uri.encodeComponent(vendorId)}/station/past-day',
        body: {
          'station_id': stationId,
          'business_date': businessDate,
          'reason': reason
        }));
  }

  IssuedCode _code(Map<String, dynamic> body) =>
      IssuedCode(body['code'] as String, body['expires_in_hours'] as int);

  @override
  Future<IssuedCode> vendorCode(String vendorId, {bool reset = false}) async =>
      _code(_ok(await _c.authed('POST', '/admin/vendors/$vendorId/codes',
          body: {'purpose': reset ? 'pin_reset' : 'activation'})));

  @override
  Future<String> addStaff(
          {required String name, required String phone}) async =>
      _ok(await _c.authed('POST', '/admin/staff',
          body: {'name': name, 'phone': phone}))['id'] as String;

  @override
  Future<void> grantRole(
      {required String staffId,
      required String role,
      required String reason}) async {
    _ok(await _c.authed('POST', '/admin/staff/$staffId/roles',
        body: {'role': role, 'reason': reason}));
  }

  @override
  Future<void> assignSupervisor(
      {required String stationId,
      required String staffId,
      required String reason}) async {
    _ok(await _c.authed('POST', '/admin/stations/$stationId/supervisor',
        body: {'staff_id': staffId, 'reason': reason}));
  }

  @override
  Future<IssuedCode> staffCode(String staffId, {bool reset = false}) async =>
      _code(_ok(await _c.authed('POST', '/admin/staff/$staffId/codes',
          body: {'purpose': reset ? 'pin_reset' : 'activation'})));

  @override
  Future<OfficeStation> addStation(
      {required String code, required String name}) async {
    final body = _ok(await _c
        .authed('POST', '/admin/stations', body: {'code': code, 'name': name}));
    return OfficeStation(
        id: body['id'] as String,
        code: body['code'] as String,
        name: body['name'] as String);
  }

  Map<String, Object> _edit(String? name, String? phone, String reason) => {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        'reason': reason,
      };

  @override
  Future<OfficeVendor> updateVendor(String vendorId,
          {String? name, String? phone, required String reason}) async =>
      OfficeVendor.fromJson(_ok(await _c.authed(
          'PATCH', '/admin/vendors/$vendorId',
          body: _edit(name, phone, reason))));

  @override
  Future<OfficeStaff> updateStaff(String staffId,
          {String? name, String? phone, required String reason}) async =>
      OfficeStaff.fromJson(_ok(await _c.authed('PATCH', '/admin/staff/$staffId',
          body: _edit(name, phone, reason))));

  @override
  Future<void> changeVendorStatus(String vendorId, StatusChange change,
      {required String reason}) async {
    _ok(await _c.authed('POST', '/admin/vendors/$vendorId/${change.path}',
        body: {'reason': reason}));
  }

  /// Any coded 409 on the lead routes is a lead refusal (never "phone used").
  void _lead(Response<dynamic> r) {
    final code = ApiClient.errorCode(r);
    if (r.statusCode == 409 && code != null) {
      throw OfficeError(OfficeErrorKind.lead, code);
    }
    _ok(r);
  }

  @override
  Future<void> makeOutletLead(String vendorId,
      {required String clientId, required String reason}) async {
    _lead(await _c.authed('POST',
        '/staff/vendors/${Uri.encodeComponent(vendorId)}/outlet-lead',
        body: {'client_id': clientId, 'reason': reason}));
  }

  @override
  Future<void> endOutletLead(String vendorId,
      {required String clientId, required String reason}) async {
    _lead(await _c.authed('POST',
        '/staff/vendors/${Uri.encodeComponent(vendorId)}/outlet-lead/end',
        body: {'client_id': clientId, 'reason': reason}));
  }

  @override
  Future<void> changeStaffStatus(String staffId, StatusChange change,
      {required String reason}) async {
    _ok(await _c.authed('POST', '/admin/staff/$staffId/${change.path}',
        body: {'reason': reason}));
  }

  @override
  Future<void> revokeRole(
      {required String staffId,
      required String roleGrantId,
      required String reason}) async {
    _ok(await _c.authed(
        'POST', '/admin/staff/$staffId/roles/$roleGrantId/revoke',
        body: {'reason': reason}));
  }

  @override
  Future<OfficeCategory> createCategory(
      {required String code, required String name}) async {
    final body = _ok(await _c.authed('POST', '/admin/categories',
        body: {'code': code, 'name': name}));
    return OfficeCategory(body['code'] as String, body['name'] as String);
  }

  @override
  Future<OfficeUnit> createUnit(
      {required String code,
      required String name,
      required bool allowsDecimal}) async {
    final body = _ok(await _c.authed('POST', '/admin/units',
        body: {'code': code, 'name': name, 'allows_decimal': allowsDecimal}));
    return OfficeUnit.fromJson(body);
  }

  // Verification ---------------------------------------------------------------

  /// Verification refusals (403/404/409) retain the server's reason for
  /// localized display; nothing in the refused request took effect.
  void _checkVerification(Response<dynamic> r) {
    final status = r.statusCode;
    if (status == 403 && ApiClient.errorCode(r) == 'own_record') {
      throw const OfficeError(OfficeErrorKind.ownRecord);
    }
    if (status == 403 || status == 404 || status == 409) {
      final detail = r.data is Map ? (r.data as Map)['detail'] : null;
      if (detail is String && detail.trim().isNotEmpty) {
        throw OfficeError(OfficeErrorKind.refused, detail.trim());
      }
      throw OfficeError(switch (status) {
        403 => OfficeErrorKind.forbidden,
        404 => OfficeErrorKind.notFound,
        _ => OfficeErrorKind.refused,
      });
    }
    _check(r);
  }

  Future<List<dynamic>> _getRows(
      String path, Map<String, String?> query) async {
    final params = {
      for (final e in query.entries)
        if (e.value != null) e.key: e.value!
    };
    final r = await _c.authed(
        'GET',
        Uri(path: path, queryParameters: params.isEmpty ? null : params)
            .toString());
    _checkVerification(r);
    return _list(r);
  }

  Future<Map<String, dynamic>> _post(String path, {Object? body}) async {
    final r = await _c.authed('POST', path, body: body);
    _checkVerification(r);
    return _c.json(r);
  }

  // Finance books (Phase 12) -------------------------------------------------

  Future<Map<String, dynamic>> _send(String method, String path,
      {Object? body}) async {
    final r = await _c.authed(method, path, body: body);
    _checkVerification(r);
    return _c.json(r);
  }

  @override
  Future<List<FinanceAccount>> financeAccounts() async => parseRows(
      await _getRows('/staff/finance/accounts', const {}),
      FinanceAccount.fromJson);

  @override
  Future<FinanceAccount> createFinanceAccount(
          {required String code,
          required String name,
          required String kind,
          required String reason}) async =>
      FinanceAccount.fromJson(await _post('/staff/finance/accounts',
          body: {'code': code, 'name': name, 'kind': kind, 'reason': reason}));

  @override
  Future<FinanceAccount> updateFinanceAccount(String id,
          {String? name, bool? active, required String reason}) async =>
      FinanceAccount.fromJson(await _send(
          'PATCH', '/staff/finance/accounts/${Uri.encodeComponent(id)}',
          body: {
            if (name != null) 'name': name,
            if (active != null) 'active': active,
            'reason': reason,
          }));

  @override
  Future<List<PostingRule>> postingMap() async => parseRows(
      await _getRows('/staff/finance/posting-map', const {}),
      PostingRule.fromJson);

  @override
  Future<PostingRule> setPostingRule(String event,
          {required String debitAccountId,
          required String creditAccountId,
          required String reason}) async =>
      PostingRule.fromJson(await _send(
          'PUT', '/staff/finance/posting-map/${Uri.encodeComponent(event)}',
          body: {
            'debit_account_id': debitAccountId,
            'credit_account_id': creditAccountId,
            'reason': reason,
          }));

  @override
  Future<FinanceStatus> financeStatus() async =>
      FinanceStatus.fromJson(await _send('GET', '/staff/finance/status'));

  @override
  Future<PostResult> postToBooks({required String until}) async =>
      PostResult.fromJson(
          await _post('/staff/finance/post', body: {'until': until}));

  @override
  Future<List<FinancePeriod>> financePeriods() async => parseRows(
      await _getRows('/staff/finance/periods', const {}),
      FinancePeriod.fromJson);

  @override
  Future<FinancePeriod> lockFinancePeriod(String month,
          {required String reason}) async =>
      FinancePeriod.fromJson(await _post(
          '/staff/finance/periods/${Uri.encodeComponent(month)}/lock',
          body: {'reason': reason}));

  @override
  Future<List<JournalEntry>> journal(
          {String? from, String? to, String? accountId}) async =>
      parseRows(
          await _getRows('/staff/finance/journal',
              {'from': from, 'to': to, 'account_id': accountId}),
          JournalEntry.fromJson);

  @override
  Future<TrialBalance> trialBalance({String? asOf}) async =>
      TrialBalance.fromJson(await _getJson(
          '/staff/finance/reports/trial-balance', {'as_of': asOf}));

  @override
  Future<OperatingResult> operatingResult({String? from, String? to}) async =>
      OperatingResult.fromJson(await _getJson(
          '/staff/finance/reports/operating-result', {'from': from, 'to': to}));

  @override
  Future<CashPosition> cashPosition({String? asOf}) async =>
      CashPosition.fromJson(await _getJson(
          '/staff/finance/reports/cash-position', {'as_of': asOf}));

  // Owner bonuses, sale corrections and performance settings (Phase 9) ------

  @override
  Future<OwnerBonusPeriod> bonuses(
      {required String period, String? date}) async {
    final r = await _c.authed(
        'GET',
        Uri(path: '/owner/bonuses', queryParameters: {
          'period': period,
          if (date != null) 'date': date,
        }).toString());
    _checkVerification(r);
    return OwnerBonusPeriod.fromJson(_c.json(r));
  }

  @override
  Future<OwnerVendorBonus> vendorBonus(String vendorId,
      {required String period, String? date}) async {
    final r = await _c.authed(
        'GET',
        Uri(
            path: '/owner/bonuses/vendors/${Uri.encodeComponent(vendorId)}',
            queryParameters: {
              'period': period,
              if (date != null) 'date': date,
            }).toString());
    _checkVerification(r);
    return OwnerVendorBonus.fromJson(_c.json(r));
  }

  @override
  Future<void> correctSale(String saleId, {required String reason}) async {
    await _post('/owner/sales/${Uri.encodeComponent(saleId)}/correct',
        body: {'reason': reason});
  }

  @override
  Future<OwnerPerformanceSettings> performanceSettings() async {
    final r = await _c.authed('GET', '/admin/settings');
    _checkVerification(r);
    return OwnerPerformanceSettings.fromJson(_c.json(r));
  }

  // Owner performance: overview, scorecards, stations, ratings (Phase 9) ----

  Future<Map<String, dynamic>> _getJson(
      String path, Map<String, String?> query) async {
    final params = {
      for (final e in query.entries)
        if (e.value != null) e.key: e.value!
    };
    final r = await _c.authed(
        'GET',
        Uri(path: path, queryParameters: params.isEmpty ? null : params)
            .toString());
    _checkVerification(r);
    return _c.json(r);
  }

  @override
  Future<PerformanceOverview> performanceOverview(PerformancePeriod period,
          {String? date, int attentionLimit = 20}) async =>
      PerformanceOverview.fromJson(await _getJson('/owner/overview', {
        'period': period.wire,
        'date': date,
        'attention_limit': '$attentionLimit',
      }));

  @override
  Future<Scorecard> vendorScorecard(String vendorId, PerformancePeriod period,
          {String? date}) async =>
      Scorecard.fromJson(await _getJson(
          '/owner/vendors/${Uri.encodeComponent(vendorId)}',
          {'period': period.wire, 'date': date}));

  @override
  Future<Scorecard> staffScorecard(String staffId, PerformancePeriod period,
          {String? date}) async =>
      Scorecard.fromJson(await _getJson(
          '/owner/staff/${Uri.encodeComponent(staffId)}',
          {'period': period.wire, 'date': date}));

  @override
  Future<StationPerformanceDetail> stationPerformance(
          String stationId, PerformancePeriod period, {String? date}) async =>
      StationPerformanceDetail.fromJson(await _getJson(
          '/owner/stations/${Uri.encodeComponent(stationId)}',
          {'period': period.wire, 'date': date}));

  @override
  Future<OwnerRating> rate(
          {String? vendorId,
          String? staffId,
          required int stars,
          String? comment}) async =>
      OwnerRating.fromJson(await _post('/staff/ratings', body: {
        if (vendorId != null) 'vendor_id': vendorId,
        if (staffId != null) 'staff_id': staffId,
        'stars': stars,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      }));

  @override
  Future<List<OwnerRating>> ratings(
          {String? vendorId, String? staffId}) async =>
      parseRows(
          await _getRows(
              '/staff/ratings', {'vendor_id': vendorId, 'staff_id': staffId}),
          OwnerRating.fromJson);

  @override
  Future<AreaRating> rateArea(
          {String? vendorId,
          String? staffId,
          required String date,
          required String area,
          required int score}) async =>
      AreaRating.fromJson(await _post('/staff/area-ratings', body: {
        if (vendorId != null) 'vendor_id': vendorId,
        if (staffId != null) 'staff_id': staffId,
        'business_date': date,
        'area': area,
        'score': score,
      }));

  @override
  Future<List<AreaRating>> areaRatings(
          {String? vendorId, String? staffId, required String date}) async =>
      parseRows(
          await _getRows('/staff/area-ratings', {
            'vendor_id': vendorId,
            'staff_id': staffId,
            'business_date': date
          }),
          AreaRating.fromJson);

  // Deleting what was added by mistake ------------------------------------

  Future<void> _delete(String path, String reason) async =>
      _ok(await _c.authed('POST', path, body: {'reason': reason}));

  @override
  Future<void> deleteProduct(String code, {required String reason}) =>
      _delete('/admin/products/${Uri.encodeComponent(code)}/delete', reason);

  @override
  Future<void> deleteCategory(String code, {required String reason}) =>
      _delete('/admin/categories/${Uri.encodeComponent(code)}/delete', reason);

  @override
  Future<void> deleteStation(String stationId, {required String reason}) =>
      _delete(
          '/admin/stations/${Uri.encodeComponent(stationId)}/delete', reason);

  @override
  Future<void> deleteCreditCustomer(String customerId,
          {required String reason}) =>
      _delete(
          '/staff/credit-customers/${Uri.encodeComponent(customerId)}/delete',
          reason);

  // Vendor balances, adjustments and exports (Phase 6) ---------------------

  @override
  Future<List<OfficeVendorBalance>> vendorBalances({String? stationId}) async =>
      parseRows(
          await _getRows('/staff/money/balances', {'station_id': stationId}),
          OfficeVendorBalance.fromJson);

  @override
  Future<OfficeVendorMoney> vendorMoney(String vendorId) async {
    final r = await _c.authed(
        'GET', '/staff/money/vendors/${Uri.encodeComponent(vendorId)}');
    _checkVerification(r);
    return OfficeVendorMoney.fromJson(_c.json(r));
  }

  @override
  Future<List<OfficeAdjustment>> adjustments(
          {String? status, String? vendorId}) async =>
      parseRows(
          await _getRows('/staff/money/adjustments',
              {'status': status, 'vendor_id': vendorId}),
          OfficeAdjustment.fromJson);

  @override
  Future<OfficeAdjustment> requestAdjustment(
          {required String clientId,
          required String vendorId,
          required String businessDate,
          required AdjustmentKind kind,
          required String direction,
          required int amount,
          required String reason,
          required String basisRef,
          String? correctsId}) async =>
      OfficeAdjustment.fromJson(await _post('/staff/money/adjustments', body: {
        'client_id': clientId,
        'vendor_id': vendorId,
        'business_date': businessDate,
        'kind': kind.wire,
        'direction': direction,
        'amount': amount,
        'reason': reason,
        'basis_ref': basisRef,
        if (correctsId != null) 'corrects_id': correctsId,
      }));

  @override
  Future<OfficeAdjustment> decideAdjustment(String id,
          {required bool approve, required String reason}) async =>
      OfficeAdjustment.fromJson(await _post(
          '/staff/money/adjustments/${Uri.encodeComponent(id)}/decision',
          body: {'approve': approve, 'reason': reason}));

  @override
  Future<MoneyExport> moneyExport(MoneyExportKind kind,
      {required String from, required String to, String? stationId}) async {
    final r = await _c.authed(
        'GET',
        Uri(path: '/staff/money/export', queryParameters: {
          'kind': kind.wire,
          'from': from,
          'to': to,
          if (stationId != null) 'station_id': stationId,
        }).toString());
    _checkVerification(r);
    return MoneyExport.fromJson(_c.json(r));
  }

  @override
  Future<List<OfficeVerificationStation>> verificationQueue() async =>
      parseRows(await _getRows('/staff/verification', const {}),
          OfficeVerificationStation.fromJson);

  @override
  Future<List<OfficeSale>> stationSales(String stationId,
          {String? businessDate, String? status}) async =>
      parseRows(
          await _getRows('/staff/sales', {
            'station_id': stationId,
            'business_date': businessDate,
            'status': status
          }),
          OfficeSale.fromJson);

  @override
  Future<List<OfficeSale>> autoVerifiedSales(String stationId) async =>
      parseRows(
          await _getRows('/staff/sales',
              {'station_id': stationId, 'verified_method': 'auto'}),
          OfficeSale.fromJson);

  @override
  Future<OfficeShadowSummary> autoVerifySummary(
      {required String from, required String to}) async {
    final r = await _c.authed(
        'GET',
        '/owner/auto-verify/summary?from=${Uri.encodeQueryComponent(from)}'
            '&to=${Uri.encodeQueryComponent(to)}');
    _checkVerification(r);
    return OfficeShadowSummary.fromJson(_c.json(r));
  }

  @override
  Future<List<String>> verifySales(List<String> saleIds) async {
    assert(saleIds.length <= 500, 'the server takes at most 500 per batch');
    final body =
        await _post('/staff/sales/verify', body: {'sale_ids': saleIds});
    return [for (final id in body['verified'] as List? ?? const []) '$id'];
  }

  @override
  Future<List<OfficeDamageReport>> damageReports(
          {required String stationId, String status = 'reported'}) async =>
      parseRows(
          await _getRows('/staff/damage-reports',
              {'status': status, 'station_id': stationId}),
          OfficeDamageReport.fromJson);

  @override
  Future<OfficeDamageReport> decideDamage(String reportId,
          {required bool approve, required String reason}) async =>
      OfficeDamageReport.fromJson(await _post(
          '/staff/damage-reports/${Uri.encodeComponent(reportId)}/decision',
          body: {'approve': approve, 'reason': reason}));

  @override
  Future<List<OfficeClosingCount>> closingCounts(
          {required String stationId, String status = 'recorded'}) async =>
      parseRows(
          await _getRows('/staff/closing-counts',
              {'status': status, 'station_id': stationId}),
          OfficeClosingCount.fromJson);

  @override
  Future<OfficeClosingCount> confirmClosing(String closingId) async =>
      OfficeClosingCount.fromJson(await _post(
          '/staff/closing-counts/${Uri.encodeComponent(closingId)}/confirm'));

  @override
  Future<List<OfficeException>> exceptions(
          {required String stationId, String status = 'open'}) async =>
      parseRows(
          await _getRows(
              '/staff/exceptions', {'status': status, 'station_id': stationId}),
          OfficeException.fromJson);

  // Money ----------------------------------------------------------------------

  @override
  Future<List<OfficeMoneyDay>> moneyDays(
          {required String stationId, required String businessDate}) async =>
      parseRows(
          await _getRows('/staff/money/days',
              {'station_id': stationId, 'business_date': businessDate}),
          OfficeMoneyDay.fromJson);

  @override
  Future<OfficeHandover> recordHandover(
          {required String vendorId,
          required String businessDate,
          required int amount,
          DateTime? receivedAt,
          String? note,
          String? clientId}) async =>
      OfficeHandover.fromJson(await _post('/staff/handovers', body: {
        'vendor_id': vendorId,
        'business_date': businessDate,
        'amount': amount,
        if (receivedAt != null)
          'received_at': receivedAt.toUtc().toIso8601String(),
        if (note != null) 'note': note,
        if (clientId != null) 'client_id': clientId,
      }));

  @override
  Future<List<OfficeHandover>> handovers(
          {String? stationId,
          String? vendorId,
          String? from,
          String? to,
          String? status}) async =>
      parseRows(
          await _getRows('/staff/handovers', {
            'station_id': stationId,
            'vendor_id': vendorId,
            'from': from,
            'to': to,
            'status': status
          }),
          OfficeHandover.fromJson);

  @override
  Future<OfficeHandover> confirmHandover(String handoverId) async =>
      OfficeHandover.fromJson(await _post(
          '/staff/handovers/${Uri.encodeComponent(handoverId)}/confirm'));

  @override
  Future<OfficeHandover> reverseHandover(String handoverId,
          {required String reason}) async =>
      OfficeHandover.fromJson(await _post(
          '/staff/handovers/${Uri.encodeComponent(handoverId)}/reverse',
          body: {'reason': reason}));

  @override
  Future<OfficeExpense> recordExpense(
          {required String stationId,
          required String businessDate,
          required String category,
          String? item,
          required int amount,
          String? note,
          String? clientId}) async =>
      OfficeExpense.fromJson(await _post('/staff/expenses', body: {
        'station_id': stationId,
        'business_date': businessDate,
        'category': category,
        if (item != null) 'item': item,
        'amount': amount,
        if (note != null) 'note': note,
        if (clientId != null) 'client_id': clientId,
      }));

  @override
  Future<List<OfficeExpense>> expenses(
          {String? stationId,
          String? from,
          String? to,
          String? status,
          String? paidBy}) async =>
      parseRows(
          await _getRows('/staff/expenses', {
            'station_id': stationId,
            'from': from,
            'to': to,
            'status': status,
            'paid_by': paidBy
          }),
          OfficeExpense.fromJson);

  @override
  Future<OfficeExpense> decideExpense(String expenseId,
          {required bool approve, required String reason}) async =>
      OfficeExpense.fromJson(await _post(
          '/staff/expenses/${Uri.encodeComponent(expenseId)}/decision',
          body: {'approve': approve, 'reason': reason}));

  @override
  Future<OfficeExpense> reverseExpense(String expenseId,
          {required String reason}) async =>
      OfficeExpense.fromJson(await _post(
          '/staff/expenses/${Uri.encodeComponent(expenseId)}/reverse',
          body: {'reason': reason}));

  // Credit customers (MN018).

  @override
  Future<List<OfficeCreditCustomer>> creditCustomers(
          {String? stationId}) async =>
      [
        for (final row in await _getRows(
            '/staff/credit-customers', {'station_id': stationId}))
          OfficeCreditCustomer.fromJson(Map<String, dynamic>.from(row as Map))
      ];

  @override
  Future<OfficeCreditCustomer> createCreditCustomer(
          {required String stationId,
          required String name,
          String? phone,
          String? note}) async =>
      OfficeCreditCustomer.fromJson(
          await _post('/staff/credit-customers', body: {
        'station_id': stationId,
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (note != null && note.isNotEmpty) 'note': note,
      }));

  @override
  Future<OfficeCreditStatement> creditStatement(String customerId) async =>
      OfficeCreditStatement.fromJson(_ok(await _c.authed('GET',
          '/staff/credit-customers/${Uri.encodeComponent(customerId)}')));

  @override
  Future<OfficeCreditCustomer> setCreditLimit(String customerId,
          {required int? limit, required String reason}) async =>
      OfficeCreditCustomer.fromJson(_ok(await _c.authed('PUT',
          '/staff/credit-customers/${Uri.encodeComponent(customerId)}/limit',
          body: {'credit_limit': limit, 'reason': reason})));

  @override
  Future<OfficeCreditCustomer> setCreditStatus(String customerId,
          {required bool suspended, required String reason}) async =>
      OfficeCreditCustomer.fromJson(await _post(
          '/staff/credit-customers/${Uri.encodeComponent(customerId)}/status',
          body: {
            'status': suspended ? 'suspended' : 'active',
            'reason': reason
          }));

  @override
  Future<OfficeCreditStatement> recordCreditRepayment(String customerId,
          {required int amount, required String method, String? note}) async =>
      OfficeCreditStatement.fromJson(await _post(
          '/staff/credit-customers/${Uri.encodeComponent(customerId)}/repayments',
          body: {
            'amount': amount,
            'method': method,
            if (note != null && note.isNotEmpty) 'note': note,
          }));

  @override
  Future<OfficeCreditStatement> reverseCreditRepayment(String repaymentId,
          {required String reason}) async =>
      OfficeCreditStatement.fromJson(await _post(
          '/staff/credit-repayments/${Uri.encodeComponent(repaymentId)}/reverse',
          body: {'reason': reason}));

  @override
  Future<OfficeCreditStatement> writeOffCredit(String customerId,
          {required int amount, required String reason}) async =>
      OfficeCreditStatement.fromJson(await _post(
          '/staff/credit-customers/${Uri.encodeComponent(customerId)}/write-offs',
          body: {'amount': amount, 'reason': reason}));

  @override
  Future<OfficeMoneySettings> moneySettings() async {
    final r = await _c.authed('GET', '/admin/settings');
    _checkVerification(r);
    return OfficeMoneySettings.fromJson(_c.json(r));
  }

  @override
  Future<void> saveSetting(String key,
      {required Object value, required String reason}) async {
    final r = await _c.authed(
        'PUT', '/admin/settings/${Uri.encodeComponent(key)}',
        body: {'value': value, 'reason': reason});
    _checkVerification(r);
    _c.json(r);
  }

  // -- supply requests, "Maombi ya mzigo" (MN038) --

  @override
  Future<List<SupplyRequest>> waitingSupplyRequests() => _supply.waiting();

  @override
  Future<List<SupplyRequest>> ownSupplyRequests() => _supply.mine();

  @override
  Future<SupplyRequest> supplyRequestById(String id) => _supply.one(id);

  @override
  Future<List<SupplyRequest>> supplyRequestsByStatus(String status,
          {String? stationId}) =>
      _supply.byStatus(status, stationId: stationId);

  @override
  Future<SupplyRequest> decideSupplyRequest(String id,
          {required String clientId,
          required int step,
          required bool approve,
          String? reason}) =>
      _supply.decide(id,
          clientId: clientId, step: step, approve: approve, reason: reason);

  @override
  Future<SupplyRequest> giveSupplyMoney(String id,
          {required String clientId, required int amount}) =>
      _supply.advance(id, clientId: clientId, amount: amount);

  @override
  Future<SupplyRequest> confirmSupply(String id,
          {required String clientId, required bool acceptOverspend}) =>
      _supply.confirm(id, clientId: clientId, acceptOverspend: acceptOverspend);

  @override
  Future<List<OutstandingAdvance>> officeSupplyOutstanding() =>
      _supply.outstanding();

  // -- business assets, "Mali za biashara" (MN039) --

  @override
  Future<List<AssetLocation>> assetLocations() => _assets.locations();

  @override
  Future<List<AssetCategory>> assetCategories() => _assets.categories();

  @override
  Future<AssetCategory> createAssetCategory(String name,
          {required String clientId}) =>
      _assets.createCategory(name, clientId);

  @override
  Future<AssetCategory> renameAssetCategory(
          String id, String name, String reason) =>
      _assets.renameCategory(id, name, reason);

  @override
  Future<List<Asset>> assets(
          {String? locationId, String? categoryId, String? query}) =>
      _assets.list(
          locationId: locationId, categoryId: categoryId, query: query);

  @override
  Future<Asset> assetById(String id) => _assets.one(id);

  @override
  Future<List<Asset>> registerAssets(AssetDraft draft) =>
      _assets.register(draft);

  @override
  Future<Asset> addAssetPurchase(String id,
          {required String clientId,
          required int quantity,
          required num unitPrice,
          required String purchaseDate,
          String? supplier,
          String? reference,
          String? inServiceDate,
          String? notes}) =>
      _assets.purchase(id, {
        'client_id': clientId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'purchase_date': purchaseDate,
        if (supplier != null) 'supplier': supplier,
        if (reference != null) 'reference': reference,
        if (inServiceDate != null) 'in_service_date': inServiceDate,
        if (notes != null) 'notes': notes,
      });

  @override
  Future<Asset> changeAsset(String id,
          {required String clientId,
          required String change,
          required String reason,
          int? quantity,
          String? condition,
          String? area,
          AssetPerson? custodian,
          String? locationId}) =>
      _assets.change(id, {
        'client_id': clientId,
        'change': change,
        'reason': reason,
        if (quantity != null) 'quantity': quantity,
        if (condition != null) 'condition': condition,
        if (area != null) 'area': area,
        if (custodian != null)
          (custodian.kind == 'staff'
              ? 'custodian_staff_id'
              : 'custodian_vendor_id'): custodian.id,
        if (locationId != null) 'location_id': locationId,
      });

  @override
  Future<Asset> editAssetDetails(String id,
          {String? name,
          String? categoryId,
          String? notes,
          required String reason}) =>
      _assets.edit(id, {
        if (name != null) 'name': name,
        if (categoryId != null) 'category_id': categoryId,
        if (notes != null) 'notes': notes,
        'reason': reason,
      });
}

/// Without an API (no `MN_API_URL`), the office fails closed like the vendor side.
class UnavailableOfficeRepository implements OfficeRepository {
  const UnavailableOfficeRepository();

  @override
  Future<OfficeProduct> createProduct(
          {required String code,
          required String name,
          required String category,
          required String unit}) async =>
      _fail();
  @override
  Future<List<OfficeProduct>> products() async => _fail();
  @override
  Future<List<OfficeCategory>> categories() async => _fail();
  @override
  Future<List<OfficeUnit>> units() async => _fail();
  @override
  Future<List<OfficeStationPrice>> productPrices(String code) async => _fail();
  @override
  Future<void> updateProduct(String code,
          {required String name,
          required String category,
          required String unit,
          required bool available,
          required String status,
          required String? imageKey,
          required String reason}) async =>
      _fail();
  @override
  Future<void> setProductPrice(String code,
          {required int amount,
          String? stationId,
          required String reason}) async =>
      _fail();
  @override
  Future<String> uploadProductImage(Uint8List bytes) async => _fail();
  @override
  Future<void> placeStaff(String staffId,
          {required List<String> stationIds, required String reason}) async =>
      _fail();
  Never _fail() => throw const AuthFailure(AuthFailureKind.notConfigured);

  @override
  Future<bool> hasSession() async => false;
  @override
  Future<SignInStep> startSignIn(String phone) async => _fail();
  @override
  Future<StaffProfile> signIn(
          {required String phone, required String pin}) async =>
      _fail();
  @override
  Future<String> verifyCode(
          {required String phone,
          required String code,
          bool reset = false}) async =>
      _fail();
  @override
  Future<StaffProfile> setPin(
          {required String setupToken, required String pin}) async =>
      _fail();
  @override
  Future<void> signOut() async {}
  @override
  Future<void> changePin(
          {required String currentPin, required String newPin}) async =>
      _fail();
  @override
  Future<List<OfficeVendor>> vendors() async => _fail();
  @override
  Future<List<OfficeStaff>> staff() async => _fail();
  @override
  Future<List<OfficeStation>> stations() async => _fail();
  @override
  Future<String> addVendor(
          {required String name, required String phone}) async =>
      _fail();
  @override
  Future<void> assignVendor(
          {required String vendorId,
          required String stationId,
          required String reason}) async =>
      _fail();
  @override
  Future<IssuedCode> vendorCode(String vendorId, {bool reset = false}) async =>
      _fail();
  @override
  Future<String> addStaff(
          {required String name, required String phone}) async =>
      _fail();
  @override
  Future<void> grantRole(
          {required String staffId,
          required String role,
          required String reason}) async =>
      _fail();
  @override
  Future<void> assignSupervisor(
          {required String stationId,
          required String staffId,
          required String reason}) async =>
      _fail();
  @override
  Future<IssuedCode> staffCode(String staffId, {bool reset = false}) async =>
      _fail();
  @override
  Future<OfficeStation> addStation(
          {required String code, required String name}) async =>
      _fail();
  @override
  Future<OfficeVendor> updateVendor(String vendorId,
          {String? name, String? phone, required String reason}) async =>
      _fail();
  @override
  Future<OfficeStaff> updateStaff(String staffId,
          {String? name, String? phone, required String reason}) async =>
      _fail();
  @override
  Future<void> changeVendorStatus(String vendorId, StatusChange change,
          {required String reason}) async =>
      _fail();
  @override
  Future<void> changeStaffStatus(String staffId, StatusChange change,
          {required String reason}) async =>
      _fail();
  @override
  Future<void> revokeRole(
          {required String staffId,
          required String roleGrantId,
          required String reason}) async =>
      _fail();
  @override
  Future<OfficeCategory> createCategory(
          {required String code, required String name}) async =>
      _fail();
  @override
  Future<OfficeUnit> createUnit(
          {required String code,
          required String name,
          required bool allowsDecimal}) async =>
      _fail();
  @override
  Future<List<OfficeVerificationStation>> verificationQueue() async => _fail();
  @override
  Future<List<OfficeSale>> stationSales(String stationId,
          {String? businessDate, String? status}) async =>
      _fail();
  @override
  Future<List<String>> verifySales(List<String> saleIds) async => _fail();
  @override
  Future<List<OfficeDamageReport>> damageReports(
          {required String stationId, String status = 'reported'}) async =>
      _fail();
  @override
  Future<OfficeDamageReport> decideDamage(String reportId,
          {required bool approve, required String reason}) async =>
      _fail();
  @override
  Future<List<OfficeClosingCount>> closingCounts(
          {required String stationId, String status = 'recorded'}) async =>
      _fail();
  @override
  Future<OfficeClosingCount> confirmClosing(String closingId) async => _fail();
  @override
  Future<List<OfficeException>> exceptions(
          {required String stationId, String status = 'open'}) async =>
      _fail();
  @override
  Future<List<OfficeMoneyDay>> moneyDays(
          {required String stationId, required String businessDate}) async =>
      _fail();
  @override
  Future<OfficeHandover> recordHandover(
          {required String vendorId,
          required String businessDate,
          required int amount,
          DateTime? receivedAt,
          String? note,
          String? clientId}) async =>
      _fail();
  @override
  Future<List<OfficeHandover>> handovers(
          {String? stationId,
          String? vendorId,
          String? from,
          String? to,
          String? status}) async =>
      _fail();
  @override
  Future<OfficeHandover> confirmHandover(String handoverId) async => _fail();
  @override
  Future<OfficeHandover> reverseHandover(String handoverId,
          {required String reason}) async =>
      _fail();
  @override
  Future<OfficeExpense> recordExpense(
          {required String stationId,
          required String businessDate,
          required String category,
          String? item,
          required int amount,
          String? note,
          String? clientId}) async =>
      _fail();
  @override
  Future<List<OfficeExpense>> expenses(
          {String? stationId,
          String? from,
          String? to,
          String? status,
          String? paidBy}) async =>
      _fail();
  @override
  Future<OfficeExpense> decideExpense(String expenseId,
          {required bool approve, required String reason}) async =>
      _fail();
  @override
  Future<OfficeExpense> reverseExpense(String expenseId,
          {required String reason}) async =>
      _fail();
  @override
  Future<OfficeMoneySettings> moneySettings() async => _fail();
  @override
  Future<void> saveSetting(String key,
          {required Object value, required String reason}) async =>
      _fail();
}
