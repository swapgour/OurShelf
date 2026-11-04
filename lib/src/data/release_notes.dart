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
