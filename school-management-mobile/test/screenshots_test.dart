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
