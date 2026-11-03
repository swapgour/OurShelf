import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_profile.dart';

/// Reads and writes the `users/{uid}` profile document that backs sign-in
/// state and the newsletter/marketing mailing list.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Creates or updates the signed-in user's profile document.
  ///
  /// Google sign-in always supplies a verified email, so we use it as the
  /// default marketing contact email the first time, without overwriting an
  /// email the user may have entered manually after a phone sign-in.
  Future<void> upsertFromAuthUser(User user) async {
    final doc = _users.doc(user.uid);
    final snapshot = await doc.get();
    final hasContactEmail = (snapshot.data()?['contactEmail'] as String?)
            ?.isNotEmpty ==
        true;

    final data = <String, dynamic>{
      'displayName': user.displayName,
      'phoneNumber': user.phoneNumber,
      'photoUrl': user.photoURL,
      'lastSignInAt': FieldValue.serverTimestamp(),
    };
    if (user.email != null && !hasContactEmail) {
      data['contactEmail'] = user.email;
      data['marketingOptIn'] = true;
    }
    if (!snapshot.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['marketingOptIn'] ??= false;
    }
    await doc.set(data, SetOptions(merge: true));
  }

  /// Saves the newsletter contact email a user enters manually (e.g. after
  /// signing in with phone OTP, which has no email of its own).
  Future<void> setMarketingEmail({
    required String uid,
    required String email,
    required bool optIn,
  }) {
    return _users.doc(uid).set({
      'contactEmail': email,
      'marketingOptIn': optIn,
    }, SetOptions(merge: true));
  }

  /// Registers a device's FCM token so the notification Cloud Function can
  /// reach it. A user can have several tokens (several devices).
  Future<void> addFcmToken({required String uid, required String token}) {
    return _users.doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  Future<void> removeFcmToken({required String uid, required String token}) {
    return _users.doc(uid).set({
      'fcmTokens': FieldValue.arrayRemove([token]),
    }, SetOptions(merge: true));
  }

  Stream<UserProfile?> watchProfile(String uid) {
    return _users.doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return UserProfile.fromMap(uid, data);
    });
  }
}
