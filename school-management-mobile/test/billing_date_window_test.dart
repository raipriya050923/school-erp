import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:school_management_mobile/core/theme/app_theme.dart';
import 'package:school_management_mobile/features/staff/platform_billing_screen.dart';

/// The date window's rules are the web console's, and they are easy to get
/// subtly wrong: inclusive at both ends, compared by calendar day, and an
/// un-issued invoice drops out once a window is set.
void main() {
  testWidgets('the issued-date control is offered and starts unfiltered',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const PlatformBillingScreen()),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Issued: any date'),
      findsOneWidget,
      reason: 'the window starts open, and says so',
    );
    expect(tester.takeException(), isNull);
  });
}
