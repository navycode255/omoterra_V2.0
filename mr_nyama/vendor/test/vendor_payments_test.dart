import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/vendor_pay_forms.dart';
import 'package:mr_nyama_vendor/shared/widgets/icon.dart';
import 'helpers.dart';
import 'office_test.dart' show FakeOfficeRepository;

// Server fixtures only: never seeded into the operational app.
class PayOffice extends FakeOfficeRepository
    implements OfficeVendorPayRepository {
  final commands =
      <({String vendor, String command, Map<String, dynamic> body})>[];
  int overviewCalls = 0;
  bool failPaymentOnce = false;
  int paid = 2000;
  PayOffice() {
    signedIn = true;
  }
  Map<String, dynamic> get vendor => {
        'id': 'v1',
        'name': 'Asha Juma',
        'station': 'Kariakoo',
        'frequency': 'weekly',
        'earned': 6500,
        'paid': paid,
        'balance': 6500 - paid,
        'due': 6500 - paid,
        'overpaid': 0,
        'next_due': '2026-10-23'
      };
  @override
  Future<Map<String, dynamic>> vendorPayOverview() async {
    overviewCalls++;
    return {
      'as_of': '2026-10-24',
      'earned': 12500,
      'paid': paid + 6000,
      'balance': 6500 - paid,
      'due': 6500 - paid,
      'missing_contracts': 1,
      'overpaid': 0,
      'vendors': [
        vendor,
        {
          'id': 'v2',
          'name': 'Rehema Ali',
          'station': 'Mikocheni',
          'frequency': 'daily',
          'earned': 6000,
          'paid': 6000,
          'balance': 0,
          'due': 0,
          'overpaid': 0
        },
        {
          'id': 'v3',
          'name': 'Juma Said',
          'station': null,
          'frequency': null,
          'earned': null,
          'paid': 0,
          'balance': null,
          'due': null,
          'overpaid': 0
        },
      ]
    };
  }

  @override
  Future<Map<String, dynamic>> vendorPayStatement(
          String vendor, String from, String to) async =>
      {
        'vendor': this.vendor,
        'period_from': from,
        'period_to': to,
        'days': [
          {
            'date': '2026-10-23',
            'station': 'Kariakoo',
            'present': true,
            'reported_sales': 20000,
            'verified_sales': 15000,
            'earned': 6500,
            'attendance': {
              'id': 'a1',
              'station_id': 's1',
              'business_date': '2026-10-23',
              'present': true
            }
          },
          {
            'date': '2026-10-22',
            'station': 'Kariakoo',
            'present': null,
            'reported_sales': 2000,
            'verified_sales': 0,
            'earned': null,
            'attendance': null
          },
        ],
        'contracts': [
          {
            'id': 'c1',
            'effective_from': '2026-10-01',
            'daily_rate': 5000,
            'commission_bps': 1000,
            'frequency': 'weekly',
            'pay_weekday': 4,
            'pay_monthday': null,
            'reference': 'TEST-AGREEMENT',
            'terms': 'Malipo kwa siku na asilimia ya mauzo yaliyothibitishwa'
          }
        ],
        'payments': [
          {
            'id': 'p1',
            'amount': 2000,
            'method': 'mpesa',
            'reference': 'TEST-RECEIPT',
            'paid_at': '2026-10-23T12:00:00Z',
            'period_from': '2026-10-01',
            'period_to': '2026-10-23',
            'reversed': false,
            'is_reversal': false
          }
        ]
      };
  @override
  Future<Map<String, dynamic>> vendorPayCommand(
      String vendor, String command, Map<String, dynamic> body) async {
    commands.add((
      vendor: vendor,
      command: command,
      body: Map<String, dynamic>.from(body)
    ));
    if (command == 'payments' && failPaymentOnce) {
      failPaymentOnce = false;
      throw StateError('network unavailable');
    }
    if (command == 'payments') paid += (body['amount'] as int);
    return {'id': body['client_id']};
  }
}

Future<PayOffice> openPay(WidgetTester tester,
    {String role = StaffRole.owner,
    bool statement = false,
    Size size = const Size(390, 844),
    double scale = 1}) async {
  final office = PayOffice();
  final app = await pumpApp(tester,
      office: office,
      startAs: StartAs.signedOut,
      size: size,
      textScale: scale,
      now: DateTime.utc(2026, 10, 24, 9));
  await app.container.read(officeSessionProvider.notifier).signedIn(
      StaffProfile(
          id: 'owner', name: 'Ofisi', phone: '+255712345678', roles: [role]));
  app.router.go(statement
      ? MNRoutes.officeVendorPay('v1')
      : MNRoutes.officeVendorPayments);
  await tester.pumpAndSettle();
  return office;
}

Future<void> pick(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(PayChoiceField, label);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

Future<void> tapLabel(WidgetTester tester, String label) async {
  final f = find.text(label).last;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  test(
      'vendor pay HTTP requests use staff authentication and preserve commands',
      () async {
    final requests = <RequestOptions>[];
    final store = InMemoryStore();
    await store.write('office_access_token', 'staff-token');
    final dio = Dio()..httpClientAdapter = PayAdapter(requests);
    final api = HttpOfficeRepository(
        baseUrl: 'https://example.test', store: store, dio: dio);
    await api.vendorPayOverview();
    await api.vendorPayStatement('v1', '2026-10-01', '2026-10-24');
    final body = {'client_id': 'command-id', 'amount': 1200};
    await api.vendorPayCommand('v1', 'payments', body);
    expect(requests.map((r) => r.method), ['GET', 'GET', 'POST']);
    expect(
        requests
            .every((r) => r.headers['Authorization'] == 'Bearer staff-token'),
        true);
    expect(requests[0].uri.path, '/api/v1/staff/vendor-payments');
    expect(requests[1].uri.queryParameters,
        {'period_from': '2026-10-01', 'period_to': '2026-10-24'});
    expect(requests[2].uri.path, '/api/v1/staff/vendor-payments/v1/payments');
    expect(requests[2].data, body);
  });
  testWidgets(
      'owner roster separates owed, paid and missing contracts without invented zero earnings',
      (tester) async {
    await openPay(tester);
    expect(find.text('Bado haijahesabiwa'), findsWidgets);
    await tapLabel(tester, 'Wamelipwa');
    expect(find.text('Rehema Ali'), findsOneWidget);
    expect(find.text('Asha Juma'), findsNothing);
    await tapLabel(tester, 'Hana mkataba');
    expect(find.text('Juma Said'), findsOneWidget);
    expect(find.text('Rehema Ali'), findsNothing);
  });
  testWidgets(
      'finance sees attendance and payments but cannot set contract terms',
      (tester) async {
    await openPay(tester, role: StaffRole.finance, statement: true);
    expect(find.text('Rekodi malipo yaliyofanyika'), findsOneWidget);
    expect(find.text('Weka mkataba'), findsNothing);
    expect(find.text('Amefanya kazi'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Hayajarekodiwa'), 250);
    expect(find.text('Hayajarekodiwa'), findsOneWidget);
  });
  testWidgets('supervisor cannot load business-wide vendor pay',
      (tester) async {
    final office = await openPay(tester, role: StaffRole.supervisor);
    expect(office.overviewCalls, 0);
    expect(find.text('Akaunti yako hairuhusiwi kufanya hili'), findsOneWidget);
  });
  testWidgets(
      'owner records fixed pay plus commission and a monthly payment date',
      (tester) async {
    final office = await openPay(tester, statement: true);
    await tapLabel(tester, 'Weka mkataba');
    await tester.enterText(find.byType(TextField).at(0), '5000');
    await tester.enterText(find.byType(TextField).at(1), '1.25');
    await pick(tester, 'Ratiba ya malipo', 'Kila mwezi');
    await tester.enterText(find.byType(TextField).at(2), '28');
    await tester.enterText(
        find.byType(TextField).last, 'Masharti yaliyokubaliwa na muuzaji');
    await tapLabel(tester, 'Hifadhi');
    final request = office.commands.single;
    expect(request.command, 'contracts');
    expect(request.body['daily_rate'], 5000);
    expect(request.body['commission_bps'], 125);
    expect(request.body['pay_monthday'], 28);
    expect(request.body['frequency'], 'monthly');
    expect(request.body['client_id'], isNotEmpty);
  });
  testWidgets('attendance needs an explicit station and worked/absent choice',
      (tester) async {
    final office = await openPay(tester, statement: true);
    await tapLabel(tester, 'Rekodi mahudhurio');
    await tapLabel(tester, 'Hifadhi');
    expect(office.commands, isEmpty);
    await pick(tester, 'Jina la kituo', 'Kariakoo');
    await pick(tester, 'Mahudhurio', 'Amefanya kazi');
    await tapLabel(tester, 'Hifadhi');
    final request = office.commands.single;
    expect(request.command, 'attendance');
    expect(request.body['station_id'], 's1');
    expect(request.body['present'], true);
  });
  testWidgets(
      'unconfirmed partial payment retries the same frozen request and refreshes only after success',
      (tester) async {
    final office = await openPay(tester, statement: true);
    office.failPaymentOnce = true;
    await tapLabel(tester, 'Rekodi malipo yaliyofanyika');
    await tester.enterText(find.byType(TextField).at(0), '1000');
    await pick(tester, 'Njia ya malipo', 'M-Pesa');
    await tester.enterText(find.byType(TextField).at(1), 'TEST-MPESA');
    await tapLabel(tester, 'Hifadhi');
    expect(office.paid, 2000);
    expect(
        find.text(
            'Hatujathibitisha jibu la seva. Jaribu tena kwa ombi hili hili.'),
        findsOneWidget);
    await tapLabel(tester, 'Jaribu tena');
    expect(office.paid, 3000);
    expect(office.commands.length, 2);
    expect(jsonEncode(office.commands.first.body),
        jsonEncode(office.commands.last.body));
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('payment screens fit a small phone at text scale $scale',
        (tester) async {
      await openPay(tester,
          statement: true, size: const Size(320, 568), scale: scale);
      await tester.scrollUntilVisible(find.text('Historia ya malipo'), 250);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('payment overview preview uses development fixture records',
      (tester) async {
    await openPay(tester);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first);
    final image =
        (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
    final bytes = await tester
        .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
    await tester.runAsync(() async {
      final dir = Directory('../../output/vendor-payments-previews');
      await dir.create(recursive: true);
      await File('${dir.path}/overview.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    });
    image.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('statement and command form previews use fixture data only',
      (tester) async {
    await openPay(tester, statement: true);
    Future<void> capture(String name) async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first);
      final image =
          (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
      final bytes = await tester
          .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
      await tester.runAsync(() async {
        final dir = Directory('../../output/vendor-payments-previews');
        await dir.create(recursive: true);
        await File('${dir.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      });
      image.dispose();
    }

    await capture('statement');
    await tapLabel(tester, 'Rekodi malipo yaliyofanyika');
    expect(
        find.descendant(
            of: find.byType(PayChoiceField), matching: find.byType(MNIcon)),
        findsWidgets);
    await capture('payment-form');
    Navigator.of(tester.element(find.byType(PayChoiceField).first)).pop();
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Weka mkataba');
    await capture('contract-form');
    expect(tester.takeException(), isNull);
  });
}

class PayAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests;
  PayAdapter(this.requests);
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(
        jsonEncode({'vendors': [], 'id': 'accepted'}), 200,
        headers: {
          'content-type': ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}
