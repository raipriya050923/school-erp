import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_mobile/core/theme/app_colors.dart';
import 'package:school_management_mobile/core/theme/app_theme.dart';

/// Checks the colour actually resolved onto the chrome, not the source text.
void main() {
  for (final (String name, ThemeData theme, Color want) in <(String, ThemeData, Color)>[
    ('light', AppTheme.light(), AppColors.primary600),
    ('dark', AppTheme.dark(), AppColors.primary800),
  ]) {
    testWidgets('$name: app bar and bottom nav are brand blue', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          appBar: AppBar(title: const Text('Platform')),
          bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            destinations: const <Widget>[
              NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.list), label: 'Schools'),
            ],
          ),
        ),
      ));

      final AppBar bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(Theme.of(tester.element(find.byType(AppBar))).appBarTheme.backgroundColor, want,
          reason: 'app bar background');
      expect(bar.preferredSize.height, greaterThan(0));

      final Material navMaterial = tester.widget<Material>(
        find.descendant(of: find.byType(NavigationBar), matching: find.byType(Material)).first,
      );
      expect(navMaterial.color, want, reason: 'bottom nav background');

      // Status bar + gesture bar glyphs must be light on a blue bar, in BOTH themes.
      final SystemUiOverlayStyle overlay = theme.appBarTheme.systemOverlayStyle!;
      expect(overlay.statusBarIconBrightness, Brightness.light);
      expect(overlay.systemNavigationBarColor, want, reason: 'gesture bar fill');
      expect(overlay.systemNavigationBarIconBrightness, Brightness.light);

      // Labels/icons must not still be resolving to the blue primary.
      final Color? selected = theme.navigationBarTheme.iconTheme
          ?.resolve(<WidgetState>{WidgetState.selected})?.color;
      final Color? idle = theme.navigationBarTheme.iconTheme
          ?.resolve(<WidgetState>{})?.color;
      expect(selected, Colors.white);
      expect(idle!.a, lessThan(1.0), reason: 'idle icons are muted white');
      expect(idle.r, 1.0);
    });
  }
}
