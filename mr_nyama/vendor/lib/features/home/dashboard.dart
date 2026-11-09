import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../core/api/vendor_repository.dart';
import '../../core/auth/session.dart';
import '../../shared/widgets/sync_indicator.dart';
import '../../core/sync/sync_engine.dart';
import '../sales/sales_store.dart';

/// Today's figures from the server. Re-fetched when the dashboard opens or
/// is pulled down; never computed or invented on the phone.
final dashboardProvider =
    FutureProvider.autoDispose<DashboardSummary>((ref) async {
  // Refetch for a new session.
  ref.watch(sessionProvider.select((s) => s.valueOrNull is SignedIn));
  final repository = ref.read(vendorRepositoryProvider);
  return ref
      .read(sessionProvider.notifier)
      .authorised((token) => repository.dashboard(token));
});

/// Saved records overlap the outbox: count them once. Legacy records that
/// predate the queue remain visible until backfill has caught up.
final syncOutstandingCountProvider = Provider<int?>((ref) {
  final queue = ref.watch(queueCountsProvider).valueOrNull;
  final legacy = ref.watch(unsentCountProvider).valueOrNull;
  if (queue == null && legacy == null) return null;
  final pending = queue?.pending ?? 0;
  final unsent = legacy ?? 0;
  return (pending > unsent ? pending : unsent) + (queue?.needsReview ?? 0);
});

/// Sending takes precedence while a pass runs. An empty confirmed queue is
/// green; unavailable/loading local counts must never imply everything is sent.
final syncStatusProvider = Provider<MNSyncStatus>((ref) {
  if (ref.watch(syncEngineProvider).running) return MNSyncStatus.sending;
  final queueState = ref.watch(queueCountsProvider);
  final legacyState = ref.watch(unsentCountProvider);
  final queue = queueState.valueOrNull;
  final legacy = legacyState.valueOrNull;
  if ((queue?.needsReview ?? 0) > 0) return MNSyncStatus.attention;
  if ((ref.watch(syncOutstandingCountProvider) ?? 0) > 0) {
    return MNSyncStatus.waiting;
  }
  if (queue == null ||
      legacy == null ||
      queueState.hasError ||
      legacyState.hasError) {
    return MNSyncStatus.unknown;
  }
  return MNSyncStatus.sent;
});
