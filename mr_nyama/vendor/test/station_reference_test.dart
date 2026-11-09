import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/media/photo_cache.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/product_screens.dart'
    show pickProductPhotoProvider;
import 'package:mr_nyama_vendor/features/office/station_screen.dart';

import 'package:mr_nyama_vendor/shared/widgets/account.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/image_spinner.dart';

import 'helpers.dart';
import 'station_management_test.dart' show StationOffice;

final _pixel = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0x50,
  0x0F,
  0x00,
  0x04,
  0x85,
  0x01,
  0x80,
  0x84,
  0xA9,
  0x8C,
  0x21,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82
]);

class _Reference extends StationOffice {
  _Reference() {
    stationsList[0] = const OfficeStation(
        id: 's1',
        code: 'MR01',
        name: 'Mr. Nyama 101',
        area: 'Bunju B, Njia ya Mwabwepande',
        stockLocationId: 'loc1');
    vendorsList.add(const OfficeVendor(
        id: 'mj',
        name: 'Maternus Joshua',
        phone: '+255712000111',
        activated: true,
        suspended: false,
        stationId: 's1',
        stationName: 'Mr. Nyama 101',
        stationCode: 'MR01'));
  }

  @override
  Future<List<Map<String, dynamic>>> stationStock(String id) async => [
        for (final p in ['KUKU', 'PAJA', 'KIDALI'])
          {'product': p, 'name': p, 'unit': 'piece', 'quantity': 4}
      ];
}

/// A photo that never finishes loading.
class _PendingImage extends ImageProvider<_PendingImage> {
  @override
  Future<_PendingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(_PendingImage key, ImageDecoderCallback d) =>
      OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}

Future<TestApp> open(WidgetTester tester, StationOffice repo,
    {String language = 'en', Uint8List? photo}) async {
  final app = await pumpApp(tester,
      startAs: StartAs.signedOut,
      office: repo,
      size: const Size(390, 1181),
      overrides: [
        pickProductPhotoProvider.overrideWithValue(() async => _pixel),
        stationImageProvider
            .overrideWithValue((_) => MemoryImage(photo ?? _pixel)),
      ]);
  tester.view
    ..padding = const FakeViewPadding(top: 44, bottom: 34)
    ..viewPadding = const FakeViewPadding(top: 44, bottom: 34);
  app.container.read(languageProvider.notifier).state = language;
  await app.container.read(officeSessionProvider.notifier).signedIn(repo.owner);
  app.router.go(MNRoutes.officeStation('s1'));
  await tester.pumpAndSettle();
  return app;
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('REFERENCE_CAPTURES')) return;
  await tester.pump();
  RenderObject? node = tester.renderObject(find.byType(Scaffold).first);
  RenderRepaintBoundary? root;
  while (node != null) {
    if (node is RenderRepaintBoundary) root = node;
    node = node.parent;
  }
  final image = (await tester.runAsync(() => root!.toImage(pixelRatio: 1.3)))!;
  final bytes = await tester
      .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  await tester.runAsync(() async {
    final dir = Directory('../../output/station-reference');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
  image.dispose();
}

void main() {
  testWidgets('no photo: the reference\'s sections, in order, and Add photo',
      (tester) async {
    final repo = _Reference();
    await open(tester, repo);
    for (final text in [
      'Mr. Nyama 101',
      'Station MR01',
      'Add photo',
      'Station information',
      'Bunju B, Njia ya Mwabwepande',
      'Not set',
      'Station people',
      'Maternus Joshua',
      'Vendor',
      'Station menu',
      'Products and station prices',
      'Station stock',
      'Stock',
      'Counts and returns',
      '3',
      'Delete station',
      'Only stations created by mistake can be deleted. Sales and stock history stay.',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    final order = [
      'Station information',
      'Station people',
      'Station menu',
      'Station stock',
      'Delete station'
    ].map((t) => tester.getTopLeft(find.text(t)).dy).toList();
    expect(order, [...order]..sort());
    expect(find.text('Credit customers'), findsNothing);
    expect(find.bySemanticsLabel('Photo options'), findsNothing);
    await capture(tester, '2-no-photo');
    expect(tester.takeException(), isNull);
  });

  testWidgets('add, change and remove the photo', (tester) async {
    // The ember ring keeps animating while a photo decodes, so nothing settles.
    Future<void> frames() async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    final repo = _Reference();
    await open(tester, repo);
    await tester.tap(find.text('Add photo'));
    await frames();
    expect(repo.photoUploads, hasLength(1));
    expect(find.text('Add photo'), findsNothing);
    expect(find.byType(Image), findsWidgets);

    await tester.tap(find.bySemanticsLabel('Photo options'));
    await frames();
    await tester.tap(find.text('Change photo'));
    await frames();
    expect(repo.photoUploads, hasLength(2));

    await tester.tap(find.bySemanticsLabel('Photo options'));
    await frames();
    await tester.tap(find.text('Remove photo'));
    await frames();
    expect(repo.photoRemoved, isTrue);
    expect(find.text('Add photo'), findsOneWidget);
  });

  testWidgets('a refused photo keeps the page and says so', (tester) async {
    final repo = _Reference()..refuse = true;
    await open(tester, repo);
    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    expect(repo.photoUploads, isEmpty);
    expect(find.text('Add photo'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('with a photo', (tester) async {
    Uint8List? photo;
    if (const bool.fromEnvironment('REFERENCE_CAPTURES')) {
      photo =
          File('../../output/station-reference/_hero.png').readAsBytesSync();
    }
    final repo = _Reference();
    await repo.uploadStationPhoto('s1', _pixel);
    await open(tester, repo, photo: photo);
    expect(find.bySemanticsLabel('Photo options'), findsOneWidget);
    expect(find.byType(MNLoadingImage), findsOneWidget);
    if (photo != null) {
      await tester.runAsync(() => precacheImage(
          MemoryImage(photo!), tester.element(find.byType(Scaffold).first)));
      await tester.pump();
    }
    await capture(tester, '1-with-photo');
  });

  testWidgets('the photo shows the ember ring while it loads and uploads',
      (tester) async {
    final repo = _Reference();
    await repo.uploadStationPhoto('s1', _pixel);
    final app = await pumpApp(tester,
        startAs: StartAs.signedOut,
        office: repo,
        size: const Size(390, 1181),
        overrides: [
          stationImageProvider.overrideWithValue((_) => _PendingImage()),
        ]);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(repo.owner);
    app.router.go(MNRoutes.officeStation('s1'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(MNImageSpinner), findsOneWidget);
    expect(find.byType(MNSpinner), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the profile avatar loads through the ember ring',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: MNAccountIdentity(
                name: 'Asha Juma',
                subtitle: 'Muuzaji',
                imageUrl: 'https://storage.test/a.jpg'))));
    expect(find.byType(MNLoadingImage), findsOneWidget);
    expect(find.byType(MNImageSpinner), findsOneWidget);
  });

  testWidgets('people show their photos on the management screens',
      (tester) async {
    PhotoStore.directory = () async => null;
    PhotoStore.download = (_) async => throw const SocketException('off');
    const photo = 'https://storage.test/profiles/a/b.jpg?sig=1';
    final repo = _Reference();
    repo.vendorsList.add(const OfficeVendor(
        id: 'pv',
        name: 'Photo Vendor',
        phone: '+255712000222',
        activated: true,
        suspended: false,
        stationId: 's1',
        stationName: 'Mr. Nyama 101',
        stationCode: 'MR01',
        imageUrl: photo));
    repo.staffList.add(const OfficeStaff(
        id: 'ps',
        name: 'Photo Staff',
        phone: '+255712000333',
        roles: [StaffRole.supervisor],
        stationIds: ['s1'],
        activated: true,
        suspended: false,
        imageUrl: photo));
    final app = await open(tester, repo);
    // On the station's page, and only for those who have one.
    expect(find.byType(MNLoadingImage), findsNWidgets(2));
    app.router.go(MNRoutes.officeVendors);
    await tester.pumpAndSettle();
    expect(find.text('Photo Vendor'), findsOneWidget);
    expect(find.byType(MNLoadingImage), findsOneWidget);
    app.router.go(MNRoutes.officeStaff);
    await tester.pumpAndSettle();
    expect(find.text('Photo Staff'), findsOneWidget);
    expect(find.byType(MNLoadingImage), findsOneWidget);
  });

  testWidgets('credit, performance and deliveries moved to the Stock page',
      (tester) async {
    final repo = _Reference();
    await open(tester, repo);
    await tester.tap(find.text('Stock'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Credit customers'));
    expect(find.text('Credit customers'), findsOneWidget);
    expect(find.text('Expected deliveries'), findsOneWidget);
  });
}
