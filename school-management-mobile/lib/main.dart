import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/api/session.dart';
import 'core/app_state.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/role_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  // A remembered, still-valid token skips the login screen on launch.
  await Session.instance.restore();
  runApp(const SchoolPortalApp());
}

class SchoolPortalApp extends StatelessWidget {
  const SchoolPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppStateBuilder(
      builder: (BuildContext context, AppState state) {
        return MaterialApp(
          title: 'पाठशाला',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: state.themeMode,
          // Rebuilt when the API reports that the password must be changed, so
          // an account reset while its holder is signed in sends them to the
          // set-password screen rather than failing every screen in place.
          home: ValueListenableBuilder<bool>(
            valueListenable: Session.instance.passwordChangeRequired,
            builder: (BuildContext context, bool mustChange, Widget? child) =>
                Session.instance.isSignedIn
                    ? const RoleShell()
                    : const LoginScreen(),
          ),
          builder: (BuildContext context, Widget? child) {
            // Keep the layout predictable regardless of the device font scale.
            final MediaQueryData media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: media.textScaler.clamp(
                  minScaleFactor: 0.9,
                  maxScaleFactor: 1.25,
                ),
              ),
              child: child!,
            );
          },
        );
      },
    );
  }
}
