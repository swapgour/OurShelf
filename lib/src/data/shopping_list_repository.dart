import 'package:cloud_firestore/cloud_firestore.dart';

import '../notifications/push_trigger.dart';
import 'categorization_service.dart';
import 'shopping_item.dart';

class ShoppingListRepository {
  ShoppingListRepository({FirebaseFirestore? firestore, PushTrigger? pushTrigger})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _push = pushTrigger ?? PushTrigger();

  final FirebaseFirestore _firestore;
  final PushTrigger _push;

  CollectionReference<Map<String, dynamic>> _items(String groupId) =>
      _firestore.collection('groups').doc(groupId).collection('items');

  Stream<List<ShoppingItem>> watchItems(String groupId) {
    return _items(groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ShoppingItem.fromDoc(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> addItem({
    required String groupId,
    required String name,
    required String category,
    required String quantity,
    required String unit,
    required String addedByUid,
    required String addedByName,
  }) async {
    await _items(groupId).add({
      'name': name,
      'nameLower': name.trim().toLowerCase(),
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'status': 'to_buy',
      'addedBy': addedByUid,
      'addedByName': addedByName,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _push.notifyGroup(
      groupId: groupId,
      excludeUid: addedByUid,
      title: 'OurShelf',
      body: '$addedByName added $name to the list',
    );
  }

  /// Recent item history (any status) for this group, newest first — used
  /// to surface frequent items and support "repeat last month's list".
  Future<List<ShoppingItem>> recentHistory({
    required String groupId,
    int limit = 300,
  }) async {
    final snap = await _items(
      groupId,
    ).orderBy('createdAt', descending: true).limit(limit).get();
    return snap.docs.map((d) => ShoppingItem.fromDoc(d.id, d.data())).toList();
  }

  /// Adds several items in one batched write — used to load a starter
  /// template in a single tap instead of one round trip per item.
  Future<void> addItemsBatch({
    required String groupId,
    required List<({String name, String category, String quantity, String unit})>
    items,
    required String addedByUid,
    required String addedByName,
  }) async {
    final batch = _firestore.batch();
    for (final item in items) {
      final ref = _items(groupId).doc();
      batch.set(ref, {
        'name': item.name,
        'nameLower': item.name.trim().toLowerCase(),
        'category': item.category,
        'quantity': item.quantity,
        'unit': item.unit,
        'status': 'to_buy',
        'addedBy': addedByUid,
        'addedByName': addedByName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    if (items.isNotEmpty) {
      _push.notifyGroup(
        groupId: groupId,
        excludeUid: addedByUid,
        title: 'OurShelf',
        body:
            '$addedByName added ${items.length} '
            'item${items.length == 1 ? '' : 's'} to the list',
      );
    }
  }

  /// Adds a brand-new item that's already been bought — used by the receipt
  /// scanner when a scanned item isn't already on the list.
  Future<void> addPurchasedItem({
    required String groupId,
    required String name,
    required String category,
    required String quantity,
    required String unit,
    required String addedByUid,
    required String addedByName,
    double? price,
    String? paidByName,
    DateTime? boughtAt,
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'nameLower': name.trim().toLowerCase(),
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'status': 'bought',
      'addedBy': addedByUid,
      'addedByName': addedByName,
      'createdAt': FieldValue.serverTimestamp(),
      'boughtAt': boughtAt != null ? Timestamp.fromDate(boughtAt) : FieldValue.serverTimestamp(),
      'boughtByUid': addedByUid,
    };
    if (price != null) data['price'] = price;
    if (paidByName != null) data['paidByName'] = paidByName;
    await _items(groupId).add(data);
    _push.notifyGroup(
      groupId: groupId,
      excludeUid: addedByUid,
      title: 'OurShelf',
      body: '${paidByName ?? addedByName} bought $name',
    );
  }

  /// Looks for an existing item with the same name that's either still on
  /// the list, or was bought recently, so the UI can warn before adding a
  /// duplicate (e.g. "Priya bought milk 1 hr ago").
  Future<ShoppingItem?> findRecentMatch({
    required String groupId,
    required String name,
  }) async {
    final nameLower = name.trim().toLowerCase();
    if (nameLower.isEmpty) return null;
    final snap = await _items(
      groupId,
    ).where('nameLower', isEqualTo: nameLower).limit(5).get();
    if (snap.docs.isEmpty) return null;

    ShoppingItem? bestMatch;
    for (final doc in snap.docs) {
      final item = ShoppingItem.fromDoc(doc.id, doc.data());
      if (item.status == ItemStatus.toBuy) {
        return item; // still on the list — always worth flagging
      }
      final boughtAt = item.boughtAt;
      if (boughtAt != null &&
          DateTime.now().difference(boughtAt) < const Duration(hours: 24)) {
        bestMatch = item;
      }
    }
    return bestMatch;
  }

  /// Marks an item back as "to buy", clearing purchase details.
  Future<void> markToBuy({required String groupId, required String itemId}) {
    return _items(groupId).doc(itemId).update({
      'status': 'to_buy',
      'price': FieldValue.delete(),
      'paidByName': FieldValue.delete(),
      'boughtAt': FieldValue.delete(),
      'boughtByUid': FieldValue.delete(),
    });
  }

  /// Marks an item as bought, optionally recording price and who paid.
  /// [boughtByUid] is excluded from the push notification so nobody gets
  /// notified about their own purchase. [itemName] is only used for that
  /// notification text, not stored.
  Future<void> markBought({
    required String groupId,
    required String itemId,
    required String boughtByUid,
    required String itemName,
    double? price,
    String? paidByName,
    String? quantity,
  }) async {
    final data = <String, dynamic>{
      'status': 'bought',
      'boughtAt': FieldValue.serverTimestamp(),
      'boughtByUid': boughtByUid,
    };
    if (price != null) data['price'] = price;
    if (paidByName != null) data['paidByName'] = paidByName;
    if (quantity != null) data['quantity'] = quantity;
    await _items(groupId).doc(itemId).update(data);
    _push.notifyGroup(
      groupId: groupId,
      excludeUid: boughtByUid,
      title: 'OurShelf',
      body: '${paidByName ?? 'Someone'} bought $itemName',
    );
  }

  Future<void> updateQuantity({
    required String groupId,
    required String itemId,
    required String quantity,
    required String unit,
  }) {
    return _items(
      groupId,
    ).doc(itemId).update({'quantity': quantity, 'unit': unit});
  }

  Future<void> updateCategory({
    required String groupId,
    required String itemId,
    required String category,
  }) {
    return _items(groupId).doc(itemId).update({'category': category});
  }

  /// Past purchases of an item by name, newest first — "you paid ₹145 last
  /// time; today ₹165". Sorted client-side to avoid requiring a composite
  /// index on top of the nameLower equality filter.
  Future<List<ShoppingItem>> priceHistory({
    required String groupId,
    required String name,
  }) async {
    final nameLower = name.trim().toLowerCase();
    final snap = await _items(
      groupId,
    ).where('nameLower', isEqualTo: nameLower).limit(20).get();
    final purchases = snap.docs
        .map((d) => ShoppingItem.fromDoc(d.id, d.data()))
        .where((i) => i.status == ItemStatus.bought && i.price != null)
        .toList()
      ..sort(
        (a, b) => (b.boughtAt ?? DateTime(0)).compareTo(
          a.boughtAt ?? DateTime(0),
        ),
      );
    return purchases;
  }

  Future<void> deleteItem({required String groupId, required String itemId}) {
    return _items(groupId).doc(itemId).delete();
  }

  /// One-time migration: re-evaluates EVERY item's category (not just ones
  /// stuck in "Other") against the categorization service — corrects an
  /// item that was already miscategorized under the old taxonomy, renames
  /// old category names to their 1.2.0 equivalents, and leaves genuinely
  /// unrecognized custom entries untouched. See [resolveMigratedCategory].
  /// Returns a before/after report of every change actually made.
  Future<List<CategoryChange>> recategorizeAllItems(
    String groupId,
    Map<String, String> learnedAliases,
  ) async {
    final snap = await _items(groupId).get();
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
