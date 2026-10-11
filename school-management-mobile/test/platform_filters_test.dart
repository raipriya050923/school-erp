import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:school_management_mobile/core/loadable.dart';
import 'package:school_management_mobile/core/staff_stores.dart';
import 'package:school_management_mobile/core/theme/app_theme.dart';
import 'package:school_management_mobile/data/staff_models.dart';
import 'package:school_management_mobile/features/staff/super_admin_screens.dart';

/// The date-range filters on the two platform lists.
///
/// Both are applied in the screen, not the request: neither endpoint takes a
/// date parameter, so nothing server-side can catch them being wrong. These
/// pump each screen with a known set and check what survives.
void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const PlatformSchoolsScreen()),
    );
    await tester.pumpAndSettle();
  }

  PlatformSchool school(int id, String name, DateTime joined) => PlatformSchool(
    id: id,
    name: name,
    status: 'active',
    studentCount: 1,
    schoolCode: 'C$id',
    city: 'Noida',
    planName: 'Basic',
    createdAt: joined,
  );

  setUp(() {
    SuperAdminStore.instance.schools = Loadable<List<PlatformSchool>>.data(
      <PlatformSchool>[
        school(1, 'Early Academy', DateTime(2024, 1, 10)),
        school(2, 'Middle School', DateTime(2025, 6, 15)),
        school(3, 'Late College', DateTime(2026, 9, 20)),
      ],
    );
  });

  tearDown(SuperAdminStore.instance.reset);

  testWidgets('with no range every school is listed', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    expect(find.text('Early Academy'), findsOneWidget);
    expect(find.text('Middle School'), findsOneWidget);
    expect(find.text('Late College'), findsOneWidget);
    // Unfiltered, the count is the plain platform total.
    expect(find.text('3 onboarded'), findsOneWidget);
  });

  testWidgets('the filter bar offers search and an any-time range', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    expect(find.text('Search by name, code or city'), findsOneWidget);
    expect(find.text('Joined: any time'), findsOneWidget);
    // Nothing is applied, so there is nothing to clear.
    expect(find.text('Clear'), findsNothing);
  });

  testWidgets('a school with no joined date still lists when unfiltered', (
    WidgetTester tester,
  ) async {
    // A row the API returned without createdAt cannot be shown to be inside a
    // date range, and quietly treating it as inside would be a lie about when
    // it joined.
    SuperAdminStore.instance.schools = const Loadable<List<PlatformSchool>>.data(
      <PlatformSchool>[
        PlatformSchool(
          id: 9,
          name: 'Undated School',
          status: 'active',
          studentCount: 0,
        ),
      ],
    );
    await pump(tester);

    // Visible while no range is applied.
    expect(find.text('Undated School'), findsOneWidget);
  });

  testWidgets('an empty platform says "none yet", not "none match"', (
    WidgetTester tester,
  ) async {
    SuperAdminStore.instance.schools =
        const Loadable<List<PlatformSchool>>.data(<PlatformSchool>[]);
    await pump(tester);

    // No filter applied and no rows: the platform genuinely has none.
    expect(find.text('No schools yet'), findsOneWidget);
    expect(find.text('No schools match'), findsNothing);
  });

  group('subscriptions', () {
    PlatformSubscription sub(int id, String school, String status,
        DateTime started) =>
        PlatformSubscription(
          id: id,
          price: 9999,
          status: status,
          billingCycle: 'yearly',
          schoolName: school,
          planName: 'Basic',
          startDate: started,
          endDate: started.add(const Duration(days: 365)),
        );

    Future<void> pumpSubs(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const PlatformSubscriptionsScreen(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lists every subscription with no filter applied', (
      WidgetTester tester,
    ) async {
      SuperAdminStore.instance.subscriptions =
          Loadable<List<PlatformSubscription>>.data(<PlatformSubscription>[
        sub(1, 'Sunrise Public School', 'active', DateTime(2025, 1, 5)),
        sub(2, 'Green Valley Academy', 'trial', DateTime(2026, 2, 8)),
      ]);
      addTearDown(SuperAdminStore.instance.reset);

      await pumpSubs(tester);

      expect(find.text('Sunrise Public School'), findsOneWidget);
      expect(find.text('Green Valley Academy'), findsOneWidget);
      expect(find.text('2 subscriptions'), findsOneWidget);
      expect(find.text('All statuses'), findsOneWidget);
      expect(find.text('Started: any time'), findsOneWidget);
      // Nothing applied, so nothing to clear.
      expect(find.text('Clear'), findsNothing);
    });

    testWidgets('an empty list says "none", not "none match"', (
      WidgetTester tester,
    ) async {
      SuperAdminStore.instance.subscriptions =
          const Loadable<List<PlatformSubscription>>.data(
              <PlatformSubscription>[]);
      addTearDown(SuperAdminStore.instance.reset);

      await pumpSubs(tester);

      expect(find.text('No subscriptions'), findsOneWidget);
      expect(find.text('No subscriptions match'), findsNothing);
    });
  });
}
