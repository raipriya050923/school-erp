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
    TeacherStore.instance.dashboard = Loadable<TeacherDashboard>.data(
      TeacherDashboard(
        profile: const TeacherProfile(
          name: 'Rajesh Koirala',
          employeeCode: 'EMP-008',
          subject: 'Science',
        ),
        myClassesCount: 4,
        studentsTaught: 542,
        submissionsToGrade: 66,
        openHomework: 1,
        recentHomework: <TeacherHomework>[
          TeacherHomework(
            id: 7,
            title: 'Photosynthesis worksheet',
            subject: 'Science',
            classLabel: 'Grade 6 - A',
            dueDate: DateTime(2026, 11, 14),
            submitted: 18,
            total: 30,
            status: 'open',
          ),
        ],
      ),
    );
    addTearDown(TeacherStore.instance.reset);

    await pump(tester, const TeacherHomeScreen());

    expect(find.text('My classes'), findsOneWidget);
    expect(find.text('542'), findsOneWidget);
  });

  testWidgets('teacher dashboard lists the homework needing attention', (
    WidgetTester tester,
  ) async {
    // The counters say how much is waiting; this list says which assignments.
    // The API has always sent them - the mobile model used to drop the field,
    // so the section rendered nowhere and the suite never noticed.
    TeacherStore.instance.dashboard = Loadable<TeacherDashboard>.data(
      TeacherDashboard(
        profile: const TeacherProfile(
          name: 'Sunita Gurung',
          employeeCode: 'EMP-008',
          subject: 'English',
        ),
        myClassesCount: 2,
        studentsTaught: 64,
        submissionsToGrade: 12,
        openHomework: 2,
        recentHomework: <TeacherHomework>[
          TeacherHomework(
            id: 1,
            title: 'Essay on monsoon',
            subject: 'English',
            classLabel: 'Grade 6 - A',
            dueDate: DateTime(2026, 11, 14),
            submitted: 18,
            total: 30,
            status: 'open',
          ),
          TeacherHomework(
            id: 2,
            title: 'Poem recital notes',
            subject: 'English',
            classLabel: 'Grade 7 - B',
            dueDate: DateTime(2026, 11, 2),
            submitted: 29,
            total: 29,
            status: 'grading',
          ),
        ],
      ),
    );
    addTearDown(TeacherStore.instance.reset);

    await pump(tester, const TeacherHomeScreen());

    expect(find.text('Homework needing attention'), findsOneWidget);
    expect(find.text('Essay on monsoon'), findsOneWidget);
    expect(find.text('Poem recital notes'), findsOneWidget);
    // Handed in out of set, as the web table's Submitted column shows it.
    expect(find.text('18/30'), findsOneWidget);
    expect(find.text('29/29'), findsOneWidget);
    // Class, subject and due date on one line.
    expect(find.textContaining('Grade 6 - A'), findsOneWidget);
    expect(find.textContaining('Due 14 Nov'), findsOneWidget);
  });

  testWidgets('teacher dashboard says so when there is no homework', (
    WidgetTester tester,
  ) async {
    TeacherStore.instance.dashboard = const Loadable<TeacherDashboard>.data(
      TeacherDashboard(
        profile: TeacherProfile(name: 'Kamala Tamang'),
        myClassesCount: 1,
        studentsTaught: 30,
        submissionsToGrade: 0,
        openHomework: 0,
        recentHomework: <TeacherHomework>[],
      ),
    );
    addTearDown(TeacherStore.instance.reset);

    await pump(tester, const TeacherHomeScreen());

    expect(find.text('No homework yet'), findsOneWidget);
  });

  testWidgets('admin dashboard shows its figures once loaded', (
    WidgetTester tester,
  ) async {
    AdminStore.instance.dashboard = Loadable<AdminDashboard>.data(
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
        feesDue: 16015500,
        unpaidInvoices: 1247,
        attendanceToday: 91.5,
        attendanceTrend: <AttendancePoint>[
          AttendancePoint(
            date: DateTime(2026, 6, 1),
            percent: 94,
            present: 1170,
            total: 1245,
          ),
          AttendancePoint(
            date: DateTime(2026, 6, 2),
            percent: 61,
            present: 760,
            total: 1245,
          ),
        ],
        recentAdmissions: <RecentAdmission>[
          RecentAdmission(
            name: 'Sunil Rai',
            className: 'Grade 6',
            sectionName: 'A',
            admissionDate: DateTime(2026, 10, 25),
          ),
        ],
        latestNotices: <SchoolNotice>[
          SchoolNotice(
            id: 1,
            title: 'Parent-teacher meeting',
            body: 'Saturday at 10am in the main hall.',
            audience: 'parents',
            publishDate: DateTime(2026, 10, 20),
            createdBy: 11,
          ),
        ],
      ),
    );
    addTearDown(AdminStore.instance.reset);

    await pump(tester, const AdminHomeScreen());

    expect(find.text('Students'), findsOneWidget);
    expect(find.text('1248'), findsOneWidget);
    // The sections the web dashboard has and mobile used to drop.
    expect(find.text('Attendance overview'), findsOneWidget);
    expect(find.text('Recent admissions'), findsOneWidget);
    expect(find.text('Sunil Rai'), findsOneWidget);
    expect(find.text('Latest notices'), findsOneWidget);
    expect(find.text('Parent-teacher meeting'), findsOneWidget);
    expect(find.text('Fees collection'), findsOneWidget);
    // Twice now, and deliberately: the Fees tile and the split-bar legend.
    expect(find.text('Collected'), findsNWidgets(2));
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
    // The row labels the count rather than showing a bare integer beside a
    // column of money.
    expect(find.text('16 students'), findsOneWidget);
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

  testWidgets('the fees split bar actually has height', (
    WidgetTester tester,
  ) async {
    // A ColoredBox has no height of its own, so a Row that centres its children
    // gives each segment zero height: correct colours, correct widths, and
    // nothing on screen. Only a size assertion catches that - the widgets are
    // all present and findable either way.
    AdminStore.instance.dashboard = Loadable<AdminDashboard>.data(
      AdminDashboard(
        schoolName: 'Sunrise Public School',
        academicYear: '2026-27',
        totalStudents: 1249,
        totalTeachers: 12,
        teachersOnLeave: 1,
        totalClasses: 5,
        totalSections: 10,
        feesBilled: 34341000,
        feesCollected: 140000,
        feesOverdue: 16015500,
        feesDue: 34201000,
        unpaidInvoices: 2716,
        attendanceToday: null,
        attendanceTrend: const <AttendancePoint>[],
        recentAdmissions: const <RecentAdmission>[],
        latestNotices: const <SchoolNotice>[],
      ),
    );
    addTearDown(AdminStore.instance.reset);

    await pump(tester, const AdminHomeScreen());

    final List<Size> segments = find
        .byType(ColoredBox)
        .evaluate()
        .map((Element e) => e.size!)
        .where((Size s) => s.width < 380) // excludes the page background
        .toList();

    expect(segments, hasLength(3), reason: 'collected, pending and overdue');
    for (final Size s in segments) {
      expect(s.height, greaterThan(0), reason: 'a zero-height bar draws nothing');
      expect(s.width, greaterThan(0));
    }
  });

  testWidgets('the attendance columns actually have size', (
    WidgetTester tester,
  ) async {
    // The same trap as the fees bar, from the other direction: the column's
    // child has no width of its own, so without a widthFactor every bar is
    // zero-wide and the chart is an empty box with date labels under it.
    AdminStore.instance.dashboard = Loadable<AdminDashboard>.data(
      AdminDashboard(
        schoolName: 'Sunrise Public School',
        academicYear: '2026-27',
        totalStudents: 1249,
        totalTeachers: 12,
        teachersOnLeave: 1,
        totalClasses: 5,
        totalSections: 10,
        feesBilled: 100,
        feesCollected: 50,
        feesOverdue: 25,
        feesDue: 50,
        unpaidInvoices: 1,
        attendanceToday: 91.5,
        attendanceTrend: <AttendancePoint>[
          AttendancePoint(
            date: DateTime(2026, 6, 1),
            percent: 94,
            present: 1170,
            total: 1245,
          ),
          AttendancePoint(
            date: DateTime(2026, 6, 2),
            percent: 12,
            present: 150,
            total: 1245,
          ),
          // A day marked with nobody present: still a visible stub, so it reads
          // as a terrible day rather than as a day nobody marked.
          AttendancePoint(
            date: DateTime(2026, 6, 3),
            percent: 0,
            present: 0,
            total: 1245,
          ),
        ],
        recentAdmissions: const <RecentAdmission>[],
        latestNotices: const <SchoolNotice>[],
      ),
    );
    addTearDown(AdminStore.instance.reset);

    await pump(tester, const AdminHomeScreen());

    final List<Size> bars = find
        .byType(FractionallySizedBox)
        .evaluate()
        .map((Element e) => e.size!)
        .toList();

    expect(bars, hasLength(3));
    for (final Size s in bars) {
      expect(s.width, greaterThan(0), reason: 'a zero-width column draws nothing');
      expect(s.height, greaterThan(0));
    }
    // Taller day is taller on screen, and the 0% day still shows something.
    expect(bars[0].height, greaterThan(bars[1].height));
    expect(bars[2].height, greaterThan(0));
  });

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
    feesDue: 50,
    unpaidInvoices: 3,
    attendanceToday: null,
    attendanceTrend: const <AttendancePoint>[],
    recentAdmissions: const <RecentAdmission>[],
    latestNotices: const <SchoolNotice>[],
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
