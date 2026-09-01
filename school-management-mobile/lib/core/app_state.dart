import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/static_data.dart';

/// App-wide, in-memory state. Everything here is seeded from [SchoolData] and
/// lives only for the session — there is no persistence and no backend.
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

  // --------------------------------------------------------- notifications
  final List<AppNotification> _notifications = SchoolData.notifications();
  List<AppNotification> get notifications =>
      List<AppNotification>.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((AppNotification n) => !n.read).length;

  void markAsRead(int id) {
    final int index = _notifications.indexWhere((AppNotification n) => n.id == id);
    if (index == -1 || _notifications[index].read) return;
    _notifications[index] = _notifications[index].copyWith(read: true);
    notifyListeners();
  }

  void markAllAsRead() {
    if (unreadCount == 0) return;
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(read: true);
    }
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
