import 'package:flutter/material.dart';

import '../assignments/assignments_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../fees/fees_screen.dart';
import '../profile/profile_screen.dart';
import '../timetable/timetable_screen.dart';

/// Lets any child screen switch the shell's active tab (used by the dashboard
/// quick actions).
class ShellController extends InheritedWidget {
  const ShellController({
    super.key,
    required this.goToTab,
    required super.child,
  });

  final void Function(ShellTab tab) goToTab;

  static ShellController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellController>();

  @override
  bool updateShouldNotify(ShellController oldWidget) => false;
}

enum ShellTab { home, timetable, assignments, fees, profile }

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialTab = ShellTab.home});

  /// Tab selected on first build. Defaults to the dashboard.
  final ShellTab initialTab;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late ShellTab _tab = widget.initialTab;

  static const List<_Destination> _destinations = <_Destination>[
    _Destination(
      label: 'Home',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
    ),
    _Destination(
      label: 'Timetable',
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_month_rounded,
    ),
    _Destination(
      label: 'Tasks',
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment_rounded,
    ),
    _Destination(
      label: 'Fees',
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
    ),
    _Destination(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  void _goToTab(ShellTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ShellController(
      goToTab: _goToTab,
      child: Scaffold(
        body: IndexedStack(
          index: _tab.index,
          children: const <Widget>[
            DashboardScreen(),
            TimetableScreen(),
            AssignmentsScreen(),
            FeesScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.dividerTheme.color ?? theme.dividerColor,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _tab.index,
            onDestinationSelected: (int index) =>
                _goToTab(ShellTab.values[index]),
            destinations: <Widget>[
              for (final _Destination d in _destinations)
                NavigationDestination(
                  label: d.label,
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.activeIcon),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
