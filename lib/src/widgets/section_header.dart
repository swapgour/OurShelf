import 'package:flutter/material.dart';

import '../app.dart';

/// A consistent "Section Title ... action" row — used above the Recent
/// Activity list, Pantry categories, etc., instead of each screen rolling
/// its own Row(Text, Spacer, TextButton).
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: ourShelfTextPrimary),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: ourShelfSeed),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}
