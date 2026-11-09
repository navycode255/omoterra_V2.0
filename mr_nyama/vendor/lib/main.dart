import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/sync/background_sync.dart';
import 'dev/perf_harness.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (devPerfHarnessEnabled) return runApp(const PerfHarness());
  if (!kIsWeb && Platform.isAndroid) unawaited(registerBackgroundSync());
  runApp(const ProviderScope(child: MrNyamaApp()));
}
