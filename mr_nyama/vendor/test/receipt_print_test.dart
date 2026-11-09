import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/history/history_store.dart';
import 'package:mr_nyama_vendor/features/history/receipt_print.dart';

import 'helpers.dart';
import 'history_flow_test.dart' show record, now;

void main() {
  testWidgets('receipt printing uses the saved sale and allows cancellation',
      (tester) async {
    SaleDetail? printed;
    final app = await pumpApp(tester, now: now, overrides: [
      receiptPrinterProvider.overrideWithValue((sale, _) async {
        printed = sale;
        return false; // Closing the system print dialog is not an error.
      }),
    ]);
    await record(app, 'receipt-sale', now);
    app.router.push(MNRoutes.saleDetail('receipt-sale'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Printi risiti'));
    await tester.tap(find.text('Printi risiti'));
    await tester.pumpAndSettle();
    expect(printed!.entry.total, 20000);
    expect(printed!.lines.first.unitPrice, 9000);
    expect(tester.takeException(), isNull);
    final stored = (await app.db.select(app.db.sales).get()).single;
    expect(stored.total, 20000);
  });

  testWidgets('receipt PDF renders from bundled fonts and stored prices',
      (tester) async {
    final app = await pumpApp(tester, now: now);
    await record(app, 'receipt-pdf', now);
    final sale =
        (await app.container.read(historyStoreProvider).sale('receipt-pdf'))!;
    final pdf =
        await buildSaleReceipt(sale, const Strings('sw'), PdfPageFormat.a4);
    expect(ascii.decode(pdf.take(5).toList()), '%PDF-');
    expect(pdf.length, greaterThan(1000));
  });
}
