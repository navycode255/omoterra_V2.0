import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../business_day.dart';
import '../../features/sales/sales_store.dart' show databaseProvider;

/// Statuses that mean "only on this phone". A record the office holds for
/// review (`conflict`) or refused (`failed`) has reached the server, so it
/// is not unsent.
const unsentStatuses = ['saved', 'waiting', 'synchronizing'];

/// When the oldest unsent record was saved, or null when none is waiting.
final oldestUnsentProvider = StreamProvider<DateTime?>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.outbox)
        ..where((o) => o.status.isIn(unsentStatuses))
        ..orderBy([(o) => OrderingTerm.asc(o.createdAt)])
        ..limit(1))
      .watchSingleOrNull()
      .map((row) => row?.createdAt);
});

/// A fixed rule, not a setting: a record unsent for more than one business
/// day (by Tanzanian business date, not 24 hours) is worth a warning.
bool unsentPastOneBusinessDay(DateTime oldest, DateTime now) =>
    businessDate(now).difference(businessDate(oldest)).inDays > 1;

/// The business date to show in the Nyumbani warning, or null when there is
/// nothing to warn about.
final unsentWarningProvider = Provider<DateTime?>((ref) {
  final oldest = ref.watch(oldestUnsentProvider).valueOrNull;
  if (oldest == null) return null;
  final now = ref.read(clockProvider)();
  return unsentPastOneBusinessDay(oldest, now) ? businessDate(oldest) : null;
});
