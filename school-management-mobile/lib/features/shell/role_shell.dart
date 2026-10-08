import 'package:flutter/material.dart';

import '../../core/api/session.dart';
import '../../core/staff_stores.dart';
import '../../core/student_store.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import '../staff/admin_screens.dart';
import '../staff/super_admin_screens.dart';
import '../staff/teacher_screens.dart';
import '../auth/set_password_screen.dart';
import 'app_shell.dart';

/// Sends the signed-in user to the portal built for their role.
///
/// The app used to refuse anything but a student at the login call. Now every
/// role signs in and lands here, and this is the single place that decides
/// which set of screens they see — so adding a role means adding one case, not
/// hunting for role checks scattered through the screens.
class RoleShell extends StatelessWidget {
  const RoleShell({super.key});

  @override
  Widget build(BuildContext context) {
    // A freshly issued account — a new parent login, student or teacher — is
    // refused every endpoint until its password is changed, so it goes here
    // before any portal rather than into a shell that would 403 throughout.
    if (Session.instance.user?.mustChangePassword == true) {
      return const SetPasswordScreen();
    }
    switch (Session.instance.user?.role) {
      case 'student':
      // A parent gets the student shell. The API scopes every student endpoint
      // by the student_id their token carries, so these screens already show
      // the child's data with nothing to change.
      case 'parent':
        return const AppShell();
      case 'teacher':
        return const _TabShell(tabs: _teacherTabs);
      case 'school_admin':
        return const _TabShell(tabs: _adminTabs);
      case 'super_admin':
        return const _TabShell(tabs: _platformTabs);
      default:
        // A role the app has no portal for. Signing them into someone else's
        // screens would just 403 on every request, so say so instead.
        return const _UnsupportedRole();
    }
  }

  /// Clears every role's cached data. Called on sign-out so the next account
  /// cannot be shown the previous one's school.
  static void resetAllStores() {
    StudentStore.instance.reset();
    TeacherStore.instance.reset();
    AdminStore.instance.reset();
    SuperAdminStore.instance.reset();
  }
}

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon, this.screen);

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget screen;
}

const List<_Tab> _teacherTabs = <_Tab>[
  _Tab('Home', Icons.grid_view_outlined, Icons.grid_view_rounded, TeacherHomeScreen()),
  _Tab('Classes', Icons.class_outlined, Icons.class_rounded, TeacherClassesScreen()),
  _Tab('Timetable', Icons.calendar_today_outlined, Icons.calendar_month_rounded,
      TeacherTimetableScreen()),
  _Tab('Leave', Icons.beach_access_outlined, Icons.beach_access_rounded,
      TeacherLeaveScreen()),
  _Tab('Settings', Icons.settings_outlined, Icons.settings_rounded, SettingsScreen()),
];

const List<_Tab> _adminTabs = <_Tab>[
  _Tab('Home', Icons.grid_view_outlined, Icons.grid_view_rounded, AdminHomeScreen()),
  _Tab('Students', Icons.groups_outlined, Icons.groups_rounded, AdminStudentsScreen()),
  _Tab('Teachers', Icons.co_present_outlined, Icons.co_present_rounded,
      AdminTeachersScreen()),
  _Tab('Fees', Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded, AdminFeesScreen()),
  _Tab('Settings', Icons.settings_outlined, Icons.settings_rounded, SettingsScreen()),
];

const List<_Tab> _platformTabs = <_Tab>[
  _Tab('Home', Icons.grid_view_outlined, Icons.grid_view_rounded, PlatformHomeScreen()),
  _Tab('Schools', Icons.apartment_outlined, Icons.apartment_rounded,
      PlatformSchoolsScreen()),
  _Tab('Plans', Icons.workspace_premium_outlined, Icons.workspace_premium_rounded,
      PlatformSubscriptionsScreen()),
  _Tab('Support', Icons.confirmation_number_outlined,
      Icons.confirmation_number_rounded, PlatformTicketsScreen()),
];

/// A bottom-tab shell over a fixed set of screens.
class _TabShell extends StatefulWidget {
  const _TabShell({required this.tabs});

  final List<_Tab> tabs;

  @override
  State<_TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<_TabShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      // IndexedStack, not a swap: each tab keeps its scroll position and its
      // already-fetched data when you come back to it.
      body: IndexedStack(
        index: _index,
        children: <Widget>[for (final _Tab t in widget.tabs) t.screen],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.dividerTheme.color ?? theme.dividerColor),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (int i) => setState(() => _index = i),
          destinations: <Widget>[
            for (final _Tab t in widget.tabs)
              NavigationDestination(
                label: t.label,
                icon: Icon(t.icon),
                selectedIcon: Icon(t.activeIcon),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnsupportedRole extends StatelessWidget {
  const _UnsupportedRole();

  @override
  Widget build(BuildContext context) {
    final String role = Session.instance.user?.role ?? 'unknown';
    return Scaffold(
      appBar: AppBar(title: const Text('Not supported')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.lock_outline_rounded, size: 40),
              const SizedBox(height: 14),
              Text(
                'There is no mobile portal for the "$role" role yet. '
                'Please use the web app.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  await Session.instance.clear();
                  RoleShell.resetAllStores();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((Route<void> r) => r.isFirst);
                  }
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The profile screen is student-shaped; staff get their settings tab instead.
/// Exposed so the student shell keeps using it unchanged.
const Widget studentProfileScreen = ProfileScreen();
