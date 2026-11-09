import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/business_day.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import 'history_screen.dart';
import 'history_store.dart';

/// Builds from the immutable saved sale, including its snapshotted prices.
/// Fonts and branding are bundled; printing needs no catalogue or network.
Future<Uint8List> buildSaleReceipt(
    SaleDetail sale, Strings strings, PdfPageFormat format) async {
  final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Manrope.ttf'));
  final logo = pw.MemoryImage(
      (await rootBundle.load('assets/brand/icon.png')).buffer.asUint8List());
  final entry = sale.entry;
  final recorded = eatClock(entry.recordedAt);
  final document = pw.Document(title: entry.reference, author: strings.brand);
  document.addPage(pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(24),
      theme: pw.ThemeData.withFont(base: font, bold: font),
      build: (_) => [
            pw.Image(logo, width: 48, height: 48),
            pw.SizedBox(height: 12),
            pw.Text(strings.brand, style: pw.TextStyle(fontSize: 18)),
            pw.Text(entry.reference),
            pw.Text('${strings.date(recorded)} · ${strings.hhmm(recorded)}'),
            pw.Text(strings.paymentMethodName(entry.payment.name,
                customer: entry.customer)),
            pw.Text(saleStatus(strings, entry).$1),
            pw.SizedBox(height: 20),
            pw.Table(columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(2)
            }, children: [
              pw.TableRow(children: [
                pw.Text(strings.products),
                pw.Text(strings.unitsLabel),
                pw.Text(strings.total, textAlign: pw.TextAlign.right)
              ]),
              for (final line in sale.lines)
                pw.TableRow(children: [
                  pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8),
                      child: pw.Text(line.productName)),
                  pw.Text('${line.quantity}'),
                  pw.Text(formatTsh(line.lineTotal),
                      textAlign: pw.TextAlign.right),
                ]),
            ]),
            pw.Divider(),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(strings.total),
                  pw.Text(formatTsh(entry.total)),
                ]),
          ]));
  return document.save();
}

typedef ReceiptPrinter = Future<bool> Function(SaleDetail, Strings);

final receiptPrinterProvider = Provider<ReceiptPrinter>((ref) =>
    (sale, strings) => Printing.layoutPdf(
        name: sale.entry.reference,
        onLayout: (format) => buildSaleReceipt(sale, strings, format)));
