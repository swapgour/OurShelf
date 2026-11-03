import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.actorName,
    required this.summary,
    this.createdAt,
  });

  final String id;
  final String actorName;
  final String summary;
  final DateTime? createdAt;

  factory ActivityEntry.fromDoc(String id, Map<String, dynamic> map) {
    return ActivityEntry(
      id: id,
      actorName: map['actorName'] as String? ?? 'Someone',
      summary: map['summary'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
