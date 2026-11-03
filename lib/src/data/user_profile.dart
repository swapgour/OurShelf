import 'package:cloud_firestore/cloud_firestore.dart';

/// A user's profile document, stored at `users/{uid}` in Firestore.
///
/// `contactEmail` + `marketingOptIn` are what later let us export a mailing
/// list for newsletters and marketing emails.
class UserProfile {
  const UserProfile({
    required this.uid,
    this.displayName,
    this.phoneNumber,
    this.photoUrl,
    this.contactEmail,
    this.marketingOptIn = false,
    this.groupId,
    this.createdAt,
  });

  final String uid;
  final String? displayName;
  final String? phoneNumber;
  final String? photoUrl;
  final String? contactEmail;
  final bool marketingOptIn;
  final String? groupId;
  final DateTime? createdAt;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      displayName: map['displayName'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      photoUrl: map['photoUrl'] as String?,
      contactEmail: map['contactEmail'] as String?,
      marketingOptIn: map['marketingOptIn'] as bool? ?? false,
      groupId: map['groupId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
