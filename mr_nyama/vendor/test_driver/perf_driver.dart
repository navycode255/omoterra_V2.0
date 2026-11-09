import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Writes the frame-timing summaries reported by `watchPerformance` to
/// `build/motion_perf.json` and prints them.
Future<void> main() => integrationDriver(
      responseDataCallback: (data) async {
        if (data == null) return;
        final json = const JsonEncoder.withIndent('  ').convert(data);
        await File('build/motion_perf.json').writeAsString(json);
        // ignore: avoid_print
        print(json);
      },
    );
