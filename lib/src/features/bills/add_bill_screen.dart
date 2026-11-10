import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app.dart';
import '../../auth/auth_providers.dart';
import '../../data/category_style.dart';
import '../../data/group.dart';
import '../../data/providers.dart';
import '../../data/stored_document.dart';

String _documentCategoryForBill(String billCategory) => switch (billCategory) {
  'House EMI' || 'Transfer to Parents' => 'Finance',
  'Internet Bill' || 'Mobile Recharge' || 'Electricity Bill' => 'Utilities',
  _ => 'Other',
};

/// Logs a household bill/transfer — House EMI, internet, mobile recharge,
/// money sent to parents, etc. These aren't groceries (no quantity/unit,
/// never shown on the shopping list or topped up in Pantry), but they're
/// still written through [ShoppingListRepository.addPurchasedItem] as an
/// already-bought item, so they automatically show up in Expenses,
/// Reports & Insights and Activity alongside grocery spending for free.
class AddBillScreen extends ConsumerStatefulWidget {
  const AddBillScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends ConsumerState<AddBillScreen> {
  String _category = billCategories.first;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _paidByUid;
  bool _saving = false;
  Uint8List? _attachmentBytes;
  String? _attachmentName;
  String? _attachmentMime;

  Future<void> _pickAttachment() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Upload a PDF'),
              onTap: () => Navigator.of(context).pop('pdf'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    if (choice == 'pdf') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      final path = result?.files.single.path;
      if (path == null) return;
      final bytes = await File(path).readAsBytes();
      setState(() {
        _attachmentBytes = bytes;
        _attachmentName = result!.files.single.name;
        _attachmentMime = 'application/pdf';
      });
    } else {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _attachmentBytes = bytes;
        _attachmentName = file.name;
        _attachmentMime = 'image/jpeg';
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save(List<GroupMember> members) async {
    final user = ref.read(authStateProvider).value;
    final amount = double.tryParse(_amountController.text.trim());
    if (user == null || amount == null || amount <= 0) return;

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
    final note = _noteController.text.trim();
    final name = note.isEmpty ? _category : '$_category — $note';

    await ref.read(shoppingListRepositoryProvider).addPurchasedItem(
      groupId: widget.groupId,
      name: name,
      category: _category,
      quantity: '1',
      unit: '',
      addedByUid: user.uid,
      addedByName: paidByName,
      price: amount,
      paidByName: paidByName,
      boughtAt: _date,
    );
    await ref.read(activityRepositoryProvider).log(
      groupId: widget.groupId,
      actorName: paidByName,
      summary: 'Logged $_category — ₹${amount.toStringAsFixed(0)}',
    );

    final attachment = _attachmentBytes;
    if (attachment != null) {
      // Best-effort — the bill itself is already saved above regardless of
      // whether the attachment upload succeeds.
      try {
        await ref.read(documentRepositoryProvider).uploadDocument(
          groupId: widget.groupId,
          bytes: attachment,
          name: name,
          mimeType: _attachmentMime!,
          category: _documentCategoryForBill(_category),
          documentDate: _date,
          provider: note.isEmpty ? null : note,
          amount: amount,
          uploadedByUid: user.uid,
          uploadedByName: paidByName,
          ocrStatus: DocumentOcrStatus.notApplicable,
        );
      } catch (_) {}
    }

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
        title: const Text('Log a Bill'),
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: royalHeaderGradient),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: billCategories.map((category) {
              final selected = category == _category;
              final color = colorForCategory(category);
              return ChoiceChip(
                label: Text(category),
                avatar: Icon(iconForCategory(category), size: 17, color: selected ? Colors.white : color),
                selected: selected,
                selectedColor: ourShelfSeed,
                backgroundColor: ourShelfCard,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : ourShelfTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(color: selected ? ourShelfSeed : ourShelfBorder),
                onSelected: (_) => setState(() => _category = category),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'e.g. March installment',
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            tileColor: ourShelfCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: ourShelfBorder),
            ),
            leading: Icon(Icons.calendar_month_outlined, color: ourShelfSeed),
            title: const Text('Date'),
            trailing: Text(
              '${_date.day}/${_date.month}/${_date.year}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: members.any((m) => m.uid == _paidByUid) ? _paidByUid : user?.uid,
            decoration: const InputDecoration(labelText: 'Paid By'),
            items: [
              if (user != null && !members.any((m) => m.uid == user.uid))
                DropdownMenuItem(
                  value: user.uid,
                  child: Text(user.displayName ?? user.phoneNumber ?? 'You'),
                ),
              ...members.map((m) => DropdownMenuItem(value: m.uid, child: Text(m.displayName))),
            ],
            onChanged: (v) => setState(() => _paidByUid = v),
          ),
          const SizedBox(height: 16),
          if (_attachmentName == null)
            OutlinedButton.icon(
              onPressed: _pickAttachment,
              icon: const Icon(Icons.attach_file),
              label: const Text('Attach bill (photo or PDF) — optional'),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ourShelfCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ourShelfBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    _attachmentMime == 'application/pdf'
                        ? Icons.picture_as_pdf_outlined
                        : Icons.image_outlined,
                    color: ourShelfSeed,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _attachmentName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() {
                      _attachmentBytes = null;
                      _attachmentName = null;
                      _attachmentMime = null;
                    }),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 90),
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
                : const Text('Save Bill'),
          ),
        ),
      ),
    );
  }
}
