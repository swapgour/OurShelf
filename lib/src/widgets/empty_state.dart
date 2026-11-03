import 'package:flutter/material.dart';

import '../app.dart';

/// Shared empty-state presentation: icon, heading, short explanation and an
/// optional call-to-action — used everywhere a list/screen has no data yet
/// instead of each screen inventing its own blank-space treatment.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.ctaLabel,
    this.onCta,
    this.compact = false,
    this.accentColor = ourShelfSeed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;
  /// A smaller, inline variant (e.g. inside a "Recent Activity" card)
  /// rather than a full-screen centered treatment.
  final bool compact;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(compact ? 14 : 22),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: compact ? 26 : 40, color: accentColor),
        ),
        SizedBox(height: compact ? 12 : 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: compact ? 14 : 16,
            color: ourShelfTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: ourShelfTextSecondary, fontSize: compact ? 12.5 : 13),
        ),
        if (ctaLabel != null && onCta != null) ...[
          SizedBox(height: compact ? 14 : 20),
          OutlinedButton(onPressed: onCta, child: Text(ctaLabel!)),
        ],
      ],
    );

    if (compact) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: body);
    }
    return Center(
      child: Padding(padding: const EdgeInsets.all(24), child: body),
    );
  }
}
