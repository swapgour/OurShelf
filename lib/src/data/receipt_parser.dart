import 'catalogue.dart';
import 'shopping_item.dart';

/// One candidate item parsed out of a line of OCR text from a purchased
/// list / receipt photo. [price] is the line's total amount (not unit
/// rate); [quantity] is a best-guess count read off the line, if any.
class ParsedLine {
  const ParsedLine({
    required this.rawText,
    required this.name,
    this.price,
    this.quantity,
    this.unit,
  });

  final String rawText;
  final String name;
  final double? price;
  final String? quantity;
  /// A unit read directly off the source (set only when the AI receipt
  /// parser supplied one); null falls back to the starter catalogue's
  /// guess in [matchScannedLines].
  final String? unit;
}

/// Lines that are store/receipt boilerplate rather than purchased items —
/// filtered out so "Total", "GST", etc. don't show up as fake items.
const _stopWords = <String>{
  'total',
  'subtotal',
  'sub total',
  'grand total',
  'tax',
  'gst',
  'gstin',
  'cgst',
  'sgst',
  'fssai',
  'discount',
  'cash',
  'change',
  'balance',
  'thank you',
  'thanks for shopping',
  'visit again',
  'welcome',
  'invoice',
  'receipt',
  'bill',
  'date',
  'time',
  'cashier',
  'qty',
  'quantity',
  'amount',
  'items',
  'payment',
  'card',
  'upi',
  'mob',
  'mobile',
  'phone',
  'tel',
  'state name',
  'customer',
  'table no',
  'order no',
  'user',
  'sl ',
  'sl.',
  'hsn',
  'sac',
  'description',
  // E-commerce / app order-confirmation boilerplate (DMart, Blinkit,
  // Zepto, etc. print a running "You Save" / "You Pay" line under every
  // item instead of a single price column, plus order-metadata fields
  // that would otherwise look like item names).
  'you save',
  'you pay',
  'order number',
  'ordered date',
  'delivery address',
  'delivery date',
  'delivery charges',
  'delivery',
  'cart total',
  'shipment',
  'special offer',
  'item details',
  'approx',
  'payment details',
  'payment mode',
  'payment received',
  'time slot',
};

// Phrases that only ever show up in receipt boilerplate (shop header,
// invoice metadata, footer) — distinctive enough that matching them
// anywhere in a line (not just at its start) is safe, which matters
// because a curled/angled photo can make OCR split or reorder lines so the
// noise word isn't at the start any more (e.g. "Time : 17:51 hrs" coming
// back as a lone "17:51 hrs", or "Thank You Visit Again" as "NOU Visit
// Again"). Deliberately NOT position-based: on a distorted photo, ML Kit's
// block order isn't reliably top-to-bottom, so slicing lines by where a
// header/footer line was *found* can silently discard real item rows that
// happened to be read out of order — this is content-based instead, so it
// can never throw away a line just because of where it landed in the list.
final _noisePhrases = RegExp(
  r'visit again|thank you|tax invoice|hsn\s*/?\s*sac|state name|'
  r'gstin|fssai|bill no|total paid|sub\s*total|grand\s*total|'
  r'\b(post|road|nagar|layout|hobli|cross|colony|district|taluk)\b',
  caseSensitive: false,
);
// A bare time ("17:51 hrs", "7:51 PM") or date-metadata fragment left over
// after OCR splits a "Time : ..." / "Date : ..." line apart.
final _timeOrDateFragment = RegExp(
  r'^\d{1,2}:\d{2}(\s*(hrs?|am|pm))?$|^\d{1,2}[-/]\d{1,2}[-/]\d{2,4}$',
  caseSensitive: false,
);
final _phoneNumber = RegExp(r'\d{10}');
// A 6-digit PIN code — never a real price/quantity on an Indian grocery
// receipt, but easily mistaken for one if left to the generic trailing-
// number matcher (e.g. an address ending "... Bengaluru - 560067").
final _pinCode = RegExp(r'\b\d{6}\b');

// A tabular receipt row: "<serial> <item name> <qty> <rate> <amount>" —
// e.g. "1 Rice 2.00 110.00 220.00". Captures the name, quantity and the
// line's total amount directly, instead of treating the serial number as
// part of the item name.
final _tabularRow = RegExp(
  r'^(\d{1,3})\s+([A-Za-z][A-Za-z .&\-]*?)\s+'
  r'(\d+(?:\.\d{1,2})?)\s+'
  r'([\d,]+(?:\.\d{1,2})?)\s+'
  r'([\d,]+(?:\.\d{1,2})?)\s*$',
);

// Free-form list line with a leading count, e.g. "2 Tomatoes" or "3x Milk"
// — captures the count as a quantity instead of discarding it as a marker.
final _leadingQty = RegExp(r'^[\s\-\*••\[\]✓✔]*(\d{1,3}(?:\.\d{1,2})?)\s*[xX]?\s+(?=[A-Za-z])');
final _leadingMarker = RegExp(r'^[\s\-\*••\[\]xX✓✔]*(\d+[\.\)])?[\s\-\*••\[\]xX✓✔]*');
final _trailingPrice = RegExp(
  r'(?:₹|rs\.?|inr)?\s*([0-9]+(?:[.,][0-9]{1,2})?)\s*$',
  caseSensitive: false,
);

String _formatQty(String raw) {
  final value = double.tryParse(raw);
  if (value == null) return raw;
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}

/// Turns the raw OCR text lines from a photo into candidate purchased
/// items — the item's name, quantity and total amount — while dropping
/// boilerplate (shop name/address, phone numbers, invoice metadata,
/// totals) and list markers/checkboxes.
List<ParsedLine> parseReceiptLines(List<String> rawLines) {
  final results = <ParsedLine>[];
  for (final raw in rawLines) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) continue;
    if (_phoneNumber.hasMatch(trimmed)) continue;
    if (_pinCode.hasMatch(trimmed)) continue;
    if (_noisePhrases.hasMatch(trimmed)) continue;
    if (_timeOrDateFragment.hasMatch(trimmed)) continue;

    final tabular = _tabularRow.firstMatch(trimmed);
    if (tabular != null) {
      final name = tabular.group(2)!.trim();
      final lowerName = name.toLowerCase();
      if (name.length >= 2 && !_stopWords.any(lowerName.startsWith)) {
        final amount = double.tryParse(tabular.group(5)!.replaceAll(',', ''));
        results.add(
          ParsedLine(
            rawText: raw,
            name: name,
            price: amount != null && amount > 0 ? amount : null,
            quantity: _formatQty(tabular.group(3)!),
          ),
        );
      }
      continue;
    }

    String? quantity;
    var rest = trimmed;
    final qtyMatch = _leadingQty.firstMatch(trimmed);
    if (qtyMatch != null) {
      quantity = _formatQty(qtyMatch.group(1)!);
      rest = trimmed.substring(qtyMatch.end);
    }

    final withoutMarker = rest.replaceFirst(_leadingMarker, '').trim();
    if (withoutMarker.isEmpty) continue;

    final lower = withoutMarker.toLowerCase();
    if (_stopWords.any(lower.startsWith)) continue;
    // Pure number line (e.g. a lone total/date) — not an item.
    if (RegExp(r'^[\d\s.,:/-]+$').hasMatch(withoutMarker)) continue;

    double? price;
    var name = withoutMarker;
    final priceMatch = _trailingPrice.firstMatch(withoutMarker);
    if (priceMatch != null) {
      final numText = priceMatch.group(1)?.replaceAll(',', '');
      final parsed = numText == null ? null : double.tryParse(numText);
      final hasDecimal = numText != null && numText.contains('.');
      // A bare integer with no decimal point and a large magnitude is more
      // likely a PIN code, phone fragment or ID than a price — only trust
      // it as a price when it has a decimal or is a plausible item price.
      if (parsed != null && parsed > 0 && (hasDecimal || parsed < 10000)) {
        price = parsed;
        name = withoutMarker.substring(0, priceMatch.start).trim();
      }
    }
    name = name.replaceAll(RegExp(r'[\-:.,]+$'), '').trim();
    if (name.length < 2) continue;

    results.add(ParsedLine(rawText: raw, name: name, price: price, quantity: quantity));
  }
  return results;
}

String _normalize(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();

/// Classic edit-distance — small inputs (item names), so the O(n*m) table is
/// cheap enough without a package dependency.
int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final prev = List<int>.generate(b.length + 1, (j) => j);
  final curr = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      curr[j] = [curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost]
          .reduce((v, e) => v < e ? v : e);
    }
    for (var j = 0; j <= b.length; j++) {
      prev[j] = curr[j];
    }
  }
  return prev[b.length];
}

/// 1.0 = identical, 0.0 = nothing in common.
double _similarity(String a, String b) {
  final na = _normalize(a);
  final nb = _normalize(b);
  if (na.isEmpty || nb.isEmpty) return 0;
  if (na == nb) return 1;
  if (na.contains(nb) || nb.contains(na)) return 0.85;
  final distance = _levenshtein(na, nb);
  final longest = na.length > nb.length ? na.length : nb.length;
  return 1 - (distance / longest);
}

final _unitPattern = RegExp(
  r'(\d+(?:\.\d+)?)\s*'
  r'(kgs?|kilograms?|kilos?|grams?|gms?|g|ltrs?|litres?|liters?|l|ml|'
  r'dozens?|dz|packets?|packs?|pcs?|pieces?|bunch(?:es)?|bottles?|'
  r'box(?:es)?|jars?|tubes?)\b',
  caseSensitive: false,
);

const _unitCanonical = {
  'kg': 'kg', 'kgs': 'kg', 'kilogram': 'kg', 'kilograms': 'kg', 'kilo': 'kg', 'kilos': 'kg',
  'g': 'g', 'gm': 'g', 'gms': 'g', 'gram': 'g', 'grams': 'g',
  'l': 'L', 'ltr': 'L', 'ltrs': 'L', 'litre': 'L', 'litres': 'L', 'liter': 'L', 'liters': 'L',
  'ml': 'ml',
  'dozen': 'dozen', 'dozens': 'dozen', 'dz': 'dozen',
  'pack': 'pack', 'packs': 'pack', 'packet': 'pack', 'packets': 'pack',
  'pc': 'pc', 'pcs': 'pc', 'piece': 'pc', 'pieces': 'pc',
  'bunch': 'bunch', 'bunches': 'bunch',
  'bottle': 'bottle', 'bottles': 'bottle',
  'box': 'box', 'boxes': 'box',
  'jar': 'jar', 'jars': 'jar',
  'tube': 'tube', 'tubes': 'tube',
};

/// Splits a free-typed or pasted shopping list — e.g. copied from a text
/// message, one item per line or comma/semicolon separated, with or
/// without quantities — into add-ready lines: a best-guess category from
/// the starter catalogue, and a quantity/unit either read off the text or
/// defaulted to that item's typical catalogue unit (so "Onion" alone comes
/// out as 1 kg, "Milk" as 1 of its usual pack size, etc.).
List<({String name, String category, String quantity, String unit})>
parsePastedList(String text) {
  const matchThreshold = 0.72;
  final results = <({String name, String category, String quantity, String unit})>[];

  for (final rawEntry in text.split(RegExp(r'[\n,;]+'))) {
    var entry = rawEntry.trim();
    if (entry.isEmpty) continue;
    entry = entry.replaceFirst(_leadingMarker, '').trim();
    if (entry.isEmpty) continue;

    String? quantity;
    String? unit;
    final unitMatch = _unitPattern.firstMatch(entry);
    if (unitMatch != null) {
      quantity = _formatQty(unitMatch.group(1)!);
      unit = _unitCanonical[unitMatch.group(2)!.toLowerCase()];
      entry = (entry.substring(0, unitMatch.start) + entry.substring(unitMatch.end)).trim();
    } else {
      final leadingCount = _leadingQty.firstMatch(entry);
      if (leadingCount != null) {
        quantity = _formatQty(leadingCount.group(1)!);
        entry = entry.substring(leadingCount.end).trim();
      }
    }

    final name = entry.replaceAll(RegExp(r'^[\s\-:.,]+|[\s\-:.,]+$'), '').trim();
    if (name.length < 2) continue;

    CatalogueItem? best;
    double bestScore = 0;
    for (final c in starterCatalogue) {
      final score = _similarity(name, c.name);
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    final matched = bestScore >= matchThreshold ? best : null;

    results.add((
      name: name,
      category: matched?.category ?? 'Other',
      quantity: quantity ?? '1',
      unit: unit ?? matched?.unit ?? 'pc',
    ));
  }
  return results;
}

/// What a scanned line resolved to: either an existing "to buy" item to
/// mark bought, or a brand-new item (with a best-guess category/unit from
/// the starter catalogue) to add as already bought.
class ScanMatch {
  const ScanMatch({
    required this.line,
    this.matchedItem,
    this.suggestedCategory = 'Other',
    this.suggestedUnit = 'pc',
  });

  final ParsedLine line;
  final ShoppingItem? matchedItem;
  final String suggestedCategory;
  final String suggestedUnit;

  bool get isNewItem => matchedItem == null;
}

/// Matches each parsed line against the group's current "to buy" items
/// first (so scanning a purchased list closes out what was already
/// planned), then falls back to the starter catalogue for a category/unit
/// guess when it's a brand-new item.
List<ScanMatch> matchScannedLines({
  required List<ParsedLine> lines,
  required List<ShoppingItem> currentItems,
}) {
  final toBuy = currentItems.where((i) => i.status == ItemStatus.toBuy).toList();
  const matchThreshold = 0.72;

  return lines.map((line) {
    ShoppingItem? best;
    double bestScore = 0;
    for (final item in toBuy) {
      final score = _similarity(line.name, item.name);
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }
    if (best != null && bestScore >= matchThreshold) {
      return ScanMatch(line: line, matchedItem: best);
    }

    CatalogueItem? bestCatalogue;
    double bestCatalogueScore = 0;
    for (final entry in starterCatalogue) {
      final score = _similarity(line.name, entry.name);
      if (score > bestCatalogueScore) {
        bestCatalogueScore = score;
        bestCatalogue = entry;
      }
    }
    if (bestCatalogue != null && bestCatalogueScore >= matchThreshold) {
      return ScanMatch(
        line: line,
        suggestedCategory: bestCatalogue.category,
        suggestedUnit: line.unit ?? bestCatalogue.unit,
      );
    }

    return ScanMatch(line: line, suggestedUnit: line.unit ?? 'pc');
  }).toList();
}
