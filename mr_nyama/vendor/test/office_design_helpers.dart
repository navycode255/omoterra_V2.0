import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/features/office/owner_widgets.dart';

Future<void> expandOfficeDetails(WidgetTester tester, String title) async {
  final section = find
      .byWidgetPredicate(
          (widget) => widget is OwnerDetails && widget.title == title)
      .first;
  final heading =
      find.descendant(of: section, matching: find.text(title)).first;
  await tester.ensureVisible(heading);
  await tester.pumpAndSettle();
  await tester.tap(heading);
  await tester.pumpAndSettle();
}

Future<void> openOfficeHelp(WidgetTester tester) async {
  final help = find.byType(OwnerHelp).first;
  await tester.ensureVisible(help);
  await tester.pumpAndSettle();
  await tester
      .tap(find.descendant(of: help, matching: find.byType(TextButton)).first);
  await tester.pumpAndSettle();
}
