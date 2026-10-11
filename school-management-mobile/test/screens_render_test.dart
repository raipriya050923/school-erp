import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:school_management_mobile/core/theme/app_theme.dart';
import 'package:school_management_mobile/features/assignments/assignments_screen.dart';
import 'package:school_management_mobile/features/attendance/attendance_screen.dart';
import 'package:school_management_mobile/features/auth/login_screen.dart';
import 'package:school_management_mobile/features/fees/fees_screen.dart';
import 'package:school_management_mobile/features/notifications/notifications_screen.dart';
import 'package:school_management_mobile/features/profile/profile_screen.dart';
import 'package:school_management_mobile/features/results/results_screen.dart';
import 'package:school_management_mobile/features/settings/settings_screen.dart';
import 'package:school_management_mobile/features/shell/app_shell.dart';
import 'package:school_management_mobile/features/staff/admin_attendance_report_screen.dart';
import 'package:school_management_mobile/features/staff/admin_attendance_screen.dart';
import 'package:school_management_mobile/features/staff/admin_exams_screen.dart';
import 'package:school_management_mobile/features/staff/admin_leave_screen.dart';
import 'package:school_management_mobile/features/staff/admin_notices_screen.dart';
import 'package:school_management_mobile/features/staff/admin_screens.dart';
import 'package:school_management_mobile/features/staff/admin_student_form_screen.dart';
import 'package:school_management_mobile/features/staff/admin_teacher_form_screen.dart';
import 'package:school_management_mobile/features/staff/admin_staff_attendance_screen.dart';
import 'package:school_management_mobile/features/staff/platform_billing_screen.dart';
import 'package:school_management_mobile/features/staff/platform_geography_screen.dart';
import 'package:school_management_mobile/features/staff/platform_plans_screen.dart';
import 'package:school_management_mobile/features/staff/my_profile_screen.dart';
import 'package:school_management_mobile/features/staff/platform_plan_form_screen.dart';
import 'package:school_management_mobile/features/staff/platform_school_form_screen.dart';
import 'package:school_management_mobile/features/staff/super_admin_screens.dart';
import 'package:school_management_mobile/features/staff/teacher_attendance_screen.dart';
import 'package:school_management_mobile/features/staff/teacher_marks_screen.dart';
import 'package:school_management_mobile/features/staff/teacher_results_screen.dart';
import 'package:school_management_mobile/features/staff/teacher_screens.dart';
import 'package:school_management_mobile/features/timetable/timetable_screen.dart';

/// Screens are pumped at a few common phone sizes in both themes. Any
/// RenderFlex overflow or layout assertion surfaces as a caught exception.
void main() {
  const List<({String name, Size size})> devices = <({String name, Size size})>[
    (name: 'compact 360x690', size: Size(360, 690)),
    (name: 'standard 390x844', size: Size(390, 844)),
    (name: 'large 430x932', size: Size(430, 932)),
  ];

  final Map<String, Widget Function()> screens = <String, Widget Function()>{
    'Login': () => const LoginScreen(),
    'Shell': () => const AppShell(),
    'Timetable': () => const TimetableScreen(),
    'Attendance': () => const AttendanceScreen(),
    'Results': () => const ResultsScreen(),
    'Assignments': () => const AssignmentsScreen(),
    'Fees': () => const FeesScreen(),
    'Notifications': () => const NotificationsScreen(),
    'Profile': () => const ProfileScreen(),
    'Settings': () => const SettingsScreen(),
    // Staff portals. Each is pumped with no session, so every store is in its
    // loading state — which is exactly the frame most likely to overflow,
    // since the spinner and the empty app bar have to lay out on their own.
    'Teacher home': () => const TeacherHomeScreen(),
    'Teacher classes': () => const TeacherClassesScreen(),
    'Teacher timetable': () => const TeacherTimetableScreen(),
    'Teacher leave': () => const TeacherLeaveScreen(),
    'Teacher attendance': () => const TeacherAttendanceScreen(),
    'Teacher marks': () => const TeacherMarksScreen(),
    'Teacher results': () => const TeacherResultsScreen(),
    'Admin home': () => const AdminHomeScreen(),
    'Admin students': () => const AdminStudentsScreen(),
    'Admin teachers': () => const AdminTeachersScreen(),
    'Admin fees': () => const AdminFeesScreen(),
    'Admin attendance': () => const AdminAttendanceScreen(),
    'Admin staff attendance': () => const AdminStaffAttendanceScreen(),
    'Admin exams': () => const AdminExamsScreen(),
    'Admin leave': () => const AdminLeaveScreen(),
    'Admin notices': () => const AdminNoticesScreen(),
    'Admin attendance report': () => const AdminAttendanceReportScreen(),
    'Platform home': () => const PlatformHomeScreen(),
    'Platform schools': () => const PlatformSchoolsScreen(),
    'Platform subscriptions': () => const PlatformSubscriptionsScreen(),
    'Platform tickets': () => const PlatformTicketsScreen(),
    'Platform plans': () => const PlatformPlansScreen(),
    'Platform billing': () => const PlatformBillingScreen(),
    'Platform geography': () => const PlatformGeographyScreen(),
    'Platform plan form': () => const PlatformPlanFormScreen(),
    'My profile': () => const MyProfileScreen(),
    'Platform school form': () => const PlatformSchoolFormScreen(),
    // Both open in their create state, which is the one that renders with
    // no record behind it and so is the one that can overflow on a small
    // screen before anything is typed.
    'Admin student form': () => const AdminStudentFormScreen(),
    'Admin teacher form': () => const AdminTeacherFormScreen(),
  };

  for (final ({String name, Size size}) device in devices) {
    for (final MapEntry<String, Widget Function()> entry in screens.entries) {
      for (final bool dark in <bool>[false, true]) {
        testWidgets(
          '${entry.key} lays out on ${device.name} (${dark ? 'dark' : 'light'})',
          (WidgetTester tester) async {
            tester.view.physicalSize = device.size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? AppTheme.dark() : AppTheme.light(),
                home: entry.value(),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('every shell tab lays out when selected', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();

    for (final String label in <String>[
      'Timetable',
      'Tasks',
      'Fees',
      'Profile',
      'Home',
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$label tab overflowed');
    }
  });
}
