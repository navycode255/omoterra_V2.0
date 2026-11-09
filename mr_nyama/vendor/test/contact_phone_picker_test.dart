import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/contacts/contact_phones.dart';
import 'package:mr_nyama_vendor/core/theme/theme.dart';
import 'package:mr_nyama_vendor/features/office/people_screens.dart';
import 'package:mr_nyama_vendor/shared/widgets/contact_phone_picker.dart';

class _FakeContacts implements ContactPhoneSource {
  final ContactAccess access;
  final List<ContactPhone> list;
  bool throws;
  int asked = 0;
  _FakeContacts(this.access, this.list, {this.throws = false});

  @override
  Future<ContactAccess> requestAccess() async {
    asked++;
    return access;
  }

  @override
  Future<List<ContactPhone>> phones() async {
    if (throws) throw StateError('unreadable');
    return list;
  }
}

Widget _phoneForm(TextEditingController controller, ContactPhoneSource source) =>
    ProviderScope(
      overrides: [contactPhoneSourceProvider.overrideWithValue(source)],
      child: MaterialApp(
        theme: mrNyamaTheme(),
        home: Scaffold(
            body: Padding(
                padding: const EdgeInsets.all(16),
                child: OfficePhoneInput(controller: controller))),
      ),
    );

const _people = [
  ContactPhone(name: 'Amina Juma', phone: '+255712345678'),
  ContactPhone(name: 'Baraka Mushi', phone: '+255754000111'),
];

void main() {
  test('contact numbers become Tanzanian mobiles, one per number, by name', () {
    final out = contactPhonesFrom([
      (name: 'Zawadi', numbers: ['0712 345 678', '+255 712-345-678', '255713000222']),
      (name: 'amina', numbers: ['+255 754 000 111', '022 211 0000', '12345']),
      (name: '', numbers: ['0688000333']),
    ]);
    expect([for (final c in out) '${c.name}=${c.phone}'], [
      '+255688000333=+255688000333',
      'amina=+255754000111',
      'Zawadi=+255712345678',
      'Zawadi=+255713000222',
    ]);
  });

  testWidgets('picking a contact fills the phone field; typing still works',
      (tester) async {
    final phone = TextEditingController();
    await tester.pumpWidget(
        _phoneForm(phone, _FakeContacts(ContactAccess.granted, _people)));
    await tester.enterText(find.byType(TextField), '0711');
    expect(phone.text, '0711');

    await tester.tap(find.bySemanticsLabel('Chagua kwenye anwani'));
    await tester.pumpAndSettle();
    expect(find.text('Anwani za simu'), findsOneWidget);
    expect(find.text('+255 754 000 111'), findsOneWidget);
    await tester.tap(find.text('Baraka Mushi'));
    await tester.pumpAndSettle();

    expect(phone.text, '754000111');
    expect(find.text('Anwani za simu'), findsNothing);
  });

  testWidgets('search narrows the contacts by name or number', (tester) async {
    final phone = TextEditingController();
    await tester.pumpWidget(
        _phoneForm(phone, _FakeContacts(ContactAccess.granted, _people)));
    await tester.tap(find.bySemanticsLabel('Chagua kwenye anwani'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '0712');
    await tester.pumpAndSettle();
    expect(find.text('Amina Juma'), findsOneWidget);
    expect(find.text('Baraka Mushi'), findsNothing);

    await tester.enterText(find.byType(TextField).last, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Hakuna anwani inayolingana.'), findsOneWidget);
  });

  testWidgets('refused permission says so and leaves the field to typing',
      (tester) async {
    final phone = TextEditingController(text: '712');
    final source = _FakeContacts(ContactAccess.denied, _people);
    await tester.pumpWidget(_phoneForm(phone, source));
    await tester.tap(find.bySemanticsLabel('Chagua kwenye anwani'));
    await tester.pumpAndSettle();

    expect(source.asked, 1);
    expect(find.text('Simu haikuruhusu kusoma anwani. Andika namba mwenyewe.'),
        findsOneWidget);
    expect(phone.text, '712');
  });

  testWidgets('unreadable contacts say so', (tester) async {
    final phone = TextEditingController();
    await tester.pumpWidget(_phoneForm(
        phone, _FakeContacts(ContactAccess.granted, _people, throws: true)));
    await tester.tap(find.bySemanticsLabel('Chagua kwenye anwani'));
    await tester.pumpAndSettle();
    expect(find.text('Anwani hazikusomeka. Andika namba mwenyewe.'),
        findsOneWidget);
    expect(phone.text, isEmpty);
  });

  testWidgets('no Tanzanian numbers shows an empty note', (tester) async {
    await tester.pumpWidget(_phoneForm(
        TextEditingController(), _FakeContacts(ContactAccess.granted, const [])));
    await tester.tap(find.bySemanticsLabel('Chagua kwenye anwani'));
    await tester.pumpAndSettle();
    expect(find.text('Hakuna namba ya simu ya Tanzania kwenye anwani zako.'),
        findsOneWidget);
  });

  testWidgets('a long contact list shows the first rows and a narrowing note',
      (tester) async {
    final many = [
      for (var i = 0; i < contactSheetLimit + 5; i++)
        ContactPhone(
            name: 'Mteja ${i.toString().padLeft(3, '0')}',
            phone: '+2557120${i.toString().padLeft(5, '0')}'),
    ];
    await tester.pumpWidget(_phoneForm(
        TextEditingController(), _FakeContacts(ContactAccess.granted, many)));
    await tester.tap(find.bySemanticsLabel('Chagua kwenye anwani'));
    await tester.pumpAndSettle();
    expect(find.text('Anwani 5 zaidi. Andika jina kupunguza.'), findsOneWidget);
  });
}
