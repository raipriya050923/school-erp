import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:school_management_mobile/core/theme/app_theme.dart';
import 'package:school_management_mobile/features/staff/platform_school_form_screen.dart';
import 'package:school_management_mobile/features/staff/super_admin_screens.dart';

/// Drives the Schools screen the way a person would, rather than asserting the
/// source contains the right words. A regression here is silent: the screen
/// still renders, it just stops being a way in to anything.
void main() {
  testWidgets('the add control opens the onboarding form', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const PlatformSchoolsScreen()),
    );
    await tester.pumpAndSettle();

    final Finder add = find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(Icons.add),
    );
    expect(add, findsOneWidget, reason: 'the app bar should carry the add-school button');

    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(
      find.byType(PlatformSchoolFormScreen),
      findsOneWidget,
      reason: 'tapping add should push the onboarding form',
    );
    expect(find.text('New school'), findsOneWidget);
  });
}
