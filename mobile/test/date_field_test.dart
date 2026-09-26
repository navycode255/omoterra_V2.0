import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/shared/widgets/components.dart';

Widget _form(
        GlobalKey<FormState> key, TextEditingController c, bool optional) =>
    MaterialApp(
        home: Scaffold(
            body: Form(
                key: key,
                child: OmoterraDateField('Ready by', c, optional: optional))));

void main() {
  testWidgets('an optional date may stay empty, and can be cleared',
      (tester) async {
    final key = GlobalKey<FormState>();
    final c = TextEditingController(text: '2027-01-05');
    await tester.pumpWidget(_form(key, c, true));
    await tester.tap(find.byTooltip('Clear date'));
    await tester.pump();
    expect(c.text, '');
    expect(key.currentState!.validate(), isTrue);
    expect(find.text('Any date'), findsOneWidget);
  });

  testWidgets('a required date still must be chosen', (tester) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(_form(key, TextEditingController(), false));
    expect(key.currentState!.validate(), isFalse);
  });

  testWidgets('tapping opens a calendar instead of asking for YYYY-MM-DD',
      (tester) async {
    final c = TextEditingController();
    await tester.pumpWidget(_form(GlobalKey<FormState>(), c, true));
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(DateTime.tryParse(c.text), isNotNull);
  });
}
