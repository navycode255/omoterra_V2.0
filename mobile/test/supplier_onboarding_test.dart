import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/features/account/role_registration_screen.dart';

void main() {
  testWidgets(
      'supplier onboarding captures identity, categories, pickup and review',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: SupplierOnboardingWizard())));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextFormField).at(0), 'JM Poultry Supply');
    await tester.enterText(find.byType(TextFormField).at(1), 'Jane Farmer');
    await tester.enterText(find.byKey(const Key('region')), 'Pwani');
    await tester.enterText(find.byKey(const Key('district')), 'Kibaha');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('What you supply'), findsNWidgets(2));
    await tester.tap(find.text('Broilers'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('capacity_broilers')), '2000');
    await tester.enterText(
        find.byKey(const Key('production_frequency')), 'Every 6 weeks');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('internal_pickup_address')),
        'Maili Moja farm road');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Current production'), findsNWidgets(2));

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Photos'), findsNWidgets(2));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Review'), findsNWidgets(2));
    expect(find.text('JM Poultry Supply'), findsOneWidget);
    expect(find.textContaining('Broilers'), findsOneWidget);
    expect(find.textContaining('reviewed by Omoterra'), findsOneWidget);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
