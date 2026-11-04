import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/category_style.dart';
import '../../data/group.dart';
import '../../data/providers.dart';
import '../../data/shopping_item.dart';
import '../../widgets/motion.dart';

/// The "where did the money go" screen: a touch-interactive pie chart of
/// spend by category plus the headline numbers (total, this month,
/// projected, top category) — the royal-themed home for expense analytics.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(shoppingItemsProvider(groupId));
    final group = ref.watch(groupStreamProvider(groupId)).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: royalHeaderGradient),
        ),
      ),
      body: itemsAsync.when(
        data: (items) => _DashboardBody(items: items, members: group?.members ?? const []),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load the dashboard: $e')),
      ),
    );
  }
}

class _DashboardBody extends StatefulWidget {
  const _DashboardBody({required this.items, required this.members});

  final List<ShoppingItem> items;
  final List<GroupMember> members;

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  int? _touchedIndex;
  // null = "All" members.
  String? _selectedPayer;

  @override
  Widget build(BuildContext context) {
    final allPaid = widget.items
        .where((i) => i.status == ItemStatus.bought && i.price != null)
        .toList();

    // Every group member, plus any past payer not currently a member (so a
    // removed/renamed member's old purchases are still filterable) — shown
    // whenever there's more than one person to choose between, even if only
    // one of them has actually paid for anything yet.
    final payers = <String>{
      for (final m in widget.members) m.displayName,
      for (final item in allPaid) item.paidByName ?? item.addedByName,
    }.toList()..sort();

    final paid = _selectedPayer == null
        ? allPaid
        : allPaid.where((i) => (i.paidByName ?? i.addedByName) == _selectedPayer).toList();

    final filterBar = payers.length > 1
        ? Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _PayerChip(
                    label: 'All',
                    selected: _selectedPayer == null,
                    onTap: () => setState(() => _selectedPayer = null),
                  ),
                  for (final payer in payers) ...[
                    const SizedBox(width: 8),
                    _PayerChip(
                      label: payer,
                      selected: _selectedPayer == payer,
                      onTap: () => setState(() => _selectedPayer = payer),
                    ),
                  ],
                ],
              ),
            ),
          )
        : null;

    if (paid.isEmpty) {
      return Column(
        children: [
          if (filterBar != null) Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: filterBar),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _selectedPayer == null
                      ? 'No priced purchases yet. Mark items bought with a price to '
                          'see your spending breakdown here.'
                      : '$_selectedPayer hasn\'t paid for anything yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      );
    }

    double total = 0;
    double spentThisMonth = 0;
    final now = DateTime.now();
    final byCategory = <String, double>{};
    for (final item in paid) {
      final price = item.price!;
      total += price;
      byCategory[item.category] = (byCategory[item.category] ?? 0) + price;
      final boughtAt = item.boughtAt;
      if (boughtAt != null &&
          boughtAt.year == now.year &&
          boughtAt.month == now.month) {
        spentThisMonth += price;
      }
    }
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final projected = now.day > 0
        ? spentThisMonth / now.day * daysInMonth
        : spentThisMonth;

    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategory = entries.first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ?filterBar,
        Row(
          children: [
            Expanded(
              child: FadeSlideIn(
                child: _StatTile(
                  label: 'Total spent',
                  numericValue: total,
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
                  numericValue: spentThisMonth,
                  icon: Icons.calendar_month_outlined,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FadeSlideIn(
                delay: const Duration(milliseconds: 120),
                child: _StatTile(
                  label: 'Projected / month',
                  numericValue: projected,
                  icon: Icons.trending_up,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FadeSlideIn(
                delay: const Duration(milliseconds: 180),
                child: _StatTile(
                  label: 'Top category',
                  value: topCategory.key,
                  icon: Icons.workspace_premium_outlined,
                  valueFontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FadeSlideIn(
          delay: const Duration(milliseconds: 220),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            decoration: BoxDecoration(
              color: ourShelfCard,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A148C).withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Spend by category',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutBack,
                  builder: (context, pop, child) =>
                      Transform.scale(scale: pop, child: child),
                  child: AspectRatio(
                    aspectRatio: 1.25,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 56,
                            pieTouchData: PieTouchData(
                              touchCallback: (event, response) {
                                setState(() {
                                  if (!event.isInterestedForInteractions ||
                                      response == null ||
                                      response.touchedSection == null) {
                                    _touchedIndex = null;
                                    return;
                                  }
                                  _touchedIndex = response
                                      .touchedSection!
                                      .touchedSectionIndex;
                                });
                              },
                            ),
                            sections: List.generate(entries.length, (i) {
                              final entry = entries[i];
                              final isTouched = i == _touchedIndex;
                              final percent = entry.value / total * 100;
                              return PieChartSectionData(
                                value: entry.value,
                                color: colorForCategory(entry.key),
                                radius: isTouched ? 66 : 58,
                                title: percent >= 6
                                    ? '${percent.toStringAsFixed(0)}%'
                                    : '',
                                titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                titlePositionPercentageOffset: 0.6,
                              );
                            }),
                          ),
                          duration: const Duration(milliseconds: 250),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _touchedIndex != null &&
                                      _touchedIndex! < entries.length
                                  ? '₹${entries[_touchedIndex!].value.toStringAsFixed(0)}'
                                  : '₹${total.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: ourShelfSeed,
                              ),
                            ),
                            Text(
                              _touchedIndex != null &&
                                      _touchedIndex! < entries.length
                                  ? entries[_touchedIndex!].key
                                  : 'Total',
                              style: TextStyle(
                                fontSize: 12,
                                color: ourShelfTextSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'By category',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...List.generate(entries.length, (i) {
          final entry = entries[i];
          final percent = entry.value / total * 100;
          final color = colorForCategory(entry.key);
          return FadeSlideIn(
            delay: Duration(milliseconds: 260 + i * 50),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        iconForCategory(entry.key),
                        size: 16,
                        color: ourShelfTextSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '₹${entry.value.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 42,
                        child: Text(
                          '${percent.toStringAsFixed(0)}%',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: ourShelfTextSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: percent / 100),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, fraction, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 6,
                        backgroundColor: color.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// One "All" / member-name pill in the Dashboard's payer filter bar.
class _PayerChip extends StatelessWidget {
  const _PayerChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF4A148C) : ourShelfCard,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? Colors.transparent : ourShelfBorder,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : ourShelfTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.icon,
    this.value,
    this.numericValue,
    this.valueFontSize = 20,
  }) : assert(value != null || numericValue != null);

  final String label;
  final String? value;
  final double? numericValue;
  final IconData icon;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A148C), Color(0xFF6A1B9A)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A148C).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PulseIcon(child: Icon(icon, color: const Color(0xFFC9A227), size: 20)),
          const SizedBox(height: 10),
          numericValue != null
              ? CountUpText(
                  value: numericValue!,
                  prefix: '₹',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: valueFontSize,
                  ),
                )
              : Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: valueFontSize,
                  ),
                ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
