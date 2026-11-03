import 'package:cloud_firestore/cloud_firestore.dart';

import 'activity_entry.dart';

/// A per-group activity feed: "Ravi bought milk", "Mom added 3 items" — the
/// spec's requirement to show who added, bought, changed or finished what,
/// and when.
class ActivityRepository {
  ActivityRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _activity(String groupId) =>
      _firestore.collection('groups').doc(groupId).collection('activity');

  Future<void> log({
    required String groupId,
    required String actorName,
    required String summary,
  }) {
    return _activity(groupId).add({
      'actorName': actorName,
      'summary': summary,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ActivityEntry>> watch(String groupId) {
    return _activity(groupId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ActivityEntry.fromDoc(d.id, d.data()))
              .toList(),
        );
  }
}
