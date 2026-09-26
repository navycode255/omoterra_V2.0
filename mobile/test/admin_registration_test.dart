import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/phone.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/admin/admin_screens.dart';

class _Staff extends LocalRepository {
  final writes = <String, Map<String, dynamic>>{};
  final referrals = <Map<String, dynamic>>[];
  String? failSignIn;
  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) async {
    if (path == '/mobile-admin/me') return {'name': 'Asha Staff'};
    if (path == '/referrals/mine') return referrals;
    return super.read(path, query);
  }

  @override
  Future<dynamic> write(String path, Map<String, dynamic> data,
      {String method = 'POST', String? key}) async {
    writes[path] = data;
    if (path == '/mobile-admin/auth/otp' && failSignIn != null) {
      throw ApiFailure(failSignIn!);
    }
    if (path == '/mobile-admin/auth/otp') {
      return {
        'challenge_id': 'ch-1',
        'otp_length': 6,
        'development_code': '482913'
      };
    }
    if (path == '/mobile-admin/auth/verify') {
      return {
        'session_token': 'op-token',
        'operator': {'name': 'Asha Staff'}
      };
    }
    if (path == '/referrals/buyer') {
      referrals.add({
        'role': 'buyer',
        'phone': data['phone'],
        'name': data['name'],
        'business_name': data['business_name'],
        'created_at': '2026-09-26T08:00:00Z',
      });
      return referrals.last;
    }
    return {};
  }
}

Future<_Staff> _open(WidgetTester tester, {String? token}) async {
  FlutterSecureStorage.setMockInitialValues(
      {if (token != null) 'operator_session': token});
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _Staff();
  final router = GoRouter(initialLocation: '/admin', routes: [
    GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminGate(child: AdminHome())),
    GoRoute(
        path: '/admin/buyer',
        builder: (_, __) => const AdminGate(child: AdminRegisterBuyer())),
  ]);
  await tester.pumpWidget(ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(theme: omoterraTheme(), routerConfig: router)));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  test('phone numbers are accepted however they are typed', () {
    for (final typed in [
      '0712 345 678',
      '712345678',
      '255712345678',
      '+255 712 345 678'
    ]) {
      expect(tanzanianMobile(typed), '+255712345678');
    }
    expect(tanzanianMobile('0812345678'), isNull);
    expect(tanzanianMobile('07123'), isNull);
  });

  testWidgets('staff sign in with passphrase, phone, then code',
      (tester) async {
    final repo = await _open(tester);
    expect(find.text('Staff sign-in'), findsOneWidget);
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the staff passphrase'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('admin_passphrase')), 'field-onboarding');
    await tester.enterText(
        find.byKey(const Key('admin_phone')), '0710 000 001');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(repo.writes['/mobile-admin/auth/otp'],
        {'passphrase': 'field-onboarding', 'phone': '+255710000001'});

    // No SMS provider yet: the test code is shown and already filled in.
    expect(find.text('Development code: 482913'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('admin_code')))
            .controller!
            .text,
        '482913');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Asha Staff'), findsOneWidget);
    expect(find.text('Nobody registered yet.'), findsOneWidget);
  });

  testWidgets('a buyer registered in three steps appears in the list',
      (tester) async {
    final repo = await _open(tester, token: 'op-token');
    await tester.tap(find.text('Buyer'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 3'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('buyer_business_name')), 'Asha Grill House');
    await tester.enterText(find.byKey(const Key('buyer_name')), 'Mama Asha');
    await tester.enterText(find.byKey(const Key('buyer_phone')), '0713000001');
    await tester.tap(find.text('Next: Where they are'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 3'), findsOneWidget);
    await tester.tap(find.text('Next: How they buy'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Broilers'));
    await tester.tap(find.widgetWithText(FilterChip, 'Friday'));
    await tester.enterText(find.byKey(const Key('buyer_minimum_order')), '50');
    await tester.enterText(
        find.byKey(const Key('buyer_internal_notes')), 'Met at Sinza market');
    await tester.tap(find.text('Finish registration'));
    await tester.pumpAndSettle();

    final sent = repo.writes['/referrals/buyer']!;
    expect(sent['phone'], '+255713000001');
    expect(sent['buyer_type'], 'restaurant');
    expect(sent['region'], 'Dar es Salaam');
    expect(sent['area'], 'Kinondoni');
    expect(sent['minimum_order'], '50');
    expect(sent['last_known_buying_price'], isNull);
    expect(sent['internal_notes'], 'Met at Sinza market');
    final preferences = sent['preferences'] as Map;
    expect(preferences['preferred_products'], ['broilers']);
    expect(preferences['preferred_days'], ['friday']);

    // Back on the staff home, the new buyer is listed.
    expect(find.text('Asha Grill House'), findsOneWidget);
    expect(find.textContaining('Buyer · +255713000001'), findsOneWidget);
  });

  testWidgets('a wrong phone number stops the first step', (tester) async {
    await _open(tester, token: 'op-token');
    await tester.tap(find.text('Buyer'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('buyer_business_name')), 'Asha Grill House');
    await tester.enterText(find.byKey(const Key('buyer_name')), 'Mama Asha');
    await tester.enterText(find.byKey(const Key('buyer_phone')), '12345');
    await tester.tap(find.text('Next: Where they are'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a Tanzanian mobile number'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);
  });

  testWidgets('sign-in failures show the real reason, not "check connection"',
      (tester) async {
    final repo = await _open(tester);
    repo.failSignIn = 'Mobile admin is turned off on this server.';
    await tester.enterText(
        find.byKey(const Key('admin_passphrase')), 'field-onboarding');
    await tester.enterText(find.byKey(const Key('admin_phone')), '0746484666');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(find.textContaining('isn’t switched on yet'), findsOneWidget);
    expect(find.textContaining('check your connection'), findsNothing);

    repo.failSignIn = 'That passphrase is not right.';
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(find.text('That passphrase is not right.'), findsOneWidget);
  });
}
