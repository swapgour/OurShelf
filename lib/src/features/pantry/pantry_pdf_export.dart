import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/pantry_item.dart';

String _statusText(StockLevel level) => switch (level) {
  StockLevel.full || StockLevel.half => 'Available',
  StockLevel.low => 'Low',
  StockLevel.out => 'Empty',
};

/// "2", "1.5" — trims a trailing ".0", or "-" when no purchase has been
/// recorded for this item yet (not the same as a quantity of zero). A
/// plain hyphen rather than an "—" em dash — the PDF's default font has no
/// glyph for that either and renders it as a missing-character box, same
/// issue as the rupee sign below.
String _quantityText(num totalPurchased) {
  if (totalPurchased <= 0) return '-';
  return totalPurchased == totalPurchased.roundToDouble()
      ? totalPurchased.toStringAsFixed(0)
      : totalPurchased.toString();
}

/// "Rs 290", or "-" when no purchase of this item had a price logged.
/// Spelled out rather than "₹" — the PDF's default font has no glyph for
/// the rupee sign and would render it as a missing-character box.
String _amountText(num totalAmount) {
  if (totalAmount <= 0) return '-';
  return 'Rs ${totalAmount.toStringAsFixed(0)}';
}

Future<Uint8List> _buildPdfBytes(List<PantryItem> items) async {
  final doc = pw.Document();
  final logoBytes = await rootBundle.load('assets/icon/icon_doc.png');
  final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());

  final byCategory = <String, List<PantryItem>>{};
  for (final item in items) {
    byCategory.putIfAbsent(item.category, () => []).add(item);
  }
  final categories = byCategory.keys.toList()..sort();
  for (final list in byCategory.values) {
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  final lowCount = items.where((i) => i.level == StockLevel.low).length;
  final emptyCount = items.where((i) => i.level == StockLevel.out).length;
  final generatedAt = DateFormat('d MMM yyyy, h:mm a').format(DateTime.now());

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 40),
      header: (context) => context.pageNumber == 1
          ? pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Image(logo, width: 44, height: 44),
                pw.SizedBox(height: 6),
                pw.Text(
                  'OurShelf',
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  'Pantry Inventory Report',
                  style: const pw.TextStyle(fontSize: 13),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Generated $generatedAt',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Total items: ${items.length}   |   Low stock: $lowCount   |   Empty: $emptyCount',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1),
              ],
            )
          : pw.Container(),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        for (final category in categories) ...[
          pw.SizedBox(height: 14),
          pw.Text(
            '${category.toUpperCase()} (${byCategory[category]!.length})',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: ['Product', 'Quantity', 'Unit', 'Amount', 'Status'],
            data: [
              for (final item in byCategory[category]!)
                [
                  item.name,
                  _quantityText(item.totalPurchased),
                  item.unit,
                  _amountText(item.totalAmount),
                  _statusText(item.level),
                ],
            ],
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.6),
              1: const pw.FlexColumnWidth(1.1),
              2: const pw.FlexColumnWidth(1.1),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.3),
            },
          ),
        ],
      ],
    ),
  );

  return doc.save();
}

/// Exposed for `tool/export_sample_pdf.dart` and for anything else that
/// wants the raw bytes without going through a platform print/share
/// channel (e.g. a future email/upload flow).
Future<Uint8List> buildPantryInventoryPdfBytes(List<PantryItem> items) => _buildPdfBytes(items);

/// Opens the system print/save dialog with the pantry's current data as a
/// PDF — the user can save it (acts as a download, via the OS's own "Save
/// as PDF"/"Save to Drive" options), print it, or tap through to the same
/// share sheet [sharePantryInventoryPdf] uses.
Future<void> openPantryInventoryPdf(List<PantryItem> items) async {
  final bytes = await _buildPdfBytes(items);
  await Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: 'OurShelf Pantry Inventory',
  );
}

/// Shares the pantry's current data as a PDF through Android's native share
/// sheet (WhatsApp, email, "Save to Files", etc.).
Future<void> sharePantryInventoryPdf(List<PantryItem> items) async {
  final bytes = await _buildPdfBytes(items);
  final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
  await Printing.sharePdf(bytes: bytes, filename: 'ourshelf_pantry_$stamp.pdf');
}
