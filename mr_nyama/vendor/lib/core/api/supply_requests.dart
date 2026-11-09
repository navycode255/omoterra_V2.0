// Supply requests, "Maombi ya mzigo" (MN038, team roles plan Part 2). A request
// is not money and not stock: it asks, is approved step by step, may get money
// from Owner or Finance, is explained by the holder (spent / change returned)
// and confirmed. Goods enter stock separately, through a delivery.
//
// Routes (mr_nyama/backend/mr_nyama/routes_supply_requests.py):
//   seller   POST/GET /vendor/supply-requests, POST .../{id}/withdraw,
//            POST .../{id}/settlement, GET .../outstanding
//   office   GET /staff/supply-requests, GET .../waiting, POST .../{id}/decision,
//            POST .../{id}/advance, POST .../{id}/settlement/confirm,
//            GET .../outstanding
import 'package:dio/dio.dart';

import 'api_client.dart';

String _str(Object? v) => v == null ? '' : '$v';

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

num? _numOrNull(Object? v) => v == null ? null : num.tryParse('$v');

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<Map<String, dynamic>> _rows(Object? v) =>
    [for (final row in v is List ? v : const []) _map(row)];

/// A refusal the server explained with a machine code (`error`), for example
/// `wrong_step` or `over_approved`. [Strings.supplyRefusal] words it.
class SupplyError implements Exception {
  final String code;
  final int status;
  const SupplyError(this.code, [this.status = 409]);
  @override
  String toString() => 'SupplyError($code)';
}

/// Codes a delivery answers with when it names a supply request that cannot
/// be linked (`POST /staff/manifests` with `supply_request_id`).
const supplyLinkRefusals = {
  'request_not_purchase',
  'request_not_found',
  'request_other_station',
  'request_not_funded',
};

/// The statuses a request moves through, in the server's words.
class SupplyStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const withdrawn = 'withdrawn';
  static const funded = 'funded';
  static const purchased = 'purchased';
  static const closed = 'closed';
}

class SupplyLine {
  final String id;
  final String? productId, productName, item;
  final num quantity, estimatedUnitPrice;
  final String unit;

  /// Accepted by the receiving count; null for a written item (unknown).
  final num? received, difference;
  const SupplyLine(
      {required this.id,
      this.productId,
      this.productName,
      this.item,
      this.quantity = 0,
      this.unit = '',
      this.estimatedUnitPrice = 0,
      this.received,
      this.difference});

  String get name => productName ?? item ?? '';

  factory SupplyLine.fromJson(Map<String, dynamic> j) => SupplyLine(
      id: _str(j['id']),
      productId: j['product_id'] as String?,
      productName: j['product_name'] as String?,
      item: j['item'] as String?,
      quantity: _numOrNull(j['quantity']) ?? 0,
      unit: _str(j['unit']),
      estimatedUnitPrice: _numOrNull(j['estimated_unit_price']) ?? 0,
      received: _numOrNull(j['received']),
      difference: _numOrNull(j['difference']));
}

class SupplyStep {
  final int index;

  /// `station`, `lead` or `final`.
  final String kind;
  final bool skipped;
  final bool? approve;
  final String? reason, decidedBy;
  const SupplyStep(
      {required this.index,
      required this.kind,
      this.skipped = false,
      this.approve,
      this.reason,
      this.decidedBy});

  factory SupplyStep.fromJson(Map<String, dynamic> j) {
    final d = j['decision'] is Map ? _map(j['decision']) : null;
    return SupplyStep(
        index: _int(j['index']),
        kind: _str(j['kind']),
        skipped: j['skipped'] == true,
        approve: d?['approve'] as bool?,
        reason: d?['reason'] as String?,
        decidedBy: _map(d?['decided_by'])['name'] as String?);
  }
}

class SupplyAdvance {
  final int amount;
  final String holderName, holderId;
  final DateTime? givenAt;
  const SupplyAdvance(
      {required this.amount,
      this.holderName = '',
      this.holderId = '',
      this.givenAt});
  factory SupplyAdvance.fromJson(Map<String, dynamic> j) => SupplyAdvance(
      amount: _int(j['amount']),
      holderName: _str(_map(j['given_to'])['name']),
      holderId: _str(_map(j['given_to'])['id']),
      givenAt: DateTime.tryParse(_str(j['given_at']))?.toLocal());
}

class SupplySettlement {
  final int spent, changeReturned, overspend;
  final String supplier;
  final DateTime? confirmedAt;
  const SupplySettlement(
      {required this.spent,
      required this.changeReturned,
      this.overspend = 0,
      this.supplier = '',
      this.confirmedAt});
  bool get confirmed => confirmedAt != null;
  factory SupplySettlement.fromJson(Map<String, dynamic> j) => SupplySettlement(
      spent: _int(j['spent']),
      changeReturned: _int(j['change_returned']),
      overspend: _int(j['overspend']),
      supplier: _str(j['supplier']),
      confirmedAt: DateTime.tryParse(_str(j['confirmed_at']))?.toLocal());
}

class SupplyDelivery {
  final String id, reference, sender, status;
  const SupplyDelivery(
      {required this.id,
      this.reference = '',
      this.sender = '',
      this.status = ''});
  factory SupplyDelivery.fromJson(Map<String, dynamic> j) => SupplyDelivery(
      id: _str(j['id']),
      reference: _str(j['reference']),
      sender: _str(j['sender']),
      status: _str(j['status']));
}

class SupplyRequest {
  final String id, clientId, stationId, stationName, status;
  final String requesterName, requesterId, neededBy, chain;
  final String? note;
  final int currentStep, estimatedTotal;
  final List<SupplyStep> steps;
  final List<SupplyLine> lines;
  final List<SupplyDelivery> deliveries;
  final SupplyAdvance? advance;
  final SupplySettlement? settlement;
  final DateTime? createdAt;
  const SupplyRequest(
      {required this.id,
      this.clientId = '',
      this.stationId = '',
      this.stationName = '',
      this.status = SupplyStatus.pending,
      this.requesterName = '',
      this.requesterId = '',
      this.neededBy = '',
      this.chain = 'small',
      this.note,
      this.currentStep = 0,
      this.estimatedTotal = 0,
      this.steps = const [],
      this.lines = const [],
      this.deliveries = const [],
      this.advance,
      this.settlement,
      this.createdAt});

  bool get isPending => status == SupplyStatus.pending;

  /// The kind of the step it waits at (`station`, `lead`, `final`); null when
  /// it is not pending.
  String? get waitingKind {
    if (!isPending) return null;
    for (final step in steps) {
      if (step.index == currentStep) return step.kind;
    }
    return null;
  }

  factory SupplyRequest.fromJson(Map<String, dynamic> j) => SupplyRequest(
      id: _str(j['id']),
      clientId: _str(j['client_id']),
      stationId: _str(_map(j['station'])['id']),
      stationName: _str(_map(j['station'])['name']),
      status: _str(j['status']),
      requesterName: _str(_map(j['requester'])['name']),
      requesterId: _str(_map(j['requester'])['id']),
      neededBy: _str(j['needed_by']),
      chain: j['chain'] == null ? 'small' : _str(j['chain']),
      note: j['note'] as String?,
      currentStep: _int(j['current_step']),
      estimatedTotal: _int(j['estimated_total']),
      steps: [for (final s in _rows(j['steps'])) SupplyStep.fromJson(s)],
      lines: [for (final l in _rows(j['lines'])) SupplyLine.fromJson(l)],
      deliveries: [
        for (final d in _rows(j['deliveries'])) SupplyDelivery.fromJson(d)
      ],
      advance: j['advance'] is Map
          ? SupplyAdvance.fromJson(_map(j['advance']))
          : null,
      settlement: j['settlement'] is Map
          ? SupplySettlement.fromJson(_map(j['settlement']))
          : null,
      createdAt: DateTime.tryParse(_str(j['created_at']))?.toLocal());
}

/// Money given and not yet closed: funded, or explained and waiting for
/// confirmation. [ageDays] counts business days since it was given.
class OutstandingAdvance {
  final String requestId, status, stationId, stationName, holderName;
  final int amount, ageDays;
  final int? spent, changeReturned;
  const OutstandingAdvance(
      {required this.requestId,
      required this.status,
      this.stationId = '',
      this.stationName = '',
      this.holderName = '',
      this.amount = 0,
      this.ageDays = 0,
      this.spent,
      this.changeReturned});

  int get overspend => spent == null ? 0 : (spent! - amount).clamp(0, 1 << 40);
  bool get explained => status == SupplyStatus.purchased;

  factory OutstandingAdvance.fromJson(
          Map<String, dynamic> j) =>
      OutstandingAdvance(
          requestId: _str(j['request_id']),
          status: _str(j['status']),
          stationId: _str(_map(j['station'])['id']),
          stationName: _str(_map(j['station'])['name']),
          holderName: _str(_map(j['holder'])['name']),
          amount: _int(j['amount']),
          ageDays: _int(j['age_days']),
          spent: j['spent'] == null ? null : _int(j['spent']),
          changeReturned:
              j['change_returned'] == null ? null : _int(j['change_returned']));

  /// What the request page can show of a request known only by its money.
  SupplyRequest asRequest() => SupplyRequest(
      id: requestId,
      status: status,
      stationId: stationId,
      stationName: stationName,
      advance: SupplyAdvance(amount: amount, holderName: holderName),
      settlement: spent == null
          ? null
          : SupplySettlement(
              spent: spent!,
              changeReturned: changeReturned ?? 0,
              overspend: overspend));
}

class SupplyDraftLine {
  final String? productId, item, unit;
  final int quantity, estimatedUnitPrice;
  const SupplyDraftLine(
      {this.productId,
      this.item,
      this.unit,
      required this.quantity,
      required this.estimatedUnitPrice});

  Map<String, Object?> toJson() => {
        if (productId != null) 'product_id': productId,
        if (productId == null) 'item': item,
        if (productId == null) 'unit': unit,
        'quantity': quantity,
        'estimated_unit_price': estimatedUnitPrice,
      };
}

/// What a seller sends. The station is never in it: the server uses his own.
class SupplyDraft {
  final String clientId, neededBy;
  final String? note;
  final List<SupplyDraftLine> lines;
  const SupplyDraft(
      {required this.clientId,
      required this.neededBy,
      this.note,
      required this.lines});

  Map<String, Object?> toJson() => {
        'client_id': clientId,
        'needed_by': neededBy,
        if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
        'lines': [for (final l in lines) l.toJson()],
      };
}

/// The seller's side (and an Outlet Lead's, as a seller). Online only.
abstract interface class VendorSupplyRepository {
  /// A retry with the same [SupplyDraft.clientId] returns the first request.
  Future<SupplyRequest> createSupplyRequest(String token, SupplyDraft draft);
  Future<List<SupplyRequest>> supplyRequests(String token);

  /// One request of this seller, in full. A refusal is [SupplyError]
  /// (`not_found`, 404, when it is not his).
  Future<SupplyRequest> supplyRequestById(String token, String id);
  Future<SupplyRequest> withdrawSupplyRequest(String token, String id,
      {required String clientId});

  /// The holder explains the money: [spent] plus [changeReturned] must equal
  /// what was given, or [spent] is above it and no change is returned.
  Future<SupplyRequest> settleSupply(String token, String id,
      {required String clientId,
      required int spent,
      required int changeReturned,
      required String supplier});

  /// Money this person holds and has not explained or had confirmed.
  Future<List<OutstandingAdvance>> supplyOutstanding(String token);
}

/// The office side. The server decides who may do what; the app shows only
/// what the signed-in person can do.
abstract interface class OfficeSupplyRepository {
  /// Pending requests whose current step this person may decide.
  Future<List<SupplyRequest>> waitingSupplyRequests();

  /// This person's own requests.
  Future<List<SupplyRequest>> ownSupplyRequests();

  /// One request in full (lines with received, steps, advance, settlement,
  /// linked deliveries) when this person may see it.
  Future<SupplyRequest> supplyRequestById(String id);

  /// Requests in one status (`approved`, `funded`, `purchased`, `closed`).
  /// Owner and Finance see every station; others only theirs.
  Future<List<SupplyRequest>> supplyRequestsByStatus(String status,
      {String? stationId});
  Future<SupplyRequest> decideSupplyRequest(String id,
      {required String clientId,
      required int step,
      required bool approve,
      String? reason});

  /// Owner or Finance gives money (approved requests only).
  Future<SupplyRequest> giveSupplyMoney(String id,
      {required String clientId, required int amount});

  /// Owner or Finance confirms what was spent (never the holder).
  Future<SupplyRequest> confirmSupply(String id,
      {required String clientId, required bool acceptOverspend});

  /// All unclosed advances for Owner and Finance, otherwise only the ones
  /// this person holds.
  Future<List<OutstandingAdvance>> officeSupplyOutstanding();
}

/// The HTTP side shared by the seller and office clients ([audience] is
/// `/vendor` or `/staff`).
class SupplyApi {
  final ApiClient _c;
  final String _audience;
  SupplyApi(this._c, this._audience);

  String get _base => '$_audience/supply-requests';

  Map<String, dynamic> _ok(Response<dynamic> r) {
    final status = r.statusCode ?? 0;
    final code = ApiClient.errorCode(r);
    if (status >= 400 && status != 401 && status < 500) {
      throw SupplyError(
          code ?? (status == 422 ? 'invalid' : 'refused'), status);
    }
    return _c.json(r);
  }

  List<Map<String, dynamic>> _list(Response<dynamic> r) {
    final status = r.statusCode ?? 0;
    if (status >= 400 && status != 401 && status < 500) {
      throw SupplyError(ApiClient.errorCode(r) ?? 'refused', status);
    }
    if (status != 200 || r.data is! List) _c.fail(r);
    return _rows(r.data);
  }

  Future<SupplyRequest> _one(String method, String path, Object? body) async =>
      SupplyRequest.fromJson(
          _ok(await _c.authed(method, '$_base$path', body: body)));

  Future<SupplyRequest> create(SupplyDraft draft) =>
      _one('POST', '', draft.toJson());

  Future<List<SupplyRequest>> mine() async => [
        for (final j in _list(await _c.authed('GET', _base)))
          SupplyRequest.fromJson(j)
      ];

  Future<SupplyRequest> one(String id) async =>
      SupplyRequest.fromJson(_ok(await _c.authed('GET', '$_base${_id(id)}')));

  Future<List<SupplyRequest>> byStatus(String status,
          {String? stationId}) async =>
      [
        for (final j in _list(await _c.authed(
            'GET',
            Uri(path: _base, queryParameters: {
              'status': status,
              if (stationId != null) 'station_id': stationId,
            }).toString())))
          SupplyRequest.fromJson(j)
      ];

  Future<List<SupplyRequest>> waiting() async => [
        for (final j in _list(await _c.authed('GET', '$_base/waiting')))
          SupplyRequest.fromJson(j)
      ];

  Future<List<OutstandingAdvance>> outstanding() async => [
        for (final j in _list(await _c.authed('GET', '$_base/outstanding')))
          OutstandingAdvance.fromJson(j)
      ];

  String _id(String id) => '/${Uri.encodeComponent(id)}';

  Future<SupplyRequest> withdraw(String id, String clientId) =>
      _one('POST', '${_id(id)}/withdraw', {'client_id': clientId});

  Future<SupplyRequest> settle(String id,
          {required String clientId,
          required int spent,
          required int changeReturned,
          required String supplier}) =>
      _one('POST', '${_id(id)}/settlement', {
        'client_id': clientId,
        'spent': spent,
        'change_returned': changeReturned,
        'supplier': supplier,
      });

  Future<SupplyRequest> decide(String id,
          {required String clientId,
          required int step,
          required bool approve,
          String? reason}) =>
      _one('POST', '${_id(id)}/decision', {
        'client_id': clientId,
        'step': step,
        'approve': approve,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

  Future<SupplyRequest> advance(String id,
          {required String clientId, required int amount}) =>
      _one('POST', '${_id(id)}/advance',
          {'client_id': clientId, 'amount': amount});

  Future<SupplyRequest> confirm(String id,
          {required String clientId, required bool acceptOverspend}) =>
      _one('POST', '${_id(id)}/settlement/confirm',
          {'client_id': clientId, 'accept_overspend': acceptOverspend});
}
