import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../auth/auth_providers.dart';
import '../../data/category_style.dart';
import '../../data/group.dart';
import '../../data/pantry_item.dart';
import '../../data/providers.dart';
import '../../data/shopping_item.dart';
import '../../widgets/motion.dart';

Color _levelColor(StockLevel level) {
  switch (level) {
    case StockLevel.full:
      return ourShelfSuccess;
    case StockLevel.half:
      return ourShelfWarning;
    case StockLevel.low:
      return const Color(0xFFE8822E);
    case StockLevel.out:
      return ourShelfError;
  }
}

String _levelLabel(StockLevel level) {
  switch (level) {
    case StockLevel.full:
      return 'Full';
    case StockLevel.half:
      return 'Half';
    case StockLevel.low:
      return 'Low';
    case StockLevel.out:
      return 'Out';
  }
}

double _levelFraction(StockLevel level) {
  switch (level) {
    case StockLevel.full:
      return 1.0;
    case StockLevel.half:
      return 0.6;
    case StockLevel.low:
      return 0.25;
    case StockLevel.out:
      return 0.04;
  }
}

enum _Filter { all, lowStock, expiring }

/// A simplified pantry view: what's at home, at a Full/Half/Low/Out level
/// per item, auto-topped-up to "full" whenever something's bought. Tapping
/// a level updates it; Low/Out items offer a one-tap re-add to the list.
class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  _Filter _filter = _Filter.all;
  bool _syncing = false;

  /// Catches pantry up with items that were already marked bought before
  /// pantry top-up existed in the app, or if a sync was ever missed —
  /// without this, those older purchases never retroactively show up here.
  Future<void> _syncFromBought() async {
    setState(() => _syncing = true);
    try {
      final items = await ref.read(shoppingItemsProvider(widget.groupId).future);
      final toSync = items
          .where((i) => i.status == ItemStatus.bought && !billCategories.contains(i.category))
          .toList();
      final pantryRepo = ref.read(pantryRepositoryProvider);
      for (final item in toSync) {
        await pantryRepo.topUpFromPurchase(
          groupId: widget.groupId,
          name: item.name,
          category: item.category,
          unit: item.unit,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              toSync.isEmpty
                  ? 'Nothing to sync — no bought grocery items yet'
                  : 'Synced ${toSync.length} item${toSync.length == 1 ? '' : 's'} to pantry',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not sync pantry: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(pantryItemsProvider(widget.groupId));
    final group = ref.watch(groupStreamProvider(widget.groupId)).value;
    final uid = ref.watch(authStateProvider).value?.uid;
    final isViewer = isViewerRole(group, uid);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          itemsAsync.value == null ? 'Pantry' : 'Pantry (${itemsAsync.value!.length})',
        ),
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: royalHeaderGradient),
        ),
        actions: [
          IconButton(
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Sync from bought items',
            onPressed: _syncing ? null : _syncFromBought,
          ),
        ],
      ),
      body: itemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Nothing tracked yet — items appear here once they're "
                      'marked bought on the shared list.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _syncing ? null : _syncFromBought,
                      icon: _syncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: const Text('Sync from bought items'),
                    ),
                  ],
                ),
              ),
            );
          }
          final lowStock = items
              .where((i) => i.level == StockLevel.low || i.level == StockLevel.out)
              .toList();
          final expiringSoon = items.where((i) => i.isExpiringSoon).toList();
          final visible = switch (_filter) {
            _Filter.all => items,
            _Filter.lowStock => lowStock,
            _Filter.expiring => expiringSoon,
          };

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      count: items.length,
                      selected: _filter == _Filter.all,
                      onTap: () => setState(() => _filter = _Filter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Low Stock',
                      count: lowStock.length,
                      selected: _filter == _Filter.lowStock,
                      onTap: () => setState(() => _filter = _Filter.lowStock),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Expiring Soon',
                      count: expiringSoon.length,
                      selected: _filter == _Filter.expiring,
                      onTap: () => setState(() => _filter = _Filter.expiring),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Text(
                          'Nothing here right now.',
                          style: TextStyle(color: ourShelfTextSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: visible.length,
                        itemBuilder: (context, i) => FadeSlideIn(
                          delay: Duration(milliseconds: i * 30),
                          child: _PantryTile(
                            groupId: widget.groupId,
                            item: visible[i],
                            isViewer: isViewer,
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load pantry: $e')),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? ourShelfSeed : ourShelfCard,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? Colors.transparent : ourShelfBorder),
            ),
            alignment: Alignment.center,
            child: Text(
              count > 0 ? '$label ($count)' : label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : ourShelfTextSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PantryTile extends ConsumerWidget {
  const _PantryTile({
    required this.groupId,
    required this.item,
    required this.isViewer,
  });

  final String groupId;
  final PantryItem item;
  final bool isViewer;

  Future<void> _addToList(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final profile = await ref
        .read(userRepositoryProvider)
        .watchProfile(user.uid)
        .first;
    final addedByName =
        profile?.displayName ??
        user.displayName ??
        user.phoneNumber ??
        'Member';
    await ref.read(shoppingListRepositoryProvider).addItem(
      groupId: groupId,
      name: item.name,
      category: item.category,
      quantity: '1',
      unit: item.unit,
      addedByUid: user.uid,
      addedByName: addedByName,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${item.name} added to list')));
    }
  }

  Future<void> _pickExpiry(BuildContext context, WidgetRef ref) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: item.expiryDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    await ref
        .read(pantryRepositoryProvider)
        .setExpiry(groupId: groupId, itemId: item.id, expiryDate: picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStock = item.level == StockLevel.low || item.level == StockLevel.out;
    final color = _levelColor(item.level);
    final accent = colorForCategory(item.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ourShelfCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ourShelfBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(iconForCategory(item.category), color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      item.unit,
                      style: TextStyle(color: ourShelfTextSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (item.expiryDate != null || !isViewer)
                InkWell(
                  onTap: isViewer ? null : () => _pickExpiry(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.isExpiringSoon
                          ? ourShelfError.withValues(alpha: 0.1)
                          : ourShelfBorder,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.expiryDate == null
                          ? (isViewer ? '' : 'Set expiry')
                          : item.isExpiringSoon
                              ? 'Expiring: ${item.expiryDate!.day}/${item.expiryDate!.month}'
                              : '${item.expiryDate!.day}/${item.expiryDate!.month}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: item.isExpiringSoon ? ourShelfError : ourShelfTextSecondary,
                      ),
                    ),
                  ),
                ),
              if (lowStock && !isViewer)
                IconButton(
                  icon: const Icon(Icons.add_shopping_cart, size: 20),
                  tooltip: 'Add to list',
                  onPressed: () => _addToList(context, ref),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _levelFraction(item.level)),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 7,
                      backgroundColor: color.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _levelLabel(item.level),
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: StockLevel.values.map((level) {
              final selected = level == item.level;
              final c = _levelColor(level);
              return ChoiceChip(
                label: Text(_levelLabel(level)),
                selected: selected,
                selectedColor: c.withValues(alpha: 0.18),
                labelStyle: TextStyle(
                  color: selected ? c : ourShelfTextSecondary,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                side: BorderSide(color: selected ? c : ourShelfBorder),
                onSelected: isViewer
                    ? null
                    : (_) {
                        final uid = ref.read(authStateProvider).value?.uid;
                        if (uid == null) return;
                        ref.read(pantryRepositoryProvider).setLevel(
                          groupId: groupId,
                          itemId: item.id,
                          level: level,
                          itemName: item.name,
                          actorUid: uid,
                        );
                      },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
