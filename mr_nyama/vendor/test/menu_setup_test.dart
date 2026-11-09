import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/menu_screens.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/input_field.dart';
import 'helpers.dart';
import 'office_test.dart' show FakeOfficeRepository;
import 'office_verification_test.dart' show tapVisible;

class MenuOffice extends FakeOfficeRepository implements MenuSetupRepository {
  final imports = <Map<String, dynamic>>[], saves = <Map<String, dynamic>>[];
  bool fail = false, invalidPreview = false;

  /// Replaces the two default station items when set.
  List<Map<String, dynamic>>? stationItems;
  @override
  Future<Uint8List> menuTemplate() async => Uint8List.fromList([1, 2, 3]);
  @override
  Future<Map<String, dynamic>> previewMenu(Uint8List bytes) async => {
        'can_import': !invalidPreview,
        'errors': invalidPreview
            ? [
                {'row': 2, 'message': 'Bei haisomeki.'}
              ]
            : [],
        'items': [
          {
            'row': 2,
            'code': 'KUKU',
            'name': 'Kuku mzima',
            'unit': 'bird',
            'price': 12000,
            'category': 'menu',
            'category_name': 'Menyu',
            'action': 'create',
            'expected_state': null
          }
        ],
      };
  @override
  Future<Map<String, dynamic>> importMenu(Map<String, dynamic> body) async {
    imports.add(body);
    if (fail) {
      fail = false;
      throw Exception('offline');
    }
    return {'created': 1, 'updated': 0};
  }

  @override
  Future<Map<String, dynamic>> stationMenu(String id) async => {
        'revision': 7,
        'configured': true,
        'items': stationItems ??
            [
              {
                'code': 'KUKU',
                'name': 'Kuku mzima',
                'unit': 'bird',
                'default_price': 12000,
                'station_price': 13000,
                'selected': true,
                'available': true
              },
              {
                'code': 'VIAZI',
                'name': 'Viazi',
                'unit': 'portion',
                'default_price': 2000,
                'station_price': null,
                'selected': true,
                'available': true
              },
            ]
      };
  @override
  Future<Map<String, dynamic>> saveStationMenu(
      String id, Map<String, dynamic> body) async {
    saves.add(body);
    if (fail) {
      fail = false;
      throw Exception('offline');
    }
    return {'revision': 8, 'selected': (body['items'] as List).length};
  }
}

Future<TestApp> openMenu(WidgetTester tester, MenuOffice office, String route,
    {double textScale = 1, Size size = const Size(390, 844)}) async {
  final app = await pumpApp(tester,
      startAs: StartAs.signedOut,
      office: office,
      textScale: textScale,
      size: size,
      overrides: [
        pickMenuFileProvider
            .overrideWithValue(() async => Uint8List.fromList([1]))
      ]);
  await app.container
      .read(officeSessionProvider.notifier)
      .signedIn(office.owner);
  app.router.push(route);
  await tester.pumpAndSettle();
  return app;
}

Finder button(String label) => find.widgetWithText(MNButton, label);
Finder field(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(MNTextField));
Future<void> captureMenu(WidgetTester tester, String name) async {
  if (Platform.environment['MN_MENU_PREVIEWS'] != '1') return;
  final boundary = tester
      .firstRenderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary));
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
  final bytes = await tester
      .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  await tester.runAsync(() =>
      File('/tmp/menu-$name.png').writeAsBytes(bytes!.buffer.asUint8List()));
  image.dispose();
}

Map<String, dynamic> menuItem(String code, String name,
        {required int? price, required bool selected}) =>
    {
      'code': code,
      'name': name,
      'unit': 'piece',
      'default_price': price,
      'station_price': null,
      'selected': selected,
      'available': true
    };

/// Fills the reason sheet that Hifadhi opens and confirms it.
Future<void> saveWithReason(WidgetTester tester, String reason) async {
  await tester.enterText(
      find.descendant(
          of: field('Sababu ya mabadiliko'), matching: find.byType(TextField)),
      reason);
  await tapVisible(tester, button('Hifadhi').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'Excel review precedes saving; an unanswered import retries the same UUID',
      (tester) async {
    final office = MenuOffice()..fail = true;
    await openMenu(tester, office, MNRoutes.officeMenuImport);
    await tapVisible(tester, button('Chagua faili la Excel'));
    await captureMenu(tester, 'excel-review');
    expect(office.imports, isEmpty);
    expect(find.text('Kuku mzima'), findsOneWidget);
    await tester.enterText(
        find.descendant(
            of: field('Sababu ya mabadiliko'),
            matching: find.byType(TextField)),
        'Menyu mpya');
    await tapVisible(tester, button('Hifadhi menyu'));
    expect(office.imports.length, 1);
    await tapVisible(tester, button('Jaribu tena'));
    expect(office.imports.length, 2);
    expect(office.imports[0], office.imports[1]);
    expect((office.imports.first['items'] as List).single.containsKey('action'),
        isFalse);
    expect(find.textContaining('mpya 1'), findsOneWidget);
  });
  testWidgets('invalid rows block all imports', (tester) async {
    final office = MenuOffice()..invalidPreview = true;
    await openMenu(tester, office, MNRoutes.officeMenuImport);
    await tapVisible(tester, button('Chagua faili la Excel'));
    expect(find.text('Mstari 2: Bei haisomeki.'), findsOneWidget);
    expect(button('Hifadhi menyu'), findsNothing);
    expect(office.imports, isEmpty);
  });
  testWidgets('station selection and clearing an override save together',
      (tester) async {
    final office = MenuOffice();
    await openMenu(tester, office, MNRoutes.officeStationMenu('s1'));
    await captureMenu(tester, 'station');
    expect(find.text('Menyu'), findsOneWidget);
    expect(find.text('Bidhaa 2 zimechaguliwa'), findsOneWidget);
    expect(find.text('Kwa kuku'), findsOneWidget);
    expect(find.text('Bei ya kituo'), findsOneWidget);
    await tapVisible(tester, find.text('Viazi'));
    expect(find.text('Bidhaa 1 imechaguliwa'), findsOneWidget);
    await tapVisible(tester, find.text('TZS 13,000'));
    final priceField = find.descendant(
        of: field('Bei ya kituo'), matching: find.byType(TextField));
    await tester.enterText(priceField, '');
    await tapVisible(tester, button('Hifadhi').last);
    await tester.pumpAndSettle();
    expect(find.text('TZS 12,000'), findsOneWidget);
    await tapVisible(tester, button('Hifadhi'));
    // The reason is asked for in a sheet, only when saving.
    await saveWithReason(tester, 'Bei ya kawaida');
    expect(office.saves.single['expected_revision'], 7);
    expect(office.saves.single['items'], [
      {'code': 'KUKU', 'station_price': null}
    ]);
  });
  testWidgets(
      'empty station menu remains explicit and save retry preserves UUID',
      (tester) async {
    final office = MenuOffice()..fail = true;
    await openMenu(tester, office, MNRoutes.officeStationMenu('s1'));
    await tapVisible(tester, find.text('Ondoa zote'));
    expect(find.text('Bidhaa 0 zimechaguliwa'), findsOneWidget);
    expect(find.text('Chagua zote'), findsOneWidget);
    await tapVisible(tester, button('Hifadhi'));
    await saveWithReason(tester, 'Hakuna menyu');
    await tapVisible(tester, button('Jaribu tena'));
    expect(office.saves.length, 2);
    expect(office.saves.first, office.saves.last);
    expect(office.saves.first['items'], isEmpty);
  });
  testWidgets('Hifadhi stays off until something changes', (tester) async {
    final office = MenuOffice();
    await openMenu(tester, office, MNRoutes.officeStationMenu('s1'));
    expect(tester.widget<MNButton>(button('Hifadhi')).onPressed, isNull);
    expect(find.text('Fanya mabadiliko ili kuhifadhi'), findsOneWidget);
    await tapVisible(tester, find.text('Viazi'));
    expect(tester.widget<MNButton>(button('Hifadhi')).onPressed, isNotNull);
    expect(find.text('Fanya mabadiliko ili kuhifadhi'), findsNothing);
    // Undoing the change turns it off again.
    await tapVisible(tester, find.text('Viazi'));
    expect(tester.widget<MNButton>(button('Hifadhi')).onPressed, isNull);
    // A short reason is refused in the sheet; nothing is sent.
    await tapVisible(tester, find.text('Viazi'));
    await tapVisible(tester, button('Hifadhi'));
    await saveWithReason(tester, 'ab');
    expect(find.text('Andika sababu (angalau herufi 3).'), findsWidgets);
    expect(office.saves, isEmpty);
  });
  testWidgets('an item without a price is locked until it is priced',
      (tester) async {
    final office = MenuOffice()
      ..stationItems = [
        menuItem('MAINI', 'Maini', price: null, selected: false),
        menuItem('KIDALI', 'Kidali', price: 2500, selected: true),
      ];
    await openMenu(tester, office, MNRoutes.officeStationMenu('s1'));
    expect(find.text('Hakuna bei'), findsOneWidget);
    expect(find.text('Weka bei ili uiuze'), findsOneWidget);
    // "Chagua zote" skips the unpriced item.
    await tapVisible(tester, find.text('Ondoa zote'));
    await tapVisible(tester, find.text('Chagua zote'));
    expect(find.text('Bidhaa 1 imechaguliwa'), findsOneWidget);
    // Tapping the locked item asks for its price, then chooses it.
    await tapVisible(tester, find.text('Maini'));
    await tester.enterText(
        find.descendant(
            of: field('Bei ya kituo'), matching: find.byType(TextField)),
        '1500');
    await tapVisible(tester, button('Hifadhi').last);
    await tester.pumpAndSettle();
    expect(find.text('Hakuna bei'), findsNothing);
    expect(find.text('TZS 1,500'), findsOneWidget);
    expect(find.text('Bidhaa 2 zimechaguliwa'), findsOneWidget);
  });
  testWidgets('a long menu shows ten rows at a time', (tester) async {
    final office = MenuOffice()
      ..stationItems = [
        for (var i = 1; i <= 23; i++)
          menuItem('P$i', 'Bidhaa ${i.toString().padLeft(2, '0')}',
              price: 1000, selected: false),
      ];
    await openMenu(tester, office, MNRoutes.officeStationMenu('s1'));
    expect(find.text('Bidhaa 10'), findsOneWidget);
    expect(find.text('Bidhaa 11'), findsNothing);
    await tapVisible(tester, button('Zaidi'));
    expect(find.text('Bidhaa 20'), findsOneWidget);
    expect(find.text('Bidhaa 21'), findsNothing);
    await tapVisible(tester, button('Zaidi'));
    expect(find.text('Bidhaa 23'), findsOneWidget);
    expect(button('Zaidi'), findsNothing);
    // "Chagua zote" chooses every shown match, not only the first page.
    await tapVisible(tester, find.text('Chagua zote'));
    expect(find.text('Bidhaa 23 zimechaguliwa'), findsOneWidget);
    // Searching starts again from the first page.
    await tester.enterText(find.byType(TextField).first, 'Bidhaa 2');
    await tester.pumpAndSettle();
    expect(find.text('Bidhaa 20'), findsOneWidget);
    expect(find.text('Bidhaa 23'), findsOneWidget);
    expect(button('Zaidi'), findsNothing);
  });
  testWidgets('menu screens fit 320px at double text', (tester) async {
    final app = await openMenu(
        tester, MenuOffice(), MNRoutes.officeStationMenu('s1'),
        size: const Size(320, 568), textScale: 2);
    expect(tester.takeException(), isNull);
    app.router.push(MNRoutes.officeMenuImport);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tapVisible(tester, button('Chagua faili la Excel'));
    expect(tester.takeException(), isNull);
  });
}
