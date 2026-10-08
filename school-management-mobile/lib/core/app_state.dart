import 'package:flutter/material.dart';

/// App-wide, in-memory state: the theme choice and the notification
/// preferences. Everything the user actually looks at comes from the API via
/// [StudentStore]; this holds only the handful of settings that have no
/// server-side home yet.
class AppState extends ChangeNotifier {
  AppState._();

  static final AppState instance = AppState._();

  // ----------------------------------------------------------------- theme
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void setDarkMode(bool value) {
    _themeMode = value ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  // ------------------------------------------------------------ preferences
  final Map<String, bool> _preferences = <String, bool>{
    'email': true,
    'push': true,
    'sms': false,
    'assignments': true,
    'results': true,
    'fees': true,
    'events': true,
    'announcements': true,
    'biometric': false,
  };

  bool preference(String key) => _preferences[key] ?? false;

  void setPreference(String key, bool value) {
    _preferences[key] = value;
    notifyListeners();
  }

  String language = 'English (US)';

  void setLanguage(String value) {
    language = value;
    notifyListeners();
  }
}

/// Rebuilds [builder] whenever [AppState.instance] changes.
class AppStateBuilder extends StatelessWidget {
  const AppStateBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, AppState state) builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (BuildContext context, _) => builder(context, AppState.instance),
    );
  }
}
