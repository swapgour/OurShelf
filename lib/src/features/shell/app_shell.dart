import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../data/providers.dart';
import '../home/home_screen.dart';
import '../more/more_screen.dart';
import '../pantry/pantry_screen.dart';
import '../purchase/add_purchase_screen.dart';
import '../shopping_list/shopping_list_screen.dart';

/// The app's root frame once signed in: a persistent bottom nav (Home,
/// Shopping, Add, Pantry, More) with a raised center Add button that opens
/// the purchase hub as its own screen instead of being a tab.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final groupIdAsync = ref.watch(activeGroupIdProvider);
    return groupIdAsync.when(
      data: (groupId) => _buildShell(groupId),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Could not set up your group: $error')),
      ),
    );
  }

  Widget _buildShell(String groupId) {
    final pages = [
      HomeScreen(groupId: groupId, onOpenTab: (i) => setState(() => _tabIndex = i)),
      const ShoppingListScreen(),
      PantryScreen(groupId: groupId),
      MoreScreen(groupId: groupId),
    ];

    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: pages),
      bottomNavigationBar: _BottomNav(
        index: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        onAdd: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AddPurchaseScreen(groupId: groupId)),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onTap, required this.onAdd});

  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: index == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.list_alt_rounded,
                label: 'List',
                selected: index == 1,
                onTap: () => onTap(1),
              ),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [ourShelfAccent, Color(0xFFF2CC6B)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: ourShelfAccent.withValues(alpha: 0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 26),
                    ),
                  ),
                ),
              ),
              _NavItem(
                icon: Icons.kitchen_rounded,
                label: 'Pantry',
                selected: index == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.grid_view_rounded,
                label: 'More',
                selected: index == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? ourShelfSeed : ourShelfTextSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
