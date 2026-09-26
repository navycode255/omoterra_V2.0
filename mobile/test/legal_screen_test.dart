import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/account/legal_screen.dart';

void main() {
  testWidgets('shows every section of the bundled Privacy Policy',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            theme: omoterraTheme(), home: const LegalScreen('privacy'))));
    await tester.runAsync(() => legalContent);
    await tester.pumpAndSettle();
    expect(find.text('Privacy Policy'), findsWidgets);
    expect(find.text('Who is responsible for your data'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Deleting your account'), 400);
    expect(find.text('Deleting your account'), findsOneWidget);
  });
}
