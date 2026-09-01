import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Where the SchoolErp API lives.
///
/// Override at build time when pointing at a real server:
///   flutter run --dart-define=API_BASE_URL=https://api.example.com/api
class ApiConfig {
  const ApiConfig._();

  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Base URL ending in `/api`.
  ///
  /// The default is the local dev API. An Android emulator cannot see the host
  /// machine's `localhost` — 10.0.2.2 is the loopback alias it provides instead —
  /// so the host differs per platform unless overridden.
  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:5204/api';
    return 'http://localhost:5204/api';
  }

  static String get authBase => '$baseUrl/auth';
  static String get studentBase => '$baseUrl/student';
}
