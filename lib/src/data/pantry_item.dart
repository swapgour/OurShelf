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
    this.updatedAt,
    this.expiryDate,
  });

  final String id;
  final String name;
  final String category;
  final String unit;
  final StockLevel level;
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
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      expiryDate: (map['expiryDate'] as Timestamp?)?.toDate(),
    );
  }
}
