import 'package:cloud_firestore/cloud_firestore.dart';

import '../notifications/push_trigger.dart';
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
  /// pantry entry the first time this item is bought.
  Future<void> topUpFromPurchase({
    required String groupId,
    required String name,
    required String category,
    required String unit,
  }) {
    return _pantry(groupId).doc(_idFor(name)).set({
      'name': name,
      'category': category,
      'unit': unit,
      'level': 'full',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
}
