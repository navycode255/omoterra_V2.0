import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/select_field.dart';
import 'helpers.dart';
import 'station_management_test.dart' show StationOffice;

class ReceivingOffice extends StationOffice
    implements OfficeReceivingRepository {
  final requests = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> lots;
  final List<Map<String, dynamic>> locations;
  ReceivingOffice(
      {List<Map<String, dynamic>>? lots, List<Map<String, dynamic>>? locations})
      : locations = locations ??
            [
              {
                'id': 'kitchen',
                'name': 'Jiko kuu',
                'kind': 'kitchen',
                'active': true
              }
            ],
        lots = lots ??
            [
              {
                'lot_id': 'lot',
                'product': 'KUKU',
                'name': 'Kuku mzima',
                'unit': 'piece',
                'quantity': '10',
                'created_at': '2026-10-23T06:00:00Z'
              }
            ] {
    productsList.addAll(const [
      OfficeProduct(
          code: 'KUKU',
          name: 'Kuku mzima',
          category: 'KUKU',
          unit: 'piece',
          available: true),
      OfficeProduct(
          code: 'MAINI',
          name: 'Maini',
          category: 'KUKU',
          unit: 'portion',
          available: true),
    ]);
  }
  @override
  Future<List<Map<String, dynamic>>> receivingLocations() async => locations;
  @override
  Future<List<Map<String, dynamic>>> receivingLots(String locationId) async =>
      lots;
  @override
  Future<Map<String, dynamic>> createExpectedDelivery(
      Map<String, dynamic> body) async {
    requests.add(body);
    return {'id': body['client_id']};
  }
}

Future<void> choose(WidgetTester tester, int index, String text) async {
  final field = find.byType(MNSelectField<String>).at(index);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

/// "Ongeza bidhaa" opens the product sheet; the line's name opens the
/// keypad, like a kikapu line.
Future<void> addProduct(WidgetTester tester, String name, int quantity) async {
  final add = find.widgetWithText(MNButton, 'Ongeza bidhaa');
  await tester.ensureVisible(add);
  await tester.pumpAndSettle();
  await tester.tap(add);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(name).last);
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
  for (final digit in '$quantity'.split('')) {
    await tester.tap(find.text(digit).last);
    await tester.pump();
  }
  await tester.tap(find.text('Weka idadi'));
  await tester.pumpAndSettle();
}

Future<ReceivingOffice> openForm(WidgetTester tester,
    {List<Map<String, dynamic>>? lots,
    List<Map<String, dynamic>>? locations}) async {
  final repository = ReceivingOffice(lots: lots, locations: locations);
  final app =
      await pumpApp(tester, office: repository, startAs: StartAs.signedOut);
  await app.container
      .read(officeSessionProvider.notifier)
      .signedIn(repository.owner);
  // Expected deliveries live on the station's Stock page.
  app.router.go(MNRoutes.officeStock('s1'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Ongeza').last);
  await tester.tap(find.text('Ongeza').last);
  await tester.pumpAndSettle();
  return repository;
}

Future<void> save(WidgetTester tester) async {
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  final save = find.widgetWithText(MNButton, 'Hifadhi').last;
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.tap(save);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.widgetWithText(MNButton, 'Hifadhi').last);
  await tester.pumpAndSettle();
}

void main() {
  for (final purchase in [true, false]) {
    testWidgets(
        'office creates ${purchase ? 'a supplier purchase' : 'a kitchen transfer'} for vendor receipt',
        (tester) async {
      final repository = await openForm(tester);
      await choose(
          tester,
          0,
          purchase
              ? 'Manunuzi kutoka kwa msambazaji'
              : 'Uhamisho kutoka jikoni au stoo');
      // Reference (Kumbukumbu) is assigned by the form; field 0 stays read-only.
      if (purchase) {
        await tester.enterText(find.byType(TextField).at(1), 'Msambazaji');
        await tester.enterText(find.byType(TextField).at(2), 'AGR-22');
        await choose(tester, 1, 'Baada ya kuthibitisha kupokea');
        await addProduct(tester, 'Kuku mzima', 4);
        await tester.enterText(find.byType(TextField).at(3), '6000');
      } else {
        await choose(tester, 1, 'Jiko kuu');
        await addProduct(tester, 'Kuku mzima', 4);
      }
      await save(tester);
      final request = repository.requests.single;
      expect(request['arrangement'], purchase ? 'A' : 'B');
      expect(request['station_id'], 's1');
      expect(request['client_id'], isNotEmpty);
      expect(request['reference'], startsWith('DN-'));
      expect((request['reference'] as String).length, greaterThanOrEqualTo(5));
      final line = (request['lines'] as List).single as Map;
      expect(line['product'], 'KUKU');
      expect(line['quantity'], 4);
      if (purchase) {
        expect(line['agreed_unit_price'], 6000);
      } else {
        expect(line['source_lot_id'], 'lot');
        expect(line['source_location_id'], 'kitchen');
        expect(line.containsKey('agreed_unit_price'), isFalse);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'a transfer lists registered products and takes the oldest lots first',
      (tester) async {
    final repository = await openForm(tester, lots: [
      {
        'lot_id': 'new',
        'product': 'KUKU',
        'name': 'Kuku mzima',
        'unit': 'piece',
        'quantity': '10',
        'created_at': '2026-10-23T06:00:00Z'
      },
      {
        'lot_id': 'old',
        'product': 'KUKU',
        'name': 'Kuku mzima',
        'unit': 'piece',
        'quantity': '6',
        'created_at': '2026-10-21T06:00:00Z'
      },
    ]);
    await choose(tester, 0, 'Uhamisho kutoka jikoni au stoo');
    expect(
        find.text('Chagua jikoni au stoo inayotuma kwanza.'), findsOneWidget);
    await choose(tester, 1, 'Jiko kuu');
    await tester.tap(find.widgetWithText(MNButton, 'Ongeza bidhaa'));
    await tester.pumpAndSettle();
    // Every registered product is listed; one the kitchen lacks is greyed.
    expect(find.text('Zipo hapa: 16 Kipande'), findsOneWidget);
    expect(find.text('Hazipo kwenye stoo hii'), findsOneWidget);
    await tester.tap(find.text('Maini').last);
    await tester.pumpAndSettle();
    expect(find.text('Hazipo kwenye stoo hii'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    await addProduct(tester, 'Kuku mzima', 8);
    await save(tester);
    final lines = (repository.requests.single['lines'] as List).cast<Map>();
    expect([for (final l in lines) (l['source_lot_id'], l['quantity'])],
        [('old', 6), ('new', 2)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'with only the receiving station, a transfer explains prepared intake',
      (tester) async {
    await openForm(tester, lots: const [], locations: [
      {'id': 'loc1', 'name': 'Bunju B', 'kind': 'station', 'active': true}
    ]);
    await choose(tester, 0, 'Uhamisho kutoka jikoni au stoo');
    expect(find.textContaining('Kwa bidhaa mlizoandaa ambazo hazijarekodiwa'),
        findsOneWidget);
    await choose(tester, 0, 'Manunuzi kutoka kwa msambazaji');
    await tester.ensureVisible(find.widgetWithText(MNButton, 'Ongeza bidhaa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MNButton, 'Ongeza bidhaa'));
    await tester.pumpAndSettle();
    // The purchase picker lists the registered products.
    expect(find.text('Kuku mzima'), findsWidgets);
    expect(find.text('Maini'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'prepared intake needs no supplier or source stock and preserves product identity',
      (tester) async {
    final repository =
        await openForm(tester, lots: const [], locations: const []);
    await choose(tester, 0, 'Vimeandaliwa na timu yetu');
    expect(find.text('Jikoni au stoo inayotuma'), findsNothing);
    expect(find.text('Kumbukumbu ya makubaliano'), findsNothing);
    await tester.enterText(
        find.byType(TextField).last, 'Timu yetu, jiko la maandalizi');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await addProduct(tester, 'Kuku mzima', 5);
    await save(tester);
    final body = repository.requests.single;
    expect(body['intake_kind'], 'prepared_locally');
    expect(body['arrangement'], 'prepared_locally');
    expect(body['unrecorded_stock'], true);
    expect(body.containsKey('agreement_reference'), false);
    final line = (body['lines'] as List).single as Map;
    expect(line['product'], 'KUKU');
    expect(line['quantity'], 5);
    expect(line['source_lot_id'], isNull);
    expect(line['agreed_unit_price'], isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'a missing kilogram product can be registered without leaving the delivery',
      (tester) async {
    final repository =
        await openForm(tester, lots: const [], locations: const []);
    await choose(tester, 0, 'Vimeandaliwa na timu yetu');
    await tester.enterText(find.byType(TextField).last, 'Timu ya jiko');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    final add = find.widgetWithText(MNButton, 'Ongeza bidhaa');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ongeza bidhaa').last);
    await tester.pumpAndSettle();
    // Inline registration asks for name, category and unit, not a technical code.
    await tester.enterText(find.byType(TextField).last, 'Nyama kwa kg');
    await choose(tester, 0, 'Kuku');
    await choose(tester, 1, 'Kilogramu');
    final create = find.widgetWithText(MNButton, 'Hifadhi mabadiliko');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.text('Nyama kwa kg'), findsOneWidget);
    final product =
        repository.productsList.singleWhere((p) => p.name == 'Nyama kwa kg');
    expect(product.unit, 'kg');
    await save(tester);
    final line = (repository.requests.single['lines'] as List).single as Map;
    expect(line['product'], product.code);
    expect(line['quantity'], 1);
    expect(tester.takeException(), isNull);
  });
}
