import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import 'vendor_payment_screens.dart';

Future<T> payCall<T>(
        Ref ref, Future<T> Function(OfficeVendorPayRepository) call) =>
    ref.read(officeSessionProvider.notifier).guard((repo) {
      if (repo is! OfficeVendorPayRepository) {
        throw const OfficeError(OfficeErrorKind.notFound);
      }
      return call(repo as OfficeVendorPayRepository);
    });

final vendorPayOverviewProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>(
        (ref) => payCall(ref, (r) => r.vendorPayOverview()));
typedef PayStatementKey = ({String vendor, String from, String to});
final vendorPayStatementProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, PayStatementKey>((ref, k) =>
        payCall(ref, (r) => r.vendorPayStatement(k.vendor, k.from, k.to)));

// Money parsing is strict: a missing amount stays unknown, never a fabricated zero.
int? payInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  throw const FormatException();
}

Map<String, dynamic> payMap(Object? value) =>
    Map<String, dynamic>.from(value as Map);
List<Map<String, dynamic>> payRows(Object? value) =>
    (value as List).map(payMap).toList();
VendorPayFrequency? payFrequency(Object? value) =>
    value == null ? null : VendorPayFrequency.values.byName(value as String);
VendorPaySummary paySummary(Map<String, dynamic> row) => VendorPaySummary(
    id: row['id'] as String,
    name: row['name'] as String,
    station: row['station'] as String?,
    frequency: payFrequency(row['frequency']),
    earned: payInt(row['earned']),
    paid: payInt(row['paid']),
    balance: payInt(row['balance']),
    due: payInt(row['due']),
    overpaid: payInt(row['overpaid']),
    nextDue: row['next_due'] == null
        ? null
        : DateTime.parse(row['next_due'] as String));
