import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/features/office/product_screens.dart';
import 'helpers.dart';
import 'package:mr_nyama_vendor/shared/widgets/sheet.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'office_test.dart' show FakeOfficeRepository;

FakeOfficeRepository office() => FakeOfficeRepository()
  ..signedIn = true
  ..productsList.add(const OfficeProduct(
      code: 'KUKU',
      name: 'Kuku mzima',
      category: 'kuku',
      unit: 'bird',
      price: 9000,
      available: true))
  ..pricesList.addAll([
    const OfficeStationPrice('a', 'Kituo A', 9000, false),
    const OfficeStationPrice('b', 'Kituo B', 9000, false),
  ]);

class PriceFailureOffice extends FakeOfficeRepository {
  bool failPrice = true;
  int metadataWrites = 0;
  @override
  Future<void> updateProduct(String code,
      {required String name,
      required String category,
      required String unit,
      required bool available,
      required String status,
      required String? imageKey,
      required String reason}) async {
    metadataWrites++;
    await super.updateProduct(code,
        name: name,
        category: category,
        unit: unit,
        available: available,
        status: status,
        imageKey: imageKey,
        reason: reason);
  }

  @override
  Future<void> setProductPrice(String code,
      {required int amount, String? stationId, required String reason}) async {
    if (failPrice) throw StateError('simulated price failure');
    await super.setProductPrice(code,
        amount: amount, stationId: stationId, reason: reason);
  }
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 250,
        scrollable: find.byType(Scrollable).first);
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pumpAndSettle();
}

Finder sheetFields() => find.descendant(
    of: find.byType(MNSheet).last, matching: find.byType(TextField));
Future<void> editName(WidgetTester tester, String name) async {
  await reveal(tester, find.text('Jina la bidhaa'));
  await tester.tap(find.text('Jina la bidhaa'));
  await tester.pumpAndSettle();
  await tester.enterText(sheetFields().first, name);
  await tester.tap(find.text('Tumia').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('owner uploads photo and saves changed product details',
      (tester) async {
    final repo = office();
    final app = await pumpApp(tester,
        startAs: StartAs.signedOut,
        office: repo,
        overrides: [
          pickProductPhotoProvider
              .overrideWithValue(() async => Uint8List.fromList([1, 2, 3]))
        ]);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(repo.owner);
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.officeProduct('KUKU'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Picha ya bidhaa'));
    await tester.pumpAndSettle();
    await editName(tester, 'Kuku wa kuchoma');
    await reveal(tester, find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'Taarifa mpya');
    await reveal(tester, find.text('Hifadhi mabadiliko'));
    await tester.tap(find.text('Hifadhi mabadiliko'));
    await tester.pumpAndSettle();
    expect(repo.productsList.single.name, 'Kuku wa kuchoma');
    expect(repo.productsList.single.imageKey, startsWith('uploads/'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'station price targets only that station and keeps unsaved details',
      (tester) async {
    final repo = office();
    final app = await pumpApp(tester, startAs: StartAs.signedOut, office: repo);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(repo.owner);
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.officeProduct('KUKU'));
    await tester.pumpAndSettle();
    await editName(tester, 'Jina halijahifadhiwa');
    await reveal(tester, find.text(const Strings('sw').stationPrices));
    await tester.tap(find.text(const Strings('sw').stationPrices));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Kituo A'));
    await tester.tap(find.text('Kituo A'));
    await tester.pumpAndSettle();
    final fields = sheetFields();
    await tester.enterText(fields.at(0), '10000');
    await tester.enterText(fields.at(1), 'Bei kituo A');
    await tester.tap(find.text('Hifadhi mabadiliko').last);
    await tester.pumpAndSettle();
    expect(repo.priceWrites.single['amount'], 10000);
    expect(repo.priceWrites.single['station'], 'a');
    Navigator.of(tester.element(find.text('Kituo A'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Jina halijahifadhiwa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('default price stays a draft until Save with a reason',
      (tester) async {
    final repo = office();
    final app = await pumpApp(tester, startAs: StartAs.signedOut, office: repo);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(repo.owner);
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.officeProduct('KUKU'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<MNButton>(
                find.widgetWithText(MNButton, 'Hifadhi mabadiliko'))
            .onPressed,
        isNull);
    await reveal(tester, find.text('Bei ya kawaida'));
    await tester.tap(find.text('Bei ya kawaida'));
    await tester.pumpAndSettle();
    await tester.enterText(sheetFields().first, '10000');
    await tester.tap(find.text('Tumia').last);
    await tester.pumpAndSettle();
    expect(repo.priceWrites, isEmpty);
    expect(find.textContaining('Iliyokuwa:'), findsOneWidget);
    await reveal(tester, find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'Bei mpya');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hifadhi mabadiliko'));
    await tester.pumpAndSettle();
    expect(repo.priceWrites.single['amount'], 10000);
    expect(repo.priceWrites.single['station'], isNull);
  });

  testWidgets(
      'turning off requires confirmation and saving; history is preserved',
      (tester) async {
    final repo = office();
    final app = await pumpApp(tester, startAs: StartAs.signedOut, office: repo);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(repo.owner);
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.officeProduct('KUKU'));
    await tester.pumpAndSettle();
    await reveal(tester, find.byType(SwitchListTile).first);
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Zima Kuku mzima?'), findsOneWidget);
    await tester.tap(find.text('Ghairi'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
        isTrue);
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(MNSheet), matching: find.text('Zima bidhaa')));
    await tester.pumpAndSettle();
    expect(repo.productsList.single.status, 'active');
    await reveal(tester, find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'Sitisha mauzo mapya');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hifadhi mabadiliko'));
    await tester.pumpAndSettle();
    expect(repo.productsList, hasLength(1));
    expect(repo.productsList.single.status, 'discontinued');
    expect(repo.productsList.single.available, isFalse);
  });

  testWidgets(
      'a partial save keeps the price pending and retry skips confirmed metadata',
      (tester) async {
    final repo = PriceFailureOffice()..signedIn = true;
    repo.productsList.addAll(office().productsList);
    final app = await pumpApp(tester, startAs: StartAs.signedOut, office: repo);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(repo.owner);
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.officeProduct('KUKU'));
    await tester.pumpAndSettle();
    await editName(tester, 'Kuku wa kuchoma');
    await reveal(tester, find.text('Bei ya kawaida'));
    await tester.tap(find.text('Bei ya kawaida'));
    await tester.pumpAndSettle();
    await tester.enterText(sheetFields().first, '10000');
    await tester.tap(find.text('Tumia').last);
    await tester.pumpAndSettle();
    await reveal(tester, find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'Taarifa na bei mpya');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hifadhi mabadiliko'));
    await tester.pumpAndSettle();
    expect(find.text(const Strings('sw').productPartialSave), findsOneWidget);
    expect(repo.metadataWrites, 1);
    expect(repo.priceWrites, isEmpty);
    repo.failPrice = false;
    await tester.tap(find.text('Hifadhi mabadiliko'));
    await tester.pumpAndSettle();
    expect(repo.metadataWrites, 1);
    expect(repo.priceWrites.single['amount'], 10000);
  });

  testWidgets('owner moves an existing worker to another station',
      (tester) async {
    final repo = office()
      ..staffList.add(const OfficeStaff(
          id: 'worker',
          name: 'Asha',
          phone: '+255712345678',
          roles: ['supervisor'],
          stationIds: ['a'],
          activated: true,
          suspended: false))
      ..stationsList.clear()
      ..stationsList.addAll([
        const OfficeStation(
            id: 'a', code: 'A', name: 'Kituo A', hasVendor: true),
        const OfficeStation(
            id: 'b', code: 'B', name: 'Kituo B', hasVendor: true),
      ]);
    final app = await pumpApp(tester, startAs: StartAs.signedOut, office: repo);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(repo.owner);
    await tester.pumpAndSettle();
    app.router.push(MNRoutes.officeStaffStations('worker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kituo A'));
    await tester.tap(find.text('Kituo B'));
    await tester.enterText(find.byType(TextField), 'Hamisha A kwenda B');
    await tester.tap(find.text('Hifadhi mabadiliko'));
    await tester.pumpAndSettle();
    expect(repo.placements['worker'], ['b']);
    expect(tester.takeException(), isNull);
  });
}
