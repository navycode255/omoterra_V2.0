import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/data/database.dart';
import 'package:mr_nyama_vendor/features/closing/closing_store.dart';
import 'package:mr_nyama_vendor/features/history/history_store.dart';
import 'package:mr_nyama_vendor/features/receiving/receiving_store.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';

import 'helpers.dart';
import 'receiving_store_test.dart' show manifest;

void main() {
  test('schema 5 upgrades additively and keeps existing sales', () async {
    final directory = await Directory.systemTemp.createTemp('mrnyama-upgrade-');
    final file = File('${directory.path}/phone.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    try {
      await SalesStore(db).saveSale(SaleDraft(
          clientId: 'old-sale',
          vendorId: 'v1',
          recordedAt: DateTime.utc(2026, 10, 23),
          payment: PaymentMethod.cash,
          lines: const [
            DraftLine(
                productId: 'kuku',
                productName: 'Kuku mzima',
                quantity: 1,
                unitPrice: 9000)
          ]));
      await db.customStatement('ALTER TABLE sale_voids DROP COLUMN note');
      await db.customStatement('ALTER TABLE receipt_lines DROP COLUMN note');
      await db.customStatement(
          'ALTER TABLE closing_count_lines DROP COLUMN reason');
      await db
          .customStatement('ALTER TABLE closing_count_lines DROP COLUMN note');
      for (final column in ['held', 'cut_from', 'cut_count']) {
        await db.customStatement(
            'ALTER TABLE catalog_products DROP COLUMN $column');
      }
      for (final column in ['credit_customer_id', 'credit_customer_name']) {
        await db.customStatement('ALTER TABLE sales DROP COLUMN $column');
      }
      await db.customStatement('PRAGMA user_version = 5');
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      expect((await db.select(db.sales).get()).single.total, 9000);
      expect(await db.select(db.saleVoids).get(), isEmpty);
      expect(await db.select(db.receiptLines).get(), isEmpty);
      expect(await db.select(db.closingCountLines).get(), isEmpty);
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 10);
    } finally {
      await db.close();
      await directory.delete(recursive: true);
    }
  });

  test(
      'receipt, closing and void evidence survives reopening and is queued once',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('mrnyama-evidence-');
    final file = File('${directory.path}/phone.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    final now = DateTime.utc(2026, 10, 23, 12);
    try {
      final sales = SalesStore(db);
      await sales.replaceCatalog(testCatalog);
      final receiving = ReceivingStore(db);
      await receiving.replaceDeliveries([manifest()]);
      Future<void> receipt() async {
        await receiving.submitReceipt(
            receiptId: 'receipt',
            eventId: 'receipt-event',
            consignmentId: 'c1',
            consignmentVersion: 1,
            sessionStationKey: 'S1',
            actorId: 'v1',
            receivedAt: now,
            counts: const [
              LineCount('L1', 48, DiscrepancyReason.short),
              LineCount('L2', 30)
            ],
            notes: const {
              'L1': 'Zilikosekana kwenye lori.'
            });
      }

      await receipt();
      await receipt();
      final products = await sales.watchProducts().first;
      await ClosingStore(db).submit(
          countId: 'closing',
          vendorId: 'v1',
          stationKey: 'S1',
          now: now,
          products: products,
          counted: const {'kuku': 2, 'paja': 0},
          reasons: const {'kuku': 'sales'},
          notes: const {'kuku': 'Wateja wengi leo.'});
      await sales.saveSale(SaleDraft(
          clientId: 'sale',
          vendorId: 'v1',
          recordedAt: now,
          payment: PaymentMethod.cash,
          lines: const [
            DraftLine(
                productId: 'kuku',
                productName: 'Kuku mzima',
                quantity: 1,
                unitPrice: 9000)
          ]));
      await HistoryStore(db).voidSale(
          voidId: 'void',
          saleClientId: 'sale',
          reason: VoidReason.other,
          note: 'Mauzo ya majaribio.',
          actorId: 'v1',
          now: now);
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      expect(
          (await ReceivingStore(db).delivery('c1'))!.lines.first.received!.note,
          'Zilikosekana kwenye lori.');
      expect(
          (await db.select(db.closingCountLines).get())
              .firstWhere((l) => l.productId == 'kuku')
              .note,
          'Wateja wengi leo.');
      expect((await HistoryStore(db).sale('sale'))!.voidRecord!.note,
          'Mauzo ya majaribio.');
      final queue = await db.select(db.outbox).get();
      expect(queue.where((e) => e.opType == 'receipt'), hasLength(1));
      final receiptPayload =
          jsonDecode(queue.singleWhere((e) => e.opType == 'receipt').payload)
              as Map;
      expect(receiptPayload['lines'][0]['note'], 'Zilikosekana kwenye lori.');
      final closingPayload = jsonDecode(
          queue.singleWhere((e) => e.opType == 'closing_count').payload) as Map;
      expect(closingPayload['lines'][0]['note'], 'Wateja wengi leo.');
      final voidPayload =
          jsonDecode(queue.singleWhere((e) => e.opType == 'sale_void').payload)
              as Map;
      expect(voidPayload['note'], 'Mauzo ya majaribio.');
    } finally {
      await db.close();
      await directory.delete(recursive: true);
    }
  });
}
