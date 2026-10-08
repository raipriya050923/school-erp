import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:school_management_mobile/core/loadable.dart';
import 'package:school_management_mobile/core/staff_stores.dart';
import 'package:school_management_mobile/core/theme/app_theme.dart';
import 'package:school_management_mobile/data/staff_models.dart';
import 'package:school_management_mobile/features/staff/admin_screens.dart';
import 'package:school_management_mobile/features/staff/super_admin_screens.dart';
import 'package:school_management_mobile/features/staff/teacher_screens.dart';

/// The staff dashboards, pumped with data already in the store.
///
/// The render suite only ever pumps these with an empty store, so it exercises
/// the spinner and never the loaded state — which is where the metric tiles
/// actually lay out. A dashboard that renders nothing once its data arrives
/// passes that suite and fails on a phone.
void main() {
  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: screen),
    );
    await tester.pump();
  }

  testWidgets('super-admin dashboard shows its figures once loaded', (
    WidgetTester tester,
  ) async {
    SuperAdminStore.instance.stats = const Loadable<PlatformStats>.data(
      PlatformStats(
        totalSchools: 12,
        activeSubscriptions: 6,
        trialSubscriptions: 4,
        monthlyRecurringRevenue: 653,
        openTickets: 5,
      ),
    );
    addTearDown(SuperAdminStore.instance.reset);

    await pump(tester, const PlatformHomeScreen());

    expect(find.text('Schools'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Open tickets'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('teacher dashboard shows its figures once loaded', (
    WidgetTester tester,
  ) async {
    TeacherStore.instance.dashboard = const Loadable<TeacherDashboard>.data(
      TeacherDashboard(
        profile: TeacherProfile(name: 'Rajesh Koirala'),
        myClassesCount: 4,
        studentsTaught: 542,
        submissionsToGrade: 66,
        openHomework: 1,
      ),
    );
    addTearDown(TeacherStore.instance.reset);

    await pump(tester, const TeacherHomeScreen());

    expect(find.text('My classes'), findsOneWidget);
    expect(find.text('542'), findsOneWidget);
  });

  testWidgets('admin dashboard shows its figures once loaded', (
    WidgetTester tester,
  ) async {
    AdminStore.instance.dashboard = const Loadable<AdminDashboard>.data(
      AdminDashboard(
        schoolName: 'Sunrise Public School',
        academicYear: '2026-27',
        totalStudents: 1248,
        totalTeachers: 8,
        teachersOnLeave: 1,
        totalClasses: 5,
        totalSections: 10,
        feesBilled: 16134500,
        feesCollected: 119000,
        feesOverdue: 16015500,
        unpaidInvoices: 1247,
      ),
    );
    addTearDown(AdminStore.instance.reset);

    await pump(tester, const AdminHomeScreen());

    expect(find.text('Students'), findsOneWidget);
    expect(find.text('1248'), findsOneWidget);
    expect(find.text('Collected'), findsOneWidget);
  });

  // The list screens share the same blind spot: the render suite only ever
  // pumps them empty, so a row that cannot lay out would never be caught.
  testWidgets('platform schools list renders its rows', (
    WidgetTester tester,
  ) async {
    SuperAdminStore.instance.schools = const Loadable<List<PlatformSchool>>.data(
      <PlatformSchool>[
        PlatformSchool(
          id: 15,
          name: 'Raghav Public School',
          status: 'active',
          studentCount: 16,
          schoolCode: 'RPS160156',
          city: 'Noida',
          planName: 'Basic',
        ),
      ],
    );
    addTearDown(SuperAdminStore.instance.reset);

    await pump(tester, const PlatformSchoolsScreen());

    expect(find.text('Raghav Public School'), findsOneWidget);
    expect(find.text('active'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
  });

  testWidgets('teacher classes list renders its rows', (
    WidgetTester tester,
  ) async {
    TeacherStore.instance.classes = const Loadable<List<TeacherClass>>.data(
      <TeacherClass>[
        TeacherClass(
          className: 'Grade 8',
          sectionName: 'A',
          studentCount: 127,
          isClassTeacher: true,
          subject: 'Mathematics',
          room: 'R-204',
        ),
      ],
    );
    addTearDown(TeacherStore.instance.reset);

    await pump(tester, const TeacherClassesScreen());

    expect(find.text('Grade 8 — A'), findsOneWidget);
    expect(find.text('class teacher'), findsOneWidget);
  });

  testWidgets('admin students list renders and filters', (
    WidgetTester tester,
  ) async {
    AdminStore.instance.students = const Loadable<List<AdminStudent>>.data(
      <AdminStudent>[
        AdminStudent(
          id: 1,
          name: 'Aarav Thapa',
          admissionNo: 'ADM-1',
          feeDue: 0,
          status: 'active',
          className: 'Grade 8',
          sectionName: 'A',
        ),
        AdminStudent(
          id: 2,
          name: 'Sneha Sharma',
          admissionNo: 'ADM-2',
          feeDue: 1200,
          status: 'active',
          className: 'Grade 9',
          sectionName: 'B',
        ),
      ],
    );
    addTearDown(AdminStore.instance.reset);

    await pump(tester, const AdminStudentsScreen());
    expect(find.text('Aarav Thapa'), findsOneWidget);
    expect(find.text('Sneha Sharma'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'sneha');
    await tester.pump();
    expect(find.text('Aarav Thapa'), findsNothing);
    expect(find.text('Sneha Sharma'), findsOneWidget);
  });

  // Every staff screen must offer a way out. The super-admin shell has no
  // Settings tab, so when sign-out lived only there a platform owner could sign
  // in and then had no route back to the login screen.
  for (final ({String name, Widget screen}) c
      in <({String name, Widget screen})>[
        (name: 'Platform home', screen: PlatformHomeScreen()),
        (name: 'Platform schools', screen: PlatformSchoolsScreen()),
        (name: 'Platform subscriptions', screen: PlatformSubscriptionsScreen()),
        (name: 'Platform tickets', screen: PlatformTicketsScreen()),
        (name: 'Teacher home', screen: TeacherHomeScreen()),
        (name: 'Teacher classes', screen: TeacherClassesScreen()),
        (name: 'Teacher timetable', screen: TeacherTimetableScreen()),
        (name: 'Teacher leave', screen: TeacherLeaveScreen()),
        (name: 'Admin home', screen: AdminHomeScreen()),
        (name: 'Admin students', screen: AdminStudentsScreen()),
        (name: 'Admin teachers', screen: AdminTeachersScreen()),
        (name: 'Admin fees', screen: AdminFeesScreen()),
      ]) {
    testWidgets('${c.name} offers sign out', (WidgetTester tester) async {
      await pump(tester, c.screen);
      expect(
        find.byIcon(Icons.logout_rounded),
        findsOneWidget,
        reason: '${c.name} has no way to sign out',
      );
    });
  }

  /* ---- subscription notices on the admin dashboard ---- */

  AdminDashboard dashWith(SubscriptionStatus? sub) => AdminDashboard(
    schoolName: 'Sunrise Public School',
    academicYear: '2026-27',
    totalStudents: 280,
    totalTeachers: 8,
    teachersOnLeave: 0,
    totalClasses: 5,
    totalSections: 10,
    feesBilled: 100,
    feesCollected: 50,
    feesOverdue: 50,
    unpaidInvoices: 3,
    subscription: sub,
  );

  testWidgets('warns the admin inside the 7-day window', (WidgetTester tester) async {
    AdminStore.instance.dashboard = Loadable<AdminDashboard>.data(
      dashWith(
        const SubscriptionStatus(
          status: 'trial', isTrial: true, studentCount: 280, atStudentCap: false,
          isLapsed: false, isExpiringSoon: true, planName: 'Basic',
          daysRemaining: 5, maxStudents: 300, seatsRemaining: 20,
        ),
      ),
    );
    addTearDown(AdminStore.instance.reset);
    await pump(tester, const AdminHomeScreen());
    expect(find.text('Trial ends in 5 days.'), findsOneWidget);
  });

  testWidgets('blocks-admissions notice once the seat cap is reached', (
    WidgetTester tester,
  ) async {
    AdminStore.instance.dashboard = Loadable<AdminDashboard>.data(
      dashWith(
        const SubscriptionStatus(
          status: 'active', isTrial: false, studentCount: 356, atStudentCap: true,
          isLapsed: false, isExpiringSoon: false, planName: 'Basic',
          daysRemaining: 200, maxStudents: 300, seatsRemaining: 0,
        ),
      ),
    );
    addTearDown(AdminStore.instance.reset);
    await pump(tester, const AdminHomeScreen());
    expect(find.text('Student limit reached.'), findsOneWidget);
  });

  testWidgets('says nothing when the plan is healthy', (WidgetTester tester) async {
    AdminStore.instance.dashboard = Loadable<AdminDashboard>.data(
      dashWith(
        const SubscriptionStatus(
          status: 'active', isTrial: false, studentCount: 16, atStudentCap: false,
          isLapsed: false, isExpiringSoon: false, planName: 'Basic',
          daysRemaining: 200, maxStudents: 300, seatsRemaining: 284,
        ),
      ),
    );
    addTearDown(AdminStore.instance.reset);
    await pump(tester, const AdminHomeScreen());
    // A banner that is always there stops being read.
    expect(find.textContaining('ends in'), findsNothing);
    expect(find.text('Student limit reached.'), findsNothing);
  });

  testWidgets('a school with no plan row shows no notice at all', (
    WidgetTester tester,
  ) async {
    AdminStore.instance.dashboard = Loadable<AdminDashboard>.data(dashWith(null));
    addTearDown(AdminStore.instance.reset);
    await pump(tester, const AdminHomeScreen());
    expect(find.text('Students'), findsOneWidget);
  });
}
