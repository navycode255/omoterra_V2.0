import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/l10n/language.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';

import 'helpers.dart';
import 'office_test.dart' show FakeOfficeRepository;

void main() {
  test('the choice is kept on the phone; nothing saved means Swahili',
      () async {
    final db = testDatabase();
    addTearDown(db.close);
    expect(await savedLanguage(db), isNull);
    await saveLanguage(db, 'en');
    expect(await savedLanguage(db), 'en');
    await saveLanguage(db, 'sw');
    expect(await savedLanguage(db), 'sw');
  });

  testWidgets('Swahili by default; the vendor switches to English in Wasifu',
      (tester) async {
    final app = await pumpApp(tester);
    expect(app.container.read(languageProvider), 'sw');
    app.router.push(MNRoutes.profile);
    await tester.pumpAndSettle();
    expect(find.text('Lugha'), findsOneWidget);
    expect(find.text('Kiswahili'), findsOneWidget);
    await tester.tap(find.text('Lugha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    // The whole app follows at once, and the choice is kept.
    expect(app.container.read(languageProvider), 'en');
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Change PIN'), findsOneWidget);
    expect(await savedLanguage(app.db), 'en');
    expect(tester.takeException(), isNull);
  });

  testWidgets('office staff switch language in Akaunti', (tester) async {
    final office = FakeOfficeRepository()..signedIn = true;
    office.owner = const StaffProfile(
        id: 'o1',
        name: 'Neema Said',
        phone: '+255713000111',
        roles: [StaffRole.finance]);
    final app =
        await pumpApp(tester, startAs: StartAs.signedOut, office: office);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(office.owner);
    await tester.pumpAndSettle();
    app.router.go(MNRoutes.officeAccount);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lugha'));
    await tester.tap(find.text('Lugha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(await savedLanguage(app.db), 'en');
    expect(tester.takeException(), isNull);
  });
}
