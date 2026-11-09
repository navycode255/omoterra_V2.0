// Task 5: the register and detail screens of Mali za biashara.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/auth/lead_session.dart';
import 'package:mr_nyama_vendor/core/api/office_assets.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/shared/widgets/states.dart' show MNErrorState;

import 'helpers.dart';
import 'lead_session_test.dart' show LeadApi, seedLead;
import 'office_test.dart' show FakeOfficeRepository;

const _cat = AssetCategory(id: 'c1', name: 'Majiko');
const _k1 = AssetLocation(
    id: 'loc1', name: 'Kariakoo', kind: 'station', stationId: 'st1');
const _k2 = AssetLocation(
    id: 'loc2', name: 'Mwenge', kind: 'station', stationId: 'st2');

Asset _asset(String id, String name,
        {AssetLocation location = _k1,
        String condition = 'good',
        num? cost,
        String? number,
        int quantity = 1,
        List<AssetLot> lots = const [],
        List<AssetHistoryEntry> history = const []}) =>
    Asset(
        id: id,
        name: name,
        number: number,
        unit: 'pcs',
        tracking: number == null ? 'counted' : 'numbered',
        category: _cat,
        location: location,
        condition: condition,
        quantity: quantity,
        cost: cost,
        lots: lots,
        history: history);

class AssetOffice extends FakeOfficeRepository
    implements OfficeAssetsRepository {
  List<AssetLocation> locations = const [_k1, _k2];
  final all = <Asset>[];
  final asked = <String?>[];

  @override
  Future<List<AssetLocation>> assetLocations() async => locations;
  @override
  Future<List<AssetCategory>> assetCategories() async => const [_cat];
  @override
  Future<List<Asset>> assets(
      {String? locationId, String? categoryId, String? query}) async {
    asked.add(locationId);
    return [
      for (final a in all)
        if (locationId == null || a.location.id == locationId) a
    ];
  }

  @override
  Future<Asset> assetById(String id) async {
    final found = all.where((a) => a.id == id);
    if (found.isEmpty) throw const AssetError('not_found', 404);
    return found.first;
  }

  @override
  Future<AssetCategory> createAssetCategory(String name,
          {required String clientId}) async =>
      throw UnimplementedError();
  @override
  Future<AssetCategory> renameAssetCategory(
          String id, String name, String reason) async =>
      throw UnimplementedError();
  @override
  Future<List<Asset>> registerAssets(AssetDraft draft) async =>
      throw UnimplementedError();
  @override
  Future<Asset> addAssetPurchase(String id,
          {required String clientId,
          required int quantity,
          required num unitPrice,
          required String purchaseDate,
          String? supplier,
          String? reference,
          String? inServiceDate,
          String? notes}) async =>
      throw UnimplementedError();
  @override
  Future<Asset> changeAsset(String id,
          {required String clientId,
          required String change,
          required String reason,
          int? quantity,
          String? condition,
          String? area,
          AssetPerson? custodian,
          String? locationId}) async =>
      throw UnimplementedError();
  @override
  Future<Asset> editAssetDetails(String id,
          {String? name,
          String? categoryId,
          String? notes,
          required String reason}) async =>
      throw UnimplementedError();
}

const _ops = StaffProfile(
    id: 'o1',
    name: 'Zawadi',
    phone: '+255700000003',
    roles: ['operations_admin']);
const _sup = StaffProfile(
    id: 'p1', name: 'Juma', phone: '+255700000002', roles: ['supervisor']);

Future<TestApp> _open(WidgetTester tester, AssetOffice office, String route,
    {StaffProfile? as}) async {
  office.signedIn = true;
  final app = await pumpApp(tester, startAs: StartAs.signedOut, office: office);
  await app.container
      .read(officeSessionProvider.notifier)
      .signedIn(as ?? office.owner);
  await tester.pumpAndSettle();
  app.router.push(route);
  await tester.pumpAndSettle();
  return app;
}

void main() {
  testWidgets('owner sees totals, costs and the register button',
      (tester) async {
    final office = AssetOffice()
      ..all.addAll([
        _asset('a1', 'Jiko', cost: 45000, number: 'MN-0001'),
        _asset('a2', 'Sahani', cost: 10000, quantity: 20),
      ]);
    final app = await _open(tester, office, MNRoutes.officeAssets);
    expect(find.text('Mali za biashara'), findsWidgets);
    expect(find.text('Jumla ya gharama: TZS 55,000'), findsOneWidget);
    expect(find.text('TZS 45,000'), findsOneWidget);
    expect(find.text('MN-0001 · Kariakoo'), findsOneWidget);
    expect(find.text('20 pcs · Kariakoo'), findsOneWidget);
    expect(find.text('MAJIKO'), findsOneWidget);
    await tester.tap(find.text('Sajili mali'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.officeAssetNew);
  });

  testWidgets('operations sees costs but no register or change buttons',
      (tester) async {
    final office = AssetOffice()..all.add(_asset('a1', 'Jiko', cost: 45000));
    await _open(tester, office, MNRoutes.officeAssets, as: _ops);
    expect(find.text('Jumla ya gharama: TZS 45,000'), findsOneWidget);
    expect(find.text('Sajili mali'), findsNothing);
    await tester.tap(find.text('Jiko'));
    await tester.pumpAndSettle();
    expect(find.text('Badilisha'), findsNothing);
    expect(find.text('Ongeza manunuzi'), findsNothing);
    expect(find.text('Rekebisha maelezo'), findsNothing);
  });

  // The server never sends money to these roles, but the screen must hide it
  // even if it were present.
  AssetOffice moneyOffice() => AssetOffice()
    ..locations = const [_k1]
    ..all.add(_asset('a1', 'Jiko', cost: 45000, lots: const [
      AssetLot(
          id: 'l1',
          quantity: 2,
          purchaseDate: '2026-11-01',
          supplier: 'Duka',
          unitPrice: 15000,
          totalCost: 30000),
      AssetLot(id: 'l0', quantity: 1, opening: true, unitPrice: 5000),
    ]));

  Future<void> expectNoMoney(WidgetTester tester) async {
    for (final text in [
      'TZS',
      'Jumla ya gharama',
      'Bei ya kimoja',
      'Thamani ya kuanzia'
    ]) {
      expect(find.textContaining(text), findsNothing, reason: text);
    }
  }

  testWidgets('supervisor sees no shilling figure anywhere', (tester) async {
    await _open(tester, moneyOffice(), MNRoutes.officeAssets, as: _sup);
    expect(find.text('Jiko'), findsOneWidget);
    await expectNoMoney(tester);
    expect(find.text('Sajili mali'), findsNothing);
    await tester.tap(find.text('Jiko'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Duka'), findsOneWidget);
    await expectNoMoney(tester);
  });

  testWidgets('lead office session sees no shilling figure anywhere',
      (tester) async {
    final office = _LeadAssetOffice()
      ..locations = const [_k1]
      ..all.addAll(moneyOffice().all);
    final app = await pumpApp(tester,
        api: _LeadSupervisorApi(), office: office, seed: seedLead);
    await tester.pumpAndSettle();
    expect(
        (app.container.read(officeSessionProvider).valueOrNull
                as OfficeSignedIn)
            .viaLead,
        isTrue);
    app.router.push(MNRoutes.officeAssets);
    await tester.pumpAndSettle();
    expect(find.text('Jiko'), findsOneWidget);
    await expectNoMoney(tester);
    await tester.tap(find.text('Jiko'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Duka'), findsOneWidget);
    await expectNoMoney(tester);
  });

  testWidgets('history dates are East Africa Time', (tester) async {
    final office = AssetOffice()
      ..all.add(_asset('a1', 'Jiko', history: const [
        AssetHistoryEntry(
            change: 'quantity',
            quantity: 2,
            condition: 'good',
            location: _k1,
            recordedBy: 'Owner',
            recordedAt: '2026-11-08T22:30:00Z')
      ]));
    await _open(tester, office, MNRoutes.officeAsset('a1'));
    await tester.scrollUntilVisible(find.text('Historia'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('2026-11-09'), findsOneWidget);
    expect(find.textContaining('2026-11-08'), findsNothing);
  });

  testWidgets('location switch filters the list', (tester) async {
    final office = AssetOffice()
      ..all.addAll([
        _asset('a1', 'Jiko'),
        _asset('a2', 'Meza', location: _k2),
      ]);
    await _open(tester, office, MNRoutes.officeAssets);
    expect(find.text('Jiko'), findsOneWidget);
    expect(find.text('Meza'), findsOneWidget);
    await tester.tap(find.text('Biashara yote'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mwenge').last);
    await tester.pumpAndSettle();
    expect(office.asked.last, 'loc2');
    expect(find.text('Jiko'), findsNothing);
    expect(find.text('Meza'), findsOneWidget);
    // In a single kituo the location is not repeated on each row.
    expect(find.text('1 pcs · Mwenge'), findsNothing);
  });

  testWidgets('search narrows the list', (tester) async {
    final office = AssetOffice()
      ..all.addAll([_asset('a1', 'Jiko'), _asset('a2', 'Meza')]);
    await _open(tester, office, MNRoutes.officeAssets);
    await tester.enterText(find.byType(TextField).first, 'mez');
    await tester.pumpAndSettle();
    expect(find.text('Jiko'), findsNothing);
    expect(find.text('Meza'), findsOneWidget);
  });

  testWidgets('station query preselects the kituo', (tester) async {
    final office = AssetOffice()
      ..all.addAll([_asset('a1', 'Jiko'), _asset('a2', 'Meza', location: _k2)]);
    await _open(tester, office, '${MNRoutes.officeAssets}?station=st2');
    expect(office.asked.last, 'loc2');
    expect(find.text('Jiko'), findsNothing);
    expect(find.text('Meza'), findsOneWidget);
  });

  testWidgets('lead station query hides the switch for one location',
      (tester) async {
    final office = AssetOffice()
      ..locations = const [_k1]
      ..all.add(_asset('a1', 'Jiko'));
    await _open(tester, office, '${MNRoutes.officeAssets}?station=st1',
        as: _sup);
    expect(office.asked.last, 'loc1');
    expect(find.text('Mahali'), findsNothing);
    expect(find.text('Biashara yote'), findsNothing);
    expect(find.text('Jiko'), findsOneWidget);
  });

  testWidgets('condition colour only for attention states', (tester) async {
    final office = AssetOffice()
      ..all.addAll([
        _asset('a1', 'Jiko', condition: 'damaged'),
        _asset('a2', 'Meza', condition: 'under_repair'),
        _asset('a3', 'Kiti', condition: 'good'),
      ]);
    await _open(tester, office, MNRoutes.officeAssets);
    Color? colour(String text) =>
        tester.widget<Text>(find.text(text)).style?.color;
    expect(colour('Imeharibika'), const Color(0xFFB42318));
    expect(colour('Inatengenezwa'), const Color(0xFFB85C00));
    expect(colour('Nzuri'), isNot(const Color(0xFFB42318)));
    expect(colour('Nzuri'), isNot(const Color(0xFFB85C00)));
  });

  testWidgets('detail shows lots and history newest first', (tester) async {
    HistoryHelper h(String change, String at, int q) =>
        HistoryHelper(AssetHistoryEntry(
            change: change,
            quantity: q,
            condition: 'good',
            location: _k1,
            recordedBy: 'Owner',
            recordedAt: at));
    final office = AssetOffice()
      ..all.add(_asset('a1', 'Sahani', cost: 20000, quantity: 7, lots: const [
        AssetLot(
            id: 'l1',
            quantity: 5,
            purchaseDate: '2026-11-01',
            supplier: 'Duka',
            reference: 'R1',
            unitPrice: 2000,
            totalCost: 10000),
        AssetLot(
            id: 'l0',
            quantity: 2,
            opening: true,
            unitPrice: 5000,
            purchaseDate: '2025-01-01')
      ], history: [
        h('registered', '2026-11-01T10:00:00', 5).entry,
        h('quantity', '2026-11-03T09:00:00', 7).entry,
      ]));
    await _open(tester, office, MNRoutes.officeAsset('a1'));
    expect(find.text('Manunuzi'), findsWidgets);
    expect(find.textContaining('Msambazaji: Duka'), findsOneWidget);
    expect(find.textContaining('Namba ya risiti: R1'), findsOneWidget);
    expect(find.textContaining('Bei ya kimoja: TZS 2,000'), findsOneWidget);
    expect(
        find.textContaining('Thamani ya kuanzia: TZS 5,000'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Historia'), 300,
        scrollable: find.byType(Scrollable).first);
    final newer = tester.getTopLeft(find.textContaining('2026-11-03')).dy;
    final older = tester.getTopLeft(find.textContaining('2026-11-01').last).dy;
    expect(newer, lessThan(older));
    // Owner buttons are there for a counted asset.
    await tester.scrollUntilVisible(find.text('Rekebisha maelezo'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Badilisha'), findsOneWidget);
    expect(find.text('Ongeza manunuzi'), findsOneWidget);
  });

  testWidgets('a numbered asset offers no purchase button', (tester) async {
    final office = AssetOffice()
      ..all.add(_asset('a1', 'Jiko', number: 'MN-0001'));
    await _open(tester, office, MNRoutes.officeAsset('a1'));
    await tester.scrollUntilVisible(find.text('Rekebisha maelezo'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Badilisha'), findsOneWidget);
    expect(find.text('Ongeza manunuzi'), findsNothing);
  });

  testWidgets('a missing asset shows a note, not a retry', (tester) async {
    final office = AssetOffice();
    await _open(tester, office, MNRoutes.officeAsset('zzz'));
    expect(find.text('Mali hii haipatikani.'), findsOneWidget);
  });

  testWidgets('empty register shows the empty state', (tester) async {
    final office = AssetOffice();
    await _open(tester, office, MNRoutes.officeAssets);
    expect(find.text('Hakuna mali iliyosajiliwa bado.'), findsOneWidget);
  });

  testWidgets('a load error shows the error state', (tester) async {
    final office = _FailingOffice();
    await _open(tester, office, MNRoutes.officeAssets);
    expect(find.byType(MNErrorState), findsOneWidget);
    expect(find.text('Hakuna mali iliyosajiliwa bado.'), findsNothing);
  });

  testWidgets('non-owner is sent from the register form to the register',
      (tester) async {
    final office = AssetOffice();
    final app = await _open(tester, office, MNRoutes.officeAssetNew, as: _ops);
    expect(app.router.state.uri.path, MNRoutes.officeAssets);
  });

  testWidgets('owner opens the register form', (tester) async {
    final office = AssetOffice();
    final app = await _open(tester, office, MNRoutes.officeAssetNew);
    expect(app.router.state.uri.path, MNRoutes.officeAssetNew);
    expect(find.text('Sajili mali'), findsWidgets);
  });

  testWidgets('entry rows: Usimamizi for operations, account for supervisor',
      (tester) async {
    final office = AssetOffice();
    final app =
        await _open(tester, office, MNRoutes.officeManagement, as: _ops);
    await tester.scrollUntilVisible(
        find.text('Vifaa na samani za biashara'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Vifaa na samani za biashara'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.officeAssets);
  });

  testWidgets('supervisor reaches the register from his account',
      (tester) async {
    final office = AssetOffice();
    final app = await _open(tester, office, MNRoutes.officeAccount, as: _sup);
    await tester.scrollUntilVisible(find.text('Mali za biashara'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Mali za biashara'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, MNRoutes.officeAssets);
  });
}

class _LeadAssetOffice extends AssetOffice implements OfficeLeadRepository {
  @override
  Future<void> keepLeadTokens(Map<String, dynamic> tokens) async {
    signedIn = true;
  }

  @override
  Future<void> signOut() async {
    signedIn = false;
  }
}

class _LeadSupervisorApi extends LeadApi {
  @override
  Future<LeadSession> leadSession(String token) async => const LeadSession(
      tokens: {'access_token': 'lead-a', 'refresh_token': 'lead-r'},
      profile: StaffProfile(
          id: 's1', name: 'Asha (ofisi)', phone: '', roles: ['supervisor']));
}

class HistoryHelper {
  final AssetHistoryEntry entry;
  HistoryHelper(this.entry);
}

class _FailingOffice extends AssetOffice {
  @override
  Future<List<Asset>> assets(
          {String? locationId, String? categoryId, String? query}) async =>
      throw const AssetError('refused', 500);
}
