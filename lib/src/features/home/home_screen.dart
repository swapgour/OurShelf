import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../auth/auth_providers.dart';
import '../../data/group.dart';
import '../../data/pantry_item.dart';
import '../../data/providers.dart';
import '../../data/shopping_item.dart';
import '../../data/user_profile.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/motion.dart';
import '../activity/activity_screen.dart';
import '../ai/ask_ai_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../groups/group_sheet.dart';
import '../purchase/add_purchase_screen.dart';
import '../scan/scan_receipt_screen.dart';

final _userProfileProvider = StreamProvider.autoDispose<UserProfile?>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(userRepositoryProvider).watchProfile(uid);
});

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good Morning';
  if (hour < 17) return 'Good Afternoon';
  return 'Good Evening';
}

String _relativeTime(DateTime? time) {
  if (time == null) return 'just now';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// The Home tab: a real dashboard (not a module launcher) — what's left to
/// buy, what's low on stock, what's been spent this month, quick actions,
/// a data-grounded tip, and a glance at recent activity.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.groupId, required this.onOpenTab});

  final String groupId;
  final void Function(int tabIndex) onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final profile = ref.watch(_userProfileProvider).value;
    final group = ref.watch(groupStreamProvider(groupId)).value;
    final itemsAsync = ref.watch(shoppingItemsProvider(groupId));
    final pantryAsync = ref.watch(pantryItemsProvider(groupId));
    final activityAsync = ref.watch(activityProvider(groupId));

    final items = itemsAsync.value ?? const <ShoppingItem>[];
    final pantry = pantryAsync.value ?? const <PantryItem>[];
    final toBuyCount = items.where((i) => i.status == ItemStatus.toBuy).length;
    final lowStockCount = pantry
        .where((p) => p.level == StockLevel.low || p.level == StockLevel.out)
        .length;
    final now = DateTime.now();
    final spentThisMonth = items
        .where(
          (i) =>
              i.status == ItemStatus.bought &&
              i.price != null &&
              i.boughtAt != null &&
              i.boughtAt!.year == now.year &&
              i.boughtAt!.month == now.month,
        )
        .fold<double>(0, (sum, i) => sum + i.price!);

    final name = profile?.displayName ?? user?.displayName ?? user?.phoneNumber ?? 'there';
    final fullStockTip = pantry.where((p) => p.level == StockLevel.full).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.shopping_basket, color: ourShelfSeed, size: 26),
                  const SizedBox(width: 8),
                  const Text(
                    'OurShelf',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: ourShelfTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    color: ourShelfTextSecondary,
                    tooltip: 'Notifications',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ActivityScreen(groupId: groupId)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  FadeSlideIn(
                    child: GestureDetector(
                      onTap: () => _openGroupSheet(context, group),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${_greeting()}, $name',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: ourShelfTextPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const WiggleIcon(
                                      child: Text('👋', style: TextStyle(fontSize: 18)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  "Let's keep your kitchen organised · ${group?.name ?? 'Your group'}",
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: ourShelfTextSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: ourShelfBorder),
                            ),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: ourShelfSeed.withValues(alpha: 0.1),
                              backgroundImage: user?.photoURL != null
                                  ? NetworkImage(user!.photoURL!)
                                  : null,
                              child: user?.photoURL == null
                                  ? const Icon(Icons.person, color: ourShelfSeed)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 60),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => onOpenTab(2),
                        child: Ink(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: royalGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: ourShelfSeed.withValues(alpha: 0.3),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Your Kitchen, in Sync',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Know what's at home. Buy what you need.",
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                                    ),
                                  ],
                                ),
                              ),
                              PulseIcon(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.kitchen, color: Colors.white, size: 28),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.7,
                    children: [
                      _SummaryCard(
                        delay: 0,
                        icon: Icons.shopping_cart_outlined,
                        color: ourShelfSeed,
                        label: 'To Buy',
                        value: toBuyCount.toDouble(),
                        onTap: () => onOpenTab(1),
                      ),
                      _SummaryCard(
                        delay: 40,
                        icon: Icons.warning_amber_rounded,
                        color: ourShelfWarning,
                        label: 'Low Stock',
                        value: lowStockCount.toDouble(),
                        onTap: () => onOpenTab(2),
                      ),
                      _SummaryCard(
                        delay: 80,
                        icon: Icons.inventory_2_outlined,
                        color: ourShelfSuccess,
                        label: 'In Pantry',
                        value: pantry.length.toDouble(),
                        onTap: () => onOpenTab(2),
                      ),
                      _SummaryCard(
                        delay: 120,
                        icon: Icons.account_balance_wallet_outlined,
                        color: ourShelfAccent,
                        label: 'This Month',
                        value: spentThisMonth,
                        prefix: '₹',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => DashboardScreen(groupId: groupId)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 160),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => DashboardScreen(groupId: groupId)),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: ourShelfBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.pie_chart_outline, color: ourShelfSeed, size: 20),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'View full spending breakdown',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                ),
                              ),
                              Icon(Icons.chevron_right, color: ourShelfTextSecondary, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.add,
                          label: 'Add Item',
                          color: ourShelfSuccess,
                          onTap: () => onOpenTab(1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.receipt_long,
                          label: 'Log Purchase',
                          color: ourShelfSeed,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddPurchaseScreen(groupId: groupId),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.document_scanner_outlined,
                          label: 'Scan Bill',
                          color: ourShelfSecondary,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ScanReceiptScreen(groupId: groupId),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.auto_awesome,
                          label: 'Ask AI',
                          color: ourShelfAccent,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => AskAiScreen(groupId: groupId)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (fullStockTip.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    FadeSlideIn(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ourShelfAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ourShelfAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline, color: ourShelfAccent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(color: ourShelfTextPrimary, height: 1.3),
                                  children: [
                                    const TextSpan(
                                      text: 'OurShelf suggests: ',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(
                                      text:
                                          'you have enough ${fullStockTip.first.name}. '
                                          "No need to buy it this week.",
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text(
                        'Recent Activity',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ActivityScreen(groupId: groupId)),
                        ),
                        child: const Text('See All'),
                      ),
                    ],
                  ),
                  activityAsync.when(
                    data: (entries) {
                      if (entries.isEmpty) {
                        return EmptyState(
                          compact: true,
                          icon: Icons.history_toggle_off,
                          title: 'Your household activity starts here',
                          message: 'Your shopping and purchase updates will appear here.',
                          ctaLabel: 'Add your first item',
                          onCta: () => onOpenTab(1),
                        );
                      }
                      return Column(
                        children: entries.take(3).map((e) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: ourShelfSeed.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.history, color: ourShelfSeed, size: 18),
                            ),
                            title: Text(e.summary),
                            subtitle: Text('${e.actorName} · ${_relativeTime(e.createdAt)}'),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const LoadingSkeletonList(count: 2),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openGroupSheet(BuildContext context, Group? group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => GroupSheet(group: group),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
    this.prefix = '',
    this.delay = 0,
  });

  final IconData icon;
  final Color color;
  final String label;
  final double value;
  final String prefix;
  final VoidCallback onTap;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      delay: Duration(milliseconds: 140 + delay),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ourShelfBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CountUpText(
                        value: value,
                        prefix: prefix,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: ourShelfTextPrimary,
                        ),
                      ),
                      Text(
                        label,
                        style: TextStyle(color: ourShelfTextSecondary, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ourShelfBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ourShelfTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
