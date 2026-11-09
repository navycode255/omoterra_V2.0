import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/data/database.dart';
import '../../core/sync/outbox.dart';
import '../../core/sync/payloads.dart';
import '../sales/sales_store.dart';

/// Reasons a vendor can give, matching the server contract.
/// The server accepts notes up to this length (`DamageReport.note`).
const damageNoteMaxLength = 200;

enum DamageReason { spoiled, burnt, spilled, other }

class DamageEntry {
  final String reportId;
  final String productName;
  final int quantity;
  final DamageReason reason;
  final String? note;
  final String? photoPath;
  final DateTime reportedAt;

  /// `saved` while only on this phone.
  final String syncStatus;

  /// From the server: `reported`, `verified` or `rejected`.
  final String review;

  const DamageEntry(
      {required this.reportId,
      required this.productName,
      required this.quantity,
      required this.reason,
      this.note,
      this.photoPath,
      required this.reportedAt,
      required this.syncStatus,
      required this.review});

  bool get sent => syncStatus != 'saved';
}

class DamageRefused implements Exception {
  final String reason;
  const DamageRefused(this.reason);
}

/// Damage reports on this phone. Reporting deducts nothing: stock changes
/// only if staff verify the loss on the server, once, keyed by the report.
class DamageStore {
  final AppDatabase db;
  DamageStore(this.db);

  DamageEntry _entry(DamageReport r) => DamageEntry(
      reportId: r.reportId,
      productName: r.productName,
      quantity: r.quantity,
      reason: DamageReason.values.byName(r.reason),
      note: r.note,
      photoPath: r.imagePath,
      reportedAt: r.reportedAt,
      syncStatus: r.syncStatus,
      review: r.review);

  /// Reports from the last seven days, newest first.
  Stream<List<DamageEntry>> watchRecent(DateTime now) =>
      (db.select(db.damageReports)
            ..where((r) => r.reportedAt
                .isBiggerOrEqualValue(now.subtract(const Duration(days: 7))))
            ..orderBy([(r) => OrderingTerm.desc(r.reportedAt)]))
          .watch()
          .map((rows) => rows.map(_entry).toList());

  /// A report for the same product, quantity and reason in the last five
  /// minutes: likely the same damage reported twice. The vendor is asked
  /// before a second one is saved.
  Future<DamageEntry?> recentSimilar(
      {required String productId,
      required int quantity,
      required DamageReason reason,
      required DateTime now}) async {
    final row = await (db.select(db.damageReports)
          ..where((r) =>
              r.productId.equals(productId) &
              r.quantity.equals(quantity) &
              r.reason.equals(reason.name) &
              r.reportedAt.isBiggerOrEqualValue(
                  now.subtract(const Duration(minutes: 5))))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _entry(row);
  }

  /// Copies a picker temporary file into app-private storage so it survives
  /// process restarts and remains available to the offline sync queue.
  Future<String> persistPhoto(String reportId, String sourcePath) async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/damage_photos');
    await directory.create(recursive: true);
    final target = File('${directory.path}/$reportId.photo');
    await File(sourcePath).copy(target.path);
    return target.path;
  }

  /// Saves a report. The same [reportId] again returns the stored report
  /// and writes nothing.
  Future<DamageEntry> submit({
    required String reportId,
    required Product product,
    required int quantity,
    required DamageReason reason,
    String? note,
    String? photoPath,
    required String stationKey,
    required String actorId,
    required DateTime now,
  }) =>
      db.transaction(() async {
        final existing = await (db.select(db.damageReports)
              ..where((r) => r.reportId.equals(reportId)))
            .getSingleOrNull();
        if (existing != null) return _entry(existing);
        if (quantity <= 0) throw const DamageRefused('quantity');
        final known = await (db.select(db.catalogProducts)
              ..where((p) => p.id.equals(product.id)))
            .getSingleOrNull();
        if (known == null) throw const DamageRefused('product');
        var trimmed = note?.trim();
        if (trimmed != null && trimmed.length > damageNoteMaxLength) {
          trimmed = trimmed.substring(0, damageNoteMaxLength);
        }
        final savedPhotoPath =
            photoPath == null ? null : await persistPhoto(reportId, photoPath);
        await db.into(db.damageReports).insert(DamageReportsCompanion.insert(
            reportId: reportId,
            productId: product.id,
            productName: product.name,
            quantity: quantity,
            reason: reason.name,
            note: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
            imagePath: Value(savedPhotoPath),
            stationKey: stationKey,
            actorId: actorId,
            reportedAt: now));
        await enqueueOperation(db,
            opId: reportId,
            opType: 'damage_report',
            vendorId: actorId,
            stationKey: stationKey,
            occurredAt: now,
            createdAt: now,
            payload: damagePayload(
                reportId: reportId,
                productId: product.id,
                quantity: quantity,
                reason: reason.name,
                note: trimmed == null || trimmed.isEmpty ? null : trimmed,
                reportedAt: now));
        return _entry((await (db.select(db.damageReports)
              ..where((r) => r.reportId.equals(reportId)))
            .getSingle()));
      });

  /// Applies the server's answer (sync milestone).
  Future<void> applyResult(String reportId,
          {bool sent = true, String? review}) =>
      (db.update(db.damageReports)..where((r) => r.reportId.equals(reportId)))
          .write(DamageReportsCompanion(
              syncStatus: Value(sent ? 'sent' : 'saved'),
              review: review == null ? const Value.absent() : Value(review)));
}

final damageStoreProvider =
    Provider<DamageStore>((ref) => DamageStore(ref.watch(databaseProvider)));
