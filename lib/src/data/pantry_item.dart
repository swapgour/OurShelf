import 'package:cloud_firestore/cloud_firestore.dart';

/// Casual stock level for a pantry item — the simplified alternative to a
/// full stock-movement ledger, per the product spec's "Simple levels for
/// casual users: Full / Half / Low / Out".
enum StockLevel { full, half, low, out }

StockLevel stockLevelFromString(String? value) {
  switch (value) {
    case 'half':
      return StockLevel.half;
    case 'low':
      return StockLevel.low;
    case 'out':
      return StockLevel.out;
    default:
      return StockLevel.full;
  }
}

String stockLevelToString(StockLevel level) => level.name;

class PantryItem {
  const PantryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.level,
    this.totalPurchased = 0,
    this.totalAmount = 0,
    this.updatedAt,
    this.expiryDate,
  });

  final String id;
  final String name;
  final String category;
  final String unit;
  final StockLevel level;

  /// Running total of [unit]s bought over time (e.g. 1 last week + 1 this
  /// week = 2) — accumulated server-side every time a purchase tops this
  /// item up. Only counts purchases made since this field was introduced;
  /// 0 means no purchase has been recorded yet, not that none is in stock.
  final num totalPurchased;

  /// Running total of ₹ spent on this item over time — same accumulation
  /// as [totalPurchased], but only from purchases that had a price logged
  /// (receipt scans and "Mark bought" both make price optional).
  final num totalAmount;
  final DateTime? updatedAt;
  final DateTime? expiryDate;

  bool get isExpiringSoon {
    final d = expiryDate;
    if (d == null) return false;
    return d.isBefore(DateTime.now().add(const Duration(days: 3)));
  }

  factory PantryItem.fromDoc(String id, Map<String, dynamic> map) {
    return PantryItem(
      id: id,
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? 'Other',
      unit: map['unit'] as String? ?? 'pc',
      level: stockLevelFromString(map['level'] as String?),
      totalPurchased: map['totalPurchased'] as num? ?? 0,
      totalAmount: map['totalAmount'] as num? ?? 0,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      expiryDate: (map['expiryDate'] as Timestamp?)?.toDate(),
    );
  }
}
