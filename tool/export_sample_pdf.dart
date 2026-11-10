// One-off dev utility, not a real test — run with `flutter test
// tool/export_sample_pdf.dart` to render a sample Pantry PDF export for a
// quick visual check (e.g. after changing pantry_pdf_export.dart) without
// needing a device or the in-app share/print flow.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ourshelf/src/data/pantry_item.dart';
import 'package:ourshelf/src/features/pantry/pantry_pdf_export.dart';

void main() {
  testWidgets('export sample pantry pdf', (tester) async {
    await tester.runAsync(() async {
      const items = [
        PantryItem(id: '1', name: 'Rice', category: 'Grains & Flours', unit: 'kg', level: StockLevel.full, totalPurchased: 5, totalAmount: 450),
        PantryItem(id: '2', name: 'Curd', category: 'Dairy & Eggs', unit: 'pack', level: StockLevel.low, totalPurchased: 2, totalAmount: 90),
        PantryItem(id: '3', name: 'Brinjal', category: 'Vegetables', unit: 'kg', level: StockLevel.full, totalPurchased: 3.5, totalAmount: 140),
        PantryItem(id: '4', name: 'Groundnut', category: 'Dry Fruits & Nuts', unit: '1 L', level: StockLevel.full),
      ];
      final bytes = await buildPantryInventoryPdfBytes(items);
      File('sample_pantry.pdf').writeAsBytesSync(bytes);
      // ignore: avoid_print
      print('wrote sample_pantry.pdf');
    });
  });
}
