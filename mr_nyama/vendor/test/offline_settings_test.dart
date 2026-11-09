import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/owner_reference.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/input_field.dart';

import 'office_money_test.dart' show moneyOffice, openMoney;
import 'office_verification_test.dart' show tapVisible;

const sw = Strings('sw');

Finder _field(String key) => find.descendant(
    of: find.widgetWithText(MNTextField, sw.offlineLimitName(key)),
    matching: find.byType(TextField));

void main() {
  testWidgets(
      'the owner sets the three offline limits; out of range is refused',
      (tester) async {
    final office = moneyOffice();
    await openMoney(tester, office,
        roles: const ['business_owner'], route: MNRoutes.officeMoneySettings);
    await tester.scrollUntilVisible(find.text(sw.offlineSettingsTitle), 300,
        scrollable: find.byType(Scrollable).first);
    expect(
        find.descendant(
            of: find.widgetWithText(OwnerMenuRow, sw.offlineSettingsTitle),
            matching: find.text(sw.offlineOff)),
        findsOneWidget);
    await tapVisible(tester, find.text(sw.offlineSettingsTitle));
    final save = find.widgetWithText(MNButton, sw.saveChanges);
    await tester.ensureVisible(_field('offline.validity_hours'));
    await tester.enterText(_field('offline.validity_hours'), '900');
    await tapVisible(tester, save);
    expect(
        find.text(sw.offlineLimitInvalid(
            sw.offlineLimitName('offline.validity_hours'))),
        findsOneWidget);
    expect(office.settingWrites, isEmpty);
    await tester.enterText(_field('offline.validity_hours'), '48');
    await tester.enterText(_field('offline.relock_minutes'), '30');
    await tester.enterText(_field('offline.pin_attempts'), '5');
    await tapVisible(tester, save);
    expect([
      for (final w in office.settingWrites) (w['key'], w['value'])
    ], [
      ('offline.validity_hours', 48),
      ('offline.relock_minutes', 30),
      ('offline.pin_attempts', 5),
    ]);
    expect(tester.takeException(), isNull);
  });

  test('the limits are read from the settings', () {
    final s = OfficeMoneySettings.fromJson({
      'offline.validity_hours': 48,
      'offline.relock_minutes': 30,
      'offline.pin_attempts': null,
    });
    expect(s.offline,
        {'offline.validity_hours': 48, 'offline.relock_minutes': 30});
  });
}
