import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'activity_entry.dart';
import 'activity_repository.dart';
import 'group.dart';
import 'group_repository.dart';
import 'pantry_item.dart';
import 'pantry_repository.dart';
import 'reminder.dart';
import 'reminder_repository.dart';
import 'shopping_item.dart';
import 'shopping_list_repository.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository();
});

final shoppingListRepositoryProvider = Provider<ShoppingListRepository>((
  ref,
) {
  return ShoppingListRepository();
});

/// Ensures the signed-in user has a group (creating "My Home" the first
/// time) and resolves to its id. Idempotent, so safe to watch repeatedly.
final activeGroupIdProvider = FutureProvider.autoDispose<String>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    throw StateError('No signed-in user.');
  }
  final displayName = user.displayName ?? user.phoneNumber ?? 'Member';
  return ref
      .watch(groupRepositoryProvider)
      .ensureGroupForUser(uid: user.uid, displayName: displayName);
});

final groupStreamProvider = StreamProvider.autoDispose.family<Group?, String>(
  (ref, groupId) {
    return ref.watch(groupRepositoryProvider).watchGroup(groupId);
  },
);

final shoppingItemsProvider = StreamProvider.autoDispose
    .family<List<ShoppingItem>, String>((ref, groupId) {
      return ref.watch(shoppingListRepositoryProvider).watchItems(groupId);
    });

final pantryRepositoryProvider = Provider<PantryRepository>((ref) {
  return PantryRepository();
});

final pantryItemsProvider = StreamProvider.autoDispose
    .family<List<PantryItem>, String>((ref, groupId) {
      return ref.watch(pantryRepositoryProvider).watchPantry(groupId);
    });

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository();
});

final activityProvider = StreamProvider.autoDispose
    .family<List<ActivityEntry>, String>((ref, groupId) {
      return ref.watch(activityRepositoryProvider).watch(groupId);
    });

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository();
});

final remindersProvider = StreamProvider.autoDispose
    .family<List<Reminder>, String>((ref, groupId) {
      return ref.watch(reminderRepositoryProvider).watch(groupId);
    });
