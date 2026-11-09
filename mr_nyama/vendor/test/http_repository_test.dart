import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/http_vendor_repository.dart';
import 'package:mr_nyama_vendor/core/api/providers.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';

import 'fakes.dart';

typedef Handler = (int, Object?) Function(RequestOptions request);

/// Answers requests from [routes] ("METHOD /path") and records them.
class FakeServer implements HttpClientAdapter {
  final Map<String, Handler> routes;
  final requests = <RequestOptions>[];
  bool down = false;
  FakeServer(this.routes);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (down) {
      throw DioException.connectionError(
          requestOptions: options, reason: 'no route to host');
    }
    final path = options.uri.path.replaceFirst('/api/v1/vendor', '');
    final handler = routes['${options.method} $path'];
    if (handler == null) {
      return ResponseBody.fromString('{"error":"not_found"}', 404);
    }
    final (status, body) = handler(options);
    return ResponseBody.fromString(body == null ? '' : jsonEncode(body), status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}

  Map<String, dynamic> bodyOf(String pathEnd) =>
      requests.lastWhere((r) => r.uri.path.endsWith(pathEnd)).data
          as Map<String, dynamic>;

  int count(String pathEnd) =>
      requests.where((r) => r.uri.path.endsWith(pathEnd)).length;
}

const profile = {
  'id': 'v-1',
  'vendor_code': 'V-0001',
  'name': 'Asha',
  'phone': '+255712345678',
  'station': {'id': 's-1', 'code': 'KA01', 'name': 'Kariakoo'},
};

Map<String, dynamic> tokens(String n) => {
      'access_token': 'access-$n',
      'refresh_token': 'refresh-$n',
      'expires_in': 900
    };

(HttpVendorRepository, FakeServer, InMemoryStore) build(
    Map<String, Handler> routes) {
  final server = FakeServer(routes);
  final store = InMemoryStore();
  final dio = Dio()..httpClientAdapter = server;
  return (
    HttpVendorRepository(baseUrl: 'https://api.test', store: store, dio: dio),
    server,
    store
  );
}

void main() {
  test(
      'sign-in sends the phone, PIN and a stable device id and keeps the tokens',
      () async {
    final (repo, server, store) = build({
      'POST /auth/sign-in': (_) => (200, {...tokens('1'), 'profile': profile}),
    });
    final session = await repo.signIn(phone: '+255712345678', pin: '2580');
    expect(session.profile.stationKey, 'KA01');
    expect(session.profile.station, 'Kariakoo');
    expect(session.token, HttpVendorRepository.sessionMarker);
    final body = server.bodyOf('/auth/sign-in');
    expect(body['phone'], '+255712345678');
    expect(body['pin'], '2580');
    expect(store.values.containsValue('access-1'), isTrue);
    await repo.signIn(phone: '+255712345678', pin: '2580');
    expect(server.bodyOf('/auth/sign-in')['device_id'], body['device_id']);
    // The PIN is never written to the store.
    expect(store.values.values.any((v) => v.contains('2580')), isFalse);
  });

  test('activated vendors go to the PIN and new ones to the code', () async {
    final (repo, server, _) = build({
      'POST /auth/start': (r) => (
            200,
            {
              'next':
                  (r.data as Map)['phone'] == '+255712345678' ? 'pin' : 'code'
            }
          ),
    });
    expect(await repo.startSignIn('+255712345678'), SignInStep.pin);
    expect(await repo.startSignIn('+255700000001'), SignInStep.activation);
    expect(server.count('/auth/start'), 2);
  });

  test('refusals map to the failures the screens explain', () async {
    Future<AuthFailureKind> kind(int status, Map<String, dynamic> body) async {
      final (repo, _, _) = build({'POST /auth/sign-in': (_) => (status, body)});
      try {
        await repo.signIn(phone: '+255712345678', pin: '1111');
      } on AuthFailure catch (f) {
        return f.kind;
      }
      fail('no failure');
    }

    expect(await kind(401, {'error': 'invalid_credentials'}),
        AuthFailureKind.wrongPin);
    expect(await kind(403, {'error': 'account_unavailable'}),
        AuthFailureKind.suspended);
    expect(await kind(500, {'error': 'boom'}), AuthFailureKind.offline);
    final (repo, _, _) = build({
      'POST /auth/sign-in': (_) =>
          (429, {'error': 'too_many_attempts', 'retry_after_seconds': 60}),
    });
    try {
      await repo.signIn(phone: '+255712345678', pin: '1111');
      fail('no failure');
    } on AuthFailure catch (f) {
      expect(f.kind, AuthFailureKind.locked);
      expect(f.retryAfter!.isAfter(DateTime.now()), isTrue);
    }
  });

  test('no network is "offline"', () async {
    final (repo, server, _) = build({});
    server.down = true;
    await expectLater(
        repo.signIn(phone: '+255712345678', pin: '2580'),
        throwsA(isA<AuthFailure>()
            .having((f) => f.kind, 'kind', AuthFailureKind.offline)));
  });

  test('activation verifies the code for its purpose, then sets the PIN',
      () async {
    final (repo, server, _) = build({
      'POST /auth/verify-code': (_) =>
          (200, {'exchange_token': 'ex-1', 'expires_in': 600}),
      'POST /auth/set-pin': (_) => (200, tokens('1')),
      'GET /me': (r) => r.headers['Authorization'] == 'Bearer access-1'
          ? (200, profile)
          : (401, {'error': 'invalid_session'}),
    });
    expect(
        await repo.verifyCode(phone: '+255712345678', code: '123456'), 'ex-1');
    expect(server.bodyOf('/auth/verify-code')['purpose'], 'activation');
    await repo.verifyCode(phone: '+255712345678', code: '123456', reset: true);
    expect(server.bodyOf('/auth/verify-code')['purpose'], 'pin_reset');
    final session = await repo.setPin(setupToken: 'ex-1', pin: '2580');
    expect(server.bodyOf('/auth/set-pin')['pin_confirmation'], '2580');
    expect(session.profile.id, 'v-1');
  });

  test('a weak PIN refused by the server is reported as weak', () async {
    final (repo, _, _) = build({
      'POST /auth/set-pin': (_) => (422, {'error': 'pin_too_simple'}),
    });
    await expectLater(
        repo.setPin(setupToken: 'x', pin: '2222'),
        throwsA(isA<AuthFailure>()
            .having((f) => f.kind, 'kind', AuthFailureKind.weakPin)));
  });

  test('an expired access token is refreshed once and the call repeated',
      () async {
    var refreshes = 0;
    final (repo, server, store) = build({
      'POST /auth/sign-in': (_) => (200, {...tokens('1'), 'profile': profile}),
      'POST /auth/refresh': (r) {
        refreshes++;
        return (200, tokens('2'));
      },
      'GET /dashboard': (r) => r.headers['Authorization'] == 'Bearer access-2'
          ? (
              200,
              {
                'date': '2026-10-19',
                'today_total': 7500,
                'sale_count': 2,
                'recent': []
              }
            )
          : (401, {'error': 'invalid_session'}),
    });
    await repo.signIn(phone: '+255712345678', pin: '2580');
    final results =
        await Future.wait([repo.dashboard('t'), repo.dashboard('t')]);
    expect(results.first.todayTotal, 7500);
    expect(refreshes, 1); // both callers waited on one refresh
    expect(server.bodyOf('/auth/refresh')['refresh_token'], 'refresh-1');
    expect(store.values.containsValue('refresh-2'), isTrue);
  });

  test('a refused refresh ends the session and forgets the tokens', () async {
    final (repo, _, store) = build({
      'POST /auth/sign-in': (_) => (200, {...tokens('1'), 'profile': profile}),
      'POST /auth/refresh': (_) => (401, {'error': 'invalid_session'}),
      'GET /catalogue': (_) => (401, {'error': 'invalid_session'}),
    });
    await repo.signIn(phone: '+255712345678', pin: '2580');
    await expectLater(
        repo.catalog('t'),
        throwsA(isA<AuthFailure>()
            .having((f) => f.kind, 'kind', AuthFailureKind.sessionExpired)));
    expect(store.values.containsValue('refresh-1'), isFalse);
  });

  test('sync sends the outbox envelope and reads every outcome', () async {
    final (repo, server, _) = build({
      'POST /auth/sign-in': (_) => (200, {...tokens('1'), 'profile': profile}),
      'POST /sync': (_) => (
            200,
            {
              'results': [
                {'op_id': 'a', 'status': 'accepted', 'reason': 'accepted'},
                {'op_id': 'b', 'status': 'duplicate', 'reason': 'accepted'},
                {'op_id': 'c', 'status': 'conflict', 'reason': 'wrong_station'},
                {'op_id': 'd', 'status': 'rejected', 'reason': 'no_price'},
              ],
              'verified_sales': ['a'],
              'confirmed_closings': [],
              'server_time': '2026-10-19T09:00:00+00:00',
            }
          ),
    });
    await repo.signIn(phone: '+255712345678', pin: '2580');
    final created = DateTime.utc(2026, 10, 19, 8);
    final reply = await repo.sync('t', phoneTime: created, operations: [
      SyncOperation(
          opId: 'a',
          opType: 'sale',
          vendorId: 'v-1',
          stationKey: 'KA01',
          businessDate: '2026-10-19',
          createdAt: created,
          payload: const {'client_id': 'a'}),
    ]);
    final body = server.bodyOf('/sync');
    expect(body['phone_time'], '2026-10-19T08:00:00.000Z');
    final op = (body['operations'] as List).single as Map;
    expect(
        op.keys,
        containsAll([
          'op_id',
          'op_type',
          'vendor_id',
          'station_key',
          'business_date',
          'created_at',
          'payload'
        ]));
    expect(reply.results.map((r) => r.outcome), [
      OperationOutcome.accepted,
      OperationOutcome.duplicate,
      OperationOutcome.conflict,
      OperationOutcome.rejected
    ]);
    expect(reply.verifiedSales, ['a']);
    expect(reply.serverTime, DateTime.utc(2026, 10, 19, 9));
  });

  test('catalogue and deliveries are read as the app expects', () async {
    final (repo, _, _) = build({
      'POST /auth/sign-in': (_) => (200, {...tokens('1'), 'profile': profile}),
      'GET /catalogue': (_) => (
            200,
            {
              'products': [
                {
                  'id': 'KUKU',
                  'name': 'Kuku mzima',
                  'price': 9000,
                  'price_version': 'pv-1',
                  'category': 'kuku',
                  'category_name': 'Kuku',
                  'image_key': null,
                  'available': 4
                },
                {
                  'id': 'MAINI',
                  'name': 'Maini',
                  'price': null,
                  'price_version': null,
                  'category': 'vyakula',
                  'category_name': 'Vyakula',
                  'image_key': null,
                  'available': null
                },
              ],
              'mpesa_recipient': null,
            }
          ),
      'GET /deliveries': (_) => (
            200,
            [
              {
                'consignment_id': 'm-1',
                'version': 2,
                'reference': 'DN-1',
                'sender': 'Omoterra',
                'station_key': 'KA01',
                'station_name': 'Kariakoo',
                'dispatched_at': '2026-10-19T06:00:00+00:00',
                'lines': [
                  {
                    'line_id': 'l-1',
                    'product_id': 'KUKU',
                    'product_name': 'Kuku mzima',
                    'quantity': 20,
                    'image_key': null
                  }
                ]
              },
            ]
          ),
    });
    await repo.signIn(phone: '+255712345678', pin: '2580');
    final catalogue = await repo.catalog('t');
    expect(catalogue.products.first.price, 9000);
    expect(catalogue.products.last.price, isNull);
    expect(catalogue.mpesaRecipient, isNull);
    final [delivery] = await repo.deliveries('t');
    expect((delivery.version, delivery.lines.single.quantity), (2, 20));
  });

  test('signing out forgets the tokens even when the server cannot be reached',
      () async {
    final (repo, server, store) = build({
      'POST /auth/sign-in': (_) => (200, {...tokens('1'), 'profile': profile}),
    });
    await repo.signIn(phone: '+255712345678', pin: '2580');
    server.down = true;
    await repo.signOut('t');
    expect(store.values.keys.where((k) => k.contains('token')), isEmpty);
  });

  test('release builds accept only an https API', () {
    expect(apiUrlAllowed('https://mrnyama.jopex.co.tz', release: true), isTrue);
    expect(apiUrlAllowed('http://192.168.1.20:8000', release: true), isFalse);
    expect(apiUrlAllowed('http://192.168.1.20:8000', release: false), isTrue);
    expect(apiUrlAllowed('', release: false), isFalse);
    expect(apiUrlAllowed('mrnyama.jopex.co.tz', release: true), isFalse);
  });
}
