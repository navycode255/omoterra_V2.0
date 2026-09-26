import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/shared/widgets/support_contact.dart';

class _Config extends LocalRepository {
  final String phone;
  _Config(this.phone);
  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) async =>
      path == '/config' ? {'support_phone': phone} : super.read(path, query);
}

Future<ProviderContainer> _pump(WidgetTester tester, String phone) async {
  final container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(_Config(phone))]);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          theme: omoterraTheme(),
          home: const Scaffold(body: SupportContact(topic: 'order #ABC')))));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('no support number configured means no dead buttons',
      (tester) async {
    await _pump(tester, '');
    expect(find.byKey(const Key('support_contact')), findsNothing);
  });

  testWidgets('a configured number shows Call and WhatsApp', (tester) async {
    final container = await _pump(tester, '0712 345 678');
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(container.read(supportPhoneProvider).value, '255712345678');
  });

  testWidgets('an international number is kept as is', (tester) async {
    final container = await _pump(tester, '+255 712 345 678');
    expect(container.read(supportPhoneProvider).value, '255712345678');
  });
}
