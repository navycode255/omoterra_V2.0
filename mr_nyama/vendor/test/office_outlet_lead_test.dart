import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/office_errors.dart';
import 'package:mr_nyama_vendor/shared/widgets/sheet.dart';

import 'helpers.dart';
import 'office_test.dart' show FakeOfficeRepository;

OfficeVendor _vendor({bool lead = false, bool station = true}) => OfficeVendor(
    id: 'v1',
    name: 'Asha Juma',
    phone: '+255712345678',
    code: 'V-001',
    stationId: station ? 's1' : null,
    stationName: station ? 'Kariakoo' : null,
    activated: true,
    suspended: false,
    isLead: lead);

class LeadOffice extends FakeOfficeRepository
    implements OfficeOutletLeadRepository {
  final calls = <String>[];
  final ids = <String>[];
  Object? refuse;

  @override
  Future<void> makeOutletLead(String vendorId,
      {required String clientId, required String reason}) async {
    calls.add('make $vendorId $reason');
    ids.add(clientId);
    if (refuse case final e?) {
      refuse = null;
      throw e;
    }
    vendorsList[0] = _vendor(lead: true);
  }

  @override
  Future<void> endOutletLead(String vendorId,
      {required String clientId, required String reason}) async {
    calls.add('end $vendorId $reason');
    ids.add(clientId);
    vendorsList[0] = _vendor();
  }
}

Future<TestApp> _open(WidgetTester tester, LeadOffice office,
    {StaffProfile? as}) async {
  office.signedIn = true;
  final app = await pumpApp(tester, startAs: StartAs.signedOut, office: office);
  await app.container
      .read(officeSessionProvider.notifier)
      .signedIn(as ?? office.owner);
  await tester.pumpAndSettle();
  app.router.push(MNRoutes.officeVendor('v1'));
  await tester.pumpAndSettle();
  return app;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(f, 200,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Finder _inSheet(Finder f) =>
    find.descendant(of: find.byType(MNSheet), matching: f);

void main() {
  testWidgets('owner sees make-lead button', (tester) async {
    final office = LeadOffice()..vendorsList.add(_vendor());
    await _open(tester, office);
    expect(find.text('Mfanye Kiongozi wa Kituo'), findsOneWidget);
    expect(find.text('Ondoa ukiongozi'), findsNothing);
  });

  testWidgets('supervisor does not', (tester) async {
    final office = LeadOffice()..vendorsList.add(_vendor());
    await _open(tester, office,
        as: const StaffProfile(
            id: 's', name: 'Neema', phone: '', roles: ['supervisor']));
    expect(find.text('Asha Juma'), findsWidgets);
    expect(find.text('Mfanye Kiongozi wa Kituo'), findsNothing);
    expect(find.text('Ondoa ukiongozi'), findsNothing);
  });

  testWidgets('after making, button reads Ondoa ukiongozi', (tester) async {
    final office = LeadOffice()..vendorsList.add(_vendor());
    await _open(tester, office);
    await _tap(tester, find.text('Mfanye Kiongozi wa Kituo'));
    await tester.tap(_inSheet(find.text('Mfanye Kiongozi wa Kituo')).last);
    await tester.pumpAndSettle();
    expect(office.calls, isEmpty, reason: 'a reason is needed first');
    await tester.enterText(_inSheet(find.byType(TextField)), 'Ni mwaminifu');
    await tester.tap(_inSheet(find.text('Mfanye Kiongozi wa Kituo')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mfanye Kiongozi wa Kituo').last);
    await tester.pumpAndSettle();
    expect(office.calls, ['make v1 Ni mwaminifu']);
    expect(find.text('Ondoa ukiongozi'), findsOneWidget);
    expect(find.text('Kiongozi wa Kituo'), findsOneWidget);
  });

  testWidgets('no_station message; a definite refusal mints a new client id',
      (tester) async {
    final office = LeadOffice()
      ..vendorsList.add(_vendor(station: false))
      ..refuse = const OfficeError(OfficeErrorKind.lead, 'no_station');
    await _open(tester, office);
    await _tap(tester, find.text('Mfanye Kiongozi wa Kituo'));
    await tester.enterText(_inSheet(find.byType(TextField)), 'Ni mwaminifu');
    Future<void> submit() async {
      await tester.tap(_inSheet(find.text('Mfanye Kiongozi wa Kituo')).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mfanye Kiongozi wa Kituo').last);
      await tester.pumpAndSettle();
    }

    await submit();
    expect(find.text('Mpe kituo kwanza'), findsOneWidget);
    await submit();
    expect(office.ids.length, 2);
    expect(office.ids[0], isNot(office.ids[1]));
  });

  testWidgets('an unknown send failure keeps the same client id on retry',
      (tester) async {
    final office = LeadOffice()
      ..vendorsList.add(_vendor())
      ..refuse = Exception('network down');
    await _open(tester, office);
    await _tap(tester, find.text('Mfanye Kiongozi wa Kituo'));
    await tester.enterText(_inSheet(find.byType(TextField)), 'Ni mwaminifu');
    Future<void> submit() async {
      await tester.tap(_inSheet(find.text('Mfanye Kiongozi wa Kituo')).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mfanye Kiongozi wa Kituo').last);
      await tester.pumpAndSettle();
    }

    await submit();
    await submit();
    expect(office.ids.length, 2);
    expect(office.ids[0], office.ids[1]);
  });

  for (final (code, text) in [
    ('staff_unavailable', 'Akaunti ya ofisi ya mtu huyu haipatikani'),
    ('client_id_used', 'Ombi hili limetumika kwa muuzaji mwingine'),
    ('some_new_code', 'Jaribu tena baada ya muda mfupi.'),
  ]) {
    test('409 $code on the lead route is not the phone-used message',
        () async {
      final store = InMemoryStore();
      await store.write('office_access_token', 'staff-token');
      final dio = Dio()
        ..httpClientAdapter = _Adapter(409, {'error': code});
      final repo =
          HttpOfficeRepository(baseUrl: 'https://x', store: store, dio: dio);
      await expectLater(
          repo.makeOutletLead('v1', clientId: 'c', reason: 'sababu'),
          throwsA(isA<OfficeError>()
              .having((e) => e.kind, 'kind', OfficeErrorKind.lead)));
      try {
        await repo.makeOutletLead('v1', clientId: 'c', reason: 'sababu');
      } catch (e) {
        expect(officeErrorText(const Strings('sw'), e), text);
      }
    });
  }

  test('own_record message', () {
    final s = const Strings('sw');
    expect(officeErrorText(s, const OfficeError(OfficeErrorKind.ownRecord)),
        'Huwezi kuhakiki rekodi zako mwenyewe');
  });

  test('roleName shows Kiongozi wa Kituo only for a lead', () {
    final s = const Strings('sw');
    expect(s.roleName('supervisor'), 'Msimamizi');
    expect(s.roleName('supervisor', lead: true), 'Kiongozi wa Kituo');
  });
}

class _Adapter implements HttpClientAdapter {
  final int status;
  final Object data;
  _Adapter(this.status, this.data);
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
          Future<void>? cancel) async =>
      ResponseBody.fromString(jsonEncode(data), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  void close({bool force = false}) {}
}
