import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/shared/widgets/components.dart';

void main() {
  testWidgets('Omoterra select opens the custom picker and returns a choice',
      (tester) async {
    var selected = 'one';
    await tester.pumpWidget(MaterialApp(
      theme: omoterraTheme(),
      home: Scaffold(
          body: StatefulBuilder(
              builder: (context, setState) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: OmoterraDropdown<String>(
                      label: 'Supply type',
                      value: selected,
                      items: const [
                        DropdownMenuItem(
                            value: 'one', child: Text('Option one')),
                        DropdownMenuItem(
                            value: 'two', child: Text('Option two')),
                      ],
                      onChanged: (value) => setState(() => selected = value!),
                    ),
                  ))),
    ));

    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.tap(find.text('Option one'));
    await tester.pumpAndSettle();
    expect(find.text('Supply type'), findsNWidgets(2));
    expect(find.text('Option two'), findsOneWidget);
    await tester.tap(find.text('Option two'));
    await tester.pumpAndSettle();
    expect(find.text('Option two'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });
}
