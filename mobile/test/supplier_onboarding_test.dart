import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/features/account/role_registration_screen.dart';

class _Recorder extends LocalRepository {
  String? path;
  Map<String, dynamic>? sent;
  @override
  Future<dynamic> write(String path, Map<String, dynamic> data,
      {String method = 'POST', String? key}) async {
    this.path = path;
    sent = data;
    return {'id': 'referral-1'};
  }
}

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
    // The exact farm location is required, not just the typed directions.
    expect(find.textContaining('Add the farm location'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('farm_map_link')),
        'Maili Moja Farm https://www.google.com/maps/place/Maili+Moja/@-6.78,38.9,15z/data=!3d-6.781234!4d38.912345');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('-6.781234, 38.912345'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Continue'), 300,
        scrollable: find.byType(Scrollable).first);
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
    expect(find.text('-6.781234, 38.912345'), findsOneWidget);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets(
      'staff register someone else with the same full wizard, plus their phone and notes',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Recorder();
    var registered = false;
    await tester.pumpWidget(ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
            home: SupplierOnboardingWizard(
                onBehalf: true, onRegistered: () => registered = true))));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('public_alias')), 'JM Poultry Supply');
    await tester.enterText(find.byKey(const Key('legal_name')), 'Jane Farmer');
    await tester.enterText(find.byKey(const Key('region')), 'Pwani');
    await tester.enterText(find.byKey(const Key('district')), 'Kibaha');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    // The supplier's own phone is required and must be a mobile number.
    expect(find.text('This field is required'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('phone')), '0713 000 010');
    await tester.enterText(
        find.byKey(const Key('alternate_phone')), '0754000011');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Broilers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('internal_pickup_address')),
        'Maili Moja farm road');
    await tester.enterText(find.byKey(const Key('farm_map_link')),
        'https://www.google.com/maps/place/Maili+Moja/@-6.78,38.9,15z/data=!3d-6.781234!4d38.912345');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Continue'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('internal_notes')), 'Visited on market day');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('+255713000010'), findsOneWidget);
    await tester.tap(find.text('Submit registration'));
    await tester.pumpAndSettle();

    expect(repo.path, '/referrals/supplier');
    expect(repo.sent!['phone'], '+255713000010');
    expect(repo.sent!['alternate_phone'], '+255754000011');
    expect(repo.sent!['internal_notes'], 'Visited on market day');
    expect(repo.sent!['public_alias'], 'JM Poultry Supply');
    expect(repo.sent!['categories'], ['broilers']);
    expect(repo.sent!['internal_pickup_address'], 'Maili Moja farm road');
    expect(registered, isTrue);
  });
}
