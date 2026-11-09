import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/data/database.dart';

void main() {
  test('schema 9 adds the optional damage photo path without losing reports',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('mrnyama-damage-photo-');
    final file = File('${directory.path}/phone.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    try {
      await db.into(db.damageReports).insert(DamageReportsCompanion.insert(
            reportId: 'report-1',
            productId: 'product-1',
            productName: 'Kuku',
            quantity: 1,
            reason: 'burnt',
            stationKey: 'S1',
            actorId: 'vendor-1',
            reportedAt: DateTime.utc(2026, 10, 9),
          ));
      await db
          .customStatement('ALTER TABLE damage_reports DROP COLUMN image_path');
      await db.customStatement('PRAGMA user_version = 9');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      final report = await db.select(db.damageReports).getSingle();
      expect(report.reportId, 'report-1');
      expect(report.imagePath, isNull);
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 10);
    } finally {
      await db.close();
      await directory.delete(recursive: true);
    }
  });
}
