import 'dart:async';
import 'dart:convert';

import 'package:mr_nyama_vendor/core/api/notifications.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/auth/device_sign_in.dart';
import 'package:mr_nyama_vendor/core/auth/secure_store.dart';

const testProfile = VendorProfile(
    id: 'v1',
    name: 'Asha Mussa',
    phone: '+255712345678',
    station: 'Kariakoo',
    stationKey: 'S1');

class InMemoryStore implements KeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  /// A stored session, last used at [lastActive].
  void signIn({DateTime? lastActive}) {
    values['session_token'] = 'token-1';
    values['session_profile'] = jsonEncode(testProfile.toJson());
    values['last_phone'] = testProfile.phone;
    values['last_active'] = (lastActive ?? DateTime.now()).toIso8601String();
  }
}

/// Scriptable repository for tests. Each call can be made to fail, and
/// [gate] can hold calls open to observe loading states.
class FakeVendorRepository
    implements
        VendorRepository,
        VendorCreditRepository,
        VendorProgressRepository,
        VendorMoneyRepository,
        VendorOfflineRepository,
        VendorDeviceKeyRepository,
        VendorNotificationsRepository {
  AuthFailure? changePinFailure;

  /// The vendor's notifications (MN025), newest first.
  final notificationList = <AppNotification>[];
  final notificationLangs = <String>[];
  AuthFailure? notificationsFailure;

  @override
  Future<NotificationPage> notifications(String token,
      {required String lang, String? before}) async {
    notificationLangs.add(lang);
    if (notificationsFailure case final failure?) throw failure;
    return NotificationPage(
        items: List.of(notificationList),
        unread: notificationList.where((n) => !n.read).length);
  }

  @override
  Future<int> markNotificationsRead(String token, List<String>? ids) async {
    var marked = 0;
    for (var i = 0; i < notificationList.length; i++) {
      final n = notificationList[i];
      if (!n.read && (ids == null || ids.contains(n.id))) {
        notificationList[i] = n.markedRead();
        marked++;
      }
    }
    return marked;
  }

  /// Fingerprint sign-in keys the server issued and still accepts (MN024).
  final liveDeviceKeys = <String>{};
  int deviceKeysIssued = 0;

  @override
  Future<String> issueDeviceKey() async {
    final key = 'device-key-${++deviceKeysIssued}';
    liveDeviceKeys
      ..clear()
      ..add(key);
    return key;
  }

  @override
  Future<void> forgetDeviceKey() async => liveDeviceKeys.clear();

  @override
  Future<VendorSession> deviceSignIn(String key) async {
    calls.add('deviceSignIn');
    if (!liveDeviceKeys.contains(key)) {
      throw const AuthFailure(AuthFailureKind.sessionExpired);
    }
    return const VendorSession('token-3', testProfile);
  }

  /// The station's credit customers the server returns (MN018).
  List<CreditCustomerData> creditCustomerList = [];

  /// The offline grant the server issues (Phase 11); default: not enabled.
  OfflineGrantAnswer offlineGrantValue = OfflineGrantAnswer.disabled;
  int offlineGrantCalls = 0;

  @override
  Future<OfflineGrantAnswer> offlineGrant(String token) async {
    offlineGrantCalls++;
    return offlineGrantValue;
  }

  /// The vendor's progress (Phase 10); default: nothing configured.
  VendorProgress progressValue = VendorProgress.none;
  AuthFailure? progressFailure;
  int progressCalls = 0;

  @override
  Future<VendorProgress> progress(String token) async {
    progressCalls++;
    if (progressFailure case final failure?) throw failure;
    return progressValue;
  }

  VendorMoneySummary moneySummaryValue = const VendorMoneySummary();
  AuthFailure? moneySummaryFailure;
  int moneySummaryCalls = 0;

  @override
  Future<VendorMoneySummary> moneyBalance(String token) async {
    moneySummaryCalls++;
    if (moneySummaryFailure case final failure?) throw failure;
    return moneySummaryValue;
  }

  @override
  Future<List<CreditCustomerData>> creditCustomers(String token) async {
    if (creditFailure case final failure?) throw failure;
    return creditCustomerList;
  }

  /// Fails the credit-customer list (e.g. offline).
  AuthFailure? creditFailure;

  SignInStep step = SignInStep.pin;
  String pin = '2580';
  String code = '123456';
  AuthFailure? startFailure;
  AuthFailure? dashboardFailure;
  AuthFailure? signInFailure;
  DashboardSummary dashboardSummary = DashboardSummary(
      date: DateTime(2026, 10, 7), todayTotal: 0, saleCount: 0, recent: []);
  Completer<void>? gate;
  AuthFailure? catalogFailure;
  CatalogSnapshot catalogSnapshot = const CatalogSnapshot(products: []);
  AuthFailure? deliveriesFailure;
  List<DeliveryManifest> deliveryList = const [];

  /// Decides each synced operation; default: accept everything. Return null
  /// to leave an operation without a result (partial sync).
  OperationResult? Function(SyncOperation op)? syncDecision;

  /// Like production today: no sync service. Sync tests set this to null
  /// (and optionally [syncDecision]) to get server answers.
  AuthFailure? syncFailure = const AuthFailure(AuthFailureKind.notConfigured);
  List<String> verifiedSales = [];
  List<String> confirmedClosings = [];
  final syncedBatches = <List<SyncOperation>>[];
  Completer<void>? syncGate;
  final calls = <String>[];

  Future<void> _hold() async {
    if (gate != null) await gate!.future;
  }

  @override
  Future<SignInStep> startSignIn(String phone) async {
    calls.add('start $phone');
    await _hold();
    if (startFailure != null) throw startFailure!;
    return step;
  }

  @override
  Future<VendorSession> signIn(
      {required String phone, required String pin}) async {
    calls.add('signIn $phone');
    await _hold();
    if (signInFailure != null) throw signInFailure!;
    if (pin != this.pin) {
      throw const AuthFailure(AuthFailureKind.wrongPin, attemptsLeft: 2);
    }
    return const VendorSession('token-2', testProfile);
  }

  @override
  Future<String> verifyCode(
      {required String phone, required String code, bool reset = false}) async {
    calls.add('verify reset=$reset');
    await _hold();
    if (code != this.code) {
      throw const AuthFailure(AuthFailureKind.invalidCode);
    }
    return 'setup-1';
  }

  @override
  Future<VendorSession> setPin(
      {required String setupToken, required String pin}) async {
    calls.add('setPin $setupToken');
    this.pin = pin;
    return const VendorSession('token-3', testProfile);
  }

  @override
  Future<void> changePin(
      {required String token,
      required String currentPin,
      required String newPin}) async {
    calls.add('changePin');
    if (changePinFailure != null) throw changePinFailure!;
    if (currentPin != pin) throw const AuthFailure(AuthFailureKind.wrongPin);
    pin = newPin;
  }

  @override
  Future<DashboardSummary> dashboard(String token) async {
    calls.add('dashboard $token');
    await _hold();
    if (dashboardFailure != null) throw dashboardFailure!;
    return dashboardSummary;
  }

  @override
  Future<CatalogSnapshot> catalog(String token) async {
    calls.add('catalog');
    if (catalogFailure != null) throw catalogFailure!;
    return catalogSnapshot;
  }

  @override
  Future<List<DeliveryManifest>> deliveries(String token) async {
    calls.add('deliveries');
    if (deliveriesFailure != null) throw deliveriesFailure!;
    return deliveryList;
  }

  @override
  Future<SyncReply> sync(String token,
      {required DateTime phoneTime,
      required List<SyncOperation> operations}) async {
    calls.add('sync ${operations.length}');
    if (syncGate != null) await syncGate!.future;
    if (syncFailure != null) throw syncFailure!;
    syncedBatches.add(operations);
    return SyncReply(
      results: [
        for (final op in operations)
          if ((syncDecision ??
                  (op) =>
                      OperationResult(op.opId, OperationOutcome.accepted))(op)
              case final r?)
            r
      ],
      verifiedSales: verifiedSales,
      confirmedClosings: confirmedClosings,
    );
  }

  @override
  Future<void> signOut(String token) async => calls.add('signOut');
}
