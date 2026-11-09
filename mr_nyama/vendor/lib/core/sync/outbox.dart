import 'dart:convert';

import 'package:drift/drift.dart';

import '../auth/offline_unlock.dart';
import '../business_day.dart';
import '../data/database.dart';

/// Queues an operation for sync. Call inside the same transaction that saves
/// the record, so the record and its queue entry exist together or not at
/// all. Queuing the same [opId] again changes nothing.
///
/// While the phone is unlocked offline (business policies §10) the stored
/// JSON also names the grant under [offlineMarkKey]; the sync engine sends it
/// as `made_offline` / `offline_grant_id` and never inside the payload.
Future<void> enqueueOperation(
  AppDatabase db, {
  required String opId,
  required String opType,
  required String vendorId,
  required String stationKey,
  required DateTime occurredAt,
  required DateTime createdAt,
  required Map<String, dynamic> payload,
}) =>
    db.into(db.outbox).insert(
        OutboxCompanion.insert(
            opId: opId,
            opType: opType,
            vendorId: vendorId,
            stationKey: stationKey,
            businessDate: businessDateKey(occurredAt),
            payload: jsonEncode({
              ...payload,
              if (OfflineUnlock.markForNewOperations case final grant?)
                offlineMarkKey: grant,
            }),
            createdAt: createdAt),
        mode: InsertMode.insertOrIgnore);

/// Key under which an operation queued during an offline unlock keeps its
/// grant id in the outbox JSON. Stripped before the payload is sent.
const offlineMarkKey = '__offline_grant_id';
