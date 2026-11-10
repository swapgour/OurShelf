/// One shipped version's changes, shown on the About screen — each entry
/// just 1-2 lines so the whole list stays skimmable.
class ReleaseNote {
  const ReleaseNote({required this.version, required this.date, required this.lines});

  final String version;
  final String date;
  final List<String> lines;
}

/// Newest first. Keep each line short — this is a skim list, not a
/// commit log.
const releaseNotes = [
  ReleaseNote(
    version: '1.2.0',
    date: 'Nov 2026',
    lines: [
      'Added: products auto-categorize everywhere (manual add included) using a shared catalogue of 150+ items, aliases and regional names',
      'Added: one-tap "Reclassify all items" to correct existing items into the finalized 18-category list, with a before/after report',
      'Added: Pantry now tracks a running total quantity and amount spent per item (e.g. bought 1 last week + 1 this week shows 2) — shown on each Pantry item and on the PDF export',
      'Changed: new brand mark — two pantry jars on a gold shelf, replacing the generic shelves icon on the splash screen, Home header, app icon and PDF export',
      'Fixed: Pantry PDF header is centered with the logo on top; untracked quantity/amount no longer show a broken glyph box',
      'Changed: splash screen loading motion — gold sparkles orbiting the logo, not generic bouncing dots',
      'Added: redesigned Pantry — search, category tabs, compact rows, filters & sorting',
      'Added: Pantry PDF export and share',
      'Added: Document History — every scanned/uploaded bill is now permanently saved and searchable',
      'Added: low-stock push notifications; AI-powered receipt scanning for messy/multi-column bills',
      'Added: Pooja & Religious Items category for diyas, camphor, rangoli and similar items',
      'Fixed: PDF scan silently failing on long order-confirmation pages',
      'Fixed: category chips scroll with an auto-peek hint instead of hiding undiscovered, or eating the whole screen by wrapping',
      'Fixed: items like "Premia Badam (Badami)" or "Besan (Kadale Hitu)" now categorize correctly instead of staying in Other',
      'Fixed: several dark-mode contrast issues',
    ],
  ),
  ReleaseNote(
    version: '1.1.0',
    date: 'Nov 2026',
    lines: [
      'Added: Paste a list — bulk add items from pasted text, auto-categorized',
      'Added: Ask AI answers now render as tables, bold text and bullet lists',
      'Added: About & What\'s New section',
      'Fixed: quantity from a reviewed scanned bill now saves correctly',
    ],
  ),
  ReleaseNote(
    version: '1.0.0',
    date: 'Nov 2026',
    lines: [
      'Added: Dark, light and system theme support',
      'Added: Per-member spending filter on the dashboard pie chart',
      'Added: Push notification when someone starts shopping',
      'Fixed: joining a group with a code now switches you into it',
      'Fixed: quantity/amount fields only accept numbers and display correctly',
    ],
  ),
];
