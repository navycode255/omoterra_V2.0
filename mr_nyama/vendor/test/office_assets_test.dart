import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_assets.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';

const sw = Strings('sw');

Map<String, dynamic> lot({bool money = false}) => {
      'id': 'l1',
      'quantity': 3,
      'purchase_date': '2026-11-01',
      'supplier': 'Duka',
      'reference': 'R1',
      'in_service_date': null,
      'opening': false,
      if (money) ...{
        'unit_price': 15000,
        'total_cost': 45000,
        'original_unit_price': null,
        'original_purchase_date': '2025-03-01',
      },
    };

Map<String, dynamic> asset({bool money = false}) => {
      'id': 'a1',
      'number': 'MN-0001',
      'name': 'Jiko',
      'unit': 'pcs',
      'tracking': 'numbered',
      'category': {'id': 'c1', 'name': 'Majiko'},
      'location': {
        'id': 'loc1',
        'name': 'Kariakoo',
        'kind': 'station',
        'station_id': 's1'
      },
      'area': null,
      'custodian': {'kind': 'vendor', 'id': 'v1', 'name': 'Asha'},
      'condition': 'new',
      'status': 'in_use',
      'quantity': 1,
      'notes': null,
      'created_at': '2026-11-01T10:00:00',
      'lots': [lot(money: money)],
      if (money) 'cost': 45000,
      'history': [
        {
          'change': 'register',
          'quantity': 1,
          'condition': 'new',
          'area': null,
          'location': {'id': 'loc1', 'name': 'Kariakoo', 'kind': 'station'},
          'custodian': null,
          'reason': null,
          'recorded_by': {'id': 'u1', 'name': 'Owner'},
          'recorded_at': '2026-11-01T10:00:00',
        }
      ],
    };

void main() {
  test('asset JSON without money keys has null cost and lot prices', () {
    final a = Asset.fromJson(asset());
    expect(a.cost, isNull);
    expect(a.lots.single.unitPrice, isNull);
    expect(a.lots.single.totalCost, isNull);
    expect(a.lots.single.originalUnitPrice, isNull);
    expect(a.lots.single.originalPurchaseDate, isNull);
    expect(a.number, 'MN-0001');
    expect(a.location.stationId, 's1');
    expect(a.custodian?.name, 'Asha');
    expect(a.history.single.recordedBy, 'Owner');
  });

  test('asset JSON with money keeps them', () {
    final a = Asset.fromJson(asset(money: true));
    expect(a.cost, 45000);
    expect(a.lots.single.unitPrice, 15000);
    expect(a.lots.single.totalCost, 45000);
    expect(a.lots.single.originalPurchaseDate, '2025-03-01');
  });

  test('draft toJson matches the server body', () {
    final draft = AssetDraft(
      clientId: 'c-1',
      opening: false,
      purchaseDate: '2026-11-01',
      supplier: 'Duka',
      reference: 'R1',
      inServiceDate: '2026-11-02',
      notes: 'n',
      items: [
        const AssetDraftItem(
            name: 'Sahani',
            categoryId: 'cat',
            unit: 'pcs',
            tracking: 'counted',
            quantity: 50,
            locationId: 'loc',
            unitPrice: 2500,
            condition: 'new'),
        const AssetDraftItem(
            name: 'Jiko',
            categoryId: 'cat',
            unit: 'pcs',
            tracking: 'numbered',
            quantity: 2,
            locationId: 'loc',
            numbers: ['MN-0007', '', '  ', ' MN-0008 '],
            custodianVendorId: 'v1'),
      ],
    );
    expect(draft.toJson(), {
      'client_id': 'c-1',
      'purchase': {
        'opening': false,
        'purchase_date': '2026-11-01',
        'supplier': 'Duka',
        'reference': 'R1',
        'in_service_date': '2026-11-02',
        'notes': 'n',
      },
      'items': [
        {
          'name': 'Sahani',
          'category_id': 'cat',
          'unit': 'pcs',
          'tracking': 'counted',
          'quantity': 50,
          'location_id': 'loc',
          'unit_price': 2500,
          'condition': 'new',
          'numbers': <String>[],
        },
        {
          'name': 'Jiko',
          'category_id': 'cat',
          'unit': 'pcs',
          'tracking': 'numbered',
          'quantity': 2,
          'location_id': 'loc',
          'numbers': ['MN-0007', 'MN-0008'],
          'custodian_vendor_id': 'v1',
        },
      ],
    });
  });

  test('every asset error code has a Swahili sentence', () {
    const codes = [
      'forbidden', 'not_found', 'client_id_used', 'name_taken', 'no_change',
      'numbered_quantity', 'numbers_exceed_quantity', 'number_taken',
      'price_required', 'unknown_category', 'unknown_custodian',
      'invalid_change', 'invalid_condition', 'invalid_price',
      'invalid_quantity', 'invalid_tracking', 'items_required',
      'name_required', 'one_custodian', 'purchase_date_required',
      'reason_required', 'invalid', 'refused',
    ];
    for (final code in codes) {
      final text = sw.assetError(AssetError(code, 409));
      expect(text.trim(), isNotEmpty, reason: code);
      expect(text, isNot(contains('_')), reason: code);
      expect(text, isNot(contains('null')), reason: code);
    }
    expect(sw.assetError(const AssetError('number_taken', 409, 'MN-0003')),
        'Namba MN-0003 tayari imetumika.');
    expect(sw.assetError(const AssetError('number_taken', 409)),
        isNot(contains('  ')));
    expect(sw.assetError(const AssetError('totally_new', 409)), isNotEmpty);
    expect(sw.conditionLabel('needs_maintenance'), 'Inahitaji matengenezo');
    expect(sw.assetStatusLabel('in_use'), 'Inatumika');
  });

  test('canSeeAssets and canSeeAssetValues by role', () {
    StaffProfile p(String role) =>
        StaffProfile(id: 'x', name: 'x', phone: '', roles: [role]);
    expect([p('finance').canSeeAssets, p('finance').canSeeAssetValues],
        [false, false]);
    expect([p('supervisor').canSeeAssets, p('supervisor').canSeeAssetValues],
        [true, false]);
    expect(
        [p('operations_admin').canSeeAssets, p('operations_admin').canSeeAssetValues],
        [true, true]);
    expect([p('business_owner').canSeeAssets, p('business_owner').canSeeAssetValues],
        [true, true]);
  });
}
