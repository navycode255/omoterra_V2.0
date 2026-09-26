import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/shared/media_cache.dart';
import 'package:omoterra/shared/widgets/components.dart';

/// A phone with nothing cached: records what the photo asked for.
class _EmptyCache implements BaseCacheManager {
  final keys = <String>[];
  final urls = <String>[];
  final headers = <Map<String, String>?>[];
  final removed = <String>[];

  @override
  Stream<FileResponse> getFileStream(String url,
      {String? key, Map<String, String>? headers, bool withProgress = false}) {
    keys.add(key ?? url);
    urls.add(url);
    this.headers.add(headers);
    return Stream.error(const SocketExceptionLike());
  }

  @override
  Future<void> removeFile(String key) async => removed.add(key);

  @override
  Future<void> emptyCache() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}

/// The server's answer to "may I see this photo?".
class _Signer extends LocalRepository {
  final FutureOr<SignedMedia?> Function() answer;
  var asked = 0;
  _Signer(this.answer);
  @override
  Future<SignedMedia?> mediaLink(String url) async {
    asked++;
    return answer();
  }
}

Future<_EmptyCache> _show(WidgetTester tester, _Signer server,
    {bool fresh = true}) async {
  final cache = _EmptyCache();
  debugMediaCache = cache;
  if (fresh) await clearMediaCache();
  await tester.pumpWidget(ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(server)],
      child: MaterialApp(
          theme: omoterraTheme(),
          home: const Scaffold(
              body: ProductImage(['/media/abc'], category: 'broilers')))));
  await tester.pumpAndSettle();
  return cache;
}

void main() {
  test('photos are cached by media id, not by address', () {
    expect(mediaCacheKey('/media/abc'), 'media:abc');
  });

  testWidgets(
      'an uncached photo offline shows the category picture, not a broken icon',
      (tester) async {
    final cache = await _show(tester,
        _Signer(() => throw const ApiFailure('We could not reach Omoterra.')));

    // Only a copy already on the phone could show; nothing is removed.
    expect(cache.keys, ['media:abc']);
    expect(cache.removed, isEmpty);
    expect(find.text('Photo shows when you’re back online'), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a signed photo downloads from its link, cached by media id',
      (tester) async {
    final server = _Signer(() => SignedMedia(
        'https://r2.example/livestock/photos/abc.jpg?X-Amz-Signature=1',
        DateTime.now().add(const Duration(minutes: 10))));
    final cache = await _show(tester, server);

    expect(cache.keys, ['media:abc']);
    expect(cache.urls,
        ['https://r2.example/livestock/photos/abc.jpg?X-Amz-Signature=1']);
    // The signature is the permission: no sign-in token goes to storage.
    expect(cache.headers.single?['Authorization'], isNull);

    // Shown again while the link is fresh: the server isn't asked again.
    await tester.pumpWidget(const SizedBox());
    await _show(tester, server, fresh: false);
    expect(server.asked, 1);
  });

  testWidgets('a photo the server refuses is removed from the phone',
      (tester) async {
    final cache = await _show(tester, _Signer(() => null));

    expect(cache.removed, ['media:abc']);
    expect(cache.keys, isEmpty);
    expect(find.text('Photo shows when you’re back online'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
