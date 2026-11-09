import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';

/// Every problem kind the server titles in notifications.py (PROBLEMS) has a
/// label on the office screens, so a raw code is never shown.
void main() {
  test('every server problem kind has an office label', () {
    final source =
        File('../backend/mr_nyama/notifications.py').readAsStringSync();
    final table = RegExp(r'PROBLEMS[^=]*=\s*\{(.*?)\n\}', dotAll: true)
        .firstMatch(source)!
        .group(1)!;
    final kinds = RegExp(r"^\s*'([a-z_]+)':", multiLine: true)
        .allMatches(table)
        .map((m) => m.group(1)!)
        .toList();
    expect(kinds, isNotEmpty);
    for (final language in ['sw', 'en']) {
      final s = Strings(language);
      final missing = [for (final k in kinds) if (s.problemKind(k) == k) k];
      expect(missing, isEmpty, reason: 'no label in $language for $missing');
    }
  });
}
