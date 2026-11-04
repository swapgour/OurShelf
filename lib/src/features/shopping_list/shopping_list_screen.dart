import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../app.dart';
import '../../auth/auth_providers.dart';
import '../../data/catalogue.dart';
import '../../data/category_style.dart';
import '../../data/group.dart';
import '../../data/providers.dart';
import '../../data/receipt_parser.dart';
import '../../data/shopping_item.dart';
import '../../data/templates.dart';
import '../../data/user_profile.dart';
import '../activity/activity_screen.dart';
import '../expenses/expenses_screen.dart';
import '../groups/group_sheet.dart';
import '../pantry/pantry_screen.dart';
import '../reminders/reminders_screen.dart';
import '../scan/scan_receipt_screen.dart';

final _userProfileProvider = StreamProvider.autoDispose<UserProfile?>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(userRepositoryProvider).watchProfile(uid);
});

class ShoppingListScreen extends ConsumerWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupIdAsync = ref.watch(activeGroupIdProvider);
    return groupIdAsync.when(
      data: (groupId) => _HomeContent(groupId: groupId),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          Scaffold(body: Center(child: Text('Could not set up your group: $error'))),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final profile = ref.watch(_userProfileProvider).value;
    final group = ref.watch(groupStreamProvider(groupId)).value;
    final itemsAsync = ref.watch(shoppingItemsProvider(groupId));
    final needsEmail =
        profile != null &&
        (profile.contactEmail == null || profile.contactEmail!.isEmpty);
    final isViewer = isViewerRole(group, user?.uid);

    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: Text(group?.name ?? 'OurShelf'),
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: royalHeaderGradient),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.kitchen),
            tooltip: 'Pantry',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PantryScreen(groupId: groupId)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Expenses',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ExpensesScreen(groupId: groupId),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'reminders':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RemindersScreen(groupId: groupId),
                    ),
                  );
                case 'activity':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ActivityScreen(groupId: groupId),
                    ),
                  );
                case 'scan':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScanReceiptScreen(groupId: groupId),
                    ),
                  );
                case 'invite':
                  _showGroupSheet(context, ref, group);
                case 'signout':
                  ref.read(authRepositoryProvider).signOut();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'reminders',
                child: ListTile(
                  leading: Icon(Icons.event_repeat),
                  title: Text('Reminders'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'activity',
                child: ListTile(
                  leading: Icon(Icons.history),
                  title: Text('Activity'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'scan',
                child: ListTile(
                  leading: Icon(Icons.document_scanner_outlined),
                  title: Text('Scan purchased list'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'invite',
                child: ListTile(
                  leading: Icon(Icons.group_add),
                  title: Text('Invite / join a group'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'signout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sign out'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primary, primary.withValues(alpha: 0.75)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? Icon(Icons.person, color: primary)
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi, ${profile?.displayName ?? user?.displayName ?? user?.phoneNumber ?? 'there'} 👋',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile?.contactEmail ??
                            user?.phoneNumber ??
                            user?.email ??
                            '',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (group != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.people_alt,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${group.members.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (group != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _ShoppingNowBanner(
                groupId: groupId,
                shoppers: group.shoppingNow,
                currentUid: user?.uid,
                currentDisplayName:
                    profile?.displayName ?? user?.displayName ?? user?.phoneNumber ?? 'Me',
              ),
            ),
          if (needsEmail)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: _EmailCaptureCard(),
            ),
          const SizedBox(height: 20),
          itemsAsync.when(
            data: (items) => _ShoppingList(
              groupId: groupId,
              items: items,
              isViewer: isViewer,
            ),
            loading: () =>
                const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                )),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Could not load the list: $e'),
            ),
          ),
        ],
      ),
      floatingActionButton: isViewer
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddItemSheet(context, ref, groupId),
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
    );
  }

  void _showGroupSheet(BuildContext context, WidgetRef ref, Group? group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => GroupSheet(group: group),
    );
  }

  void _showAddItemSheet(BuildContext context, WidgetRef ref, String groupId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddItemSheet(groupId: groupId),
    );
  }
}

class _ShoppingNowBanner extends ConsumerWidget {
  const _ShoppingNowBanner({
    required this.groupId,
    required this.shoppers,
    required this.currentUid,
    required this.currentDisplayName,
  });

  final String groupId;
  final List<ShopperStatus> shoppers;
  final String? currentUid;
  final String currentDisplayName;

  String _message(bool iAmShopping, List<ShopperStatus> others) {
    if (iAmShopping && others.isEmpty) {
      return "You're shopping now — add anything you spot!";
    }
    final names = [
      if (iAmShopping) 'You',
      ...others.map((s) => s.displayName),
    ];
    final verb = names.length == 1 && !iAmShopping ? 'is' : 'are';
    return '${names.join(', ')} $verb at the store right now';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iAmShopping = shoppers.any((s) => s.uid == currentUid);
    final others = shoppers.where((s) => s.uid != currentUid).toList();

    if (!iAmShopping && others.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.storefront),
          label: const Text("I'm going shopping"),
          onPressed: currentUid == null
              ? null
              : () => ref.read(groupRepositoryProvider).startShopping(
                  groupId: groupId,
                  uid: currentUid!,
                  displayName: currentDisplayName,
                ),
        ),
      );
    }

    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.storefront),
            const SizedBox(width: 12),
            Expanded(child: Text(_message(iAmShopping, others))),
            if (iAmShopping)
              TextButton(
                onPressed: () => ref.read(groupRepositoryProvider).stopShopping(
                  groupId: groupId,
                  uid: currentUid!,
                ),
                child: const Text('Done'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingList extends StatelessWidget {
  const _ShoppingList({
    required this.groupId,
    required this.items,
    required this.isViewer,
  });

  final String groupId;
  final List<ShoppingItem> items;
  final bool isViewer;

  @override
  Widget build(BuildContext context) {
    final toBuy = items.where((i) => i.status == ItemStatus.toBuy).toList();
    final bought = items.where((i) => i.status == ItemStatus.bought).toList();

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No items yet. Tap "Add item" to build your shared list.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final byCategory = <String, List<ShoppingItem>>{};
    for (final item in toBuy) {
      byCategory.putIfAbsent(item.category, () => []).add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'To buy (${toBuy.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...byCategory.entries.expand(
          (entry) => [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colorForCategory(entry.key),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            ...entry.value.map(
              (item) => _ItemTile(groupId: groupId, item: item, isViewer: isViewer),
            ),
          ],
        ),
        if (bought.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 20,
                color: Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                'Bought (${bought.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...bought.map(
            (item) => _ItemTile(groupId: groupId, item: item, isViewer: isViewer),
          ),
        ],
      ],
    );
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({
    required this.groupId,
    required this.item,
    required this.isViewer,
  });

  final String groupId;
  final ShoppingItem item;
  final bool isViewer;

  Future<void> _onCheckChanged(
    BuildContext context,
    WidgetRef ref,
    bool? value,
  ) async {
    final repo = ref.read(shoppingListRepositoryProvider);
    final currentUser = ref.read(authStateProvider).value;
    final currentUserName =
        currentUser?.displayName ?? currentUser?.phoneNumber ?? 'Someone';
    if (value != true) {
      try {
        await repo.markToBuy(groupId: groupId, itemId: item.id);
        await ref.read(activityRepositoryProvider).log(
          groupId: groupId,
          actorName: currentUserName,
          summary: 'Moved ${item.name} back to the list',
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Could not update: $e')));
        }
      }
      return;
    }
    final group = ref.read(groupStreamProvider(groupId)).value;
    final result = await showDialog<_PurchaseDetails>(
      context: context,
      builder: (_) => _MarkBoughtDialog(
        itemName: item.name,
        members: group?.members ?? const [],
        defaultPaidBy:
            currentUser?.displayName ?? currentUser?.phoneNumber ?? 'Me',
      ),
    );
    if (result == null) return; // cancelled
    try {
      await repo.markBought(
        groupId: groupId,
        itemId: item.id,
        boughtByUid: currentUser!.uid,
        itemName: item.name,
        price: result.price,
        paidByName: result.paidByName,
      );
      await ref
          .read(pantryRepositoryProvider)
          .topUpFromPurchase(
            groupId: groupId,
            name: item.name,
            category: item.category,
            unit: item.unit,
          );
      await ref.read(activityRepositoryProvider).log(
        groupId: groupId,
        actorName: result.paidByName ?? currentUserName,
        summary: 'Bought ${item.name}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not mark bought: $e')));
      }
    }
  }

  Future<void> _onTapEdit(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _EditQuantityDialog(item: item),
    );
    if (result == null) return;
    await ref.read(shoppingListRepositoryProvider).updateQuantity(
      groupId: groupId,
      itemId: item.id,
      quantity: result.$1,
      unit: result.$2,
    );
  }

  void _showPriceHistory(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PriceHistorySheet(groupId: groupId, itemName: item.name),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove item?'),
        content: Text(
          'Remove "${item.name}" from the list? This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ourShelfError),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Deletes the item and leaves a trace of who removed what — and who
  /// originally added it, if that was someone else — in the Activity feed.
  void _deleteItem(WidgetRef ref) {
    final actor = ref.read(authStateProvider).value;
    final actorName = actor?.displayName ?? actor?.phoneNumber ?? 'Someone';
    ref
        .read(shoppingListRepositoryProvider)
        .deleteItem(groupId: groupId, itemId: item.id);
    final summary = actorName == item.addedByName
        ? 'Removed ${item.name} from the list'
        : 'Removed ${item.name} from the list (added by ${item.addedByName})';
    ref.read(activityRepositoryProvider).log(
      groupId: groupId,
      actorName: actorName,
      summary: summary,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bought = item.status == ItemStatus.bought;
    final accent = colorForCategory(item.category);
    final details = [
      '${item.quantity} ${item.unit}',
      'added by ${item.addedByName}',
      if (bought && item.paidByName != null) 'paid by ${item.paidByName}',
      if (bought && item.price != null) '₹${item.price!.toStringAsFixed(0)}',
    ].join(' · ');

    return Dismissible(
      key: ValueKey(item.id),
      direction: isViewer ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => _deleteItem(ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: bought ? ourShelfBorder.withValues(alpha: 0.4) : ourShelfCard,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: accent, width: 4)),
          boxShadow: bought
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isViewer ? null : () => _onTapEdit(context, ref),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: Row(
                children: [
                  _AnimatedCheck(
                    checked: bought,
                    accent: accent,
                    onTap: isViewer
                        ? null
                        : () => _onCheckChanged(context, ref, !bought),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      iconForCategory(item.category),
                      size: 18,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: bought ? Colors.grey : Colors.black87,
                            decoration: bought
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                          child: Text(item.name),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          details,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'More',
                    onSelected: (value) async {
                      if (value == 'history') {
                        _showPriceHistory(context, ref);
                      } else if (value == 'delete') {
                        if (await _confirmDelete(context)) _deleteItem(ref);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'history',
                        child: ListTile(
                          leading: Icon(Icons.show_chart),
                          title: Text('Price history'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (!isViewer)
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete_outline, color: ourShelfError),
                            title: Text('Remove', style: TextStyle(color: ourShelfError)),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A custom circular checkbox that pops with a scale when toggled, instead
/// of Material's flat instant-swap checkbox.
class _AnimatedCheck extends StatelessWidget {
  const _AnimatedCheck({
    required this.checked,
    required this.accent,
    required this.onTap,
  });

  final bool checked;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: checked ? accent : Colors.transparent,
          border: Border.all(
            color: checked ? accent : Colors.grey.shade400,
            width: 2,
          ),
        ),
        child: AnimatedScale(
          scale: checked ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: const Icon(Icons.check, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

class _PriceHistorySheet extends ConsumerWidget {
  const _PriceHistorySheet({required this.groupId, required this.itemName});

  final String groupId;
  final String itemName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<List<ShoppingItem>>(
          future: ref
              .read(shoppingListRepositoryProvider)
              .priceHistory(groupId: groupId, name: itemName),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final history = snapshot.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Price history: $itemName',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                if (history.isEmpty)
                  const Text('No past purchases with a price recorded yet.')
                else
                  ...history.map(
                    (h) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.receipt),
                      title: Text('₹${h.price!.toStringAsFixed(0)}'),
                      subtitle: Text(
                        '${h.quantity} ${h.unit} · paid by ${h.paidByName ?? h.addedByName}',
                      ),
                      trailing: Text(
                        h.boughtAt != null
                            ? '${h.boughtAt!.day}/${h.boughtAt!.month}/${h.boughtAt!.year}'
                            : '',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PurchaseDetails {
  const _PurchaseDetails({this.price, this.paidByName});
  final double? price;
  final String? paidByName;
}

class _MarkBoughtDialog extends StatefulWidget {
  const _MarkBoughtDialog({
    required this.itemName,
    required this.members,
    required this.defaultPaidBy,
  });

  final String itemName;
  final List<GroupMember> members;
  final String defaultPaidBy;

  @override
  State<_MarkBoughtDialog> createState() => _MarkBoughtDialogState();
}

class _MarkBoughtDialogState extends State<_MarkBoughtDialog> {
  final _priceController = TextEditingController();
  late String _paidBy = widget.defaultPaidBy;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = {
      widget.defaultPaidBy,
      ...widget.members.map((m) => m.displayName),
    }.toList();
    return AlertDialog(
      title: Text('Bought ${widget.itemName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: const InputDecoration(
              labelText: 'Price (optional)',
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: names.contains(_paidBy) ? _paidBy : names.first,
            decoration: const InputDecoration(labelText: 'Paid by'),
            items: names
                .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                .toList(),
            onChanged: (v) => setState(() => _paidBy = v ?? _paidBy),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final price = double.tryParse(_priceController.text.trim());
            Navigator.of(
              context,
            ).pop(_PurchaseDetails(price: price, paidByName: _paidBy));
          },
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _EditQuantityDialog extends StatefulWidget {
  const _EditQuantityDialog({required this.item});

  final ShoppingItem item;

  @override
  State<_EditQuantityDialog> createState() => _EditQuantityDialogState();
}

class _EditQuantityDialogState extends State<_EditQuantityDialog> {
  late final _qtyController = TextEditingController(text: widget.item.quantity);
  late final _unitController = TextEditingController(text: widget.item.unit);

  @override
  void dispose() {
    _qtyController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.item.name}'),
      content: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _unitController,
              decoration: const InputDecoration(labelText: 'Unit'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((
            _qtyController.text.trim().isEmpty
                ? '1'
                : _qtyController.text.trim(),
            _unitController.text.trim().isEmpty
                ? 'pc'
                : _unitController.text.trim(),
          )),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AddItemSheet extends ConsumerStatefulWidget {
  const _AddItemSheet({required this.groupId});

  final String groupId;

  @override
  ConsumerState<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<_AddItemSheet> {
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  late final Future<List<ShoppingItem>> _historyFuture;
  final _speech = stt.SpeechToText();
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _historyFuture = ref
        .read(shoppingListRepositoryProvider)
        .recentHistory(groupId: widget.groupId);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition is not available')),
        );
      }
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() => _nameController.text = result.recognizedWords);
      },
    );
  }

  List<ShoppingItem> _frequentItems(List<ShoppingItem> history) {
    final byName = <String, List<ShoppingItem>>{};
    for (final item in history) {
      byName.putIfAbsent(item.name.trim().toLowerCase(), () => []).add(item);
    }
    final groups = byName.values.where((g) => g.length >= 2).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return groups.take(10).map((g) => g.first).toList();
  }

  Future<void> _addCustom() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await _add(name: name, category: 'Other', quantity: _qtyController.text.trim().isEmpty ? '1' : _qtyController.text.trim(), unit: 'pc');
    _nameController.clear();
    _qtyController.text = '1';
  }

  Future<void> _add({
    required String name,
    required String category,
    required String quantity,
    required String unit,
  }) async {
    final repo = ref.read(shoppingListRepositoryProvider);
    final match = await repo.findRecentMatch(
      groupId: widget.groupId,
      name: name,
    );
    if (match != null && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => _DuplicateWarningDialog(name: name, match: match),
      );
      if (proceed != true) return;
    }

    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final profile = await ref
        .read(userRepositoryProvider)
        .watchProfile(user.uid)
        .first;
    final addedByName =
        profile?.displayName ?? user.displayName ?? user.phoneNumber ?? 'Member';
    await repo.addItem(
      groupId: widget.groupId,
      name: name,
      category: category,
      quantity: quantity,
      unit: unit,
      addedByUid: user.uid,
      addedByName: addedByName,
    );
    await ref.read(activityRepositoryProvider).log(
      groupId: widget.groupId,
      actorName: addedByName,
      summary: 'Added $name to the list',
    );
  }

  Future<void> _loadTemplate(ListTemplate template) async {
    await _bulkAdd(
      confirmTitle: template.name,
      confirmBody: 'Add all ${template.lines.length} items from this starter list?',
      activitySummary: 'Loaded the "${template.name}" starter list',
      lines: template.lines
          .map(
            (l) => (
              name: l.name,
              category: l.category,
              quantity: l.quantity,
              unit: l.unit,
            ),
          )
          .toList(),
    );
  }

  Future<void> _repeatLastMonth(List<ShoppingItem> history) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 35));
    final seen = <String>{};
    final lines = <({String name, String category, String quantity, String unit})>[];
    for (final item in history) {
      if (item.status != ItemStatus.bought) continue;
      final boughtAt = item.boughtAt;
      if (boughtAt == null || boughtAt.isBefore(cutoff)) continue;
      final key = item.name.trim().toLowerCase();
      if (!seen.add(key)) continue;
      lines.add((
        name: item.name,
        category: item.category,
        quantity: item.quantity,
        unit: item.unit,
      ));
    }
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No purchases from the last month yet")),
      );
      return;
    }
    await _bulkAdd(
      confirmTitle: 'Repeat last month',
      confirmBody: 'Add ${lines.length} items you bought in the last month?',
      activitySummary: "Repeated last month's purchases",
      lines: lines,
    );
  }

  Future<void> _bulkAdd({
    required String confirmTitle,
    required String confirmBody,
    required String activitySummary,
    required List<({String name, String category, String quantity, String unit})> lines,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(confirmTitle),
        content: Text(confirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final profile = await ref
        .read(userRepositoryProvider)
        .watchProfile(user.uid)
        .first;
    final addedByName =
        profile?.displayName ?? user.displayName ?? user.phoneNumber ?? 'Member';

    await ref.read(shoppingListRepositoryProvider).addItemsBatch(
      groupId: widget.groupId,
      items: lines,
      addedByUid: user.uid,
      addedByName: addedByName,
    );
    await ref.read(activityRepositoryProvider).log(
      groupId: widget.groupId,
      actorName: addedByName,
      summary: activitySummary,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'Type an item name…',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addCustom(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 70,
                      child: TextField(
                        controller: _qtyController,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        decoration: const InputDecoration(
                          hintText: 'Qty',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _listening ? Icons.mic : Icons.mic_none,
                        color: _listening
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                      tooltip: 'Add by voice',
                      onPressed: _toggleListening,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: _addCustom,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: const Icon(Icons.content_paste, size: 16),
                        label: const Text('Paste a list'),
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => _PasteListSheet(groupId: widget.groupId),
                        ),
                      ),
                    ),
                    ...starterTemplates.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: const Icon(Icons.auto_awesome, size: 16),
                          label: Text(t.name),
                          onPressed: () => _loadTemplate(t),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<ShoppingItem>>(
                future: _historyFuture,
                builder: (context, snapshot) {
                  final history = snapshot.data ?? const [];
                  final frequent = _frequentItems(history);
                  if (frequent.isEmpty && history.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: const Icon(Icons.replay, size: 16),
                            label: const Text('Repeat last month'),
                            onPressed: () => _repeatLastMonth(history),
                          ),
                        ),
                        ...frequent.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              avatar: const Icon(Icons.star, size: 16),
                              label: Text(item.name),
                              onPressed: () => _add(
                                name: item.name,
                                category: item.category,
                                quantity: item.quantity,
                                unit: item.unit,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: catalogueCategories.map((category) {
                    final items = starterCatalogue
                        .where((c) => c.category == category)
                        .toList();
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: items.map((c) {
                              return ActionChip(
                                avatar: Icon(c.icon, size: 18),
                                label: Text(c.name),
                                onPressed: () => _add(
                                  name: c.name,
                                  category: c.category,
                                  quantity: '1',
                                  unit: c.unit,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PastedDraft {
  _PastedDraft({
    required this.name,
    required this.category,
    required this.unit,
    required String quantity,
  }) : quantityController = TextEditingController(text: quantity);

  final String name;
  final String category;
  final String unit;
  final TextEditingController quantityController;
}

/// Lets the user paste or type a free-form list (e.g. copied from a text
/// message) and adds the recognised items straight to "to buy" with a
/// best-guess category and quantity, after a quick review.
class _PasteListSheet extends ConsumerStatefulWidget {
  const _PasteListSheet({required this.groupId});

  final String groupId;

  @override
  ConsumerState<_PasteListSheet> createState() => _PasteListSheetState();
}

class _PasteListSheetState extends ConsumerState<_PasteListSheet> {
  final _textController = TextEditingController();
  List<_PastedDraft>? _drafts;
  late List<bool> _selected;
  bool _saving = false;

  @override
  void dispose() {
    _textController.dispose();
    for (final d in _drafts ?? const <_PastedDraft>[]) {
      d.quantityController.dispose();
    }
    super.dispose();
  }

  void _parse() {
    final text = _textController.text;
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type or paste a list first')),
      );
      return;
    }
    final parsed = parsePastedList(text);
    if (parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't find any items in that text")),
      );
      return;
    }
    setState(() {
      _drafts = parsed
          .map(
            (l) => _PastedDraft(
              name: l.name,
              category: l.category,
              unit: l.unit,
              quantity: l.quantity,
            ),
          )
          .toList();
      _selected = List.filled(parsed.length, true);
    });
  }

  Future<void> _confirm() async {
    final drafts = _drafts!;
    final chosen = <({String name, String category, String quantity, String unit})>[
      for (var i = 0; i < drafts.length; i++)
        if (_selected[i])
          (
            name: drafts[i].name,
            category: drafts[i].category,
            quantity: drafts[i].quantityController.text.trim().isEmpty
                ? '1'
                : drafts[i].quantityController.text.trim(),
            unit: drafts[i].unit,
          ),
    ];
    if (chosen.isEmpty) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final profile = await ref.read(userRepositoryProvider).watchProfile(user.uid).first;
      final addedByName =
          profile?.displayName ?? user.displayName ?? user.phoneNumber ?? 'Member';
      await ref.read(shoppingListRepositoryProvider).addItemsBatch(
        groupId: widget.groupId,
        items: chosen,
        addedByUid: user.uid,
        addedByName: addedByName,
      );
      await ref.read(activityRepositoryProvider).log(
        groupId: widget.groupId,
        actorName: addedByName,
        summary:
            'Added ${chosen.length} item${chosen.length == 1 ? '' : 's'} from a pasted list',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add items: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final drafts = _drafts;
    final selectedCount = drafts == null ? 0 : _selected.where((s) => s).length;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Paste a list',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              if (drafts == null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _textController,
                    minLines: 6,
                    maxLines: 10,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'e.g.\nOnion 2kg\nMilk\nEggs 1 dozen, bread',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "One item per line, or separated by commas. If you don't "
                    "give a quantity we'll default it sensibly (kg, packet, "
                    "litre…) based on the item.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _parse,
                      child: const Text('Find items'),
                    ),
                  ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Found ${drafts.length} item${drafts.length == 1 ? '' : 's'} — review before adding',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemCount: drafts.length,
                    itemBuilder: (context, i) {
                      final draft = drafts[i];
                      final color = colorForCategory(draft.category);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: CheckboxListTile(
                          value: _selected[i],
                          onChanged: (v) => setState(() => _selected[i] = v ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(iconForCategory(draft.category), color: color, size: 20),
                          ),
                          title: Text(
                            draft.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Row(
                            children: [
                              Expanded(
                                child: Text(draft.category, style: const TextStyle(fontSize: 12)),
                              ),
                              SizedBox(
                                width: 54,
                                child: TextFormField(
                                  controller: draft.quantityController,
                                  textAlign: TextAlign.center,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                                  ],
                                  style: const TextStyle(fontSize: 13),
                                  decoration: const InputDecoration(isDense: true, border: UnderlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(draft.unit, style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  minimum: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : () => setState(() => _drafts = null),
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: selectedCount == 0 || _saving ? null : _confirm,
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text('Add $selectedCount item${selectedCount == 1 ? '' : 's'}'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DuplicateWarningDialog extends StatelessWidget {
  const _DuplicateWarningDialog({required this.name, required this.match});

  final String name;
  final ShoppingItem match;

  @override
  Widget build(BuildContext context) {
    final message = match.status == ItemStatus.toBuy
        ? '$name is already on the list (${match.quantity} ${match.unit}, added by ${match.addedByName}).'
        : '${match.paidByName ?? match.addedByName} already bought $name recently.';
    return AlertDialog(
      title: const Text('Already on the list?'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Add anyway'),
        ),
      ],
    );
  }
}

class _EmailCaptureCard extends ConsumerStatefulWidget {
  const _EmailCaptureCard();

  @override
  ConsumerState<_EmailCaptureCard> createState() => _EmailCaptureCardState();
}

class _EmailCaptureCardState extends ConsumerState<_EmailCaptureCard> {
  final _emailController = TextEditingController();
  bool _optIn = true;
  bool _saving = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address')),
      );
      return;
    }
    setState(() => _saving = true);
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid != null) {
      await ref.read(userRepositoryProvider).setMarketingEmail(
        uid: uid,
        email: email,
        optIn: _optIn,
      );
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add your email',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('Get restock reminders, tips and occasional offers.'),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'you@example.com',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            CheckboxListTile(
              value: _optIn,
              onChanged: (v) => setState(() => _optIn = v ?? true),
              title: const Text('Send me newsletters and offers'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
