import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../auth/auth_providers.dart';
import '../../data/group.dart';
import '../../data/providers.dart';
import '../../data/purchase_commit.dart';
import '../../data/receipt_parser.dart';
import '../scan/scan_receipt_screen.dart';

/// The "+" hub: record a purchase either by typing it in (several items at
/// once, like a mini receipt) or by scanning a photo of a purchased list.
/// Manual entries go through the same matching/commit path as the scanner,
/// so a manually-typed "Milk" still closes out "Milk" on the shopping list.
class AddPurchaseScreen extends ConsumerStatefulWidget {
  const AddPurchaseScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends ConsumerState<AddPurchaseScreen> {
  bool _manualMode = true;
  final List<_LineController> _lines = [_LineController()];
  DateTime _purchaseDate = DateTime.now();
  final _storeController = TextEditingController();
  String? _paidByUid;
  bool _saving = false;

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    _storeController.dispose();
    super.dispose();
  }

  double get _total => _lines.fold(0, (sum, l) => sum + (l.price ?? 0));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _purchaseDate = picked);
  }

  Future<void> _save(List<GroupMember> members) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final validLines = _lines.where((l) => l.name.text.trim().isNotEmpty).toList();
    if (validLines.isEmpty) return;

    setState(() => _saving = true);
    final paidByName = members
        .firstWhere(
          (m) => m.uid == (_paidByUid ?? user.uid),
          orElse: () => GroupMember(
            uid: user.uid,
            displayName: user.displayName ?? user.phoneNumber ?? 'Me',
            role: 'member',
          ),
        )
        .displayName;

    final parsedLines = validLines
        .map(
          (l) => ParsedLine(
            rawText: l.name.text,
            name: l.name.text.trim(),
            price: l.price,
          ),
        )
        .toList();
    final currentItems = ref.read(shoppingItemsProvider(widget.groupId)).value ?? [];
    final matches = matchScannedLines(lines: parsedLines, currentItems: currentItems);

    await commitPurchaseMatches(
      shoppingRepo: ref.read(shoppingListRepositoryProvider),
      activityRepo: ref.read(activityRepositoryProvider),
      pantryRepo: ref.read(pantryRepositoryProvider),
      groupId: widget.groupId,
      matches: matches,
      selected: List.filled(matches.length, true),
      prices: matches.map((m) => m.line.price).toList(),
      uid: user.uid,
      paidByName: paidByName,
      activitySummary: (n) => 'Logged a purchase of $n item${n == 1 ? '' : 's'}',
      boughtAt: _purchaseDate,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupStreamProvider(widget.groupId)).value;
    final user = ref.watch(authStateProvider).value;
    final members = group?.members ?? const <GroupMember>[];
    _paidByUid ??= user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Purchase'),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: royalHeaderGradient),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: ourShelfBorder,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _SegmentButton(
                      icon: Icons.edit_note,
                      label: 'Manual Entry',
                      selected: _manualMode,
                      onTap: () => setState(() => _manualMode = true),
                    ),
                  ),
                  Expanded(
                    child: _SegmentButton(
                      icon: Icons.document_scanner_outlined,
                      label: 'Scan Bill',
                      selected: !_manualMode,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ScanReceiptScreen(groupId: widget.groupId),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Text(
                  'Items (${_lines.where((l) => l.name.text.trim().isNotEmpty).length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._lines.asMap().entries.map((entry) {
                  final i = entry.key;
                  final line = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: line.name,
                            decoration: const InputDecoration(
                              hintText: 'Item name',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: line.priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              prefixText: '₹ ',
                              hintText: 'price',
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (_lines.length > 1)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _lines.removeAt(i)),
                          ),
                      ],
                    ),
                  );
                }),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _lines.add(_LineController())),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add Another Item'),
                  ),
                ),
                const Divider(height: 28),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Purchase Date'),
                  trailing: Text(
                    '${_purchaseDate.day}/${_purchaseDate.month}/${_purchaseDate.year}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: _pickDate,
                ),
                TextField(
                  controller: _storeController,
                  decoration: const InputDecoration(labelText: 'Store (optional)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: members.any((m) => m.uid == _paidByUid)
                      ? _paidByUid
                      : user?.uid,
                  decoration: const InputDecoration(labelText: 'Who Paid?'),
                  items: [
                    if (user != null && !members.any((m) => m.uid == user.uid))
                      DropdownMenuItem(
                        value: user.uid,
                        child: Text(user.displayName ?? user.phoneNumber ?? 'You'),
                      ),
                    ...members.map(
                      (m) => DropdownMenuItem(value: m.uid, child: Text(m.displayName)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _paidByUid = v),
                ),
                const SizedBox(height: 90),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : () => _save(members),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text('Save Purchase (₹${_total.toStringAsFixed(0)})'),
          ),
        ),
      ),
    );
  }
}

class _LineController {
  final name = TextEditingController();
  final priceController = TextEditingController();

  double? get price => double.tryParse(priceController.text.trim());

  void dispose() {
    name.dispose();
    priceController.dispose();
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      elevation: selected ? 1 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? ourShelfSeed : ourShelfTextSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: selected ? ourShelfSeed : ourShelfTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
