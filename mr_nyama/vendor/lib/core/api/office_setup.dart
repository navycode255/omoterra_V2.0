import 'office_stock.dart';

// Setting a station up: opening stock (#10) and kitchens and stores (#13).
// The server holds the rules (opening date, closed flag, maker is never
// checker, a grant needs a kitchen); parsing here never invents a value.

String _s(Object? v) => v == null ? '' : '$v';
String? _o(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

/// One opening-stock entry (`GET /staff/opening-entries`).
class OfficeOpeningEntry {
  final String id, locationId, productId, reference, status, enteredBy;
  final String productCode, productName, locationName, enteredByName;
  final int quantity;

  /// Whole shillings per unit; null means the cost is not known (never zero).
  final int? unitCost;
  final String asOf;
  final String? decidedBy;
  const OfficeOpeningEntry(
      {required this.id,
      this.locationId = '',
      this.productId = '',
      this.productCode = '',
      this.productName = '',
      this.locationName = '',
      this.enteredByName = '',
      required this.quantity,
      this.unitCost,
      this.asOf = '',
      this.reference = '',
      this.status = 'draft',
      this.enteredBy = '',
      this.decidedBy});

  bool get isDraft => status == 'draft';

  factory OfficeOpeningEntry.fromJson(Map<String, dynamic> j) =>
      OfficeOpeningEntry(
          id: _s(j['id']),
          locationId: _s(j['location_id']),
          productId: _s(j['product_id']),
          productCode: _s(j['product']),
          productName: _o(j['product_name']) ?? _s(j['product']),
          locationName: _s(j['location_name']),
          enteredByName: _s(j['entered_by_name']),
          quantity: j['quantity'] is num
              ? (j['quantity'] as num).round()
              : int.tryParse(_s(j['quantity'])) ?? 0,
          unitCost: j['unit_cost'] is num
              ? (j['unit_cost'] as num).round()
              : int.tryParse(_s(j['unit_cost'])),
          asOf: _s(j['as_of']),
          reference: _s(j['reference']),
          status: _s(j['status']),
          enteredBy: _s(j['entered_by']),
          decidedBy: _o(j['decided_by']));
}

/// `opening.date` and `opening.closed`. An unset date means off.
class OfficeOpeningSettings {
  final String? date;
  final bool closed;
  const OfficeOpeningSettings({this.date, this.closed = false});
  factory OfficeOpeningSettings.fromJson(Map<String, dynamic> j) =>
      OfficeOpeningSettings(
          date: _o(j['opening.date']), closed: j['opening.closed'] == true);

  /// Drafting is possible only with a date and while entries are open.
  bool get open => date != null && !closed;
}

/// Kinds an office adds by hand.
const setupLocationKinds = ['kitchen', 'receiving'];

/// Opening stock and kitchens, over the staff API.
abstract interface class OfficeSetupRepository {
  Future<List<OfficeOpeningEntry>> openingEntries();
  Future<OfficeOpeningSettings> openingSettings();

  /// A retry with the same [clientId] and details returns the first draft.
  Future<OfficeOpeningEntry> draftOpening(
      {required String clientId,
      required String locationId,
      required String product,
      required int quantity,
      int? unitCost,
      required String asOf,
      required String reference});
  Future<OfficeOpeningEntry> decideOpening(String id,
      {required bool approve, required String reason});

  /// Owner only.
  Future<void> setOpeningDate(String date, {required String reason});
  Future<void> closeOpening({required String reason});

  /// Every stock location (kitchens, stores, stations' custody).
  Future<List<OfficeStockLocation>> setupLocations();
  Future<OfficeStockLocation> createLocation(
      {required String code, required String name, required String kind});

  /// Places kitchen staff at a kitchen; a second call adds a second kitchen.
  Future<void> grantKitchenRole(
      {required String staffId,
      required String kitchenLocationId,
      required String reason});
}
