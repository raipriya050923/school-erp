@Tags(<String>['screenshots'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:school_management_mobile/core/app_state.dart';
import 'package:school_management_mobile/core/theme/app_theme.dart';
import 'package:school_management_mobile/features/attendance/attendance_screen.dart';
import 'package:school_management_mobile/features/auth/login_screen.dart';
import 'package:school_management_mobile/features/fees/fees_screen.dart';
import 'package:school_management_mobile/features/notifications/notifications_screen.dart';
import 'package:school_management_mobile/features/results/results_screen.dart';
import 'package:school_management_mobile/features/settings/settings_screen.dart';
import 'package:school_management_mobile/features/shell/app_shell.dart';
import 'package:school_management_mobile/core/loadable.dart';
import 'package:school_management_mobile/core/staff_stores.dart';
import 'package:school_management_mobile/data/staff_models.dart';
import 'package:school_management_mobile/features/staff/teacher_screens.dart';
import 'package:school_management_mobile/features/staff/admin_screens.dart';
import 'package:school_management_mobile/features/staff/admin_transport_screen.dart';
import 'package:school_management_mobile/features/staff/teacher_roster_screen.dart';

/// Renders every screen at 390x844 logical pixels (@2x) and writes a PNG to
/// `screenshots/`. Skipped in the normal suite because it compares rendered
/// pixels; regenerate with:
///
///     flutter test --run-skipped --tags screenshots --update-goldens
///
/// Real fonts are loaded first (the default test font draws boxes instead of
/// glyphs) and shadows are re-enabled, so the output matches a device.
void main() {
  setUpAll(() async {
    await _loadBundledFonts();
    await _loadSystemFontAs('Roboto');
  });

  const Size logical = Size(390, 844);

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget screen, {
    bool dark = false,
    double scrollBy = 0,
  }) async {
    tester.view.physicalSize = logical * 2;
    tester.view.devicePixelRatio = 2.0;
    tester.view.padding = const FakeViewPadding(top: 94, bottom: 68);
    addTearDown(tester.view.reset);

    // Tests normally paint shadows as hard rectangles; a screenshot should show
    // the real blur. The framework asserts this is restored before the test
    // ends, so it is reset as soon as the frame has been painted.
    debugDisableShadows = false;
    AppState.instance.setDarkMode(dark);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _screenshotTheme(dark),
        home: screen,
      ),
    );
    await tester.pumpAndSettle();

    if (scrollBy != 0) {
      await tester.drag(
        find.byType(Scrollable).first,
        Offset(0, -scrollBy),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
    }

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../screenshots/$name.png'),
    );
    debugDisableShadows = true;
  }

  // ------------------------------------------------------------ light theme

  testWidgets('00 teacher dashboard', (WidgetTester t) async {
    // Seeded rather than fetched: the point of the shot is the layout once the
    // data has arrived, which a live login would only make harder to reproduce.
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
          TeacherHomework(
            id: 3,
            title: 'Grammar exercise 4',
            subject: 'English',
            classLabel: 'Grade 6 - A',
            dueDate: DateTime(2026, 10, 28),
            submitted: 30,
            total: 30,
            status: 'graded',
          ),
        ],
      ),
    );
    addTearDown(TeacherStore.instance.reset);
    await shoot(t, '00-teacher-dashboard', const TeacherHomeScreen());
  });

  testWidgets('00 admin dashboard', (WidgetTester t) async {
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
        attendanceTrend: <AttendancePoint>[
          for (int i = 0; i < 30; i++)
            AttendancePoint(
              date: DateTime(2026, 6, 1).add(Duration(days: i)),
              // Four sharp dips, as the web chart shows.
              percent: i % 7 == 3 ? 12 : (i % 5 == 0 ? 88 : 97),
              present: 1200,
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
          RecentAdmission(
            name: 'Ojaswi Bhattarai',
            className: 'Grade 6',
            sectionName: 'A',
            admissionDate: DateTime(2025, 4, 8),
          ),
          RecentAdmission(
            name: 'Sagar Basnet',
            className: 'Grade 6',
            sectionName: 'B',
            admissionDate: DateTime(2025, 4, 8),
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
    await shoot(t, '00-admin-dashboard', const AdminHomeScreen(), scrollBy: 300);
    await shoot(t, '00-admin-dashboard-lower', const AdminHomeScreen(), scrollBy: 1150);
  });

  testWidgets('00 transport bands', (WidgetTester t) async {
    // Three bands as a school would set them, plus the riders each one has
    // priced, which is what makes a band more than an abstraction.
    await shoot(
      t,
      '00-transport-bands',
      TransportBandsScreen(
        slabs: <TransportSlab>[
          const TransportSlab(
              id: 1, fromKm: 0, upToKm: 3, amount: 800, riders: 42),
          const TransportSlab(
              id: 2, fromKm: 3, upToKm: 6, amount: 1200, riders: 31),
          const TransportSlab(
              id: 3, fromKm: 6, upToKm: 10, amount: 1600, riders: 12),
        ],
      ),
    );
  });

  testWidgets('00 transport student', (WidgetTester t) async {
    // A rider already priced by a band: every field the web's row carries is
    // on screen, with the band that produced the amount named underneath.
    await shoot(
      t,
      '00-transport-student',
      const Scaffold(
        body: TransportStudentSheet(
          student: TransportStudent(
            studentId: 1,
            name: 'Anisha Rai',
            admissionNo: 'ADM-2079-201',
            className: 'Grade 10',
            sectionName: 'A',
            usesTransport: true,
            distanceKm: 4.5,
            pickupPoint: 'Balkhu bridge',
            amountOverride: null,
            note: null,
            amount: 1200,
            status: 'priced',
            matchedSlabKm: 6,
          ),
        ),
      ),
    );
  });

  testWidgets('00 teacher roster', (WidgetTester t) async {
    await shoot(t, '00-teacher-roster',
        const TeacherRosterScreen(
          className: 'Grade 6',
          sectionName: 'A',
          subject: 'English',
        ));
  });

  testWidgets('01 login', (WidgetTester t) async {
    await shoot(t, '01-login', const LoginScreen());
  });

  testWidgets('02 dashboard', (WidgetTester t) async {
    await shoot(t, '02-dashboard', const AppShell());
  });

  testWidgets('03 dashboard scrolled', (WidgetTester t) async {
    await shoot(t, '03-dashboard-scrolled', const AppShell(), scrollBy: 520);
  });

  testWidgets('04 timetable', (WidgetTester t) async {
    await shoot(
      t,
      '04-timetable',
      const AppShell(initialTab: ShellTab.timetable),
    );
  });

  testWidgets('05 assignments', (WidgetTester t) async {
    await shoot(
      t,
      '05-assignments',
      const AppShell(initialTab: ShellTab.assignments),
    );
  });

  testWidgets('06 fees overview', (WidgetTester t) async {
    await shoot(t, '06-fees-overview', const AppShell(initialTab: ShellTab.fees));
  });

  testWidgets('07 fees history', (WidgetTester t) async {
    await _shootTab(t, shoot, '07-fees-history', 'History');
  });

  testWidgets('08 fees structure', (WidgetTester t) async {
    await _shootTab(t, shoot, '08-fees-structure', 'Structure');
  });

  testWidgets('09 profile', (WidgetTester t) async {
    await shoot(t, '09-profile', const AppShell(initialTab: ShellTab.profile));
  });

  testWidgets('10 attendance', (WidgetTester t) async {
    await shoot(t, '10-attendance', const AttendanceScreen());
  });

  testWidgets('11 attendance calendar', (WidgetTester t) async {
    await shoot(
      t,
      '11-attendance-calendar',
      const AttendanceScreen(),
      scrollBy: 330,
    );
  });

  testWidgets('12 results', (WidgetTester t) async {
    await shoot(t, '12-results', const ResultsScreen());
  });

  testWidgets('13 results trend', (WidgetTester t) async {
    await shoot(t, '13-results-trend', const ResultsScreen(), scrollBy: 560);
  });

  testWidgets('14 notifications', (WidgetTester t) async {
    await shoot(t, '14-notifications', const NotificationsScreen());
  });

  testWidgets('15 settings', (WidgetTester t) async {
    await shoot(t, '15-settings', const SettingsScreen());
  });

  // ------------------------------------------------------------- dark theme

  testWidgets('16 dashboard dark', (WidgetTester t) async {
    await shoot(t, '16-dashboard-dark', const AppShell(), dark: true);
  });

  testWidgets('17 timetable dark', (WidgetTester t) async {
    await shoot(
      t,
      '17-timetable-dark',
      const AppShell(initialTab: ShellTab.timetable),
      dark: true,
    );
  });

  testWidgets('18 results dark', (WidgetTester t) async {
    await shoot(t, '18-results-dark', const ResultsScreen(), dark: true);
  });

  testWidgets('19 assignments dark', (WidgetTester t) async {
    await shoot(
      t,
      '19-assignments-dark',
      const AppShell(initialTab: ShellTab.assignments),
      dark: true,
    );
  });

  testWidgets('20 profile dark', (WidgetTester t) async {
    await shoot(
      t,
      '20-profile-dark',
      const AppShell(initialTab: ShellTab.profile),
      dark: true,
    );
  });

  tearDownAll(() => AppState.instance.setDarkMode(false));
}

typedef _Shoot =
    Future<void> Function(
      WidgetTester tester,
      String name,
      Widget screen, {
      bool dark,
      double scrollBy,
    });

/// Opens the fees screen, switches to [tabLabel], then captures.
Future<void> _shootTab(
  WidgetTester tester,
  _Shoot shoot,
  String name,
  String tabLabel,
) async {
  tester.view.physicalSize = const Size(390, 844) * 2;
  tester.view.devicePixelRatio = 2.0;
  tester.view.padding = const FakeViewPadding(top: 94, bottom: 68);
  addTearDown(tester.view.reset);
  debugDisableShadows = false;

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _screenshotTheme(false),
      home: const FeesScreen(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(tabLabel));
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../screenshots/$name.png'),
  );
  debugDisableShadows = true;
}

// -------------------------------------------------------------------- theme

/// Widgets such as [AppBar] and the button family *replace* the ambient
/// [DefaultTextStyle] rather than merging into it. On a device those styles
/// fall through to the platform typeface; in the test environment they fall
/// through to the glyph-less test font. Pin them to the loaded family so the
/// captures show real text.
ThemeData _screenshotTheme(bool dark) {
  final ThemeData theme = dark ? AppTheme.dark() : AppTheme.light();
  const String family = 'Roboto';

  TextStyle withFamily(TextStyle? style) =>
      (style ?? const TextStyle()).copyWith(fontFamily: family);

  ButtonStyle? patch(ButtonStyle? style) => style?.copyWith(
    textStyle: WidgetStatePropertyAll<TextStyle>(
      withFamily(style.textStyle?.resolve(const <WidgetState>{})),
    ),
  );

  return theme.copyWith(
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: withFamily(theme.appBarTheme.titleTextStyle),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: patch(theme.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: patch(theme.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: patch(theme.textButtonTheme.style),
    ),
    chipTheme: theme.chipTheme.copyWith(
      labelStyle: withFamily(theme.chipTheme.labelStyle),
    ),
    // A ListTile's title and subtitle resolve through here, not through the
    // button or chip themes — without this a SwitchListTile's label renders as
    // the fallback boxes and looks like a missing string.
    listTileTheme: theme.listTileTheme.copyWith(
      titleTextStyle: withFamily(theme.listTileTheme.titleTextStyle ??
          theme.textTheme.bodyLarge),
      subtitleTextStyle: withFamily(theme.listTileTheme.subtitleTextStyle ??
          theme.textTheme.bodyMedium),
    ),
    tabBarTheme: theme.tabBarTheme.copyWith(
      labelStyle: withFamily(theme.tabBarTheme.labelStyle),
      unselectedLabelStyle: withFamily(theme.tabBarTheme.unselectedLabelStyle),
    ),
  );
}

// ---------------------------------------------------------------- font setup

/// Registers every font declared in the app's FontManifest (this is what makes
/// Material icons render instead of empty boxes).
Future<void> _loadBundledFonts() async {
  final String manifest = await rootBundle.loadString('FontManifest.json');
  final List<dynamic> entries = json.decode(manifest) as List<dynamic>;

  for (final dynamic entry in entries) {
    final Map<String, dynamic> font = entry as Map<String, dynamic>;
    final String family = font['family'] as String;
    final FontLoader loader = FontLoader(family);
    for (final dynamic asset in font['fonts'] as List<dynamic>) {
      loader.addFont(
        rootBundle.load((asset as Map<String, dynamic>)['asset'] as String),
      );
    }
    await loader.load();
  }
}

/// The Material text theme asks for "Roboto", which the test environment does
/// not ship. Bind a real system typeface to that family name so text renders
/// with actual glyphs.
Future<void> _loadSystemFontAs(String family) async {
  const List<String> candidates = <String>[
    r'C:\Windows\Fonts\segoeui.ttf',
    r'C:\Windows\Fonts\arial.ttf',
    r'C:\Windows\Fonts\calibri.ttf',
    '/System/Library/Fonts/Supplemental/Arial.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  ];

  for (final String path in candidates) {
    final File file = File(path);
    if (!file.existsSync()) continue;
    final Uint8List bytes = await file.readAsBytes();
    await (FontLoader(family)
          ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes))))
        .load();
    return;
  }
  throw StateError('No system font found to stand in for "$family".');
}
