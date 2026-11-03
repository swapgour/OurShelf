import 'package:cloud_firestore/cloud_firestore.dart';

import 'reminder.dart';

class ReminderRepository {
  ReminderRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _reminders(String groupId) =>
      _firestore.collection('groups').doc(groupId).collection('reminders');

  Stream<List<Reminder>> watch(String groupId) {
    return _reminders(groupId).orderBy('name').snapshots().map(
      (snap) => snap.docs.map((d) => Reminder.fromDoc(d.id, d.data())).toList(),
    );
  }

  Future<void> add({
    required String groupId,
    required String name,
    required int intervalDays,
  }) {
    return _reminders(groupId).add({
      'name': name,
      'intervalDays': intervalDays,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markDone({required String groupId, required String id}) {
    return _reminders(
      groupId,
    ).doc(id).update({'lastDoneAt': FieldValue.serverTimestamp()});
  }

  Future<void> delete({required String groupId, required String id}) {
    return _reminders(groupId).doc(id).delete();
  }
}
