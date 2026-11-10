// Centralized product categorization. Every place that needs to guess a
// category/unit for a typed-in product name — manual "Add item", the
// receipt/PDF scanner, "Paste a list", and the one-time fix-up for
// existing items stuck in "Other" — goes through this one service, so the
// matching logic (and the dictionary it's built on) lives in exactly one
// place instead of being duplicated per screen.
//
// Lookup order: exact alias/catalogue name match, then fuzzy similarity
// against the catalogue (tolerates minor spelling mistakes, plurals and
// capitalization differences). Returns null when nothing is confident
// enough to call a match — the caller's job to then ask the user or fall
// back to "Other".
import 'package:cloud_firestore/cloud_firestore.dart';

import 'catalogue.dart';

String normalizeProductName(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();

/// Classic edit-distance — small inputs (item names), so the O(n*m) table is
/// cheap enough without a package dependency.
int levenshteinDistance(String a, String b) {
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

/// 1.0 = identical, 0.0 = nothing in common. Handles plural/singular and
/// minor typos via edit distance; a substring match (e.g. "Dishwash" within
/// "Dishwash liquid") scores high without being a perfect match.
double productNameSimilarity(String a, String b) {
  final na = normalizeProductName(a);
  final nb = normalizeProductName(b);
  if (na.isEmpty || nb.isEmpty) return 0;
  if (na == nb) return 1;
  // Cheap singular/plural tolerance ("onions" vs "onion").
  final na2 = na.endsWith('s') ? na.substring(0, na.length - 1) : na;
  final nb2 = nb.endsWith('s') ? nb.substring(0, nb.length - 1) : nb;
  if (na2 == nb2) return 0.97;
  if (na.contains(nb) || nb.contains(na)) return 0.85;
  final distance = levenshteinDistance(na, nb);
  final longest = na.length > nb.length ? na.length : nb.length;
  return 1 - (distance / longest);
}

const matchThreshold = 0.72;

/// One line of the before/after report the "Reclassify all items"
/// migration produces.
typedef CategoryChange = ({String name, String oldCategory, String newCategory});

/// Looks up [name] against the known-alias map first (handles short forms,
/// Hindi/Kannada grocery terms, and brand↔generic links that spell nothing
/// like the canonical catalogue entry), then falls back to fuzzy matching
/// against the starter catalogue itself. Returns null when nothing is
/// confident enough to call a match.
CatalogueItem? matchProductCategory(String name) {
  final normalized = normalizeProductName(name);
  if (normalized.isEmpty) return null;

  final aliasTarget = catalogueAliases[normalized];
  if (aliasTarget != null) {
    for (final entry in starterCatalogue) {
      if (entry.name == aliasTarget) return entry;
    }
  }

  CatalogueItem? best;
  double bestScore = 0;
  for (final entry in starterCatalogue) {
    final score = productNameSimilarity(name, entry.name);
    if (score > bestScore) {
      bestScore = score;
      best = entry;
    }
  }
  return bestScore >= matchThreshold ? best : null;
}

/// The pre-1.2.0 flat category names, mapped to their finalized
/// equivalents — a straight rename for everything except "Snacks &
/// beverages", which split into two new categories and so is handled by
/// re-matching the item's name instead (see [resolveMigratedCategory]).
const legacyCategoryRenames = <String, String>{
  'Dairy & eggs': 'Dairy & Eggs',
  'Grains & flours': 'Grains & Flours',
  'Pulses & dals': 'Pulses & Dals',
  'Spices & masalas': 'Spices & Masalas',
  'Oils & ghee': 'Oils & Ghee',
  'Bakery & breakfast': 'Breakfast & Cereals',
  'Cleaning & household': 'Cleaning & Household',
  'Personal care': 'Personal Care & Healthcare',
  'Baby & pet': 'Baby & Pet',
  'Pooja & festive': 'Pooja & Religious Items',
};

const _legacySplitCategory = 'Snacks & beverages';

/// Resolves the corrected category for an EXISTING item as part of the
/// one-time "Reclassify all items" migration (see [ShoppingListRepository
/// .recategorizeAllItems] / [PantryRepository.recategorizeAllItems]).
/// Returns null when nothing should change.
///
/// Order of precedence: a learned per-group alias always wins (an explicit
/// choice a member already made); then a confident dictionary match — this
/// is what corrects an item that was already miscategorized under the old
/// system (e.g. "Gold Refined Oil" sitting in Grains & Flours), not just
/// ones stuck in "Other"; only when neither finds anything does a plain old
/// category get renamed to its new name, which preserves whatever bucket a
/// member chose for an item the dictionary still doesn't recognize, rather
/// than guessing or moving it to "Other".
String? resolveMigratedCategory(
  String name,
  String currentCategory,
  Map<String, String> learnedAliases,
) {
  final learned = learnedAliases[normalizeProductName(name)];
  if (learned != null && learned != currentCategory) return learned;

  final matched = matchProductCategory(name)?.category;
  if (matched != null && matched != currentCategory) return matched;
  if (matched != null) return null; // already correct

  if (currentCategory == _legacySplitCategory) return 'Snacks & Sweets';
  final renamed = legacyCategoryRenames[currentCategory];
  if (renamed != null && renamed != currentCategory) return renamed;
  return null;
}

String _aliasId(String groupId, String name) =>
    normalizeProductName(name).replaceAll(RegExp(r'\s+'), '_');

/// Persists a group's own learned category choices — when a product isn't
/// in the catalogue and a member picks its category by hand, that choice is
/// remembered here so the same product auto-categorizes correctly next
/// time, for everyone in the group.
class CategorizationRepository {
  CategorizationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _aliases(String groupId) =>
      _firestore.collection('groups').doc(groupId).collection('categoryAliases');

  /// One-shot lookup for a single unknown product name, used right before
  /// falling back to "ask the user" when adding it.
  Future<Map<String, String>?> lookupLearned({
    required String groupId,
    required String name,
  }) async {
    final doc = await _aliases(groupId).doc(_aliasId(groupId, name)).get();
    if (!doc.exists) return null;
    final data = doc.data();
    final category = data?['category'] as String?;
    if (category == null) return null;
    return {'category': category, 'unit': data?['unit'] as String? ?? 'pc'};
  }

  /// All of a group's learned choices at once, keyed by normalized product
  /// name — used by the "Reclassify all items" migration so it doesn't do
  /// one Firestore read per item.
  Future<Map<String, String>> lookupAllLearned(String groupId) async {
    final snap = await _aliases(groupId).get();
    return {
      for (final doc in snap.docs)
        if (doc.data()['category'] is String)
          normalizeProductName(doc.data()['name'] as String? ?? doc.id):
              doc.data()['category'] as String,
    };
  }

  Future<void> saveLearned({
    required String groupId,
    required String name,
    required String category,
    required String unit,
  }) {
    return _aliases(groupId).doc(_aliasId(groupId, name)).set({
      'name': name,
      'category': category,
      'unit': unit,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
