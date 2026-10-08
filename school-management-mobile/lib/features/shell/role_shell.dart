import 'package:flutter/material.dart';

import '../../core/api/session.dart';
import '../../core/staff_stores.dart';
import '../../core/student_store.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import '../staff/admin_attendance_report_screen.dart';
import '../staff/admin_attendance_screen.dart';
import '../staff/admin_exams_screen.dart';
import '../staff/admin_leave_screen.dart';
import '../staff/admin_notices_screen.dart';
import '../staff/admin_screens.dart';
import '../staff/admin_staff_attendance_screen.dart';
import '../staff/super_admin_screens.dart';
import 'more_screen.dart';
import '../staff/teacher_attendance_screen.dart';
import '../staff/teacher_marks_screen.dart';
import '../staff/teacher_results_screen.dart';
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
    if (Session.instance.user?.mustChangePassword == true ||
        Session.instance.passwordChangeRequired.value) {
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

/// Attendance and marks take the two bar slots that Timetable and Leave used
/// to hold: they are the jobs a teacher does standing in a classroom, several
/// times a day, while the other two are looked at now and then. The displaced
/// screens keep their place under More.
const List<_Tab> _teacherTabs = <_Tab>[
  _Tab('Home', Icons.grid_view_outlined, Icons.grid_view_rounded, TeacherHomeScreen()),
  _Tab('Attendance', Icons.fact_check_outlined, Icons.fact_check_rounded,
      TeacherAttendanceScreen()),
  _Tab('Marks', Icons.edit_note_outlined, Icons.edit_note_rounded,
      TeacherMarksScreen()),
  _Tab('Classes', Icons.class_outlined, Icons.class_rounded, TeacherClassesScreen()),
  _Tab('More', Icons.more_horiz_outlined, Icons.more_horiz, MoreScreen(
    title: 'More',
    entries: <MoreEntry>[
      MoreEntry('Class results', Icons.workspace_premium_outlined,
          _buildTeacherResults,
          subtitle: 'Review your section and sign it off'),
      MoreEntry('My timetable', Icons.calendar_month_outlined,
          _buildTeacherTimetable, subtitle: 'Your periods for the week'),
      MoreEntry('My leave', Icons.beach_access_outlined, _buildTeacherLeave,
          subtitle: 'Apply, and see what has been decided'),
      MoreEntry('Settings', Icons.settings_outlined, _buildSettings),
    ],
  )),
];

Widget _buildTeacherResults(BuildContext _) => const TeacherResultsScreen();
Widget _buildTeacherTimetable(BuildContext _) => const TeacherTimetableScreen();
Widget _buildTeacherLeave(BuildContext _) => const TeacherLeaveScreen();
Widget _buildSettings(BuildContext _) => const SettingsScreen();

/// Students, Teachers and Fees keep their places; everything the office reaches
/// for less often moves under More, which is what lets this role grow past the
/// four or five destinations a bottom bar can carry.
const List<_Tab> _adminTabs = <_Tab>[
  _Tab('Home', Icons.grid_view_outlined, Icons.grid_view_rounded, AdminHomeScreen()),
  _Tab('Students', Icons.groups_outlined, Icons.groups_rounded, AdminStudentsScreen()),
  _Tab('Teachers', Icons.co_present_outlined, Icons.co_present_rounded,
      AdminTeachersScreen()),
  _Tab('Fees', Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded, AdminFeesScreen()),
  _Tab('More', Icons.more_horiz_outlined, Icons.more_horiz, MoreScreen(
    title: 'More',
    entries: <MoreEntry>[
      MoreEntry('Class attendance', Icons.fact_check_outlined,
          _buildAdminAttendance,
          subtitle: 'Take or correct any section\'s register'),
      MoreEntry('Staff attendance', Icons.badge_outlined,
          _buildAdminStaffAttendance, subtitle: 'The staff register for a day'),
      MoreEntry('Examinations', Icons.school_outlined, _buildAdminExams,
          subtitle: 'Schedules, sign-off and publishing'),
      MoreEntry('Leave requests', Icons.beach_access_outlined, _buildAdminLeave,
          subtitle: 'Approve or turn down staff leave'),
      MoreEntry('Notice board', Icons.campaign_outlined, _buildAdminNotices,
          subtitle: 'Post to the school'),
      MoreEntry('Attendance report', Icons.insights_outlined,
          _buildAdminAttendanceReport,
          subtitle: 'One student over a date range'),
      MoreEntry('Settings', Icons.settings_outlined, _buildSettings),
    ],
  )),
];

Widget _buildAdminAttendance(BuildContext _) => const AdminAttendanceScreen();
Widget _buildAdminStaffAttendance(BuildContext _) =>
    const AdminStaffAttendanceScreen();
Widget _buildAdminExams(BuildContext _) => const AdminExamsScreen();
Widget _buildAdminLeave(BuildContext _) => const AdminLeaveScreen();
Widget _buildAdminNotices(BuildContext _) => const AdminNoticesScreen();
Widget _buildAdminAttendanceReport(BuildContext _) =>
    const AdminAttendanceReportScreen();

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
