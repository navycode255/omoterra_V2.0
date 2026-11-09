/// Credit customers in the office (MN018, owner decisions 25 October 2026):
/// registered per station, limits set by the owner, repayments, reversals
/// and write-offs. Figures are the server's.
library;

String _str(Object? v) => v == null ? '' : '$v';
String? _opt(Object? v) => v == null || '$v'.isEmpty ? null : '$v';
int _int(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v) : null;

class OfficeCreditCustomer {
  final String id, name, status, stationId, stationName;
  final String? phone, note;
  final int? creditLimit;
  final int creditSales, repaid, writtenOff, owed;
  final DateTime? lastCreditSaleAt;
  const OfficeCreditCustomer(
      {required this.id,
      required this.name,
      this.status = 'active',
      this.stationId = '',
      this.stationName = '',
      this.phone,
      this.note,
      this.creditLimit,
      this.creditSales = 0,
      this.repaid = 0,
      this.writtenOff = 0,
      this.owed = 0,
      this.lastCreditSaleAt});

  bool get suspended => status != 'active';
  bool get creditAllowed => !suspended && creditLimit != null;
  bool get overLimit => creditLimit != null && owed > creditLimit!;

  factory OfficeCreditCustomer.fromJson(Map<String, dynamic> j) {
    final station = j['station'];
    return OfficeCreditCustomer(
        id: _str(j['id']),
        name: _str(j['name']),
        status: _opt(j['status']) ?? 'active',
        stationId: station is Map ? _str(station['id']) : '',
        stationName: station is Map ? _str(station['name']) : '',
        phone: _opt(j['phone']),
        note: _opt(j['note']),
        creditLimit: j['credit_limit'] is int ? j['credit_limit'] as int : null,
        creditSales: _int(j['credit_sales']),
        repaid: _int(j['repaid']),
        writtenOff: _int(j['written_off']),
        owed: _int(j['owed']),
        lastCreditSaleAt: _time(j['last_credit_sale_at']));
  }
}

/// One line of a customer's statement: a credit sale, a repayment, a
/// repayment's reversal or a write-off.
class OfficeCreditEntry {
  final String kind, id;
  final DateTime? at;
  final int amount;
  final String? status, method, items, note, reason, by, reversesId;
  final bool reversed;
  const OfficeCreditEntry(
      {required this.kind,
      required this.id,
      this.at,
      this.amount = 0,
      this.status,
      this.method,
      this.items,
      this.note,
      this.reason,
      this.by,
      this.reversesId,
      this.reversed = false});

  /// A repayment that can still be reversed.
  bool get reversible => kind == 'repayment' && !reversed;

  factory OfficeCreditEntry.fromJson(Map<String, dynamic> j) =>
      OfficeCreditEntry(
          kind: _str(j['kind']),
          id: _str(j['id']),
          at: _time(j['at']),
          amount: _int(j['amount']),
          status: _opt(j['status']),
          method: _opt(j['method']),
          items: _opt(j['items']),
          note: _opt(j['note']),
          reason: _opt(j['reason']),
          by: _opt(j['by']),
          reversesId: _opt(j['reverses_id']),
          reversed: j['reversed'] == true);
}

class OfficeCreditStatement {
  final OfficeCreditCustomer customer;
  final List<OfficeCreditEntry> entries;
  const OfficeCreditStatement(this.customer, this.entries);

  factory OfficeCreditStatement.fromJson(Map<String, dynamic> j) =>
      OfficeCreditStatement(
          OfficeCreditCustomer.fromJson(
              Map<String, dynamic>.from(j['customer'] as Map)),
          [
            for (final e in j['entries'] as List? ?? const [])
              OfficeCreditEntry.fromJson(Map<String, dynamic>.from(e as Map))
          ]);
}

/// Office credit calls; implemented by the HTTP office repository.
abstract interface class OfficeCreditRepository {
  Future<List<OfficeCreditCustomer>> creditCustomers({String? stationId});
  Future<OfficeCreditCustomer> createCreditCustomer(
      {required String stationId,
      required String name,
      String? phone,
      String? note});
  Future<OfficeCreditStatement> creditStatement(String customerId);

  /// Owner only; null removes the limit (no more credit).
  Future<OfficeCreditCustomer> setCreditLimit(String customerId,
      {required int? limit, required String reason});
  Future<OfficeCreditCustomer> setCreditStatus(String customerId,
      {required bool suspended, required String reason});
  Future<OfficeCreditStatement> recordCreditRepayment(String customerId,
      {required int amount, required String method, String? note});
  Future<OfficeCreditStatement> reverseCreditRepayment(String repaymentId,
      {required String reason});
  Future<OfficeCreditStatement> writeOffCredit(String customerId,
      {required int amount, required String reason});
}
