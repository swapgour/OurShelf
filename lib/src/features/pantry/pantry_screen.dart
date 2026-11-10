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
import 'pantry_pdf_export.dart';

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

/// The simplified 3-state view the compact row shows (Full/Half both read
/// as "Available") — the full 4-level detail still lives in the item's
/// detail sheet.
String _statusLabel(StockLevel level) => switch (level) {
  StockLevel.full || StockLevel.half => 'Available',
  StockLevel.low => 'Low',
  StockLevel.out => 'Empty',
};

Color _statusColor(StockLevel level) => switch (level) {
  StockLevel.full || StockLevel.half => ourShelfSuccess,
  StockLevel.low => const Color(0xFFE8822E),
  StockLevel.out => ourShelfError,
};

/// "2" / "1.5" — trims a trailing ".0". Null when no purchase has been
/// recorded for this item yet (not the same as a quantity of zero).
String? _totalPurchasedText(num totalPurchased) {
  if (totalPurchased <= 0) return null;
  return totalPurchased == totalPurchased.roundToDouble()
      ? totalPurchased.toStringAsFixed(0)
      : totalPurchased.toString();
}

/// "₹290" — null when no purchase of this item had a price logged.
String? _totalAmountText(num totalAmount) {
  if (totalAmount <= 0) return null;
  return '₹${totalAmount.toStringAsFixed(0)}';
}

enum _StockFilter { all, available, low, empty }

enum _SortOption { alphabetical, category, stockLevel, recentlyUpdated }

String _sortLabel(_SortOption s) => switch (s) {
  _SortOption.alphabetical => 'Alphabetical',
  _SortOption.category => 'Category',
  _SortOption.stockLevel => 'Stock level',
  _SortOption.recentlyUpdated => 'Recently updated',
};

/// A simplified pantry view: what's at home, at a Full/Half/Low/Out level
/// per item, auto-topped-up to "full" whenever something's bought. Search,
/// category tabs, a compact row per item, and filter/sort controls keep it
/// usable once it has more than a handful of items; tapping a row opens the
/// heavier actions (status, expiry, add to list, delete) in a detail sheet.
class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  _StockFilter _filter = _StockFilter.all;
  _SortOption _sort = _SortOption.alphabetical;
  String? _selectedCategory;
  final _searchController = TextEditingController();
  String _search = '';
  bool _syncing = false;
  bool _exporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Catches pantry up with items that were already marked bought before
  /// pantry top-up existed in the app, or if a sync was ever missed —
  /// without this, those older purchases never retroactively show up here.
  /// (Day-to-day, pantry is already always live: every screen watches the
  /// same Firestore stream, so a new/changed item shows up everywhere the
  /// instant it's written — this button is only a one-time historical
  /// backfill, not a substitute for that.)
  Future<void> _syncFromBought() async {
    setState(() => _syncing = true);
    try {
      final items = await ref.read(shoppingItemsProvider(widget.groupId).future);
      final toSync = items
          .where(
            (i) =>
                i.status == ItemStatus.bought &&
                !i.pantrySynced &&
                !billCategories.contains(i.category),
          )
          .toList();
      final pantryRepo = ref.read(pantryRepositoryProvider);
      final shoppingRepo = ref.read(shoppingListRepositoryProvider);
      for (final item in toSync) {
        await pantryRepo.topUpFromPurchase(
          groupId: widget.groupId,
          name: item.name,
          category: item.category,
          unit: item.unit,
          quantity: item.quantity,
          price: item.price,
        );
        await shoppingRepo.markPantrySynced(groupId: widget.groupId, itemId: item.id);
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

  Future<void> _exportPdf(List<PantryItem> items) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to export yet')),
      );
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save_alt_outlined),
              title: const Text('Download / Print PDF'),
              subtitle: const Text('Opens the system dialog — save as PDF or print'),
              onTap: () => Navigator.of(context).pop('download'),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share PDF'),
              subtitle: const Text('WhatsApp, email, and more'),
              onTap: () => Navigator.of(context).pop('share'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;

    setState(() => _exporting = true);
    try {
      if (action == 'download') {
        await openPantryInventoryPdf(items);
      } else {
        await sharePantryInventoryPdf(items);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
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
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.ios_share),
            tooltip: 'Export / share PDF',
            onPressed: _exporting
                ? null
                : () => _exportPdf(itemsAsync.value ?? const []),
          ),
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

          final searched = _search.isEmpty
              ? items
              : items
                    .where(
                      (i) =>
                          i.name.toLowerCase().contains(_search) ||
                          i.category.toLowerCase().contains(_search),
                    )
                    .toList();

          final categories = <String>{for (final i in searched) i.category}.toList()
            ..sort();

          final byCategory = _selectedCategory == null
              ? searched
              : searched.where((i) => i.category == _selectedCategory).toList();

          final available = byCategory
              .where((i) => i.level == StockLevel.full || i.level == StockLevel.half)
              .toList();
          final low = byCategory.where((i) => i.level == StockLevel.low).toList();
          final empty = byCategory.where((i) => i.level == StockLevel.out).toList();
          final visible = switch (_filter) {
            _StockFilter.all => byCategory,
            _StockFilter.available => available,
            _StockFilter.low => low,
            _StockFilter.empty => empty,
          };

          final sorted = [...visible];
          switch (_sort) {
            case _SortOption.alphabetical:
              sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            case _SortOption.category:
              sorted.sort((a, b) {
                final c = a.category.compareTo(b.category);
                return c != 0 ? c : a.name.compareTo(b.name);
              });
            case _SortOption.stockLevel:
              sorted.sort((a, b) => b.level.index.compareTo(a.level.index));
            case _SortOption.recentlyUpdated:
              sorted.sort(
                (a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)),
              );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by name or category…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() {
                              _searchController.clear();
                              _search = '';
                            }),
                          ),
                    isDense: true,
                    filled: true,
                    fillColor: ourShelfCard,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ourShelfBorder),
                    ),
                  ),
                ),
              ),
              if (categories.length > 1)
                AutoPeekScrollRow(
                  children: [
                    _CategoryChip(
                      label: 'All',
                      count: searched.length,
                      selected: _selectedCategory == null,
                      onTap: () => setState(() => _selectedCategory = null),
                    ),
                    for (final c in categories)
                      _CategoryChip(
                        label: c,
                        count: searched.where((i) => i.category == c).length,
                        selected: _selectedCategory == c,
                        onTap: () => setState(() => _selectedCategory = c),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All',
                            count: byCategory.length,
                            selected: _filter == _StockFilter.all,
                            onTap: () => setState(() => _filter = _StockFilter.all),
                          ),
                          const SizedBox(width: 6),
                          _FilterChip(
                            label: 'Available',
                            count: available.length,
                            selected: _filter == _StockFilter.available,
                            onTap: () => setState(() => _filter = _StockFilter.available),
                          ),
                          const SizedBox(width: 6),
                          _FilterChip(
                            label: 'Low',
                            count: low.length,
                            selected: _filter == _StockFilter.low,
                            onTap: () => setState(() => _filter = _StockFilter.low),
                          ),
                          const SizedBox(width: 6),
                          _FilterChip(
                            label: 'Empty',
                            count: empty.length,
                            selected: _filter == _StockFilter.empty,
                            onTap: () => setState(() => _filter = _StockFilter.empty),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<_SortOption>(
                      tooltip: 'Sort',
                      initialValue: _sort,
                      onSelected: (v) => setState(() => _sort = v),
                      icon: const Icon(Icons.sort, size: 20),
                      itemBuilder: (context) => [
                        for (final s in _SortOption.values)
                          PopupMenuItem(value: s, child: Text(_sortLabel(s))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: sorted.isEmpty
                    ? Center(
                        child: Text(
                          'Nothing here right now.',
                          style: TextStyle(color: ourShelfTextSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: sorted.length,
                        itemBuilder: (context, i) => FadeSlideIn(
                          delay: Duration(milliseconds: i * 20),
                          child: _PantryRow(
                            groupId: widget.groupId,
                            item: sorted[i],
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
    return Material(
      color: selected ? ourShelfSeed : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? Colors.transparent : ourShelfBorder),
          ),
          alignment: Alignment.center,
          child: Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : ourShelfTextSecondary,
            ),
          ),
        ),
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
    return Material(
      color: selected ? ourShelfSeed : ourShelfCard,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? Colors.transparent : ourShelfBorder),
          ),
          child: Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : ourShelfTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// A single compact pantry row — name, size, a small colour-coded status
/// dot, and (only when low/out) a quick "add to list" icon. Everything else
/// (status change, expiry, delete) lives behind a tap in [_PantryDetailSheet].
class _PantryRow extends ConsumerWidget {
  const _PantryRow({required this.groupId, required this.item, required this.isViewer});

  final String groupId;
  final PantryItem item;
  final bool isViewer;

  Future<void> _addToList(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final profile = await ref.read(userRepositoryProvider).watchProfile(user.uid).first;
    final addedByName =
        profile?.displayName ?? user.displayName ?? user.phoneNumber ?? 'Member';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = colorForCategory(item.category);
    final statusColor = _statusColor(item.level);
    final lowStock = item.level == StockLevel.low || item.level == StockLevel.out;

    return Material(
      color: ourShelfCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => _PantryDetailSheet(groupId: groupId, item: item, isViewer: isViewer),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ourShelfBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(iconForCategory(item.category), color: accent, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            [
                              _totalPurchasedText(item.totalPurchased) == null
                                  ? item.unit
                                  : '${_totalPurchasedText(item.totalPurchased)} ${item.unit} total',
                              if (_totalAmountText(item.totalAmount) != null)
                                _totalAmountText(item.totalAmount)!,
                            ].join('  •  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: ourShelfTextSecondary, fontSize: 11.5),
                          ),
                        ),
                        if (unitLooksOffForCategory(item.category, item.unit)) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.error_outline, size: 12, color: ourShelfWarning),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              Text(
                _statusLabel(item.level),
                style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12),
              ),
              if (lowStock && !isViewer)
                IconButton(
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  tooltip: 'Add to list',
                  onPressed: () => _addToList(context, ref),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Everything that doesn't fit on the compact row: the full Full/Half/Low/
/// Out status, an editable size/unit field, expiry date, add-to-list, and
/// delete (with confirmation).
class _PantryDetailSheet extends ConsumerStatefulWidget {
  const _PantryDetailSheet({required this.groupId, required this.item, required this.isViewer});

  final String groupId;
  final PantryItem item;
  final bool isViewer;

  @override
  ConsumerState<_PantryDetailSheet> createState() => _PantryDetailSheetState();
}

class _PantryDetailSheetState extends ConsumerState<_PantryDetailSheet> {
  late final _unitController = TextEditingController(text: widget.item.unit);

  @override
  void dispose() {
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _addToList() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final profile = await ref.read(userRepositoryProvider).watchProfile(user.uid).first;
    final addedByName =
        profile?.displayName ?? user.displayName ?? user.phoneNumber ?? 'Member';
    await ref.read(shoppingListRepositoryProvider).addItem(
      groupId: widget.groupId,
      name: widget.item.name,
      category: widget.item.category,
      quantity: '1',
      unit: widget.item.unit,
      addedByUid: user.uid,
      addedByName: addedByName,
    );
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${widget.item.name} added to list')));
    }
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.item.expiryDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    await ref
        .read(pantryRepositoryProvider)
        .setExpiry(groupId: widget.groupId, itemId: widget.item.id, expiryDate: picked);
  }

  Future<void> _saveUnit() async {
    final value = _unitController.text.trim();
    if (value.isEmpty || value == widget.item.unit) return;
    await ref
        .read(pantryRepositoryProvider)
        .updateUnit(groupId: widget.groupId, itemId: widget.item.id, unit: value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Size updated')));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove ${widget.item.name}?'),
        content: const Text('This removes it from pantry tracking only — not from the shopping list.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ourShelfError),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(pantryRepositoryProvider)
        .deleteItem(groupId: widget.groupId, itemId: widget.item.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorForCategory(item.category).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(iconForCategory(item.category), color: colorForCategory(item.category)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                        Text(item.category, style: TextStyle(color: ourShelfTextSecondary, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Stock level', style: TextStyle(fontWeight: FontWeight.w600, color: ourShelfTextSecondary, fontSize: 12.5)),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _levelFraction(item.level)),
                duration: const Duration(milliseconds: 400),
                builder: (context, v, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: v,
                    minHeight: 7,
                    backgroundColor: _levelColor(item.level).withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(_levelColor(item.level)),
                  ),
                ),
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
                    onSelected: widget.isViewer
                        ? null
                        : (_) {
                            final uid = ref.read(authStateProvider).value?.uid;
                            if (uid == null) return;
                            ref.read(pantryRepositoryProvider).setLevel(
                              groupId: widget.groupId,
                              itemId: item.id,
                              level: level,
                              itemName: item.name,
                              actorUid: uid,
                            );
                          },
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              if (unitLooksOffForCategory(item.category, item.unit))
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ourShelfWarning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ourShelfWarning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 16, color: ourShelfWarning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '"${item.unit}" looks like a liquid measure for ${item.category} — '
                          "worth checking this is right. We won't change it automatically.",
                          style: TextStyle(fontSize: 12, color: ourShelfWarning),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!widget.isViewer) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _unitController,
                        enabled: !widget.isViewer,
                        decoration: const InputDecoration(labelText: 'Size / unit', isDense: true),
                        onSubmitted: (_) => _saveUnit(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.check), onPressed: _saveUnit),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Total purchased'),
                subtitle: const Text('Adds up every purchase since this was introduced'),
                trailing: Text(
                  _totalPurchasedText(item.totalPurchased) == null
                      ? 'Not tracked yet'
                      : '${_totalPurchasedText(item.totalPurchased)} ${item.unit}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.currency_rupee_outlined),
                title: const Text('Total amount spent'),
                subtitle: const Text('Only counts purchases with a price logged'),
                trailing: Text(
                  _totalAmountText(item.totalAmount) ?? 'Not tracked yet',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Expiry date'),
                trailing: Text(
                  item.expiryDate == null
                      ? 'Not set'
                      : '${item.expiryDate!.day}/${item.expiryDate!.month}/${item.expiryDate!.year}',
                ),
                onTap: widget.isViewer ? null : _pickExpiry,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _addToList,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Add to shopping list'),
                ),
              ),
              if (!widget.isViewer) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: ourShelfError),
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove from pantry'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
