import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/auth_providers.dart';
import '../../data/group.dart';
import '../../data/providers.dart';

/// Group management sheet: shows the invite code and member list (with
/// admin-only role toggle / remove), and lets the current user join another
/// group by code or leave this one. Shared by the Shopping List screen's
/// menu and the More screen's Groups/Members entries.
class GroupSheet extends ConsumerStatefulWidget {
  const GroupSheet({super.key, required this.group});

  final Group? group;

  @override
  ConsumerState<GroupSheet> createState() => _GroupSheetState();
}

class _GroupSheetState extends ConsumerState<GroupSheet> {
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  String? _error;
  bool _joining = false;

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Opens the device's own mail app with the invite pre-filled — no
  /// email-sending backend/account needed, just one tap from the inviter.
  Future<void> _inviteByEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    final group = widget.group;
    final actor = ref.read(authStateProvider).value;
    final inviterName = actor?.displayName ?? actor?.phoneNumber ?? 'A family member';
    final groupName = group?.name ?? 'our family group';
    final code = group?.inviteCode ?? '';

    final subject = 'Join $groupName on OurShelf';
    final body =
        'Hi!\n\n'
        '$inviterName would like you to join "$groupName" on OurShelf, '
        'the shared family grocery app.\n\n'
        '1. Install OurShelf and sign in.\n'
        '2. Open the group screen and tap "Join".\n'
        '3. Enter this invite code: $code\n\n'
        'See you there!';
    // Built by hand with Uri.encodeComponent (not Uri(queryParameters:)),
    // which form-encodes spaces as "+" — correct for a web query string,
    // but mailto: bodies expect plain percent-encoding (%20) per RFC 6068,
    // so queryParameters renders as a body full of literal "+" signs.
    final uri = Uri.parse(
      'mailto:${Uri.encodeComponent(email)}'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open an email app on this device.")),
      );
      return;
    }
    if (mounted) {
      _emailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite drafted for $email — send it from your mail app.')),
      );
    }
  }

  Future<void> _join() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    final user = ref.read(authStateProvider).value;
    try {
      if (user != null) {
        final displayName = user.displayName ?? user.phoneNumber ?? 'Member';
        final joinedGroupId = await ref
            .read(groupRepositoryProvider)
            .joinGroupByCode(uid: user.uid, displayName: displayName, code: code);
        await ref.read(activityRepositoryProvider).log(
          groupId: joinedGroupId,
          actorName: displayName,
          summary: '$displayName joined the group',
        );
        // The join itself succeeds in Firestore regardless, but without
        // this the app keeps showing whatever group it was already on
        // (e.g. the personal group auto-created at first sign-in) instead
        // of switching to the one just joined.
        ref.invalidate(activeGroupIdProvider);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Could not join: $e');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final currentUid = ref.watch(authStateProvider).value?.uid;
    final isAdmin = group != null &&
        currentUid != null &&
        group.members.any((m) => m.uid == currentUid && m.role == 'admin');

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Invite to your group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Share this code — anyone who enters it joins ${group?.name ?? 'your group'}:'),
          const SizedBox(height: 8),
          SelectableText(
            group?.inviteCode ?? '······',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4),
          ),
          const SizedBox(height: 16),
          Text('Or invite by email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'family.member@email.com',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: group == null ? null : _inviteByEmail,
                icon: const Icon(Icons.email_outlined),
                tooltip: 'Draft an invite email',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Members (${group?.members.length ?? 0})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          ...?group?.members.map(
            (m) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(m.displayName),
              subtitle: Text(m.role),
              trailing: isAdmin && m.uid != currentUid
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            m.role == 'viewer'
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          tooltip: m.role == 'viewer'
                              ? 'Make member (can edit)'
                              : 'Make viewer (see only)',
                          onPressed: () => ref
                              .read(groupRepositoryProvider)
                              .setMemberRole(
                                groupId: group.id,
                                memberUid: m.uid,
                                role: m.role == 'viewer' ? 'member' : 'viewer',
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_remove_outlined),
                          tooltip: 'Remove from group',
                          onPressed: () => _confirmRemove(group, m),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
          const Divider(height: 32),
          const Text('Have a code? Join that group instead', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'e.g. AB12CD',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _joining ? null : _join,
                child: const Text('Join'),
              ),
            ],
          ),
          if (group != null) ...[
            const Divider(height: 32),
            TextButton.icon(
              onPressed: _joining ? null : _confirmLeave,
              icon: const Icon(Icons.logout),
              label: Text('Leave ${group.name}'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmLeave() async {
    final group = widget.group;
    if (group == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Leave ${group.name}?'),
        content: const Text(
          "You'll stop seeing this group's list and a new personal group "
          'will be created for you. You can always rejoin with the invite code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final displayName = user.displayName ?? user.phoneNumber ?? 'Someone';
    // Log before leaving: the activity rule requires current membership,
    // which leaveGroup() is about to revoke.
    await ref.read(activityRepositoryProvider).log(
      groupId: group.id,
      actorName: displayName,
      summary: '$displayName left the group',
    );
    await ref
        .read(groupRepositoryProvider)
        .leaveGroup(uid: user.uid, groupId: group.id);
    ref.invalidate(activeGroupIdProvider);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmRemove(Group group, GroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove ${member.displayName}?'),
        content: Text('${member.displayName} will lose access to ${group.name}\'s list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final actor = ref.read(authStateProvider).value;
    await ref
        .read(groupRepositoryProvider)
        .removeMember(groupId: group.id, memberUid: member.uid);
    await ref.read(activityRepositoryProvider).log(
      groupId: group.id,
      actorName: actor?.displayName ?? actor?.phoneNumber ?? 'Admin',
      summary: 'Removed ${member.displayName} from the group',
    );
  }
}
