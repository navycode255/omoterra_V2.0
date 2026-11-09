import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/closing/closing_store.dart';
import '../../features/damage/damage_store.dart';
import '../../features/history/history_store.dart';
import '../../features/receiving/receiving_store.dart';
import '../../features/sales/sales_store.dart';
import '../api/providers.dart';
import '../api/vendor_repository.dart';
import '../auth/session.dart';
import '../data/database.dart';
import 'outbox.dart' show offlineMarkKey;

/// Operations sent per request (the server accepts up to 200).
const syncBatchSize = 200;

/// How often a record the server kept for office review is sent again, so
/// the phone learns the office's decision (the server answers from its
/// stored decision; nothing is recorded twice).
const conflictRecheckInterval = Duration(hours: 1);

/// Wait before retrying after the n-th failed attempt.
Duration retryDelay(int attempts) => switch (attempts) {
      <= 1 => const Duration(seconds: 30),
      2 => const Duration(minutes: 1),
      3 => const Duration(minutes: 2),
      4 => const Duration(minutes: 5),
      5 => const Duration(minutes: 15),
      _ => const Duration(minutes: 30),
    };

class SyncState {
  final bool running;
  final DateTime? lastAttemptAt;

  /// `ok`, `offline`, `not_configured`, `session_expired` or `error`.
  final String? lastOutcome;
  const SyncState({this.running = false, this.lastAttemptAt, this.lastOutcome});
}

/// Sends queued operations to `/vendor/sync` and applies the answers.
///
/// Never marks anything accepted on its own: an operation leaves the
/// "waiting" states only when the server returns a result for it. Every
/// send is idempotent by op ID, so retries, crashes mid-request and
/// duplicate triggers cannot create second records.
class SyncEngine extends Notifier<SyncState> {
  bool _again = false;
  bool _recovered = false;
  bool _recheckNow = false;

  AppDatabase get _db => ref.read(databaseProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  SyncState build() => const SyncState();

  /// Asks for a sync soon. Safe to call often: a running pass absorbs it.
  /// [recheck] also asks again about every record waiting for office
  /// review, without waiting for [conflictRecheckInterval].
  void requestSync({bool recheck = false}) {
    if (recheck) _recheckNow = true;
    if (state.running) {
      _again = true;
      return;
    }
    unawaited(syncNow());
  }

  /// One sync pass (and follow-ups while more is due). Returns when done.
  Future<void> syncNow() async {
    if (state.running) {
      _again = true;
      return;
    }
    final auth = ref.read(sessionProvider).valueOrNull;
    if (auth is! SignedIn) return;
    state = SyncState(
        running: true,
        lastAttemptAt: state.lastAttemptAt,
        lastOutcome: state.lastOutcome);
    try {
      await _recover();
      do {
        _again = false;
        final full = await _pass(auth.profile.id);
        if (full) _again = true;
      } while (_again && ref.read(sessionProvider).valueOrNull is SignedIn);
    } finally {
      state = SyncState(
          running: false,
          lastAttemptAt: state.lastAttemptAt,
          lastOutcome: state.lastOutcome);
    }
  }

  /// After an app or device restart, a request may have been in flight.
  /// Its operations go back to waiting; resending them is safe.
  Future<void> _recover() async {
    if (_recovered) return;
    _recovered = true;
    await (_db.update(_db.outbox)
          ..where((o) => o.status.equals('synchronizing')))
        .write(const OutboxCompanion(status: Value('waiting')));
  }

  /// Sends one batch. Returns true when a full batch went out (more may
  /// be due).
  Future<bool> _pass(String vendorId) async {
    final now = _now();
    final recheckBefore =
        _recheckNow ? now : now.subtract(conflictRecheckInterval);
    _recheckNow = false;
    final due = await (_db.select(_db.outbox)
          ..where((o) =>
              o.vendorId.equals(vendorId) &
              ((o.status.isIn(['saved', 'waiting']) &
                      (o.nextAttemptAt.isNull() |
                          o.nextAttemptAt.isSmallerOrEqualValue(now))) |
                  (o.status.equals('conflict') &
                      (o.lastAttemptAt.isNull() |
                          o.lastAttemptAt
                              .isSmallerOrEqualValue(recheckBefore)))))
          ..orderBy([(o) => OrderingTerm(expression: o.createdAt)])
          ..limit(syncBatchSize))
        .get();
    if (due.isEmpty) return false;

    await _db.transaction(() async {
      for (final o in due) {
        // A record under office review keeps its state while it is asked
        // about again; only the time of asking is noted.
        final recheck = o.status == 'conflict';
        await (_db.update(_db.outbox)..where((x) => x.opId.equals(o.opId)))
            .write(OutboxCompanion(
                status: recheck
                    ? const Value.absent()
                    : const Value('synchronizing'),
                attempts:
                    recheck ? const Value.absent() : Value(o.attempts + 1),
                lastAttemptAt: Value(now)));
      }
    });

    // Records saved before the queue existed (schema < 5) carry no station;
    // they belong to this vendor, so the session's station is used. The
    // server checks it against the session either way.
    final sessionStation = switch (ref.read(sessionProvider).valueOrNull) {
      SignedIn(:final profile) => profile.stationKey,
      _ => '',
    };
    final repository = ref.read(vendorRepositoryProvider);
    final sendRows = <OutboxData>[];
    final operations = <SyncOperation>[];
    final mediaFailed = <OutboxData>[];
    final mediaErrors = <Type>{};
    for (final o in due) {
      String? imageKey;
      if (o.opType == 'damage_report') {
        final report = await (_db.select(_db.damageReports)
              ..where((row) => row.reportId.equals(o.opId)))
            .getSingleOrNull();
        final photoPath = report?.imagePath;
        if (photoPath != null) {
          final mediaRepository = repository is VendorMediaRepository
              ? repository as VendorMediaRepository
              : null;
          if (mediaRepository == null) {
            mediaFailed.add(o);
            mediaErrors.add(StateError);
            continue;
          }
          try {
            final bytes = await File(photoPath).readAsBytes();
            imageKey = await ref.read(sessionProvider.notifier).authorised(
                (token) => mediaRepository.uploadDamageImage(token,
                    reportId: o.opId, bytes: bytes));
          } on AuthFailure catch (failure) {
            if (failure.kind == AuthFailureKind.sessionExpired ||
                failure.kind == AuthFailureKind.suspended) {
              final code = failure.kind == AuthFailureKind.sessionExpired
                  ? 'session_expired'
                  : 'suspended';
              await _retryLater(due, now, code);
              await _log(now, code, sent: 0);
              _again = false;
              return false;
            }
            mediaFailed.add(o);
            mediaErrors.add(failure.runtimeType);
            continue;
          } catch (error) {
            mediaFailed.add(o);
            mediaErrors.add(error.runtimeType);
            continue;
          }
        }
      }
      sendRows.add(o);
      operations.add(_operation(o, sessionStation, imageKey: imageKey));
    }

    if (mediaFailed.isNotEmpty) {
      await _retryLater(mediaFailed, now, 'media_upload_failed');
    }
    if (operations.isEmpty) {
      await _log(now, 'media_upload_failed', detail: mediaErrors.firstOrNull);
      _again = false;
      return false;
    }

    SyncReply reply;
    try {
      reply = await ref.read(sessionProvider.notifier).authorised((token) =>
          repository.sync(token, phoneTime: now, operations: [...operations]));
    } on AuthFailure catch (failure) {
      final code = switch (failure.kind) {
        AuthFailureKind.offline => 'offline',
        AuthFailureKind.notConfigured => 'not_configured',
        AuthFailureKind.sessionExpired => 'session_expired',
        AuthFailureKind.suspended => 'suspended',
        _ => 'error',
      };
      await _retryLater([...sendRows, ...mediaFailed], now, code);
      await _log(now, code, sent: sendRows.length);
      _again = false;
      return false;
    } catch (error) {
      await _retryLater([...sendRows, ...mediaFailed], now, 'error');
      await _log(now, 'error',
          sent: sendRows.length, detail: error.runtimeType);
      _again = false;
      return false;
    }

    final results = {for (final r in reply.results) r.opId: r};
    var accepted = 0, conflicts = 0, rejected = 0;
    await _db.transaction(() async {
      for (final o in sendRows) {
        final r = results[o.opId];
        if (r == null) {
          // Not processed by the server this time: retry later.
          await _retryLater([o], now, 'not_processed');
          continue;
        }
        final status = switch (r.outcome) {
          OperationOutcome.accepted ||
          OperationOutcome.duplicate =>
            'synchronized',
          OperationOutcome.conflict => 'conflict',
          OperationOutcome.rejected => 'failed',
        };
        switch (status) {
          case 'synchronized':
            accepted++;
          case 'conflict':
            conflicts++;
          default:
            rejected++;
        }
        await (_db.update(_db.outbox)..where((x) => x.opId.equals(o.opId)))
            .write(OutboxCompanion(
                status: Value(status),
                resultReason: Value(r.reason),
                lastError: const Value(null),
                nextAttemptAt: const Value(null),
                syncedAt: Value(status == 'synchronized' ? now : null)));
        await _apply(o.opType, o.opId, r);
      }
      for (final id in reply.verifiedSales) {
        await ref.read(historyStoreProvider).markVerified(id);
      }
      for (final c in reply.cancelledSales) {
        await ref.read(historyStoreProvider).markCancelledByOffice(
            c.saleId, c.voidId, c.requestedAt ?? now);
      }
      for (final id in reply.confirmedClosings) {
        await ref
            .read(closingStoreProvider)
            .applyResult(id, officeConfirmed: true);
      }
    });
    await _log(now, mediaFailed.isEmpty ? 'ok' : 'media_upload_failed',
        sent: sendRows.length,
        accepted: accepted,
        conflicts: conflicts,
        rejected: rejected,
        detail: mediaErrors.firstOrNull);
    return sendRows.length == syncBatchSize;
  }

  /// Records the server's answer on the operation's own record, through
  /// the same hooks each feature already uses.
  /// The outbox row as sent: an offline mark (see `enqueueOperation`) leaves
  /// the payload and becomes `made_offline` / `offline_grant_id`.
  static SyncOperation _operation(OutboxData o, String sessionStation,
      {String? imageKey}) {
    final payload = jsonDecode(o.payload) as Map<String, dynamic>;
    final grant = payload.remove(offlineMarkKey) as String?;
    if (imageKey != null) payload['image_key'] = imageKey;
    return SyncOperation(
        opId: o.opId,
        opType: o.opType,
        vendorId: o.vendorId,
        stationKey: o.stationKey.isEmpty ? sessionStation : o.stationKey,
        businessDate: o.businessDate,
        createdAt: o.createdAt,
        payload: payload,
        offlineGrantId: grant);
  }

  Future<void> _apply(String type, String opId, OperationResult r) async {
    final ok = r.outcome == OperationOutcome.accepted ||
        r.outcome == OperationOutcome.duplicate;
    final conflict = r.outcome == OperationOutcome.conflict;
    switch (type) {
      case 'sale':
        await (_db.update(_db.sales)..where((s) => s.clientId.equals(opId)))
            .write(SalesCompanion(
                syncStatus:
                    Value(ok ? 'sent' : (conflict ? 'conflict' : 'rejected'))));
      case 'sale_void':
        await ref.read(historyStoreProvider).applyVoidResult(opId,
            accepted: ok, rejectionReason: ok ? null : r.reason);
      case 'receipt':
        await ref.read(receivingStoreProvider).applyReceiptResult(opId,
            status: ok
                ? ReceivingStatus.accepted
                : (conflict
                    ? ReceivingStatus.conflict
                    : ReceivingStatus.rejected),
            reason: r.reason);
      case 'damage_report':
        await ref
            .read(damageStoreProvider)
            .applyResult(opId, review: ok ? null : 'rejected');
      case 'closing_count':
        await ref.read(closingStoreProvider).applyResult(opId,
            conflictReason: ok ? null : (r.reason ?? 'conflict'));
    }
  }

  Future<void> _retryLater(
      List<OutboxData> ops, DateTime now, String code) async {
    // A record under office review stays there until the server answers.
    for (final o in ops.where((o) => o.status != 'conflict')) {
      // `o` was read before this attempt was counted.
      final attempts = o.attempts + 1;
      await (_db.update(_db.outbox)..where((x) => x.opId.equals(o.opId))).write(
          OutboxCompanion(
              status: const Value('waiting'),
              lastError: Value(code),
              nextAttemptAt: Value(
                  // An expired session retries as soon as the PIN is in.
                  code == 'session_expired'
                      ? null
                      : now.add(retryDelay(attempts)))));
    }
  }

  Future<void> _log(DateTime at, String outcome,
      {int sent = 0,
      int accepted = 0,
      int conflicts = 0,
      int rejected = 0,
      Type? detail}) async {
    state = SyncState(
        running: state.running, lastAttemptAt: at, lastOutcome: outcome);
    await _db.into(_db.syncLog).insert(SyncLogCompanion.insert(
        at: at,
        outcome: outcome,
        sent: Value(sent),
        accepted: Value(accepted),
        conflicts: Value(conflicts),
        rejected: Value(rejected),
        detail: Value(detail?.toString())));
    // Keep the last 200 entries.
    await _db.customStatement('DELETE FROM sync_log WHERE id NOT IN '
        '(SELECT id FROM sync_log ORDER BY id DESC LIMIT 200)');
  }
}

final syncEngineProvider =
    NotifierProvider<SyncEngine, SyncState>(SyncEngine.new);

/// Queue counts for the indicator and the sync screen.
class QueueCounts {
  final int pending;
  final int needsReview;
  const QueueCounts(this.pending, this.needsReview);
}

final queueCountsProvider = StreamProvider<QueueCounts>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
          "SELECT SUM(status IN ('saved','waiting','synchronizing')) AS p, "
          "SUM(status IN ('conflict','failed')) AS r FROM outbox",
          readsFrom: {db.outbox})
      .watchSingle()
      .map((row) => QueueCounts(
          row.readNullable<int>('p') ?? 0, row.readNullable<int>('r') ?? 0));
});

/// Operations needing attention (conflict or refused), newest first.
final attentionOperationsProvider = StreamProvider<List<OutboxData>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.outbox)
        ..where((o) => o.status.isIn(['conflict', 'failed']))
        ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
      .watch();
});
