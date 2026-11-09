// Task 6: the owner's registration form and the change, purchase and
// details sheets of Mali za biashara. Uses its own fake (below) rather than
// the Task 5 one, so it can record writes and fail once.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_assets.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart'
    show AuthFailure, AuthFailureKind;
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/quantity.dart';

import 'helpers.dart';
import 'office_test.dart' show FakeOfficeRepository;

const _cat = AssetCategory(id: 'c1', name: 'Majiko');
const _k1 = AssetLocation(
    id: 'loc1', name: 'Kariakoo', kind: 'station', stationId: 'st1');
const _k2 = AssetLocation(
    id: 'loc2', name: 'Mwenge', kind: 'station', stationId: 'st2');

Asset _asset(String id, {String? number, int quantity = 1}) => Asset(
    id: id,
    name: 'Jiko',
    number: number,
    unit: 'pcs',
    tracking: number == null ? 'counted' : 'numbered',
    category: _cat,
    location: _k1,
    quantity: quantity);

class FormOffice extends FakeOfficeRepository
    implements OfficeAssetsRepository {
  final drafts = <AssetDraft>[];
  final purchases = <Map<String, Object?>>[];
  final changes = <Map<String, Object?>>[];
  final edits = <Map<String, Object?>>[];
  final categoryCalls = <String>[];

  /// Thrown by the next write only, then cleared.
  Object? failOnce;
  List<AssetCategory> assetCats = [_cat];

  void _maybeFail() {
    final e = failOnce;
    if (e != null) {
      failOnce = null;
      throw e;
    }
  }

  @override
  Future<List<AssetLocation>> assetLocations() async => const [_k1, _k2];
  @override
  Future<List<AssetCategory>> assetCategories() async => assetCats;
  @override
  Future<List<Asset>> assets(
          {String? locationId, String? categoryId, String? query}) async =>
      const [];
  @override
  Future<Asset> assetById(String id) async => _asset(id);
  @override
  Future<AssetCategory> createAssetCategory(String name,
      {required String clientId}) async {
    _maybeFail();
    categoryCalls.add(clientId);
    final made = AssetCategory(id: 'c${assetCats.length + 1}', name: name);
    assetCats = [...assetCats, made];
    return made;
  }

  @override
  Future<AssetCategory> renameAssetCategory(
          String id, String name, String reason) async =>
      throw UnimplementedError();
  @override
  Future<List<Asset>> registerAssets(AssetDraft draft) async {
    drafts.add(draft);
    _maybeFail();
    return [_asset('new')];
  }

  @override
  Future<Asset> addAssetPurchase(String id,
      {required String clientId,
      required int quantity,
      required num unitPrice,
      required String purchaseDate,
      String? supplier,
      String? reference,
      String? inServiceDate,
      String? notes}) async {
    _maybeFail();
    purchases.add({
      'id': id,
      'clientId': clientId,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'purchaseDate': purchaseDate,
      'supplier': supplier,
      'reference': reference,
    });
    return _asset(id);
  }

  @override
  Future<Asset> changeAsset(String id,
      {required String clientId,
      required String change,
      required String reason,
      int? quantity,
      String? condition,
      String? area,
      AssetPerson? custodian,
      String? locationId}) async {
    _maybeFail();
    changes.add({
      'id': id,
      'clientId': clientId,
      'change': change,
      'reason': reason,
      'quantity': quantity,
      'condition': condition,
      'area': area,
      'custodian': custodian?.id,
      'locationId': locationId,
    });
    return _asset(id);
  }

  @override
  Future<Asset> editAssetDetails(String id,
      {String? name,
      String? categoryId,
      String? notes,
      required String reason}) async {
    _maybeFail();
    edits.add({
      'id': id,
      'name': name,
      'categoryId': categoryId,
      'notes': notes,
      'reason': reason,
    });
    return _asset(id);
  }
}

Future<TestApp> _open(WidgetTester tester, FormOffice office, String route,
    {Size size = const Size(390, 3200)}) async {
  office.signedIn = true;
  final app = await pumpApp(tester,
      startAs: StartAs.signedOut, office: office, size: size);
  await app.container
      .read(officeSessionProvider.notifier)
      .signedIn(office.owner);
  await tester.pumpAndSettle();
  app.router.push(route);
  await tester.pumpAndSettle();
  return app;
}

Finder _k(String key) => find.byKey(Key(key));

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(_k(key));
  await tester.enterText(_k(key), text);
  await tester.pump();
}

Future<void> _pick(WidgetTester tester, String key, String option) async {
  await tester.ensureVisible(_k(key));
  await tester.tap(_k(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _plus(WidgetTester tester, String key, [int times = 1]) async {
  final button = find
      .descendant(of: _k(key), matching: find.byType(MNQuantityButton))
      .last;
  for (var i = 0; i < times; i++) {
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }
}

Future<void> _pickDate(WidgetTester tester, String key) async {
  await tester.ensureVisible(_k(key));
  await tester.tap(_k(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tumia tarehe hii'));
  await tester.pumpAndSettle();
}

Future<void> _item(WidgetTester tester, int i,
    {required String name,
    String unit = 'pcs',
    String? price,
    int extra = 0,
    String location = 'Kariakoo',
    String category = 'Majiko'}) async {
  await _type(tester, 'i$i-name', name);
  await _pick(tester, 'i$i-cat', category);
  await _type(tester, 'i$i-unit', unit);
  await _pick(tester, 'i$i-loc', location);
  if (extra > 0) await _plus(tester, 'i$i-qty', extra);
  if (price != null) await _type(tester, 'i$i-price', price);
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(_k('save'));
  await tester.tap(_k('save'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'register two counted items and one numbered in one save sends one draft',
      (tester) async {
    final office = FormOffice();
    final app = await _open(tester, office, MNRoutes.officeAssetNew);
    await _pickDate(tester, 'pdate');
    await _type(tester, 'supplier', 'Duka la Juma');
    await _type(tester, 'reference', 'R-12');
    await _item(tester, 0, name: 'Sahani', price: '2000', extra: 19);
    await tester.tap(find.text('Ongeza kitu kingine'));
    await tester.pumpAndSettle();
    await _item(tester, 1, name: 'Kiti', price: '15000', extra: 1);
    await tester.tap(find.text('Ongeza kitu kingine'));
    await tester.pumpAndSettle();
    await _item(tester, 2, name: 'Jiko', price: '45000');
    await _pick(tester, 'i2-track', 'Kwa namba');
    await _type(tester, 'i2-num0', ' mn-7 ');
    await _save(tester);

    expect(office.drafts, hasLength(1));
    final json = office.drafts.single.toJson();
    final purchase = json['purchase'] as Map;
    expect(purchase['purchase_date'], matches(RegExp(r'^\d{4}-\d\d-\d\d$')));
    expect(purchase['opening'], false);
    expect(purchase['supplier'], 'Duka la Juma');
    expect(purchase['reference'], 'R-12');
    expect(json['items'], [
      {
        'name': 'Sahani',
        'category_id': 'c1',
        'unit': 'pcs',
        'tracking': 'counted',
        'quantity': 20,
        'location_id': 'loc1',
        'unit_price': 2000,
        'condition': 'good',
        'numbers': <String>[],
      },
      {
        'name': 'Kiti',
        'category_id': 'c1',
        'unit': 'pcs',
        'tracking': 'counted',
        'quantity': 2,
        'location_id': 'loc1',
        'unit_price': 15000,
        'condition': 'good',
        'numbers': <String>[],
      },
      {
        'name': 'Jiko',
        'category_id': 'c1',
        'unit': 'pcs',
        'tracking': 'numbered',
        'quantity': 1,
        'location_id': 'loc1',
        'unit_price': 45000,
        'condition': 'good',
        'numbers': ['mn-7'],
      },
    ]);
    expect(app.router.state.uri.path, MNRoutes.officeAssets);
  });

  testWidgets('purchase without price or date cannot be saved', (tester) async {
    final office = FormOffice();
    await _open(tester, office, MNRoutes.officeAssetNew);
    await _item(tester, 0, name: 'Sahani');
    await _save(tester);
    expect(office.drafts, isEmpty);
    expect(
        tester
            .widget<MNButton>(find.widgetWithText(MNButton, 'Sajili'))
            .onPressed,
        isNull);
    await _type(tester, 'i0-price', '2000');
    expect(
        tester
            .widget<MNButton>(find.widgetWithText(MNButton, 'Sajili'))
            .onPressed,
        isNull);
    await _pickDate(tester, 'pdate');
    expect(
        tester
            .widget<MNButton>(find.widgetWithText(MNButton, 'Sajili'))
            .onPressed,
        isNotNull);
  });

  testWidgets('opening item may be saved without price', (tester) async {
    final office = FormOffice();
    await _open(tester, office, MNRoutes.officeAssetNew);
    await tester.tap(find.text('Mali ya zamani (kabla ya mfumo)'));
    await tester.pumpAndSettle();
    expect(_k('pdate'), findsNothing);
    await _item(tester, 0, name: 'Meza');
    await _save(tester);
    expect(office.drafts, hasLength(1));
    final json = office.drafts.single.toJson();
    expect((json['purchase'] as Map)['opening'], true);
    expect((json['items'] as List).single, isNot(contains('unit_price')));
  });

  testWidgets('numbered quantity 3 shows three optional number fields',
      (tester) async {
    await _open(tester, FormOffice(), MNRoutes.officeAssetNew);
    await _pick(tester, 'i0-track', 'Kwa namba');
    expect(_k('i0-num0'), findsOneWidget);
    expect(_k('i0-num1'), findsNothing);
    await _plus(tester, 'i0-qty', 2);
    expect(_k('i0-num0'), findsOneWidget);
    expect(_k('i0-num1'), findsOneWidget);
    expect(_k('i0-num2'), findsOneWidget);
    expect(_k('i0-num3'), findsNothing);
    expect(find.text('Ukiacha wazi, mfumo utaweka namba'), findsWidgets);
  });

  testWidgets('retry after failure reuses the same client id', (tester) async {
    final office = FormOffice()
      ..failOnce = const AuthFailure(AuthFailureKind.offline);
    final app = await _open(tester, office, MNRoutes.officeAssetNew);
    await _pickDate(tester, 'pdate');
    await _item(tester, 0, name: 'Sahani', price: '2000');
    await _save(tester);
    expect(office.drafts, hasLength(1));
    expect(app.router.state.uri.path, MNRoutes.officeAssetNew);
    expect(find.text('Sahani'), findsOneWidget);
    await _save(tester);
    expect(office.drafts, hasLength(2));
    expect(office.drafts[1].clientId, office.drafts[0].clientId);
    expect(app.router.state.uri.path, MNRoutes.officeAssets);
  });

  testWidgets('number_taken shows the Swahili sentence and keeps the form',
      (tester) async {
    final office = FormOffice()
      ..failOnce = const AssetError('number_taken', 409, 'MN-0003');
    final app = await _open(tester, office, MNRoutes.officeAssetNew);
    await _pickDate(tester, 'pdate');
    await _item(tester, 0, name: 'Jiko', price: '2000');
    await _save(tester);
    expect(find.text('Namba MN-0003 tayari imetumika.'), findsOneWidget);
    expect(app.router.state.uri.path, MNRoutes.officeAssetNew);
    expect(find.text('Jiko'), findsOneWidget);
  });

  testWidgets('new category from the select sheet appears selected',
      (tester) async {
    final office = FormOffice();
    await _open(tester, office, MNRoutes.officeAssetNew);
    await tester.ensureVisible(_k('i0-cat'));
    await tester.tap(_k('i0-cat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ongeza aina mpya'));
    await tester.pumpAndSettle();
    await tester.enterText(_k('category-name'), 'Samani');
    await tester.pump();
    await tester.tap(_k('category-save'));
    await tester.pumpAndSettle();
    expect(office.categoryCalls, hasLength(1));
    expect(find.text('Samani'), findsOneWidget);
  });

  testWidgets('running total multiplies quantity by price', (tester) async {
    await _open(tester, FormOffice(), MNRoutes.officeAssetNew);
    await _item(tester, 0, name: 'Sahani', price: '250000', extra: 2);
    expect(find.text('Jumla ya gharama: TZS 750,000'), findsOneWidget);
  });

  testWidgets('quantity stepper never goes below 1', (tester) async {
    await _open(tester, FormOffice(), MNRoutes.officeAssetNew);
    final minus = find
        .descendant(of: _k('i0-qty'), matching: find.byType(MNQuantityButton))
        .first;
    await tester.ensureVisible(minus);
    await tester.tap(minus);
    await tester.pumpAndSettle();
    expect(tester.widget<MNQuantitySelector>(_k('i0-qty')).value, 1);
  });

  testWidgets(
      'change sheet requires a reason and hides Idadi for numbered items',
      (tester) async {
    final office = FormOffice();
    await _open(tester, office, MNRoutes.officeAsset('a1'),
        size: const Size(390, 1600));
    await tester.tap(find.widgetWithText(MNButton, 'Badilisha'));
    await tester.pumpAndSettle();
    // The fake asset is counted, so Idadi is offered.
    await _pick(tester, 'change-kind', 'Hali');
    await _pick(tester, 'change-condition', 'Imeharibika');
    expect(
        tester
            .widget<MNButton>(find.widgetWithText(MNButton, 'Hifadhi'))
            .onPressed,
        isNull);
    await _type(tester, 'change-reason', 'Imevunjika');
    await tester.tap(find.widgetWithText(MNButton, 'Hifadhi'));
    await tester.pumpAndSettle();
    expect(office.changes, hasLength(1));
    expect(office.changes.single['change'], 'condition');
    expect(office.changes.single['condition'], 'damaged');
    expect(office.changes.single['reason'], 'Imevunjika');
  });

  testWidgets('numbered asset change sheet has no Idadi option',
      (tester) async {
    final numbered = FormOfficeNumbered();
    await _open(tester, numbered, MNRoutes.officeAsset('a2'),
        size: const Size(390, 1600));
    await tester.tap(find.widgetWithText(MNButton, 'Badilisha'));
    await tester.pumpAndSettle();
    await tester.tap(_k('change-kind'));
    await tester.pumpAndSettle();
    expect(find.text('Idadi'), findsNothing);
    expect(find.text('Rekebisha mahali (kosa la usajili)'), findsOneWidget);
  });

  testWidgets('purchase sheet sends quantity, price and date', (tester) async {
    final office = FormOffice();
    await _open(tester, office, MNRoutes.officeAsset('a1'),
        size: const Size(390, 1800));
    await tester.tap(find.widgetWithText(MNButton, 'Ongeza manunuzi'));
    await tester.pumpAndSettle();
    await _plus(tester, 'purchase-qty', 4);
    await _type(tester, 'purchase-price', '1500');
    await _pickDate(tester, 'purchase-date');
    await tester.tap(find.widgetWithText(MNButton, 'Hifadhi'));
    await tester.pumpAndSettle();
    expect(office.purchases, hasLength(1));
    expect(office.purchases.single['quantity'], 5);
    expect(office.purchases.single['unitPrice'], 1500);
  });

  testWidgets('details sheet needs a reason and sends only what changed',
      (tester) async {
    final office = FormOffice();
    await _open(tester, office, MNRoutes.officeAsset('a1'),
        size: const Size(390, 1800));
    await tester.tap(find.widgetWithText(MNButton, 'Rekebisha maelezo'));
    await tester.pumpAndSettle();
    await _type(tester, 'details-name', 'Jiko kubwa');
    expect(
        tester
            .widget<MNButton>(find.widgetWithText(MNButton, 'Hifadhi'))
            .onPressed,
        isNull);
    await _type(tester, 'details-reason', 'Jina sahihi');
    await tester.tap(find.widgetWithText(MNButton, 'Hifadhi'));
    await tester.pumpAndSettle();
    expect(office.edits.single['name'], 'Jiko kubwa');
    expect(office.edits.single['categoryId'], isNull);
    expect(office.edits.single['reason'], 'Jina sahihi');
  });
}

class FormOfficeNumbered extends FormOffice {
  @override
  Future<Asset> assetById(String id) async => _asset(id, number: 'MN-0002');
}
