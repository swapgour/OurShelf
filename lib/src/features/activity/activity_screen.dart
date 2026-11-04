import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/providers.dart';
import '../../widgets/motion.dart';

String _relativeTime(DateTime? time) {
  if (time == null) return 'just now';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// "Priya bought milk", "Mom added 3 items" — a live feed of who did what
/// in this group, and when.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(activityProvider(groupId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: royalHeaderGradient),
        ),
      ),
      body: entriesAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nothing has happened yet — actions on the list and '
                  'group will show up here.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final entry = entries[i];
              return FadeSlideIn(
                delay: Duration(milliseconds: i * 25),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ourShelfCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ourShelfBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: ourShelfSeed.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.history, color: ourShelfSeed, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.summary, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '${entry.actorName} · ${_relativeTime(entry.createdAt)}',
                              style: TextStyle(color: ourShelfTextSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load activity: $e')),
      ),
    );
  }
}
