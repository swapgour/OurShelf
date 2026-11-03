import 'package:flutter/material.dart';

import '../app.dart';
import '../data/pantry_item.dart';

Color stockStatusColor(StockLevel level) {
  switch (level) {
    case StockLevel.full:
      return ourShelfSuccess;
    case StockLevel.half:
      return ourShelfWarning;
    case StockLevel.low:
      return const Color(0xFFC97A2E);
    case StockLevel.out:
      return ourShelfError;
  }
}

String stockStatusLabel(StockLevel level) {
  switch (level) {
    case StockLevel.full:
      return 'In Stock';
    case StockLevel.half:
      return 'Half Stock';
    case StockLevel.low:
      return 'Low Stock';
    case StockLevel.out:
      return 'Out of Stock';
  }
}

/// A small pill showing a pantry item's stock level in a consistent color —
/// used on Pantry cards and anywhere else stock status needs a glance-read.
class StockStatusBadge extends StatelessWidget {
  const StockStatusBadge({super.key, required this.level});

  final StockLevel level;

  @override
  Widget build(BuildContext context) {
    final color = stockStatusColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        stockStatusLabel(level),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}
