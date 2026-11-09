import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/media/photo_cache.dart';
import 'package:mr_nyama_vendor/shared/widgets/avatar.dart';
import 'package:mr_nyama_vendor/shared/widgets/image_spinner.dart';

void main() {
  const a =
      'https://storage.test/profiles/x/abc.jpg?X-Amz-Signature=1&Expires=1';
  const b =
      'https://storage.test/profiles/x/abc.jpg?X-Amz-Signature=2&Expires=2';
  const other = 'https://storage.test/profiles/x/def.jpg?X-Amz-Signature=1';

  group('a re-signed link is the same photo', () {
    test('identity ignores the signature', () {
      expect(photoIdentity(a), photoIdentity(b));
      expect(photoIdentity(a), isNot(photoIdentity(other)));
    });

    test('the image cache sees one image', () {
      expect(CachedPhoto(a), CachedPhoto(b));
      expect(CachedPhoto(a).hashCode, CachedPhoto(b).hashCode);
      expect(CachedPhoto(a), isNot(CachedPhoto(other)));
    });
  });

  group('copies on the phone', () {
    late Directory folder;
    late int downloads;
    final bytes = Uint8List.fromList([1, 2, 3]);

    setUp(() {
      folder = Directory.systemTemp.createTempSync('photos');
      downloads = 0;
      PhotoStore.directory = () async => folder;
      PhotoStore.download = (_) async {
        downloads++;
        return bytes;
      };
    });
    tearDown(() {
      if (folder.existsSync()) folder.deleteSync(recursive: true);
    });

    test('are fetched once, whatever the signature', () async {
      expect(await PhotoStore.read(a), bytes);
      expect(await PhotoStore.read(b), bytes);
      expect(downloads, 1);
      await PhotoStore.read(other);
      expect(downloads, 2);
    });

    test('leave no partial file', () async {
      await PhotoStore.read(a);
      expect(folder.listSync().where((f) => f.path.endsWith('.part')), isEmpty);
    });

    test('a failed fetch keeps nothing and tries again', () async {
      PhotoStore.download = (_) async => throw const SocketException('off');
      await expectLater(PhotoStore.read(a), throwsA(isA<SocketException>()));
      expect(folder.listSync(), isEmpty);
      PhotoStore.download = (_) async => bytes;
      expect(await PhotoStore.read(a), bytes);
    });

    test('still show without a cache folder', () async {
      PhotoStore.directory = () async => null;
      expect(await PhotoStore.read(a), bytes);
    });

    test('are gone after clearing and a damaged one is dropped', () async {
      await PhotoStore.read(a);
      await PhotoStore.forget(a);
      await PhotoStore.read(a);
      expect(downloads, 2);
      await PhotoStore.clear();
      expect(folder.existsSync(), isFalse);
    });
  });

  group('MNPersonPhoto', () {
    Widget photo(String? url) => MaterialApp(
        home: Scaffold(
            body: MNPersonPhoto(
                imageUrl: url,
                size: 46,
                color: Colors.grey,
                initials: const Text('AJ'))));

    testWidgets('without a photo shows initials', (tester) async {
      await tester.pumpWidget(photo(null));
      expect(find.text('AJ'), findsOneWidget);
      expect(find.byType(MNLoadingImage), findsNothing);
    });

    testWidgets('with a photo loads it, and failure falls back to initials',
        (tester) async {
      PhotoStore.directory = () async => null;
      PhotoStore.download = (_) async => throw const SocketException('off');
      await tester.pumpWidget(photo(a));
      expect(find.byType(MNLoadingImage), findsOneWidget);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(find.text('AJ'), findsOneWidget);
    });
  });

  test('vendor and staff rows read the photo link', () {
    expect(
        OfficeVendor.fromJson(const {
          'id': 'v',
          'name': 'Asha',
          'profile_image_url': a,
        }).imageUrl,
        a);
    expect(
        OfficeStaff.fromJson(const {
          'id': 's',
          'name': 'Juma',
          'profile_image_url': a,
        }).imageUrl,
        a);
    expect(OfficeVendor.fromJson(const {'id': 'v', 'name': 'Asha'}).imageUrl,
        null);
  });
}
