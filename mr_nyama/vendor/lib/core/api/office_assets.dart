// Business assets, "Mali za biashara" (MN039). Assets are not stock or products.
// Routes (mr_nyama/backend/mr_nyama/routes_assets.py), staff audience:
//   GET /staff/asset-locations, GET/POST /staff/asset-categories,
//   PATCH /staff/asset-categories/{id}, GET/POST /staff/assets,
//   GET/PATCH /staff/assets/{id}, POST .../{id}/purchases, POST .../{id}/changes.
// Shilling keys are ABSENT (not null) without value access; they read as null.
import 'package:dio/dio.dart';

import 'api_client.dart';

String _str(Object? v) => v == null ? '' : '$v';

String? _strOrNull(Object? v) => v == null ? null : '$v';

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

num? _numOrNull(Object? v) => v == null ? null : num.tryParse('$v');

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<Map<String, dynamic>> _rows(Object? v) =>
    [for (final row in v is List ? v : const []) _map(row)];

/// A refusal with a machine code (`error`). Malformed bodies (422 `detail`)
/// carry no code and become `invalid`. [number] is set for `number_taken`
/// and may be missing even then (the race path).
class AssetError implements Exception {
  final String code;
  final int status;
  final String? number;
  const AssetError(this.code, [this.status = 409, this.number]);
  @override
  String toString() => 'AssetError($code)';
}

class AssetCategory {
  final String id, name;
  const AssetCategory({required this.id, required this.name});
  static AssetCategory fromJson(Map<String, dynamic> j) =>
      AssetCategory(id: _str(j['id']), name: _str(j['name']));
}

/// A kituo or kitchen whose assets the person may read.
class AssetLocation {
  final String id, name, kind;
  final String? stationId;
  final bool deleted;
  const AssetLocation(
      {required this.id,
      required this.name,
      this.kind = '',
      this.stationId,
      this.deleted = false});
  static AssetLocation fromJson(Map<String, dynamic> j) => AssetLocation(
      id: _str(j['id']),
      name: _str(j['name']),
      kind: _str(j['kind']),
      stationId: _strOrNull(j['station_id']),
      deleted: j['deleted'] == true);
}

/// A custodian: a seller (`vendor`) or a staff member (`staff`).
class AssetPerson {
  final String kind, id, name;
  const AssetPerson({required this.kind, required this.id, this.name = ''});
  static AssetPerson? fromJsonOrNull(Object? v) {
    final j = _map(v);
    if (j.isEmpty) return null;
    return AssetPerson(
        kind: _str(j['kind']), id: _str(j['id']), name: _str(j['name']));
  }
}

class AssetLot {
  final String id;
  final int quantity;
  final String? purchaseDate, supplier, reference, inServiceDate;
  final String? originalPurchaseDate;
  final bool opening;
  final num? unitPrice, totalCost, originalUnitPrice;
  const AssetLot(
      {required this.id,
      required this.quantity,
      this.purchaseDate,
      this.supplier,
      this.reference,
      this.inServiceDate,
      this.opening = false,
      this.unitPrice,
      this.totalCost,
      this.originalUnitPrice,
      this.originalPurchaseDate});
  static AssetLot fromJson(Map<String, dynamic> j) => AssetLot(
      id: _str(j['id']),
      quantity: _int(j['quantity']),
      purchaseDate: _strOrNull(j['purchase_date']),
      supplier: _strOrNull(j['supplier']),
      reference: _strOrNull(j['reference']),
      inServiceDate: _strOrNull(j['in_service_date']),
      opening: j['opening'] == true,
      unitPrice: _numOrNull(j['unit_price']),
      totalCost: _numOrNull(j['total_cost']),
      originalUnitPrice: _numOrNull(j['original_unit_price']),
      originalPurchaseDate: _strOrNull(j['original_purchase_date']));
}

class AssetHistoryEntry {
  final String change;
  final int quantity;
  final String condition;
  final String? area, reason, recordedAt;
  final AssetLocation location;
  final AssetPerson? custodian;
  final String recordedBy;
  const AssetHistoryEntry(
      {required this.change,
      required this.quantity,
      required this.condition,
      this.area,
      required this.location,
      this.custodian,
      this.reason,
      this.recordedBy = '',
      this.recordedAt});
  static AssetHistoryEntry fromJson(Map<String, dynamic> j) =>
      AssetHistoryEntry(
          change: _str(j['change']),
          quantity: _int(j['quantity']),
          condition: _str(j['condition']),
          area: _strOrNull(j['area']),
          location: AssetLocation.fromJson(_map(j['location'])),
          custodian: AssetPerson.fromJsonOrNull(j['custodian']),
          reason: _strOrNull(j['reason']),
          recordedBy: _str(_map(j['recorded_by'])['name']),
          recordedAt: _strOrNull(j['recorded_at']));
}

class Asset {
  final String id;
  final String? number;
  final String name, unit, tracking;
  final AssetCategory category;
  final AssetLocation location;
  final String? area;
  final AssetPerson? custodian;
  final String condition, status;
  final int quantity;
  final String? notes;

  /// Total cost in whole shillings; null without value access (or when a
  /// lot has no price).
  final num? cost;
  final List<AssetLot> lots;
  final List<AssetHistoryEntry> history;
  const Asset(
      {required this.id,
      this.number,
      required this.name,
      this.unit = '',
      this.tracking = 'counted',
      required this.category,
      required this.location,
      this.area,
      this.custodian,
      this.condition = 'good',
      this.status = 'in_use',
      this.quantity = 1,
      this.notes,
      this.cost,
      this.lots = const [],
      this.history = const []});
  static Asset fromJson(Map<String, dynamic> j) => Asset(
      id: _str(j['id']),
      number: _strOrNull(j['number']),
      name: _str(j['name']),
      unit: _str(j['unit']),
      tracking: _str(j['tracking']),
      category: AssetCategory.fromJson(_map(j['category'])),
      location: AssetLocation.fromJson(_map(j['location'])),
      area: _strOrNull(j['area']),
      custodian: AssetPerson.fromJsonOrNull(j['custodian']),
      condition: _str(j['condition']),
      status: _str(j['status']),
      quantity: _int(j['quantity']),
      notes: _strOrNull(j['notes']),
      cost: _numOrNull(j['cost']),
      lots: [for (final l in _rows(j['lots'])) AssetLot.fromJson(l)],
      history: [
        for (final h in _rows(j['history'])) AssetHistoryEntry.fromJson(h)
      ]);
}

/// One line of a registration. `numbers` are typed numbers (blanks are left
/// out; the server numbers the rest); a numbered line of quantity n makes n assets.
class AssetDraftItem {
  final String name, categoryId, unit, tracking, locationId;
  final int quantity;
  final num? unitPrice, originalUnitPrice;
  final String? area, condition, notes, originalPurchaseDate;
  final List<String> numbers;
  final String? custodianVendorId, custodianStaffId;
  const AssetDraftItem(
      {required this.name,
      required this.categoryId,
      required this.unit,
      required this.tracking,
      required this.quantity,
      required this.locationId,
      this.unitPrice,
      this.originalUnitPrice,
      this.originalPurchaseDate,
      this.area,
      this.condition,
      this.notes,
      this.numbers = const [],
      this.custodianVendorId,
      this.custodianStaffId});

  Map<String, Object?> toJson() => {
        'name': name,
        'category_id': categoryId,
        'unit': unit,
        'tracking': tracking,
        'quantity': quantity,
        'location_id': locationId,
        if (unitPrice != null) 'unit_price': unitPrice,
        if (area != null) 'area': area,
        if (condition != null) 'condition': condition,
        if (notes != null) 'notes': notes,
        'numbers': [
          for (final n in numbers)
            if (n.trim().isNotEmpty) n.trim()
        ],
        if (custodianVendorId != null) 'custodian_vendor_id': custodianVendorId,
        if (custodianStaffId != null) 'custodian_staff_id': custodianStaffId,
        if (originalUnitPrice != null)
          'original_unit_price': originalUnitPrice,
        if (originalPurchaseDate != null)
          'original_purchase_date': originalPurchaseDate,
      };
}

class AssetDraft {
  final String clientId;
  final bool opening;
  final String? purchaseDate, supplier, reference, inServiceDate, notes;
  final List<AssetDraftItem> items;
  const AssetDraft(
      {required this.clientId,
      this.opening = false,
      this.purchaseDate,
      this.supplier,
      this.reference,
      this.inServiceDate,
      this.notes,
      required this.items});

  Map<String, Object?> toJson() => {
        'client_id': clientId,
        'purchase': {
          'opening': opening,
          if (purchaseDate != null) 'purchase_date': purchaseDate,
          if (supplier != null) 'supplier': supplier,
          if (reference != null) 'reference': reference,
          if (inServiceDate != null) 'in_service_date': inServiceDate,
          if (notes != null) 'notes': notes,
        },
        'items': [for (final i in items) i.toJson()],
      };
}

/// The list filter; value equality so the family provider caches by it.
class AssetFilter {
  final String? locationId, categoryId, query;
  const AssetFilter({this.locationId, this.categoryId, this.query});
  @override
  bool operator ==(Object other) =>
      other is AssetFilter &&
      other.locationId == locationId &&
      other.categoryId == categoryId &&
      other.query == query;
  @override
  int get hashCode => Object.hash(locationId, categoryId, query);
}

abstract interface class OfficeAssetsRepository {
  Future<List<AssetLocation>> assetLocations();
  Future<List<AssetCategory>> assetCategories();
  Future<AssetCategory> createAssetCategory(String name,
      {required String clientId});
  Future<AssetCategory> renameAssetCategory(
      String id, String name, String reason);
  Future<List<Asset>> assets(
      {String? locationId, String? categoryId, String? query});
  Future<Asset> assetById(String id);
  Future<List<Asset>> registerAssets(AssetDraft draft);
  Future<Asset> addAssetPurchase(String id,
      {required String clientId,
      required int quantity,
      required num unitPrice,
      required String purchaseDate,
      String? supplier,
      String? reference,
      String? inServiceDate,
      String? notes});
  Future<Asset> changeAsset(String id,
      {required String clientId,
      required String change,
      required String reason,
      int? quantity,
      String? condition,
      String? area,
      AssetPerson? custodian,
      String? locationId});
  Future<Asset> editAssetDetails(String id,
      {String? name, String? categoryId, String? notes, required String reason});
}

/// The HTTP side (staff audience), mapped like `SupplyApi`.
class AssetsApi {
  final ApiClient _c;
  AssetsApi(this._c);

  static const _base = '/staff';

  AssetError _error(Response<dynamic> r, int status) {
    final data = r.data;
    final code = ApiClient.errorCode(r);
    final number = data is Map && data['number'] != null
        ? '${data['number']}'
        : null;
    return AssetError(code ?? (status == 422 ? 'invalid' : 'refused'), status,
        number);
  }

  bool _refused(int status) => status >= 400 && status != 401 && status < 500;

  Map<String, dynamic> _ok(Response<dynamic> r) {
    final status = r.statusCode ?? 0;
    if (_refused(status)) throw _error(r, status);
    return _c.json(r);
  }

  List<Map<String, dynamic>> _list(Response<dynamic> r) {
    final status = r.statusCode ?? 0;
    if (_refused(status)) throw _error(r, status);
    if ((status != 200 && status != 201) || r.data is! List) _c.fail(r);
    return _rows(r.data);
  }

  String _id(String id) => '/${Uri.encodeComponent(id)}';

  Future<List<AssetLocation>> locations() async => [
        for (final j in _list(await _c.authed('GET', '$_base/asset-locations')))
          AssetLocation.fromJson(j)
      ];

  Future<List<AssetCategory>> categories() async => [
        for (final j in _list(await _c.authed('GET', '$_base/asset-categories')))
          AssetCategory.fromJson(j)
      ];

  Future<AssetCategory> createCategory(String name, String clientId) async =>
      AssetCategory.fromJson(_ok(await _c.authed(
          'POST', '$_base/asset-categories',
          body: {'client_id': clientId, 'name': name})));

  Future<AssetCategory> renameCategory(
          String id, String name, String reason) async =>
      AssetCategory.fromJson(_ok(await _c.authed(
          'PATCH', '$_base/asset-categories${_id(id)}',
          body: {'name': name, 'reason': reason})));

  Future<List<Asset>> list(
          {String? locationId, String? categoryId, String? query}) async =>
      [
        for (final j in _list(await _c.authed(
            'GET',
            Uri(path: '$_base/assets', queryParameters: {
              if (locationId != null) 'location_id': locationId,
              if (categoryId != null) 'category_id': categoryId,
              if (query != null && query.isNotEmpty) 'q': query,
            }).toString())))
          Asset.fromJson(j)
      ];

  Future<Asset> one(String id) async => Asset.fromJson(
      _ok(await _c.authed('GET', '$_base/assets${_id(id)}')));

  Future<List<Asset>> register(AssetDraft draft) async => [
        for (final j in _list(
            await _c.authed('POST', '$_base/assets', body: draft.toJson())))
          Asset.fromJson(j)
      ];

  Future<Asset> purchase(String id, Map<String, Object?> body) async =>
      Asset.fromJson(_ok(await _c.authed(
          'POST', '$_base/assets${_id(id)}/purchases',
          body: body)));

  Future<Asset> change(String id, Map<String, Object?> body) async =>
      Asset.fromJson(_ok(await _c.authed(
          'POST', '$_base/assets${_id(id)}/changes',
          body: body)));

  Future<Asset> edit(String id, Map<String, Object?> body) async =>
      Asset.fromJson(_ok(
          await _c.authed('PATCH', '$_base/assets${_id(id)}', body: body)));
}
