import 'package:cloud_firestore/cloud_firestore.dart';

/// A recurring household reminder — "LPG refill every 30 days", "water cans
/// every 7 days" — due when [lastDoneAt] plus [intervalDays] has passed.
class Reminder {
  const Reminder({
    required this.id,
    required this.name,
    required this.intervalDays,
    this.lastDoneAt,
  });

  final String id;
  final String name;
  final int intervalDays;
  final DateTime? lastDoneAt;

  bool get isDue {
    final last = lastDoneAt;
    if (last == null) return true;
    return DateTime.now().difference(last).inDays >= intervalDays;
  }

  factory Reminder.fromDoc(String id, Map<String, dynamic> map) {
    return Reminder(
      id: id,
      name: map['name'] as String? ?? '',
      intervalDays: (map['intervalDays'] as num?)?.toInt() ?? 30,
      lastDoneAt: (map['lastDoneAt'] as Timestamp?)?.toDate(),
    );
  }
}
