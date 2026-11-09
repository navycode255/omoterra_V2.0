import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// User rule (23 October 2026): the app never shows the platform's date or
/// time pickers or dropdown menus. Dates use `showMNDateSheet` /
/// `showMNDateRangeSheet`, times `showMNTimeSheet`, and choices
/// `MNSelectField` (lib/shared/widgets/).
void main() {
  test('lib/ uses no system date/time pickers or dropdowns', () {
    final banned = RegExp(r'\b(showDatePicker|showTimePicker|'
        r'showDateRangePicker|DropdownButtonFormField|DropdownButton)\b');
    final hits = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = file.readAsLinesSync();
      for (final (i, line) in lines.indexed) {
        final m = banned.firstMatch(line);
        if (m != null) hits.add('${file.path}:${i + 1}: ${m.group(0)}');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
