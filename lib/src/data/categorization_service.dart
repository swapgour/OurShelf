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
