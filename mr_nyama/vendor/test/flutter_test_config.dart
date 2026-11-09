import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

/// Runs before every test file. Loads bundled Manrope and Inter so text has its
/// real width and height; layout and overflow tests would otherwise measure
/// the test font.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  for (final family in ['Manrope', 'Inter']) {
    final bytes = File('assets/fonts/$family.ttf').readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
    await loader.load();
  }
  // Each test opens its own in-memory database on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await testMain();
}
