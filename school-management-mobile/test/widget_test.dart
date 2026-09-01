import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:school_management_mobile/core/student_store.dart';
import 'package:school_management_mobile/features/auth/login_screen.dart';
import 'package:school_management_mobile/features/shell/app_shell.dart';
import 'package:school_management_mobile/main.dart';

void main() {
  testWidgets('login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const SchoolPortalApp());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Username or email'), findsOneWidget);
  });

  testWidgets('empty credentials are rejected without leaving the screen', (
    WidgetTester tester,
  ) async {
    // Sign-in now calls the API, so an empty form must fail locally and never
    // reach the portal — the old build let any input straight through.
    await tester.pumpWidget(const SchoolPortalApp());

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your username or email'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  // The portal screens now read from the API. With no server reachable in a
  // test run they must surface a retryable error rather than blank or crash —
  // that is the contract these two cover.

  testWidgets('dashboard reports a failed load instead of blanking', (
    WidgetTester tester,
  ) async {
    StudentStore.instance.reset();
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsWidgets);
  });

  testWidgets('bottom navigation switches to the timetable tab', (
    WidgetTester tester,
  ) async {
    StudentStore.instance.reset();
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Timetable'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Timetable'), findsOneWidget);
  });
}
