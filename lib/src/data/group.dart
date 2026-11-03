class GroupMember {
  const GroupMember({
    required this.uid,
    required this.displayName,
    required this.role,
  });

  final String uid;
  final String displayName;
  final String role; // 'admin' | 'member'

  factory GroupMember.fromMap(String uid, Map<String, dynamic> map) {
    return GroupMember(
      uid: uid,
      displayName: map['displayName'] as String? ?? 'Member',
      role: map['role'] as String? ?? 'member',
    );
  }

  Map<String, dynamic> toMap() => {'displayName': displayName, 'role': role};
}

class ShopperStatus {
  const ShopperStatus({required this.uid, required this.displayName});

  final String uid;
  final String displayName;

  factory ShopperStatus.fromMap(String uid, Map<String, dynamic> map) {
    return ShopperStatus(
      uid: uid,
      displayName: map['displayName'] as String? ?? 'Someone',
    );
  }
}

/// Whether [uid] is a 'viewer' in [group] — viewers can see a group's list
/// and pantry but not change them.
bool isViewerRole(Group? group, String? uid) {
  if (group == null || uid == null) return false;
  return group.members.any((m) => m.uid == uid && m.role == 'viewer');
}

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.members,
    this.shoppingNow = const [],
  });

  final String id;
  final String name;
  final String inviteCode;
  final List<GroupMember> members;
  final List<ShopperStatus> shoppingNow;

  factory Group.fromMap(String id, Map<String, dynamic> map) {
    final membersMap = (map['members'] as Map<String, dynamic>? ?? {});
    final shoppingMap = (map['shoppingNow'] as Map<String, dynamic>? ?? {});
    return Group(
      id: id,
      name: map['name'] as String? ?? 'My Home',
      inviteCode: map['inviteCode'] as String? ?? '',
      members: membersMap.entries
          .map(
            (e) => GroupMember.fromMap(e.key, e.value as Map<String, dynamic>),
          )
          .toList(),
      shoppingNow: shoppingMap.entries
          .map(
            (e) => ShopperStatus.fromMap(e.key, e.value as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
