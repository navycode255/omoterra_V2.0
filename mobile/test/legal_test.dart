import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the app bundles the same Terms and Privacy Policy as the website', () {
    // ops/content/legal.json is the source; copy it into the app after edits:
    //   cp ops/content/legal.json mobile/assets/legal/legal.json
    final website = File('../ops/content/legal.json').readAsStringSync();
    final app = File('assets/legal/legal.json').readAsStringSync();
    expect(app, website);
  });
}
