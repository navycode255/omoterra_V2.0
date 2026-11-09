import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mr_nyama_vendor/app/app.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/api/providers.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/auth/offline_unlock.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart';
import 'package:mr_nyama_vendor/core/routing/router.dart';
import 'package:mr_nyama_vendor/core/sync/sync_triggers.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/core/data/database.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:mr_nyama_vendor/core/theme/theme.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';

import 'fakes.dart';

export 'fakes.dart';

/// Common Android phone sizes (logical pixels).
const phoneSizes = {
  'small 320×568': Size(320, 568),
  'compact 360×640': Size(360, 640),
  'reference 390×844': Size(390, 844),
  'large 412×915': Size(412, 915),
};

const textScales = [1.0, 1.3, 2.0];

/// A small priced catalogue for sales tests. Prices are test data.
const testCatalog = CatalogSnapshot(mpesaRecipient: '123456', products: [
  CatalogItem(
      id: 'kuku',
      name: 'Kuku mzima',
      price: 9000,
      priceVersion: 'v1',
      category: 'kuku',
      available: 8),
  CatalogItem(
      id: 'paja',
      name: 'Paja (Robo)',
      price: 2000,
      priceVersion: 'v1',
      category: 'kuku',
      available: 3),
  CatalogItem(
      id: 'kidali',
      name: 'Kidali (Robo)',
      price: 2500,
      priceVersion: 'v1',
      category: 'kuku',
      imageKey: 'kidali'),
  CatalogItem(id: 'maini', name: 'Maini', price: null, category: 'vyakula'),
]);

void setScreen(WidgetTester tester,
    {Size size = const Size(390, 844),
    double textScale = 1,
    bool reducedMotion = false}) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = const FakeViewPadding(top: 24, bottom: 24)
    ..viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  if (reducedMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  }
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
}

enum StartAs { signedIn, signedOut, locked }

/// Pumps the real app (theme, router, shell) with a fake vendor API and an
/// in-memory session store and database ([repository] replaces the fake
/// entirely). Starts signed in on Nyumbani unless told otherwise. The development showcase and preview are off.
typedef TestApp = ({
  GoRouter router,
  ProviderContainer container,
  FakeVendorRepository api,
  InMemoryStore store,
  AppDatabase db
});

Future<TestApp> pumpApp(WidgetTester tester,
    {String? initial,
    StartAs startAs = StartAs.signedIn,
    FakeVendorRepository? api,
    VendorRepository? repository,
    OfficeRepository? office,
    DateTime? now,
    Stream<bool>? connectivity,
    Size size = const Size(390, 844),
    double textScale = 1,
    bool reducedMotion = false,
    void Function(InMemoryStore store)? seed,
    List<Override> overrides = const []}) async {
  setScreen(tester,
      size: size, textScale: textScale, reducedMotion: reducedMotion);
  final store = InMemoryStore();
  switch (startAs) {
    case StartAs.signedIn:
      store.signIn(lastActive: now);
    case StartAs.locked:
      store.signIn(
          lastActive: DateTime.now().subtract(const Duration(hours: 13)));
    case StartAs.signedOut:
      break;
  }
  seed?.call(store);
  final fakeApi = api ?? FakeVendorRepository();
  final db = testDatabase();
  addTearDown(db.close);
  final container = ProviderContainer(overrides: [
    ...overrides,
    databaseProvider.overrideWithValue(db),
    vendorRepositoryProvider.overrideWithValue(repository ?? fakeApi),
    if (office != null) officeRepositoryProvider.overrideWithValue(office),
    keyValueStoreProvider.overrideWithValue(store),
    showcaseRouteProvider.overrideWithValue(false),
    if (now != null) clockProvider.overrideWithValue(() => now),
    connectivityProvider
        .overrideWith((ref) => connectivity ?? Stream.value(true)),
    foregroundSyncIntervalProvider.overrideWithValue(null),
    // The offline PIN verifier (Phase 11) with few rounds, on this isolate:
    // widget tests cannot wait for a background isolate.
    pinHasherProvider.overrideWithValue((pin, salt, rounds) async =>
        pbkdf2Sha256(utf8.encode(pin), salt, 3, 32)),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container, child: const RepaintBoundary(child: MrNyamaApp())));
  await tester.pumpAndSettle();
  final router = container.read(routerProvider);
  if (initial != null) {
    router.go(initial);
    await tester.pumpAndSettle();
  }
  return (
    router: router,
    container: container,
    api: fakeApi,
    store: store,
    db: db
  );
}

/// A component on a plain themed page.
Widget wrap(Widget child, {bool scroll = false}) => ProviderScope(
      child: MaterialApp(
        theme: mrNyamaTheme(),
        home: Scaffold(
          body: scroll ? ListView(children: [child]) : Center(child: child),
        ),
      ),
    );

/// A fresh in-memory database. Streams close synchronously so no timers
/// outlive a widget test.
AppDatabase testDatabase() =>
    AppDatabase(DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true));

/// Blind Funga Siku: taps "Hakiki hesabu", confirms the freeze, then gives
/// a reason and note to every product whose count differs.
Future<void> freezeCount(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(MNButton, 'Hakiki hesabu'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Endelea').last);
  await tester.pumpAndSettle();
  // A tall surface so every product row is built (the list is lazy).
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpAndSettle();
  final differing = find.text('Sababu ya tofauti (lazima)').evaluate().length;
  for (var i = 0; i < differing; i++) {
    final reason = find.text('Pungua wakati wa mauzo').at(i);
    await tester.ensureVisible(reason);
    await tester.tap(reason);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(i), 'Wateja wengi leo.');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
  }
}
