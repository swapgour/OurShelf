import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../app.dart';
import '../../auth/auth_providers.dart';
import '../../data/document_repository.dart';
import '../../data/providers.dart';
import '../../data/stored_document.dart';

/// All permanently stored originals (scanned/uploaded bills, receipts, and
/// — once Insurance ships — policy documents) in one searchable, filterable
/// library. Search + category + year + month combine, matching the rest of
/// the app's filter conventions.
class DocumentLibraryScreen extends ConsumerStatefulWidget {
  const DocumentLibraryScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<DocumentLibraryScreen> createState() => _DocumentLibraryScreenState();
}

class _DocumentLibraryScreenState extends ConsumerState<DocumentLibraryScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  String? _category;
  int? _year;
  int? _month;
  bool _uploading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload(ImageSource? source) async {
    Uint8List? bytes;
    String? name;
    String? mimeType;
    if (source != null) {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      bytes = await file.readAsBytes();
      name = file.name;
      mimeType = 'image/jpeg';
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      final path = result?.files.single.path;
      if (path == null) return;
      bytes = await File(path).readAsBytes();
      name = result!.files.single.name;
      mimeType = name.toLowerCase().endsWith('.pdf')
          ? 'application/pdf'
          : name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg';
    }

    if (!mounted) return;
    final details = await showModalBottomSheet<_NewDocumentDetails>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NewDocumentSheet(suggestedName: name!),
    );
    if (details == null) return;

    await _upload(
      bytes: bytes,
      name: details.name,
      mimeType: mimeType,
      category: details.category,
      documentDate: details.documentDate,
    );
  }

  Future<void> _upload({
    required Uint8List bytes,
    required String name,
    required String mimeType,
    required String category,
    DateTime? documentDate,
    bool allowDuplicate = false,
  }) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    setState(() => _uploading = true);
    try {
      final result = await ref.read(documentRepositoryProvider).uploadDocument(
        groupId: widget.groupId,
        bytes: bytes,
        name: name,
        mimeType: mimeType,
        category: category,
        documentDate: documentDate,
        uploadedByUid: user.uid,
        uploadedByName: user.displayName ?? user.phoneNumber ?? 'Member',
        allowDuplicate: allowDuplicate,
      );
      if (!mounted) return;
      switch (result) {
        case DocumentUploadSuccess():
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved "$name"')),
          );
        case DocumentUploadTooLarge(:final fileSizeBytes):
          final kb = (fileSizeBytes / 1024).round();
          final capKb = (DocumentRepository.maxFileBytes / 1024).round();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'That file is ${kb}KB — too large to store in-app (max ${capKb}KB). '
                'Try a lower-resolution photo or a smaller PDF.',
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        case DocumentUploadDuplicate(:final existing):
          final proceed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Looks like a duplicate'),
              content: Text(
                'This matches "${existing.name}" already saved on '
                '${DateFormat('d MMM yyyy').format(existing.uploadedAt)}. Save another copy anyway?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Save anyway'),
                ),
              ],
            ),
          );
          if (proceed == true) {
            await _upload(
              bytes: bytes,
              name: name,
              mimeType: mimeType,
              category: category,
              documentDate: documentDate,
              allowDuplicate: true,
            );
          }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save document: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          docsAsync.value == null ? 'Document History' : 'Document History (${docsAsync.value!.length})',
        ),
        flexibleSpace: DecoratedBox(decoration: BoxDecoration(gradient: royalHeaderGradient)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : () => _showAddOptions(context),
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add),
        label: const Text('Add document'),
      ),
      body: docsAsync.when(
        data: (docs) {
          final years = <int>{for (final d in docs) d.year}.toList()..sort((a, b) => b.compareTo(a));
          final searched = _search.isEmpty
              ? docs
              : docs
                    .where(
                      (d) =>
                          d.name.toLowerCase().contains(_search) ||
                          (d.provider?.toLowerCase().contains(_search) ?? false),
                    )
                    .toList();
          final filtered = searched.where((d) {
            if (_category != null && d.category != _category) return false;
            if (_year != null && d.year != _year) return false;
            if (_month != null && d.month != _month) return false;
            return true;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by name or provider…',
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
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _FilterDropdownChip<String?>(
                      label: _category ?? 'Category',
                      active: _category != null,
                      onTap: () async {
                        final picked = await _pickFromList(
                          context,
                          ['All', ...documentCategories],
                          _category ?? 'All',
                        );
                        if (picked != null) setState(() => _category = picked == 'All' ? null : picked);
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterDropdownChip<int?>(
                      label: _year?.toString() ?? 'Year',
                      active: _year != null,
                      onTap: () async {
                        final options = ['All', ...years.map((y) => y.toString())];
                        final picked = await _pickFromList(context, options, _year?.toString() ?? 'All');
                        if (picked != null) {
                          setState(() => _year = picked == 'All' ? null : int.parse(picked));
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterDropdownChip<int?>(
                      label: _month == null ? 'Month' : DateFormat('MMMM').format(DateTime(2000, _month!)),
                      active: _month != null,
                      onTap: () async {
                        final options = [
                          'All',
                          for (var m = 1; m <= 12; m++) DateFormat('MMMM').format(DateTime(2000, m)),
                        ];
                        final current = _month == null ? 'All' : DateFormat('MMMM').format(DateTime(2000, _month!));
                        final picked = await _pickFromList(context, options, current);
                        if (picked != null) {
                          setState(() => _month = picked == 'All' ? null : options.indexOf(picked));
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            docs.isEmpty
                                ? 'No documents saved yet — scan a bill or tap "Add document".'
                                : 'Nothing matches your search/filters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: ourShelfTextSecondary),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => _DocumentRow(groupId: widget.groupId, doc: filtered[i]),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load documents: $e')),
      ),
    );
  }

  Future<String?> _pickFromList(BuildContext context, List<String> options, String current) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final o in options)
              ListTile(
                title: Text(o),
                trailing: o == current ? Icon(Icons.check, color: ourShelfSeed) : null,
                onTap: () => Navigator.of(context).pop(o),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(context).pop();
                _pickAndUpload(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _pickAndUpload(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Upload a PDF or image file'),
              onTap: () {
                Navigator.of(context).pop();
                _pickAndUpload(null);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdownChip<T> extends StatelessWidget {
  const _FilterDropdownChip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? ourShelfSeed : ourShelfCard,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? Colors.transparent : ourShelfBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : ourShelfTextSecondary,
                ),
              ),
              Icon(Icons.arrow_drop_down, size: 18, color: active ? Colors.white : ourShelfTextSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.groupId, required this.doc});

  final String groupId;
  final StoredDocument doc;

  @override
  Widget build(BuildContext context) {
    final date = doc.documentDate ?? doc.uploadedAt;
    return Material(
      color: ourShelfCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => _DocumentPreviewSheet(groupId: groupId, doc: doc),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ourShelfSeed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  doc.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                  color: ourShelfSeed,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      '${DateFormat('d MMM yyyy').format(date)} · ${doc.category}'
                      '${doc.documentDate == null ? ' (upload date)' : ''}',
                      style: TextStyle(color: ourShelfTextSecondary, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              if (doc.amount != null)
                Text(
                  '₹${doc.amount!.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentPreviewSheet extends ConsumerStatefulWidget {
  const _DocumentPreviewSheet({required this.groupId, required this.doc});

  final String groupId;
  final StoredDocument doc;

  @override
  ConsumerState<_DocumentPreviewSheet> createState() => _DocumentPreviewSheetState();
}

class _DocumentPreviewSheetState extends ConsumerState<_DocumentPreviewSheet> {
  Uint8List get _bytes => base64Decode(widget.doc.base64Data);

  Future<void> _openOrPrint() async {
    if (widget.doc.isPdf) {
      await Printing.layoutPdf(onLayout: (_) async => _bytes, name: widget.doc.name);
    }
  }

  Future<void> _share() async {
    final dir = await getTemporaryDirectory();
    final ext = widget.doc.isPdf ? 'pdf' : (widget.doc.mimeType == 'image/png' ? 'png' : 'jpg');
    final file = File('${dir.path}/${widget.doc.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}_${widget.doc.id}.$ext');
    await file.writeAsBytes(_bytes);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: widget.doc.name));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${widget.doc.name}"?'),
        content: const Text('This permanently removes the stored document. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ourShelfError),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(documentRepositoryProvider)
        .deleteDocument(groupId: widget.groupId, documentId: widget.doc.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _editDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.doc.documentDate ?? widget.doc.uploadedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    await ref.read(documentRepositoryProvider).updateDocumentDate(
      groupId: widget.groupId,
      documentId: widget.doc.id,
      documentDate: picked,
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 4),
            Text(
              '${(doc.fileSizeBytes / 1024).round()} KB · uploaded by ${doc.uploadedByName}',
              style: TextStyle(color: ourShelfTextSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            if (doc.isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: Image.memory(_bytes, fit: BoxFit.contain),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _openOrPrint,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Open / preview PDF'),
              ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Document date'),
              trailing: Text(DateFormat('d MMM yyyy').format(doc.documentDate ?? doc.uploadedAt)),
              onTap: _editDate,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _share,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: ourShelfError),
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NewDocumentDetails {
  const _NewDocumentDetails({required this.name, required this.category, this.documentDate});
  final String name;
  final String category;
  final DateTime? documentDate;
}

class _NewDocumentSheet extends StatefulWidget {
  const _NewDocumentSheet({required this.suggestedName});
  final String suggestedName;

  @override
  State<_NewDocumentSheet> createState() => _NewDocumentSheetState();
}

class _NewDocumentSheetState extends State<_NewDocumentSheet> {
  late final _nameController = TextEditingController(text: widget.suggestedName);
  String _category = documentCategories.first;
  DateTime? _date;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Save document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 14),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in documentCategories) DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Document date (optional)'),
                trailing: Text(_date == null ? 'Not set' : DateFormat('d MMM yyyy').format(_date!)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final name = _nameController.text.trim();
                    if (name.isEmpty) return;
                    Navigator.of(context).pop(
                      _NewDocumentDetails(name: name, category: _category, documentDate: _date),
                    );
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
