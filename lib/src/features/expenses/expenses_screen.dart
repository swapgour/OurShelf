import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/providers.dart';
import '../../data/shopping_item.dart';
import '../../widgets/motion.dart';

/// A basic per-group spend summary: total spent, how much each member paid,
/// and a simple equal-split "who owes whom" — the MVP3 starting point for
/// expenses & member balances.
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(shoppingItemsProvider(groupId));
    final group = ref.watch(groupStreamProvider(groupId)).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: royalHeaderGradient),
        ),
      ),
      body: itemsAsync.when(
        data: (items) => _ExpensesBody(
          items: items,
          memberCount: group?.members.length ?? 1,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load expenses: $e')),
      ),
    );
  }
}

class _ExpensesBody extends StatelessWidget {
  const _ExpensesBody({required this.items, required this.memberCount});

  final List<ShoppingItem> items;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    final paidItems = items.where(
      (i) => i.status == ItemStatus.bought && i.price != null,
    );

    final totalsByPayer = <String, double>{};
    double total = 0;
    final now = DateTime.now();
    double spentThisMonth = 0;
    for (final item in paidItems) {
      final payer = item.paidByName ?? item.addedByName;
      totalsByPayer[payer] = (totalsByPayer[payer] ?? 0) + item.price!;
      total += item.price!;
      final boughtAt = item.boughtAt;
      if (boughtAt != null &&
          boughtAt.year == now.year &&
          boughtAt.month == now.month) {
        spentThisMonth += item.price!;
      }
    }
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final projectedThisMonth = now.day > 0
        ? spentThisMonth / now.day * daysInMonth
        : spentThisMonth;

    if (totalsByPayer.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No purchases with a price yet. Mark items bought and add a '
            'price to see spending here.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final fairShare = total / totalsByPayer.length.clamp(1, 1 << 30);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: FadeSlideIn(
                child: _StatTile(
                  label: 'Total spent',
                  value: total,
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: _StatTile(
                  label: 'This month',
                  value: spentThisMonth,
                  icon: Icons.calendar_month_outlined,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Projected by month end: ₹${projectedThisMonth.toStringAsFixed(0)}',
          style: TextStyle(color: ourShelfTextSecondary, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 20),
        const Text(
          'By member',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...totalsByPayer.entries.toList().asMap().entries.map((entry) {
          final i = entry.key;
          final name = entry.value.key;
          final paid = entry.value.value;
          final balance = paid - fairShare;
          final settled = balance.abs() < 1;
          final isOwed = balance > 0;
          final balanceColor = settled
              ? ourShelfTextSecondary
              : isOwed
                  ? ourShelfSuccess
                  : ourShelfWarning;
          final balanceText = settled
              ? 'Settled up'
              : isOwed
                  ? 'Is owed ₹${balance.toStringAsFixed(0)}'
                  : 'Owes ₹${balance.abs().toStringAsFixed(0)}';
          return FadeSlideIn(
            delay: Duration(milliseconds: 120 + i * 40),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ourShelfBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: ourShelfSeed.withValues(alpha: 0.1),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: ourShelfSeed),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          'Paid ₹${paid.toStringAsFixed(0)}',
                          style: TextStyle(color: ourShelfTextSecondary, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: balanceColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      balanceText,
                      style: TextStyle(
                        color: balanceColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Split equally across everyone who has paid so far. Full group '
            'balances (including members who haven\'t paid yet) are next.',
            style: TextStyle(color: ourShelfTextSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon});

  final String label;
  final double value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: royalHeaderGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: ourShelfSeed.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ourShelfAccent, size: 20),
          const SizedBox(height: 10),
          CountUpText(
            value: value,
            prefix: '₹',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
        ],
      ),
    );
  }
}
