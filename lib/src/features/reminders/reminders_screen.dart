import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../auth/auth_providers.dart';
import '../../data/group.dart';
import '../../data/providers.dart';
import '../../widgets/motion.dart';

/// Recurring household essentials — "LPG refill every 30 days" — that
/// aren't really shopping-list items (no price, no quantity) but still
/// need a nudge on a schedule.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersProvider(groupId));
    final group = ref.watch(groupStreamProvider(groupId)).value;
    final uid = ref.watch(authStateProvider).value?.uid;
    final isViewer = isViewerRole(group, uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: royalHeaderGradient),
        ),
      ),
      body: remindersAsync.when(
        data: (reminders) {
          if (reminders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No reminders yet — add recurring essentials like an '
                  'LPG refill or water cans.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final sorted = [...reminders]
            ..sort((a, b) => (b.isDue ? 1 : 0) - (a.isDue ? 1 : 0));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            itemBuilder: (context, i) {
              final r = sorted[i];
              return FadeSlideIn(
                delay: Duration(milliseconds: i * 40),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: r.isDue ? ourShelfError.withValues(alpha: 0.08) : ourShelfCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: r.isDue ? ourShelfError.withValues(alpha: 0.3) : ourShelfBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (r.isDue ? ourShelfError : ourShelfSeed).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          r.isDue ? Icons.notifications_active : Icons.event_repeat,
                          color: r.isDue ? ourShelfError : ourShelfSeed,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                              r.lastDoneAt == null
                                  ? 'Every ${r.intervalDays} days · never done'
                                  : 'Every ${r.intervalDays} days · last done '
                                        '${r.lastDoneAt!.day}/${r.lastDoneAt!.month}/${r.lastDoneAt!.year}',
                              style: TextStyle(color: ourShelfTextSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (!isViewer) ...[
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline),
                          color: ourShelfSuccess,
                          tooltip: 'Mark done today',
                          onPressed: () => ref
                              .read(reminderRepositoryProvider)
                              .markDone(groupId: groupId, id: r.id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: ourShelfTextSecondary,
                          tooltip: 'Delete',
                          onPressed: () => ref
                              .read(reminderRepositoryProvider)
                              .delete(groupId: groupId, id: r.id),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load reminders: $e')),
      ),
      floatingActionButton: isViewer
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add reminder'),
            ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final daysController = TextEditingController(text: '30');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'e.g. LPG refill'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: daysController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Repeat every (days)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final days = int.tryParse(daysController.text.trim()) ?? 30;
              if (name.isEmpty) return;
              ref
                  .read(reminderRepositoryProvider)
                  .add(groupId: groupId, name: name, intervalDays: days);
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
