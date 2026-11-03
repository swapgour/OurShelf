import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'group.dart';

const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I

String _generateInviteCode(Random random) {
  return List.generate(
    6,
    (_) => _codeChars[random.nextInt(_codeChars.length)],
  ).join();
}

/// Manages the single group a user belongs to in MVP 1 (multi-group support
/// is a later milestone per the product spec).
class GroupRepository {
  GroupRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _random = Random();

  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection('groups');

  CollectionReference<Map<String, dynamic>> get _inviteCodes =>
      _firestore.collection('inviteCodes');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Returns the user's current groupId, creating a new "My Home" group for
  /// them the first time they sign in with none.
  Future<String> ensureGroupForUser({
    required String uid,
    required String displayName,
  }) async {
    final userDoc = await _users.doc(uid).get();
    final existingGroupId = userDoc.data()?['groupId'] as String?;
    if (existingGroupId != null && existingGroupId.isNotEmpty) {
      return existingGroupId;
    }

    final groupRef = _groups.doc();
    final code = _generateInviteCode(_random);
    await groupRef.set({
      'name': 'My Home',
      'inviteCode': code,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'members': {
        uid: {'displayName': displayName, 'role': 'admin'},
      },
    });
    await _inviteCodes.doc(code).set({'groupId': groupRef.id});
    await _users.doc(uid).set({
      'groupId': groupRef.id,
    }, SetOptions(merge: true));
    return groupRef.id;
  }

  /// Joins the group identified by a 6-character invite code, switching the
  /// user's active group to it, and returns that group's id.
  Future<String> joinGroupByCode({
    required String uid,
    required String displayName,
    required String code,
  }) async {
    final normalized = code.trim().toUpperCase();
    final codeDoc = await _inviteCodes.doc(normalized).get();
    final groupId = codeDoc.data()?['groupId'] as String?;
    if (groupId == null) {
      throw StateError('No group found for that invite code.');
    }
    await _groups.doc(groupId).set({
      'members': {
        uid: {'displayName': displayName, 'role': 'member'},
      },
    }, SetOptions(merge: true));
    await _users.doc(uid).set({'groupId': groupId}, SetOptions(merge: true));
    return groupId;
  }

  /// Removes the user from their current group and clears their active
  /// group, so a new "My Home" group is created next time they need one.
  Future<void> leaveGroup({required String uid, required String groupId}) async {
    await _groups.doc(groupId).update({
      'members.$uid': FieldValue.delete(),
    });
    await _users.doc(uid).update({'groupId': FieldValue.delete()});
  }

  /// Changes a member's role between 'member' and 'viewer'. Admin role is
  /// out of scope here (transferring admin is a later milestone).
  Future<void> setMemberRole({
    required String groupId,
    required String memberUid,
    required String role,
  }) {
    return _groups.doc(groupId).update({'members.$memberUid.role': role});
  }

  /// Removes another member from the group. The UI only exposes this to
  /// admins; note this isn't enforced server-side yet (see firestore.rules),
  /// which is an acceptable MVP tradeoff for a small, trusted family group
  /// but should be tightened before a wider launch.
  Future<void> removeMember({
    required String groupId,
    required String memberUid,
  }) {
    return _groups.doc(groupId).update({
      'members.$memberUid': FieldValue.delete(),
    });
  }

  /// Tells the group "I'm at the store" so others can add last-minute items
  /// while this member is still shopping.
  Future<void> startShopping({
    required String groupId,
    required String uid,
    required String displayName,
  }) {
    return _groups.doc(groupId).update({
      'shoppingNow.$uid': {'displayName': displayName},
    });
  }

  Future<void> stopShopping({required String groupId, required String uid}) {
    return _groups.doc(groupId).update({
      'shoppingNow.$uid': FieldValue.delete(),
    });
  }

  Stream<Group?> watchGroup(String groupId) {
    return _groups.doc(groupId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return Group.fromMap(groupId, data);
    });
  }
}
