import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The signed-in user, as returned by `POST /api/auth/login`.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.schoolId,
    required this.role,
    required this.username,
    required this.fullName,
    required this.email,
    required this.title,
    required this.token,
    required this.expiresAtUtc,
  });

  final int id;
  final int? schoolId;
  final String role;
  final String username;
  final String fullName;
  final String? email;
  final String title;
  final String token;
  final DateTime expiresAtUtc;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAtUtc);

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as int,
    schoolId: json['schoolId'] as int?,
    role: json['role'] as String? ?? '',
    username: json['username'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String?,
    title: json['title'] as String? ?? '',
    token: json['token'] as String? ?? '',
    // The API sends UTC; parsing without this can yield a local-time DateTime
    // and make a valid token look expired.
    expiresAtUtc: DateTime.parse(json['expiresAtUtc'] as String).toUtc(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'schoolId': schoolId,
    'role': role,
    'username': username,
    'fullName': fullName,
    'email': email,
    'title': title,
    'token': token,
    'expiresAtUtc': expiresAtUtc.toIso8601String(),
  };
}

/// Holds the current session and, when the user asked to be remembered,
/// persists it so the app reopens signed in.
class Session {
  Session._();

  static final Session instance = Session._();

  static const String _key = 'auth_user';

  AuthUser? _user;
  AuthUser? get user => _user;

  /// Usable only while the token is still valid.
  bool get isSignedIn => _user != null && !_user!.isExpired;

  String? get token => isSignedIn ? _user!.token : null;

  /// Signs the user in for this session, persisting only if they asked.
  ///
  /// Storage problems never block sign-in: the session still works in memory,
  /// the user just has to sign in again next launch.
  Future<void> save(AuthUser user, {required bool remember}) async {
    _user = user;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (remember) {
        await prefs.setString(_key, jsonEncode(user.toJson()));
      } else {
        await prefs.remove(_key);
      }
    } catch (_) {
      // Storage unavailable — keep the in-memory session.
    }
  }

  /// Reloads a remembered session at startup. Expired sessions are discarded.
  Future<void> restore() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_key);
      if (raw == null) return;
      try {
        final AuthUser user = AuthUser.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (user.isExpired) {
          await prefs.remove(_key);
          return;
        }
        _user = user;
      } catch (_) {
        // Corrupt or from an older build — drop it rather than crash on launch.
        await prefs.remove(_key);
      }
    } catch (_) {
      // Storage unavailable — start signed out.
    }
  }

  Future<void> clear() async {
    _user = null;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // Nothing persisted, or storage unavailable.
    }
  }
}
