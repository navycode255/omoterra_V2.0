import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../auth/device_sign_in.dart';
import '../auth/lead_session.dart';
import 'office_repository.dart' show StaffProfile;
import '../auth/secure_store.dart';
import 'api_client.dart';
import 'notifications.dart';
import 'push.dart';
import 'supply_requests.dart';
import 'vendor_history.dart';
import 'vendor_repository.dart';

/// [VendorRepository] over HTTP against the Mr. Nyama API
/// (`mr_nyama/backend`, base path `/api/v1/vendor`).
///
/// Credentials and refresh are handled by [ApiClient] (tokens in the
/// Android Keystore-backed store). The `token` the app passes around is an
/// opaque marker; a refused refresh surfaces as
/// [AuthFailureKind.sessionExpired] and the app asks for the PIN again.
class HttpVendorRepository
    implements
        VendorRepository,
        VendorExpenseRepository,
        VendorHandoverRepository,
        VendorMoneyRepository,
        VendorCreditRepository,
        VendorProgressRepository,
        VendorOfflineRepository,
        VendorHistoryRepository,
        VendorMediaRepository,
        VendorDeviceKeyRepository,
        VendorLeadRepository,
        VendorNotificationsRepository,
        VendorSupplyRepository,
        VendorPushRepository {
  /// What [VendorSession.token] holds: the real tokens stay in the store.
  static const sessionMarker = 'http-session';

  final ApiClient _c;
  late final SupplyApi _supply = SupplyApi(_c, '/vendor');

  HttpVendorRepository(
      {required String baseUrl, required KeyValueStore store, Dio? dio})
      : _c = ApiClient(
            baseUrl: baseUrl,
            store: store,
            audience: '/vendor',
            keyPrefix: 'api',
            dio: dio);

  Future<String> _deviceId() => _c.deviceId();
  Future<void> _saveTokens(Map<String, dynamic> body) => _c.saveTokens(body);
  Future<void> _clearTokens() => _c.clearTokens();
  Future<Response<dynamic>> _send(String method, String path, {Object? body}) =>
      _c.send(method, '/vendor$path', body: body);
  Future<Response<dynamic>> _authed(String method, String path,
          {Object? body, String? contentType}) =>
      _c.authed(method, '/vendor$path', body: body, contentType: contentType);
  Map<String, dynamic> _json(Response<dynamic> r) => _c.json(r);
  Never _fail(Response<dynamic> r) => _c.fail(r);

  static VendorProfile _profile(Map<String, dynamic> json) {
    final station = json['station'] as Map<String, dynamic>?;
    return VendorProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        station: station?['name'] as String? ?? '',
        stationKey: station?['code'] as String? ?? '',
        profileImageUrl: json['profile_image_url'] as String?,
        outletLead: OutletLeadLink.fromJson(json['outlet_lead']));
  }

  // -- authentication --

  /// `POST /vendor/auth/lead-session`: the office session of an Outlet Lead,
  /// asked with the seller session. The tokens are for the office client.
  @override
  Future<LeadSession> leadSession(String token) async {
    final body = _json(await _authed('POST', '/auth/lead-session',
        body: {'device_id': await _deviceId()}));
    return LeadSession(
        tokens: body,
        profile: StaffProfile.fromJson(body['profile'] as Map<String, dynamic>));
  }

  /// Activated vendors go to the PIN; anyone else (new, or a number the
  /// server does not know) to the staff-issued code.
  @override
  Future<SignInStep> startSignIn(String phone) async {
    final body =
        _json(await _send('POST', '/auth/start', body: {'phone': phone}));
    return body['next'] == 'pin' ? SignInStep.pin : SignInStep.activation;
  }

  @override
  Future<VendorSession> signIn(
      {required String phone, required String pin}) async {
    final body = _json(await _send('POST', '/auth/sign-in', body: {
      'phone': phone,
      'pin': pin,
      'device_id': await _deviceId(),
    }));
    await _saveTokens(body);
    return VendorSession(
        sessionMarker, _profile(body['profile'] as Map<String, dynamic>));
  }

  @override
  Future<String> verifyCode(
      {required String phone, required String code, bool reset = false}) async {
    final body = _json(await _send('POST', '/auth/verify-code', body: {
      'phone': phone,
      'code': code,
      'purpose': reset ? 'pin_reset' : 'activation',
    }));
    return body['exchange_token'] as String;
  }

  @override
  Future<VendorSession> setPin(
      {required String setupToken, required String pin}) async {
    final body = _json(await _send('POST', '/auth/set-pin', body: {
      'exchange_token': setupToken,
      'pin': pin,
      'pin_confirmation': pin,
      'device_id': await _deviceId(),
    }));
    await _saveTokens(body);
    final me = _json(await _authed('GET', '/me'));
    return VendorSession(sessionMarker, _profile(me));
  }

  @override
  Future<void> changePin(
      {required String token,
      required String currentPin,
      required String newPin}) async {
    final r = await _authed('POST', '/auth/change-pin', body: {
      'current_pin': currentPin,
      'new_pin': newPin,
      'new_pin_confirmation': newPin,
    });
    if (r.statusCode != 204) _fail(r);
  }

  @override
  Future<void> signOut(String token) async {
    try {
      await _authed('POST', '/auth/sign-out');
    } on AuthFailure {
      // Signing out on the phone always succeeds.
    } finally {
      await _clearTokens();
    }
  }

  // -- data --

  @override
  Future<DashboardSummary> dashboard(String token) async {
    final body = _json(await _authed('GET', '/dashboard'));
    return DashboardSummary(
      date: DateTime.parse(body['date'] as String),
      todayTotal: body['today_total'] as int,
      saleCount: body['sale_count'] as int,
      cashTotal: body['cash_total'] as int?,
      mpesaTotal: body['mpesa_total'] as int?,
      creditTotal: body['credit_total'] as int?,
      recent: [
        for (final s in body['recent'] as List)
          SaleSummary(
              id: s['id'] as String,
              recordedAt: DateTime.parse(s['recorded_at'] as String).toLocal(),
              product: s['product'] as String,
              quantity: s['quantity'] as int,
              payment: switch (s['payment']) {
                'mpesa' => PaymentMethod.mpesa,
                'credit' => PaymentMethod.credit,
                _ => PaymentMethod.cash,
              },
              customer: s['customer'] as String?,
              amount: s['amount'] as int,
              voided: s['voided'] as bool? ?? false),
      ],
    );
  }

  @override
  Future<CatalogSnapshot> catalog(String token) async {
    final body = _json(await _authed('GET', '/catalogue'));
    return CatalogSnapshot(
      mpesaRecipient: body['mpesa_recipient'] as String?,
      expenseCategories: (body['expense_categories'] as List?)?.cast<String>(),
      expenseItems: switch (body['expense_items']) {
        final Map items => {
            for (final MapEntry(:key, :value) in items.entries)
              if (value is List) '$key': [for (final i in value) '$i']
          },
        _ => null,
      },
      products: [
        for (final p in body['products'] as List)
          CatalogItem(
              id: p['id'] as String,
              name: p['name'] as String,
              price: p['price'] as int?,
              priceVersion: p['price_version'] as String?,
              category: p['category'] as String? ?? '',
              imageKey: p['image_key'] as String?,
              available: p['available'] as int?,
              held: p['held'] as String?,
              cutFrom: (p['cut_from'] as Map?)?['product'] as String?,
              cutCount: (p['cut_from'] as Map?)?['count'] as int?),
      ],
    );
  }

  @override
  Future<List<CreditCustomerData>> creditCustomers(String token) async {
    final response = await _authed('GET', '/credit-customers');
    if (response.statusCode != 200 || response.data is! List) _fail(response);
    return [
      for (final row in response.data as List)
        CreditCustomerData.fromJson(Map<String, dynamic>.from(row as Map))
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> expenseClaims(String token) async {
    final response = await _authed('GET', '/expenses');
    if (response.statusCode != 200 || response.data is! List) _fail(response);
    return [
      for (final row in response.data as List)
        Map<String, dynamic>.from(row as Map)
    ];
  }

  @override
  Future<List<VendorHandover>> handovers(String token) async {
    final response = await _authed('GET', '/handovers');
    if (response.statusCode != 200 || response.data is! List) _fail(response);
    return [
      for (final row in response.data as List)
        if (row is Map) VendorHandover.fromJson(Map<String, dynamic>.from(row))
    ];
  }

  @override
  Future<VendorMoneySummary> moneyBalance(String token) async {
    final response = await _authed('GET', '/money/balance');
    if (response.statusCode != 200 || response.data is! Map) _fail(response);
    return VendorMoneySummary.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  // Fingerprint sign-in after sign-out (MN024) ----------------------------

  @override
  Future<String> issueDeviceKey() async =>
      _json(await _authed('POST', '/auth/device-key',
          body: {'device_id': await _deviceId()}))['key'] as String;

  @override
  Future<void> forgetDeviceKey() async {
    final r = await _authed('POST', '/auth/device-key/forget',
        body: {'device_id': await _deviceId()});
    if (r.statusCode != 204 && r.statusCode != 200) _fail(r);
  }

  @override
  Future<VendorSession> deviceSignIn(String key) async {
    final body = _json(await _send('POST', '/auth/device-sign-in',
        body: {'device_id': await _deviceId(), 'key': key}));
    await _saveTokens(body);
    return VendorSession(
        sessionMarker, _profile(body['profile'] as Map<String, dynamic>));
  }

  @override
  Future<OfflineGrantAnswer> offlineGrant(String token) async {
    final r = await _authed('POST', '/offline-grant',
        body: {'device_id': await _deviceId()});
    // An older server without the route: no grant, as before.
    if (r.statusCode == 404) return OfflineGrantAnswer.disabled;
    if (r.statusCode != 200 || r.data is! Map) _fail(r);
    return OfflineGrantAnswer.fromJson(
        Map<String, dynamic>.from(r.data as Map));
  }

  @override
  Future<VendorHistory> history(String token,
      {String? from, String? to}) async {
    final query = [
      if (from != null) 'from=$from',
      if (to != null) 'to=$to',
    ].join('&');
    final r =
        await _authed('GET', query.isEmpty ? '/history' : '/history?$query');
    if (r.statusCode != 200 || r.data is! Map) _fail(r);
    return VendorHistory.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  @override
  Future<NotificationPage> notifications(String token,
      {required String lang, String? before}) async {
    final r = await _authed(
        'GET',
        Uri(path: '/notifications', queryParameters: {
          'lang': lang,
          if (before != null) 'before': before,
        }).toString());
    // An older server without the route: nothing to show, as for offline grants.
    if (r.statusCode == 404) return NotificationPage.empty;
    if (r.statusCode != 200 || r.data is! Map) _fail(r);
    return NotificationPage.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  @override
  Future<int> markNotificationsRead(String token, List<String>? ids) async =>
      ((_json(await _authed('POST', '/notifications/read',
              body: {if (ids != null) 'ids': ids}))['marked']) as num?)
          ?.toInt() ??
      0;

  @override
  Future<void> registerPushToken(String token, {required String lang}) async {
    final r = await _authed('POST', '/push-token',
        body: {'token': token, 'lang': lang});
    if (r.statusCode != 204) _fail(r);
  }

  @override
  Future<VendorProgress> progress(String token) async {
    final r = await _authed('GET', '/progress');
    if (r.statusCode != 200 || r.data is! Map) _fail(r);
    return VendorProgress.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  @override
  Future<List<DeliveryManifest>> deliveries(String token) async {
    final r = await _authed('GET', '/deliveries');
    if ((r.statusCode ?? 0) != 200 || r.data is! List) _fail(r);
    return [
      for (final d in r.data as List)
        DeliveryManifest(
          consignmentId: d['consignment_id'] as String,
          version: d['version'] as int,
          reference: d['reference'] as String,
          sender: d['sender'] as String,
          stationKey: d['station_key'] as String,
          stationName: d['station_name'] as String,
          dispatchedAt: DateTime.parse(d['dispatched_at'] as String).toLocal(),
          lines: [
            for (final l in d['lines'] as List)
              ManifestLine(
                  lineId: l['line_id'] as String,
                  productId: l['product_id'] as String,
                  productName: l['product_name'] as String,
                  quantity: l['quantity'] as int,
                  imageKey: l['image_key'] as String?),
          ],
        ),
    ];
  }

  static const _outcomes = {
    'accepted': OperationOutcome.accepted,
    'duplicate': OperationOutcome.duplicate,
    'conflict': OperationOutcome.conflict,
    'rejected': OperationOutcome.rejected,
  };

  @override
  Future<SyncReply> sync(String token,
      {required DateTime phoneTime,
      required List<SyncOperation> operations}) async {
    final body = _json(await _authed('POST', '/sync', body: {
      'phone_time': phoneTime.toUtc().toIso8601String(),
      'operations': [
        for (final o in operations)
          {
            'op_id': o.opId,
            'op_type': o.opType,
            'vendor_id': o.vendorId,
            'station_key': o.stationKey,
            'business_date': o.businessDate,
            'created_at': o.createdAt.toUtc().toIso8601String(),
            'payload': o.payload,
            if (o.offlineGrantId != null) ...{
              'made_offline': true,
              'offline_grant_id': o.offlineGrantId,
            },
          }
      ],
    }));
    return SyncReply(
      results: [
        for (final r in body['results'] as List)
          if (_outcomes[r['status']] != null)
            OperationResult(r['op_id'] as String, _outcomes[r['status']]!,
                r['reason'] as String?),
      ],
      verifiedSales: [
        for (final id in body['verified_sales'] as List? ?? const []) '$id'
      ],
      cancelledSales: [
        for (final c in body['cancelled_sales'] as List? ?? const [])
          if (c is Map)
            OfficeCancelledSale(
                saleId: '${c['sale_id']}',
                voidId: '${c['void_id']}',
                requestedAt: DateTime.tryParse('${c['requested_at']}'))
      ],
      confirmedClosings: [
        for (final id in body['confirmed_closings'] as List? ?? const []) '$id'
      ],
      serverTime: DateTime.tryParse(body['server_time'] as String? ?? ''),
    );
  }

  @override
  Future<String> uploadDamageImage(String token,
      {required String reportId, required Uint8List bytes}) async {
    final r = await _authed(
        'POST', '/damage-reports/${Uri.encodeComponent(reportId)}/image',
        body: bytes, contentType: 'image/jpeg');
    return _json(r)['image_key'] as String;
  }

  @override
  Future<String> uploadProfileImage(String token, Uint8List bytes) async {
    final r = await _authed('POST', '/me/profile-image',
        body: bytes, contentType: 'image/jpeg');
    return _json(r)['profile_image_url'] as String;
  }

  // -- supply requests, "Maombi ya mzigo" (MN038). Online only. --

  @override
  Future<SupplyRequest> createSupplyRequest(String token, SupplyDraft draft) =>
      _supply.create(draft);

  @override
  Future<List<SupplyRequest>> supplyRequests(String token) => _supply.mine();

  @override
  Future<SupplyRequest> supplyRequestById(String token, String id) =>
      _supply.one(id);

  @override
  Future<SupplyRequest> withdrawSupplyRequest(String token, String id,
          {required String clientId}) =>
      _supply.withdraw(id, clientId);

  @override
  Future<SupplyRequest> settleSupply(String token, String id,
          {required String clientId,
          required int spent,
          required int changeReturned,
          required String supplier}) =>
      _supply.settle(id,
          clientId: clientId,
          spent: spent,
          changeReturned: changeReturned,
          supplier: supplier);

  @override
  Future<List<OutstandingAdvance>> supplyOutstanding(String token) =>
      _supply.outstanding();
}
