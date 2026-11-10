import 'package:cloud_firestore/cloud_firestore.dart';

import '../notifications/push_trigger.dart';
import 'categorization_service.dart';
import 'pantry_item.dart';

/// Casual pantry tracking: one doc per item (keyed by its lowercased name),
/// holding a simple Full/Half/Low/Out level. A later milestone replaces
/// this with full stock-movement tracking (purchases, consumption,
/// corrections, batches/expiry) per the product spec.
class PantryRepository {
  PantryRepository({FirebaseFirestore? firestore, PushTrigger? pushTrigger})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _push = pushTrigger ?? PushTrigger();

  final FirebaseFirestore _firestore;
  final PushTrigger _push;

  CollectionReference<Map<String, dynamic>> _pantry(String groupId) =>
      _firestore.collection('groups').doc(groupId).collection('pantry');

  String _idFor(String name) => name.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '_',
  );

  Stream<List<PantryItem>> watchPantry(String groupId) {
    return _pantry(groupId).orderBy('name').snapshots().map(
      (snap) =>
          snap.docs.map((d) => PantryItem.fromDoc(d.id, d.data())).toList(),
    );
  }

  /// Tops a pantry item back up to "full" after a purchase, creating the
  /// pantry entry the first time this item is bought, and adds [quantity]
  /// to its running [PantryItem.totalPurchased] total (e.g. 1 bought last
  /// week + 1 bought this week shows a total of 2). [price], when given,
  /// adds to [PantryItem.totalAmount] the same way.
  Future<void> topUpFromPurchase({
    required String groupId,
    required String name,
    required String category,
    required String unit,
    required String quantity,
    double? price,
  }) {
    final parsedQuantity = num.tryParse(quantity.trim()) ?? 1;
    final data = <String, dynamic>{
      'name': name,
      'category': category,
      'unit': unit,
      'level': 'full',
      'totalPurchased': FieldValue.increment(parsedQuantity),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (price != null) data['totalAmount'] = FieldValue.increment(price);
    return _pantry(groupId).doc(_idFor(name)).set(data, SetOptions(merge: true));
  }

  Future<void> setLevel({
    required String groupId,
    required String itemId,
    required StockLevel level,
    required String itemName,
    required String actorUid,
  }) async {
    await _pantry(groupId).doc(itemId).update({
      'level': stockLevelToString(level),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (level == StockLevel.low || level == StockLevel.out) {
      _push.notifyGroup(
        groupId: groupId,
        excludeUid: actorUid,
        title: 'OurShelf',
        body: level == StockLevel.out
            ? '$itemName is out — add it to the list?'
            : '$itemName is running low — add it to the list?',
      );
    }
  }

  /// Sets or clears (pass null) an item's expiry date — "paneer expires
  /// tomorrow; use it soon".
  Future<void> setExpiry({
    required String groupId,
    required String itemId,
    required DateTime? expiryDate,
  }) {
    return _pantry(groupId).doc(itemId).update({
      'expiryDate': expiryDate == null
          ? FieldValue.delete()
          : Timestamp.fromDate(expiryDate),
    });
  }

  Future<void> deleteItem({required String groupId, required String itemId}) {
    return _pantry(groupId).doc(itemId).delete();
  }

  Future<void> updateUnit({
    required String groupId,
    required String itemId,
    required String unit,
  }) {
    return _pantry(groupId).doc(itemId).update({
      'unit': unit,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Same one-time migration as
  /// [ShoppingListRepository.recategorizeAllItems], for pantry entries.
  /// Never touches [PantryItem.unit] or [StockLevel] — category only.
  Future<List<CategoryChange>> recategorizeAllItems(
    String groupId,
    Map<String, String> learnedAliases,
  ) async {
    final snap = await _pantry(groupId).get();
    final batch = _firestore.batch();
    final changes = <CategoryChange>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final name = data['name'] as String? ?? '';
      final oldCategory = data['category'] as String? ?? 'Other';
      final newCategory = resolveMigratedCategory(name, oldCategory, learnedAliases);
      if (newCategory == null) continue;
      batch.update(doc.reference, {'category': newCategory});
      changes.add((name: name, oldCategory: oldCategory, newCategory: newCategory));
    }
    if (changes.isNotEmpty) await batch.commit();
    return changes;
  }
}
