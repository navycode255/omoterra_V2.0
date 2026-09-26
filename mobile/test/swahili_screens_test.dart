import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/auth/session.dart';
import 'package:omoterra/core/l10n/strings.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/account/role_registration_screen.dart';
import 'package:omoterra/features/supplier/screens.dart';
import 'package:omoterra/shared/widgets/rating.dart';

/// The walk-through in the plan's "done when": a Kiswahili member sees
/// Kiswahili through registration, adding stock, an order and a rating.
const sw = Strings('sw');

Widget _swahili(Widget child, [OmoterraRepository? repository]) =>
    ProviderScope(
        overrides: [
          stringsProvider.overrideWithValue(sw),
          repositoryProvider.overrideWithValue(repository ?? LocalRepository()),
        ],
        child: MaterialApp(
            theme: omoterraTheme(),
            locale: const Locale('sw'),
            supportedLocales: const [Locale('en'), Locale('sw')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: child));

class _Orders extends LocalRepository {
  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) async {
    if (path == '/supplier/orders') {
      return [
        {
          'id': 'abcdef1234567890',
          'category': 'broilers',
          'quantity': '40',
          'unit_type': 'bird',
          'expected_collection_date': '2026-10-02',
          'status': 'confirmed',
        }
      ];
    }
    return super.read(path, query);
  }
}

/// Signed in as an English-speaking buyer; records profile saves.
class _Profile extends LocalRepository {
  final saves = <Map<String, dynamic>>[];
  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) async =>
      path == '/me'
          ? {
              'id': 'u1',
              'phone': '+255712000000',
              'name': 'Asha',
              'region': 'Pwani',
              'language': 'en',
              'roles': ['buyer'],
              'buyer_type': 'restaurant',
            }
          : super.read(path, query);
  @override
  Future<dynamic> write(String path, Map<String, dynamic> data,
      {String method = 'POST', String? key}) async {
    if (path != '/me') return super.write(path, data, method: method, key: key);
    saves.add(data);
    return {...await read('/me'), ...data};
  }
}

void main() {
  testWidgets('supplier registration is in Kiswahili', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_swahili(const SupplierOnboardingWizard()));
    await tester.pumpAndSettle();

    expect(find.text(sw.stepSupplierIdentity), findsNWidgets(2));
    expect(find.text('Hatua 1 kati ya 6'), findsOneWidget);
    expect(find.text('Jina la shamba / msambazaji'), findsOneWidget);
    expect(find.text('Endelea'), findsOneWidget);
    expect(find.text('Supplier identity'), findsNothing);

    // Validation messages are translated too.
    await tester.tap(find.text('Endelea'));
    await tester.pumpAndSettle();
    expect(find.text(sw.fieldRequired), findsWidgets);
  });

  testWidgets('adding stock is in Kiswahili, categories included',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_swahili(const AddStockScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Ongeza Uzalishaji / Bidhaa'), findsOneWidget);
    expect(find.text(sw.selectCategory), findsOneWidget);
    expect(find.text('Kuku wa nyama'), findsOneWidget);
    expect(find.text('Mayai'), findsOneWidget);

    await tester.ensureVisible(find.text('Mayai'));
    await tester.tap(find.text('Mayai'));
    await tester.pump();
    await tester.tap(find.text('Endelea'));
    await tester.pumpAndSettle();
    expect(find.text('Kiasi (trei)'), findsOneWidget);
    expect(find.text('Ukubwa wa Trei'), findsOneWidget);
    expect(find.text('Tarehe inayotarajiwa kuwa tayari'), findsOneWidget);
    expect(find.text('Rudi'), findsOneWidget);
  });

  testWidgets('a supplier order reads in Kiswahili', (tester) async {
    await tester.pumpWidget(
        _swahili(const Scaffold(body: SupplierOrders()), _Orders()));
    await tester.pumpAndSettle();

    expect(find.text('Maagizo na uhifadhi'), findsOneWidget);
    expect(find.text('Uhifadhi #ABCDEF12'), findsOneWidget);
    expect(find.text('Kuku wa nyama · 40 kuku'), findsOneWidget);
    expect(find.text('Uchukuaji unatarajiwa 2 Okt 2026'), findsOneWidget);
    expect(find.text('●  Imethibitishwa'), findsOneWidget);
  });

  testWidgets('rating an order is in Kiswahili', (tester) async {
    await tester.pumpWidget(_swahili(Scaffold(
        body: SingleChildScrollView(
            child: RateOrderCard(
                orderId: 'o1', rating: null, canRate: true, onRated: () {})))));

    expect(find.text('Agizo hili lilikuwaje?'), findsOneWidget);
    expect(find.text('Tuma tathmini'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('nyota 4'));
    await tester.pump();
    expect(find.text('Nzuri sana'), findsOneWidget);
    expect(find.text('Very good'), findsNothing);
  });

  test('every API request says which language to answer in', () async {
    FlutterSecureStorage.setMockInitialValues({'session': 'token'});
    final seen = <String?>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example'))
      ..interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        seen.add(options.headers['Accept-Language'] as String?);
        handler.resolve(Response(
            requestOptions: options, statusCode: 200, data: {'ok': true}));
      }));
    var language = 'sw';
    final repository = ApiRepository(dio, language: () => language);
    await repository.read('/me');
    language = 'en';
    await repository.read('/me');
    expect(seen, ['sw', 'en']);
  });

  test('switching language when signed in saves it on the profile', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({'session': 'token'});
    final repository = _Profile();
    final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repository)]);
    addTearDown(container.dispose);
    await container.read(sessionProvider.future);

    await container.read(sessionProvider.notifier).setLanguage('sw');

    // The server writes errors and notifications in the saved language.
    expect(repository.saves.single['language'], 'sw');
    expect(repository.saves.single['roles'], ['buyer']);
    expect(container.read(stringsProvider).isSwahili, isTrue);
  });
}
