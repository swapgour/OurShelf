import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../auth/auth_providers.dart';
import '../../data/group.dart';
import '../../data/providers.dart';
import '../activity/activity_screen.dart';
import '../ai/ask_ai_screen.dart';
import '../bills/add_bill_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../documents/document_library_screen.dart';
import '../expenses/expenses_screen.dart';
import '../groups/group_sheet.dart';
import '../reminders/reminders_screen.dart';
import '../../theme/theme_controller.dart';
import 'about_screen.dart';
import 'how_it_works_screen.dart';

/// Everything that doesn't get its own bottom-nav tab: expenses, activity,
/// insights, reminders, group/member management, settings and help.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupStreamProvider(groupId)).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: royalHeaderGradient),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: royalHeaderGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.home_rounded, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group?.name ?? 'Your group',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${group?.members.length ?? 1} member${(group?.members.length ?? 1) == 1 ? '' : 's'}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ).let((w) => InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openGroupSheet(context, group),
                child: w,
              )),
          const SizedBox(height: 20),
          _Section(
            title: 'Household',
            tiles: [
              _MoreTile(
                icon: Icons.group_outlined,
                color: const Color(0xFF6A1B9A),
                title: 'Groups & Members',
                subtitle: 'Invite, roles and permissions',
                onTap: () => _openGroupSheet(context, group),
              ),
              _MoreTile(
                icon: Icons.insights_outlined,
                color: const Color(0xFF1565C0),
                title: 'Reports & Insights',
                subtitle: 'Spending by category, trends',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DashboardScreen(groupId: groupId)),
                ),
              ),
              _MoreTile(
                icon: Icons.receipt_long_outlined,
                color: const Color(0xFF00695C),
                title: 'Expenses',
                subtitle: 'Who paid, who owes',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ExpensesScreen(groupId: groupId)),
                ),
              ),
              _MoreTile(
                icon: Icons.home_work_outlined,
                color: const Color(0xFFAD6800),
                title: 'Bills & EMI',
                subtitle: 'EMI, internet, recharge, transfers',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AddBillScreen(groupId: groupId)),
                ),
              ),
              _MoreTile(
                icon: Icons.folder_copy_outlined,
                color: const Color(0xFF006064),
                title: 'Document History',
                subtitle: 'Every scanned/uploaded bill, saved permanently',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DocumentLibraryScreen(groupId: groupId)),
                ),
              ),
              _MoreTile(
                icon: Icons.event_repeat_outlined,
                color: const Color(0xFFC62828),
                title: 'Reminders',
                subtitle: 'Restock & recurring alerts',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => RemindersScreen(groupId: groupId)),
                ),
              ),
              _MoreTile(
                icon: Icons.history_rounded,
                color: const Color(0xFF4527A0),
                title: 'Activity',
                subtitle: "See what's changed recently",
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ActivityScreen(groupId: groupId)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Section(
            title: 'Account',
            tiles: [
              _MoreTile(
                icon: Icons.auto_awesome_outlined,
                color: ourShelfAccent,
                title: 'Ask AI',
                subtitle: 'Ask about your list, pantry & spending',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AskAiScreen(groupId: groupId)),
                ),
              ),
              _MoreTile(
                icon: Icons.workspace_premium_outlined,
                color: ourShelfAccent,
                title: 'Subscription',
                subtitle: 'Not set up yet',
                onTap: () => _comingSoon(
                  context,
                  "OurShelf doesn't have paid plans yet — everything is free.",
                ),
              ),
              _MoreTile(
                icon: Icons.settings_outlined,
                color: ourShelfTextSecondary,
                title: 'Settings',
                subtitle: 'Account & sign out',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _SettingsScreen()),
                ),
              ),
              _MoreTile(
                icon: Icons.route_outlined,
                color: const Color(0xFF00838F),
                title: 'How It Works',
                subtitle: 'The full app flow, plus what Ask AI will do',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HowItWorksScreen()),
                ),
              ),
              _MoreTile(
                icon: Icons.help_outline,
                color: ourShelfTextSecondary,
                title: 'Help & Support',
                subtitle: 'FAQs and contact',
                onTap: () => _showHelp(context),
              ),
              _MoreTile(
                icon: Icons.info_outline,
                color: ourShelfTextSecondary,
                title: 'About',
                subtitle: 'Developer & what\'s new',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openGroupSheet(BuildContext context, Group? group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => GroupSheet(group: group),
    );
  }

  void _comingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text(
          'Add items to your shared list, mark them bought with a price, '
          "and OurShelf tracks pantry stock and spending automatically.\n\n"
          'Need help? Reach out to whoever set up this app for your family.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.tiles});

  final String title;
  final List<_MoreTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: ourShelfTextSecondary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: ourShelfCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ourShelfBorder),
          ),
          child: Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                tiles[i],
                if (i != tiles.length - 1)
                  Divider(height: 1, indent: 56, color: ourShelfBorder),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: ourShelfTextSecondary, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 20),
    );
  }
}

class _SettingsScreen extends ConsumerWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: royalHeaderGradient),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(user?.displayName ?? user?.phoneNumber ?? 'Account'),
              subtitle: Text(user?.email ?? user?.phoneNumber ?? ''),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'APPEARANCE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: ourShelfTextSecondary,
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto_outlined),
                  ),
                ],
                selected: {ref.watch(themeModeProvider)},
                onSelectionChanged: (selected) =>
                    ref.read(themeModeProvider.notifier).setMode(selected.first),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}
