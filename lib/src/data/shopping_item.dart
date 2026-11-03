import 'package:cloud_firestore/cloud_firestore.dart';

enum ItemStatus { toBuy, bought }

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.status,
    required this.addedByName,
    this.price,
    this.paidByName,
    this.createdAt,
    this.boughtAt,
  });

  final String id;
  final String name;
  final String category;
  final String quantity;
  final String unit;
  final ItemStatus status;
  final String addedByName;
  final double? price;
  final String? paidByName;
  final DateTime? createdAt;
  final DateTime? boughtAt;

  factory ShoppingItem.fromDoc(String id, Map<String, dynamic> map) {
    return ShoppingItem(
      id: id,
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? 'Other',
      quantity: map['quantity'] as String? ?? '1',
      unit: map['unit'] as String? ?? 'pc',
      status: (map['status'] as String? ?? 'to_buy') == 'bought'
          ? ItemStatus.bought
          : ItemStatus.toBuy,
      addedByName: map['addedByName'] as String? ?? 'Someone',
      price: (map['price'] as num?)?.toDouble(),
      paidByName: map['paidByName'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      boughtAt: (map['boughtAt'] as Timestamp?)?.toDate(),
    );
  }
}
