import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/data/database.dart';
import '../sales/sales_store.dart';
import 'closing_store.dart';

/// A blind count once frozen: the figures, the expected figures the vendor has
/// now seen, the products and the day. It stays on the phone (local `settings`,
/// so no schema change) until the count is saved: leaving, a lock or a killed
/// app cannot clear it, or a vendor could read the expected figures and type
/// them. Everything from the freeze to the save uses this and nothing newer.
class FrozenCount {
  final String countId, day;

  /// When the figures were counted, whenever they are saved. The server takes
  /// a count made on its own day even once the new day has begun.
  final DateTime frozenAt;
  final List<FrozenLine> lines;
  const FrozenCount(
      {required this.countId,
      required this.day,
      required this.frozenAt,
      required this.lines});

  /// The business day this count is for, as `businessDate` gives it.
  DateTime get businessDay {
    final parts = day.split('-').map(int.parse).toList();
    return DateTime.utc(parts[0], parts[1], parts[2]);
  }

  Map<String, int> get counted => {for (final l in lines) l.id: l.counted};

  /// The products as they stood at the freeze: `remaining` is the frozen
  /// expected figure, whatever the catalogue says now.
  List<Product> get products => [
        for (final l in lines)
          Product(id: l.id, name: l.name, price: null, available: l.expected)
      ];

  Map<String, Object?> toJson() => {
        'count_id': countId,
        'day': day,
        'frozen_at': frozenAt.toUtc().toIso8601String(),
        'products': [
          for (final l in lines)
            {
              'id': l.id,
              'name': l.name,
              'counted': l.counted,
              'expected': l.expected
            }
        ],
      };

  factory FrozenCount.fromJson(Map<String, dynamic> j) => FrozenCount(
      countId: j['count_id'] as String,
      day: j['day'] as String,
      frozenAt: DateTime.parse(j['frozen_at'] as String),
      lines: [
        for (final p in j['products'] as List)
          FrozenLine(p['id'] as String, p['name'] as String,
              p['counted'] as int, p['expected'] as int)
      ]);
}

class FrozenLine {
  final String id, name;
  final int counted, expected;
  const FrozenLine(this.id, this.name, this.counted, this.expected);
}

/// The phone's frozen counts, one per vendor, station and business day.
class FrozenCountStore {
  final AppDatabase db;
  FrozenCountStore(this.db);

  static String _prefix(String vendorId, String stationKey) =>
      'frozen_count|$vendorId|$stationKey|';

  Future<void> save(
          {required String vendorId,
          required String stationKey,
          required FrozenCount count}) =>
      db.into(db.settings).insertOnConflictUpdate(SettingsCompanion.insert(
          key: '${_prefix(vendorId, stationKey)}${count.day}',
          value: jsonEncode(count.toJson())));

  Future<void> clear(
          {required String vendorId,
          required String stationKey,
          required String day}) =>
      (db.delete(db.settings)
            ..where((s) =>
                s.key.equals('${_prefix(vendorId, stationKey)}$day')))
          .go();

  /// The frozen count still to be saved, the older day first. A count that
  /// reached the closing table (the app died before clearing it) is cleared
  /// here, and so is one older than [yesterday]: the phone can no longer close
  /// that day, so it belongs to the office.
  Future<FrozenCount?> pending(
      {required String vendorId,
      required String stationKey,
      required DateTime yesterday}) async {
    final prefix = _prefix(vendorId, stationKey);
    final rows = await (db.select(db.settings)
          ..where((s) => s.key.like('$prefix%'))
          ..orderBy([(s) => OrderingTerm(expression: s.key)]))
        .get();
    final oldest = dateKey(yesterday);
    FrozenCount? found;
    for (final row in rows) {
      final count = FrozenCount.fromJson(
          jsonDecode(row.value) as Map<String, dynamic>);
      final saved = await (db.select(db.closingCounts)
            ..where((c) =>
                c.vendorId.equals(vendorId) &
                c.stationKey.equals(stationKey) &
                c.businessDate.equals(count.day)))
          .getSingleOrNull();
      if (saved != null || count.day.compareTo(oldest) < 0) {
        await clear(
            vendorId: vendorId, stationKey: stationKey, day: count.day);
      } else {
        found ??= count;
      }
    }
    return found;
  }
}
