/// What the vendor app needs from the Mr. Nyama vendor API
/// (`/api/v1/vendor`, implementation plan §5). [HttpVendorRepository]
/// implements it against the server (`mr_nyama/backend`) when the build has
/// an API URL; without one, [UnavailableVendorRepository] fails closed.
library;

import 'dart:typed_data';

/// What the server says to do after the vendor enters a phone number.
enum SignInStep {
  /// The vendor has a PIN: ask for it.
  pin,

  /// First time on this phone number: ask for the staff-issued code.
  activation,
}

/// The open Outlet Lead link of a seller (the server's `outlet_lead`): the
/// station and the linked office account.
class OutletLeadLink {
  final String stationId;
  final String staffId;
  const OutletLeadLink({required this.stationId, required this.staffId});

  Map<String, Object?> toJson() =>
      {'station_id': stationId, 'staff_id': staffId};

  static OutletLeadLink? fromJson(Object? json) {
    if (json is! Map) return null;
    final station = json['station_id'], staff = json['staff_id'];
    if (station is! String || staff is! String) return null;
    return OutletLeadLink(stationId: station, staffId: staff);
  }
}

class VendorProfile {
  final String id;
  final String name;
  final String phone;

  /// The assigned station's name and key, from the server. Deliveries for
  /// any other station cannot be received on this phone.
  final String station;
  final String stationKey;
  final String? profileImageUrl;

  /// Set when this seller is an Outlet Lead; null otherwise.
  final OutletLeadLink? outletLead;

  const VendorProfile(
      {required this.id,
      required this.name,
      required this.phone,
      required this.station,
      this.stationKey = '',
      this.profileImageUrl,
      this.outletLead});

  bool get isOutletLead => outletLead != null;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'station': station,
        'station_key': stationKey,
        'profile_image_url': profileImageUrl,
        'outlet_lead': outletLead?.toJson()
      };

  VendorProfile copyWith({String? profileImageUrl}) => VendorProfile(
      id: id,
      name: name,
      phone: phone,
      station: station,
      stationKey: stationKey,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      outletLead: outletLead);

  static VendorProfile? fromJson(Map<String, dynamic>? json) => json == null
      ? null
      : VendorProfile(
          id: json['id'] as String,
          name: json['name'] as String,
          phone: json['phone'] as String,
          station: json['station'] as String,
          stationKey: json['station_key'] as String? ?? '',
          profileImageUrl: json['profile_image_url'] as String?,
          outletLead: OutletLeadLink.fromJson(json['outlet_lead']));
}

class VendorSession {
  /// Opaque server session token. Kept only in secure storage.
  final String token;
  final VendorProfile profile;

  /// Set when the PIN unlocked the phone offline under this grant (business
  /// policies §10): not a server session; operations carry the grant.
  final String? offlineGrantId;
  const VendorSession(this.token, this.profile, {this.offlineGrantId});

  bool get offline => offlineGrantId != null;
}

/// The server's answer to `POST /vendor/offline-grant` (MN020). [enabled]
/// is false while the administrator has not set the offline limits.
class OfflineGrantAnswer {
  final bool enabled;
  final String? grantId;
  final DateTime? expiresAt;
  final int? validityHours, relockMinutes, pinAttempts;
  const OfflineGrantAnswer(
      {required this.enabled,
      this.grantId,
      this.expiresAt,
      this.validityHours,
      this.relockMinutes,
      this.pinAttempts});

  static const disabled = OfflineGrantAnswer(enabled: false);

  factory OfflineGrantAnswer.fromJson(Map<String, dynamic> j) {
    int? n(Object? v) => v is int ? v : int.tryParse('$v');
    final expires = DateTime.tryParse('${j['expires_at']}');
    final complete = j['enabled'] == true &&
        j['grant_id'] != null &&
        expires != null &&
        n(j['validity_hours']) != null &&
        n(j['relock_minutes']) != null &&
        n(j['pin_attempts']) != null;
    if (!complete) return disabled;
    return OfflineGrantAnswer(
        enabled: true,
        grantId: '${j['grant_id']}',
        expiresAt: expires,
        validityHours: n(j['validity_hours']),
        relockMinutes: n(j['relock_minutes']),
        pinAttempts: n(j['pin_attempts']));
  }
}

/// Asks for an offline grant for this device, online only.
abstract interface class VendorOfflineRepository {
  Future<OfflineGrantAnswer> offlineGrant(String token);
}

abstract interface class VendorMediaRepository {
  Future<String> uploadDamageImage(String token,
      {required String reportId, required Uint8List bytes});
  Future<String> uploadProfileImage(String token, Uint8List bytes);
}

/// How the customer paid. `credit` (MN018) means a registered credit
/// customer took the goods to pay later: revenue, but not cash the vendor
/// holds.
enum PaymentMethod { cash, mpesa, credit }

/// One recorded sale as the server reports it.
class SaleSummary {
  final String id;
  final DateTime recordedAt;
  final String product;
  final int quantity;
  final PaymentMethod payment;
  final int amount;
  final bool voided;

  /// The credit customer of a credit sale.
  final String? customer;

  const SaleSummary(
      {required this.id,
      required this.recordedAt,
      required this.product,
      required this.quantity,
      required this.payment,
      required this.amount,
      this.voided = false,
      this.customer});
}

/// Today's figures for the dashboard, computed by the server.
class DashboardSummary {
  final DateTime date;
  final int todayTotal;
  final int saleCount;
  final int? cashTotal;
  final int? mpesaTotal;
  final int? creditTotal;

  /// Newest first; the dashboard shows at most three.
  final List<SaleSummary> recent;

  const DashboardSummary(
      {required this.date,
      required this.todayTotal,
      required this.saleCount,
      this.cashTotal,
      this.mpesaTotal,
      this.creditTotal,
      required this.recent});
}

/// A product as the server configures it for this vendor.
class CatalogItem {
  final String id;
  final String name;

  /// Whole shillings, or null when no price is configured: the product is
  /// shown but cannot be sold until the server provides one.
  final int? price;
  final String? priceVersion;
  final String category;

  /// Key of a bundled approved photo (see `productImageFor`), if any.
  final String? imageKey;

  /// Units the server records with this vendor; null when not tracked.
  final int? available;

  /// The own stock (whole-number string) and, for a piece cut at the
  /// station, the product it is cut from and how many one gives.
  final String? held;
  final String? cutFrom;
  final int? cutCount;

  const CatalogItem(
      {required this.id,
      required this.name,
      required this.price,
      this.priceVersion,
      this.category = '',
      this.imageKey,
      this.available,
      this.held,
      this.cutFrom,
      this.cutCount});
}

class CatalogSnapshot {
  final List<CatalogItem> products;
  final List<String>? expenseCategories;

  /// What can be bought under each category (MN017); null from a server
  /// without items.
  final Map<String, List<String>>? expenseItems;

  /// The Mr. Nyama M-Pesa number customers pay, as configured on the
  /// server. Null when not configured: the M-Pesa option is then disabled.
  final String? mpesaRecipient;
  const CatalogSnapshot(
      {required this.products,
      this.mpesaRecipient,
      this.expenseCategories,
      this.expenseItems});
}

/// One product line of a delivery, as Omoterra declared it.
class ManifestLine {
  final String lineId;
  final String productId;
  final String productName;
  final int quantity;
  final String? imageKey;
  const ManifestLine(
      {required this.lineId,
      required this.productId,
      required this.productName,
      required this.quantity,
      this.imageKey});
}

/// A delivery on its way to a station: the consignment declaration that the
/// Mr. Nyama receiving service accepted from Omoterra. Driver, vehicle and
/// route details stay in Omoterra.
class DeliveryManifest {
  final String consignmentId;

  /// Omoterra raises the version when it amends the manifest.
  final int version;
  final String reference;
  final String sender;
  final String stationKey;
  final String stationName;
  final DateTime dispatchedAt;
  final List<ManifestLine> lines;
  const DeliveryManifest(
      {required this.consignmentId,
      required this.version,
      required this.reference,
      required this.sender,
      required this.stationKey,
      required this.stationName,
      required this.dispatchedAt,
      required this.lines});
}

/// One queued operation as sent to `/vendor/sync` (backend
/// `QueuedOperation`). Vendor and station are cross-checked by the server
/// against the session; it never trusts them alone.
class SyncOperation {
  final String opId;
  final String opType;
  final String vendorId;
  final String stationKey;
  final String businessDate;
  final DateTime createdAt;
  final Map<String, dynamic> payload;

  /// Made while the phone was unlocked offline, under this grant (MN020).
  final String? offlineGrantId;
  const SyncOperation(
      {required this.opId,
      required this.opType,
      required this.vendorId,
      required this.stationKey,
      required this.businessDate,
      required this.createdAt,
      required this.payload,
      this.offlineGrantId});
}

enum OperationOutcome { accepted, duplicate, conflict, rejected }

class OperationResult {
  final String opId;
  final OperationOutcome outcome;
  final String? reason;
  const OperationResult(this.opId, this.outcome, [this.reason]);
}

class OfficeCancelledSale {
  final String saleId, voidId;
  final DateTime? requestedAt;
  const OfficeCancelledSale(
      {required this.saleId, required this.voidId, this.requestedAt});
}

/// The server's reply. Operations without a result were not processed and
/// stay queued.
class SyncReply {
  final List<OperationResult> results;
  final List<String> verifiedSales;

  /// Sales staff voided (MN034 cancellation, owner correction), by the id the
  /// phone made for the sale; the phone shows them as cancelled by the office.
  final List<OfficeCancelledSale> cancelledSales;
  final List<String> confirmedClosings;

  /// The server's clock when it answered, for spotting a wrong phone clock.
  final DateTime? serverTime;
  const SyncReply(
      {required this.results,
      this.verifiedSales = const [],
      this.cancelledSales = const [],
      this.confirmedClosings = const [],
      this.serverTime});
}

enum AuthFailureKind {
  /// The Mr. Nyama vendor API is not available to this build.
  notConfigured,

  /// The phone could not reach the server.
  offline,

  /// The phone number is not a registered vendor.
  unknownPhone,
  wrongPin,

  /// Too many wrong PINs; wait until [AuthFailure.retryAfter].
  locked,
  invalidCode,

  /// The new PIN is too easy to guess (the server's rule).
  weakPin,
  suspended,

  /// The server no longer accepts this session.
  sessionExpired,
}

class AuthFailure implements Exception {
  final AuthFailureKind kind;

  /// Attempts left before the pause, when the server says.
  final int? attemptsLeft;
  final DateTime? retryAfter;

  /// With [AuthFailureKind.offline]: the phone reached the network but the
  /// service did not answer properly. Treated as offline, only worded apart.
  final bool serviceProblem;
  const AuthFailure(this.kind,
      {this.attemptsLeft, this.retryAfter, this.serviceProblem = false});

  @override
  String toString() => 'AuthFailure($kind)';
}

abstract class VendorRepository {
  /// [phone] in E.164 form (+255…). [SignInStep.pin] for an activated
  /// vendor; otherwise [SignInStep.activation]. Unknown numbers get the same
  /// answer as new ones, and the server rate-limits the lookup.
  Future<SignInStep> startSignIn(String phone);

  Future<VendorSession> signIn({required String phone, required String pin});

  /// Checks a staff-issued code (first activation, or a PIN reset when
  /// [reset] is true). Returns a short-lived setup token for [setPin].
  Future<String> verifyCode(
      {required String phone, required String code, bool reset = false});

  Future<VendorSession> setPin(
      {required String setupToken, required String pin});

  Future<void> changePin(
      {required String token,
      required String currentPin,
      required String newPin});

  Future<DashboardSummary> dashboard(String token);

  /// Products, prices and holdings for this vendor's station.
  Future<CatalogSnapshot> catalog(String token);

  /// Deliveries addressed to this vendor's station that may need receiving.
  Future<List<DeliveryManifest>> deliveries(String token);

  /// Sends queued operations; each is decided idempotently by its op ID.
  Future<SyncReply> sync(String token,
      {required DateTime phoneTime, required List<SyncOperation> operations});

  Future<void> signOut(String token);
}

/// Production until the vendor API exists: every call fails with
/// [AuthFailureKind.notConfigured]. Nothing can appear to succeed.
class UnavailableVendorRepository implements VendorRepository {
  const UnavailableVendorRepository();

  Never _fail() => throw const AuthFailure(AuthFailureKind.notConfigured);

  @override
  Future<SignInStep> startSignIn(String phone) async => _fail();

  @override
  Future<VendorSession> signIn(
          {required String phone, required String pin}) async =>
      _fail();

  @override
  Future<String> verifyCode(
          {required String phone,
          required String code,
          bool reset = false}) async =>
      _fail();

  @override
  Future<VendorSession> setPin(
          {required String setupToken, required String pin}) async =>
      _fail();

  @override
  Future<void> changePin(
          {required String token,
          required String currentPin,
          required String newPin}) async =>
      _fail();

  @override
  Future<DashboardSummary> dashboard(String token) async => _fail();

  @override
  Future<CatalogSnapshot> catalog(String token) async => _fail();

  @override
  Future<List<DeliveryManifest>> deliveries(String token) async => _fail();

  @override
  Future<SyncReply> sync(String token,
          {required DateTime phoneTime,
          required List<SyncOperation> operations}) async =>
      _fail();

  @override
  Future<void> signOut(String token) async {}
}

/// Optional money readback capability, without changing authentication.
abstract interface class VendorExpenseRepository {
  Future<List<Map<String, dynamic>>> expenseClaims(String token);
}

/// One handover recorded in the vendor's name (`GET /vendor/handovers`).
/// Read-only: the vendor can see it, never change it. [status] is
/// `recorded`, `confirmed` or `reversed`.
class VendorHandover {
  final String id, receiver, status;
  final int amount;
  final DateTime? receivedAt, businessDate;
  final String? note;
  const VendorHandover(
      {required this.id,
      required this.amount,
      this.receivedAt,
      this.businessDate,
      this.receiver = '',
      this.status = 'recorded',
      this.note});

  factory VendorHandover.fromJson(Map<String, dynamic> j) {
    final note = j['note'];
    return VendorHandover(
        id: '${j['id'] ?? ''}',
        amount: switch (j['amount']) {
          int() => j['amount'] as int,
          num() => (j['amount'] as num).round(),
          _ => 0,
        },
        receivedAt: j['received_at'] is String
            ? DateTime.tryParse(j['received_at'] as String)?.toLocal()
            : null,
        businessDate: j['business_date'] is String
            ? DateTime.tryParse(j['business_date'] as String)
            : null,
        receiver: '${j['receiver'] ?? ''}',
        status: '${j['status'] ?? 'recorded'}',
        note: note is String && note.trim().isNotEmpty ? note.trim() : null);
  }
}

/// The vendor's own handovers of the last 31 days, newest first.
abstract interface class VendorHandoverRepository {
  Future<List<VendorHandover>> handovers(String token);
}

/// The vendor's confirmed cash balance and figures still awaiting decisions.
class VendorMoneySummary {
  final int owed;
  final int credit;
  final int unverifiedCashSales;
  final int unconfirmedHandovers;
  final int pendingVendorExpenses;
  final int unresolvedDays;

  const VendorMoneySummary({
    this.owed = 0,
    this.credit = 0,
    this.unverifiedCashSales = 0,
    this.unconfirmedHandovers = 0,
    this.pendingVendorExpenses = 0,
    this.unresolvedDays = 0,
  });

  factory VendorMoneySummary.fromJson(Map<String, dynamic> json) =>
      VendorMoneySummary(
        owed: _moneyInt(json['owed']),
        credit: _moneyInt(json['credit']),
        unverifiedCashSales: _moneyInt(json['unverified_cash_sales']),
        unconfirmedHandovers: _moneyInt(json['unconfirmed_handovers']),
        pendingVendorExpenses: _moneyInt(json['pending_vendor_expenses']),
        unresolvedDays: _moneyInt(json['unresolved_days']),
      );
}

int _moneyInt(Object? value) {
  if (value is! int || value < 0) {
    throw const FormatException('Invalid vendor money summary amount.');
  }
  return value;
}

abstract interface class VendorMoneyRepository {
  Future<VendorMoneySummary> moneyBalance(String token);
}

/// The vendor's own progress today (`GET /vendor/progress`, design §10a):
/// chickens against the target, the next bonus step, today's bonus
/// (estimated until the day is closed, then earned), the pay-period total and
/// their stars. Never profit, other vendors or rules beyond the next step.
class VendorProgress {
  final String chickens, verifiedChickens;
  final int? target;
  final ({int chickens, int amount})? nextStep;
  final int bonusToday;
  final bool bonusEarned;
  final String? payPeriod;
  final ({int earned, int estimated, int adjustments})? periodTotal;
  final int? score, stars;
  const VendorProgress(
      {this.chickens = '0',
      this.verifiedChickens = '0',
      this.target,
      this.nextStep,
      this.bonusToday = 0,
      this.bonusEarned = false,
      this.payPeriod,
      this.periodTotal,
      this.score,
      this.stars});

  static const none = VendorProgress();

  /// Whether anything is configured worth showing: a target, a bonus or stars.
  bool get worthShowing =>
      target != null ||
      nextStep != null ||
      bonusToday > 0 ||
      (periodTotal != null &&
          (periodTotal!.earned +
                  periodTotal!.estimated +
                  periodTotal!.adjustments) !=
              0) ||
      stars != null;

  static int _int(Object? v) => switch (v) {
        int() => v,
        num() => v.round(),
        String() => num.tryParse(v)?.round() ?? 0,
        _ => 0,
      };

  static int? _intOrNull(Object? v) => v == null ? null : _int(v);

  static String _number(Object? v) {
    final text = v == null ? '0' : '$v';
    return num.tryParse(text) == null ? '0' : text;
  }

  factory VendorProgress.fromJson(Map<String, dynamic> j) {
    final step = j['next_step'];
    final bonus = j['bonus_today'];
    final total = j['period_total'];
    final stars = _intOrNull(j['stars']);
    return VendorProgress(
        chickens: _number(j['chicken_equivalents']),
        verifiedChickens: _number(j['verified_equivalents']),
        target: _intOrNull(j['target']),
        nextStep: step is Map
            ? (chickens: _int(step['chickens']), amount: _int(step['amount']))
            : null,
        bonusToday: bonus is Map ? _int(bonus['amount']) : 0,
        bonusEarned: bonus is Map && bonus['state'] == 'earned',
        payPeriod: switch (j['pay_period']) {
          'weekly' => 'weekly',
          'monthly' => 'monthly',
          _ => null,
        },
        periodTotal: total is Map
            ? (
                earned: _int(total['earned']),
                estimated: _int(total['estimated']),
                adjustments: _int(total['adjustments'])
              )
            : null,
        score: _intOrNull(j['score']),
        stars: stars != null && stars >= 1 && stars <= 5 ? stars : null);
  }
}

/// Optional progress readback (Phase 10); a server without it hides the card.
abstract interface class VendorProgressRepository {
  Future<VendorProgress> progress(String token);
}

/// A credit customer of the vendor's station, as the server sees them.
class CreditCustomerData {
  final String id, name, status;
  final String? phone;

  /// Whole shillings; null until the owner sets it (then no credit).
  final int? creditLimit;

  /// What the server has recorded as owed (credit sales − repayments −
  /// write-offs).
  final int owed;
  const CreditCustomerData(
      {required this.id,
      required this.name,
      this.status = 'active',
      this.phone,
      this.creditLimit,
      this.owed = 0});

  bool get creditAllowed => status == 'active' && creditLimit != null;

  factory CreditCustomerData.fromJson(Map<String, dynamic> j) =>
      CreditCustomerData(
          id: '${j['id']}',
          name: '${j['name']}',
          status: '${j['status'] ?? 'active'}',
          phone: j['phone'] as String?,
          creditLimit: j['credit_limit'] as int?,
          owed: (j['owed'] as int?) ?? 0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status,
        'phone': phone,
        'credit_limit': creditLimit,
        'owed': owed,
      };
}

/// The station's credit customers (MN018), for the phone's cache.
abstract interface class VendorCreditRepository {
  Future<List<CreditCustomerData>> creditCustomers(String token);
}
