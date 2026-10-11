import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_mobile/core/theme/app_theme.dart';
import 'package:school_management_mobile/features/staff/platform_billing_screen.dart';

void main() {
  testWidgets('shot', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(), home: const PlatformBillingScreen(),
      debugShowCheckedModeBanner: false));
    await tester.pumpAndSettle();
    tester.takeException();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('billing.png'));
  });
}
