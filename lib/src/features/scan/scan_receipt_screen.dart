import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

import '../../ai/receipt_ai_client.dart';
import '../../app.dart';
import '../../auth/auth_providers.dart';
import '../../data/category_style.dart';
import '../../data/providers.dart';
import '../../data/purchase_commit.dart';
import '../../data/receipt_parser.dart';
import '../../widgets/motion.dart';

enum _ScanStage { pickImage, reading, review, empty }

/// Scan a photo of a purchased list / receipt: on-device OCR (Google ML
/// Kit — free, offline, and Google keeps the recognition model itself
/// current via Play Services, so there's nothing to update here) reads the
/// text, then each line is matched against what's on the shopping list
/// (closing it out as bought) or added as a new purchased item when it
/// isn't already on the list.
class ScanReceiptScreen extends ConsumerStatefulWidget {
  const ScanReceiptScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends ConsumerState<ScanReceiptScreen> {
  _ScanStage _stage = _ScanStage.pickImage;
  List<ScanMatch> _matches = [];
  late List<bool> _selected;
  late List<double?> _prices;
  bool _saving = false;
  // What OCR actually saw on the last attempt — shown on the empty-state
  // screen so "nothing found" is diagnosable (no text detected at all vs.
  // text detected but filtered out) instead of a silent dead end.
  List<String> _lastRawLines = [];

  Future<List<String>> _ocrImageFile(TextRecognizer recognizer, String path) async {
    final recognized = await recognizer.processImage(InputImage.fromFilePath(path));
    return [
      for (final block in recognized.blocks)
        for (final line in block.lines) line.text,
    ];
  }

  Future<void> _pickAndScan(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;

    setState(() => _stage = _ScanStage.reading);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final rawLines = await _ocrImageFile(recognizer, file.path);
      await _finishWithLines(rawLines);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lastRawLines = [];
        _stage = _ScanStage.empty;
      });
    } finally {
      await recognizer.close();
    }
  }

  // A whole page rendered at a flat 3x multiplier works for a normal
  // single-page receipt, but ML Kit silently finds nothing on a very tall,
  // narrow image (a long order-confirmation PDF can be one page dozens of
  // "screens" tall). pdfx's own cropRect-based tiling turned out to be
  // unreliable at this scale (returns 0 text, or throws, on some tiles) —
  // confirmed by direct on-device testing — so instead the WHOLE page is
  // rendered once (that part works fine even for a huge bitmap) and then
  // sliced into OCR-sized horizontal strips in pure Dart before each strip
  // is recognized individually.
  static const _maxRenderWidth = 3200.0;
  static const _maxTotalHeight = 20000.0;
  static const _sliceHeightPx = 3200;

  Future<List<Uint8List>> _sliceImage(Uint8List pngBytes, int sliceHeight) async {
    final codec = await ui.instantiateImageCodec(pngBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final width = image.width;
    final height = image.height;
    final slices = <Uint8List>[];
    for (var y = 0; y < height; y += sliceHeight) {
      final h = math.min(sliceHeight, height - y);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, y.toDouble(), width.toDouble(), h.toDouble()),
        Rect.fromLTWH(0, 0, width.toDouble(), h.toDouble()),
        Paint(),
      );
      final picture = recorder.endRecording();
      final sliceImg = await picture.toImage(width, h);
      final byteData = await sliceImg.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) slices.add(byteData.buffer.asUint8List());
      sliceImg.dispose();
      picture.dispose();
    }
    image.dispose();
    return slices;
  }

  /// Renders one page of a picked PDF (once, as a whole) and OCRs it —
  /// sliced into strips first when it's tall enough that a single pass
  /// would overwhelm the recognizer — appending every line found to
  /// [rawLines]. A failure on one slice is skipped rather than aborting
  /// the whole scan.
  Future<void> _renderAndOcrPage(
    pdfx.PdfPage page,
    TextRecognizer recognizer,
    List<File> tempFiles,
    List<String> rawLines,
    int pageIndex,
  ) async {
    var scale = math.min(3.0, _maxRenderWidth / math.max(page.width, 1));
    if (page.height * scale > _maxTotalHeight) {
      scale = _maxTotalHeight / page.height;
    }
    final rendered = await page.render(
      width: page.width * scale,
      height: page.height * scale,
      format: pdfx.PdfPageImageFormat.png,
    );
    if (rendered == null) return;

    final slices = (rendered.height ?? 0) > _sliceHeightPx
        ? await _sliceImage(rendered.bytes, _sliceHeightPx)
        : [rendered.bytes];

    for (var t = 0; t < slices.length; t++) {
      try {
        final tempFile = File(
          '${Directory.systemTemp.path}/ourshelf_scan_${DateTime.now().microsecondsSinceEpoch}_${pageIndex}_$t.png',
        );
        await tempFile.writeAsBytes(slices[t]);
        tempFiles.add(tempFile);
        rawLines.addAll(await _ocrImageFile(recognizer, tempFile.path));
      } catch (_) {
        // Skip this slice — a bad strip shouldn't blank out everything
        // else the scan already found.
      }
    }
  }

  /// Renders each page of a picked PDF to an image (pdfx) and OCRs each one
  /// with the same recognizer used for photos — so a PDF receipt/bill works
  /// exactly like a photographed one.
  Future<void> _pickPdfAndScan() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() => _stage = _ScanStage.reading);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    pdfx.PdfDocument? document;
    final tempFiles = <File>[];
    try {
      document = await pdfx.PdfDocument.openFile(path);
      final rawLines = <String>[];
      for (var i = 1; i <= document.pagesCount; i++) {
        final page = await document.getPage(i);
        try {
          await _renderAndOcrPage(page, recognizer, tempFiles, rawLines, i);
        } finally {
          await page.close();
        }
      }
      await _finishWithLines(rawLines);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lastRawLines = [];
        _stage = _ScanStage.empty;
      });
    } finally {
      await document?.close();
      await recognizer.close();
      for (final f in tempFiles) {
        unawaited(f.delete());
      }
    }
  }

  /// Prefers the AI parser (handles messy, out-of-order OCR text — multi
  /// column app order PDFs especially — far better than fixed regexes can)
  /// and falls back to the local line-by-line parser if the AI backend
  /// isn't configured or the request fails, so scanning still works
  /// without it.
  Future<List<ParsedLine>> _parseLines(List<String> rawLines) async {
    final aiClient = ReceiptAiClient();
    if (aiClient.isConfigured) {
      try {
        final items = await aiClient.parseItems(rawLines);
        if (items.isNotEmpty) {
          return items
              .map(
                (i) => ParsedLine(
                  rawText: i.name,
                  name: i.name,
                  price: i.price,
                  quantity: i.quantity,
                  unit: i.unit,
                ),
              )
              .toList();
        }
      } catch (_) {
        // Fall through to the local parser below.
      }
    }
    return parseReceiptLines(rawLines);
  }

  Future<void> _finishWithLines(List<String> rawLines) async {
    final parsed = await _parseLines(rawLines);
    final currentItems = ref.read(shoppingItemsProvider(widget.groupId)).value ?? [];
    final matches = matchScannedLines(lines: parsed, currentItems: currentItems);

    if (!mounted) return;
    setState(() {
      _matches = matches;
      _selected = List.filled(matches.length, true);
      _prices = matches.map((m) => m.line.price).toList();
      _lastRawLines = rawLines;
      _stage = matches.isEmpty ? _ScanStage.empty : _ScanStage.review;
    });
  }

  Future<void> _confirm() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    setState(() => _saving = true);

    final paidByName = user.displayName ?? user.phoneNumber ?? 'Me';
    try {
      await commitPurchaseMatches(
        shoppingRepo: ref.read(shoppingListRepositoryProvider),
        activityRepo: ref.read(activityRepositoryProvider),
        pantryRepo: ref.read(pantryRepositoryProvider),
        groupId: widget.groupId,
        matches: _matches,
        selected: _selected,
        prices: _prices,
        uid: user.uid,
        paidByName: paidByName,
        activitySummary: (n) => 'Added $n item${n == 1 ? '' : 's'} from a scanned list',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan purchased list'),
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: royalHeaderGradient),
        ),
      ),
      body: switch (_stage) {
        _ScanStage.pickImage => _PickImageBody(onPick: _pickAndScan, onPickPdf: _pickPdfAndScan),
        _ScanStage.reading => const _ReadingBody(),
        _ScanStage.empty => _EmptyBody(
            rawLines: _lastRawLines,
            onRetry: () => setState(() => _stage = _ScanStage.pickImage),
          ),
        _ScanStage.review => _ReviewBody(
            matches: _matches,
            selected: _selected,
            prices: _prices,
            saving: _saving,
            onToggle: (i, v) => setState(() => _selected[i] = v),
            onRename: (i, name) => setState(() {
              _matches[i] = ScanMatch(
                line: ParsedLine(
                  rawText: _matches[i].line.rawText,
                  name: name,
                  price: _matches[i].line.price,
                  quantity: _matches[i].line.quantity,
                ),
                matchedItem: _matches[i].matchedItem,
                suggestedCategory: _matches[i].suggestedCategory,
                suggestedUnit: _matches[i].suggestedUnit,
              );
            }),
            onQuantityChanged: (i, q) => setState(() {
              _matches[i] = ScanMatch(
                line: ParsedLine(
                  rawText: _matches[i].line.rawText,
                  name: _matches[i].line.name,
                  price: _matches[i].line.price,
                  quantity: q,
                ),
                matchedItem: _matches[i].matchedItem,
                suggestedCategory: _matches[i].suggestedCategory,
                suggestedUnit: _matches[i].suggestedUnit,
              );
            }),
            onPriceChanged: (i, p) => setState(() => _prices[i] = p),
            onConfirm: _confirm,
          ),
      },
    );
  }
}

class _PickImageBody extends StatelessWidget {
  const _PickImageBody({required this.onPick, required this.onPickPdf});

  final void Function(ImageSource source) onPick;
  final VoidCallback onPickPdf;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulseIcon(
              minScale: 0.95,
              maxScale: 1.06,
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: Color(0xFF4A148C).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  size: 56,
                  color: Color(0xFF4A148C),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Scan a purchased list',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Photograph, upload a photo, or upload a PDF of a handwritten "
              "or printed list you've already bought — we'll read it and "
              "mark those items bought for you.",
              textAlign: TextAlign.center,
              style: TextStyle(color: ourShelfTextSecondary),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => onPick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Take a photo'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => onPick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose from gallery'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onPickPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Upload a PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingBody extends StatelessWidget {
  const _ReadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFF4A148C)),
          SizedBox(height: 16),
          Text('Reading your list…'),
        ],
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.onRetry, this.rawLines = const []});

  final VoidCallback onRetry;
  final List<String> rawLines;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 48, color: ourShelfTextSecondary),
          const SizedBox(height: 12),
          Text(
            rawLines.isEmpty
                ? "Couldn't detect any text in that photo."
                : "Found some text, but nothing that looked like a purchased item.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Lay the receipt flat on a plain, well-lit surface, avoid glare '
            'and shadows, and fill the frame with just the receipt.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ourShelfTextSecondary),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
          if (rawLines.isNotEmpty) ...[
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'What OCR read from the photo:',
                style: TextStyle(fontWeight: FontWeight.w600, color: ourShelfTextSecondary),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ourShelfCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ourShelfBorder),
              ),
              child: Text(
                rawLines.isEmpty ? '(nothing)' : rawLines.join('\n'),
                style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: ourShelfTextPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({
    required this.matches,
    required this.selected,
    required this.prices,
    required this.saving,
    required this.onToggle,
    required this.onRename,
    required this.onQuantityChanged,
    required this.onPriceChanged,
    required this.onConfirm,
  });

  final List<ScanMatch> matches;
  final List<bool> selected;
  final List<double?> prices;
  final bool saving;
  final void Function(int index, bool value) onToggle;
  final void Function(int index, String name) onRename;
  final void Function(int index, String? quantity) onQuantityChanged;
  final void Function(int index, double? price) onPriceChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final selectedCount = selected.where((s) => s).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Found ${matches.length} item${matches.length == 1 ? '' : 's'} — review before adding',
              style: TextStyle(color: ourShelfTextSecondary, fontSize: 13),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            itemCount: matches.length,
            itemBuilder: (context, i) {
              final match = matches[i];
              final color = colorForCategory(
                match.matchedItem?.category ?? match.suggestedCategory,
              );
              return FadeSlideIn(
                delay: Duration(milliseconds: i * 35),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: CheckboxListTile(
                    value: selected[i],
                    onChanged: (v) => onToggle(i, v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        iconForCategory(
                          match.matchedItem?.category ?? match.suggestedCategory,
                        ),
                        color: color,
                        size: 20,
                      ),
                    ),
                    title: GestureDetector(
                      onTap: () async {
                        final result = await _editNameDialog(context, match.line.name);
                        if (result != null) onRename(i, result);
                      },
                      child: Text(
                        match.line.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        Text(
                          match.isNewItem ? 'New item' : 'Matches your list',
                          style: TextStyle(
                            fontSize: 12,
                            color: match.isNewItem
                                ? Colors.orange.shade800
                                : Colors.green.shade700,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 54,
                          child: TextFormField(
                            initialValue: match.line.quantity ?? '1',
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'qty',
                              border: UnderlineInputBorder(),
                            ),
                            onChanged: (v) => onQuantityChanged(i, v.trim().isEmpty ? null : v.trim()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 90,
                          child: TextFormField(
                            initialValue: prices[i]?.toStringAsFixed(0) ?? '',
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              isDense: true,
                              prefixText: '₹ ',
                              hintText: 'total',
                              border: UnderlineInputBorder(),
                            ),
                            onChanged: (v) => onPriceChanged(i, double.tryParse(v.trim())),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: selectedCount == 0 || saving ? null : onConfirm,
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Add $selectedCount item${selectedCount == 1 ? '' : 's'}'),
            ),
          ),
        ),
      ],
    );
  }

  Future<String?> _editNameDialog(BuildContext context, String current) {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit item name'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
