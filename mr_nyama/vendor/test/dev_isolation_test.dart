import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sample data must never reach a production workflow: only `lib/dev/` may
/// import it, only the router may import the showcase (behind
/// `devShowcaseEnabled`), and that flag is compile-time false in release.
void main() {
  Iterable<(String, String)> sources() sync* {
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      yield (f.path.replaceAll(r'\', '/'), f.readAsStringSync());
    }
  }

  test('sample data is imported only inside lib/dev', () {
    final importers = [
      for (final (path, source) in sources())
        if (source.contains('sample_data.dart') && !path.startsWith('lib/dev/'))
          path
    ];
    expect(importers, isEmpty);
  });

  test('the showcase is imported only by the router', () {
    final importers = [
      for (final (path, source) in sources())
        if (source.contains('dev/showcase.dart')) path
    ];
    expect(importers, ['lib/core/routing/router.dart']);
  });

  test('the preview repository is wired in exactly two places', () {
    final importers = [
      for (final (path, source) in sources())
        if (source.contains('dev/preview_repository.dart')) path
    ]..sort();
    expect(importers, ['lib/app/app.dart', 'lib/core/api/providers.dart']);
  });

  test('the preview flag excludes release builds', () {
    final source = File('lib/dev/preview_repository.dart').readAsStringSync();
    expect(
        source,
        matches(RegExp(r"const devPreviewEnabled\s*=\s*"
            r"!kReleaseMode && bool\.fromEnvironment\('MN_PREVIEW'\);")));
  });

  test('the showcase flag excludes release builds', () {
    final source = File('lib/dev/showcase.dart').readAsStringSync();
    expect(
        source,
        matches(RegExp(r"const devShowcaseEnabled\s*=\s*"
            r"!kReleaseMode && bool\.fromEnvironment\('MN_SHOWCASE'\);")));
  });

  test('no sample or fixture data in production code', () {
    final suspicious =
        RegExp(r"sample-|Sampuli|SAMPULI|fixture", caseSensitive: false);
    final offenders = [
      for (final (path, source) in sources())
        if (!path.startsWith('lib/dev/') && suspicious.hasMatch(source)) path
    ];
    expect(offenders, isEmpty);
  });
}
