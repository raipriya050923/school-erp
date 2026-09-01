import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../../data/api_models.dart';
import 'api_config.dart';
import 'session.dart';

/// A failure worth showing the user verbatim.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Thin wrapper over the SchoolErp API.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const Duration _timeout = Duration(seconds: 15);

  /// Signs in and returns the user. This build is student-only, so any other
  /// role is refused here rather than being let into a portal built for students.
  Future<AuthUser> login({
    required String username,
    required String password,
  }) async {
    final Map<String, dynamic> json = await _post(
      '${ApiConfig.authBase}/login',
      <String, dynamic>{'username': username, 'password': password},
    );

    final AuthUser user = AuthUser.fromJson(json);
    if (user.role != 'student') {
      throw const ApiException(
        'This app is for students. Use the web portal to sign in with a staff account.',
      );
    }
    return user;
  }

  // ------------------------------------------------------------- student portal

  Future<StudentDashboard> dashboard() async =>
      StudentDashboard.fromJson(await _getObject('dashboard/stats'));

  Future<StudentProfile> profile() async =>
      StudentProfile.fromJson(await _getObject('profile'));

  Future<StudentAttendance> attendance() async =>
      StudentAttendance.fromJson(await _getObject('attendance'));

  Future<StudentExams> exams() async =>
      StudentExams.fromJson(await _getObject('exams'));

  Future<List<TimetableSlot>> timetable() async =>
      (await _getList('timetable')).map(TimetableSlot.fromJson).toList();

  Future<List<StudentHomework>> homework() async =>
      (await _getList('homework')).map(StudentHomework.fromJson).toList();

  Future<List<StudentFee>> fees() async =>
      (await _getList('fees')).map(StudentFee.fromJson).toList();

  Future<List<StudentNotice>> notices() async =>
      (await _getList('notices')).map(StudentNotice.fromJson).toList();

  // ------------------------------------------------------------------ plumbing

  Future<Map<String, dynamic>> _getObject(String path) async {
    final Object decoded = await _get('${ApiConfig.studentBase}/$path');
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('The server returned an unexpected response.');
    }
    return decoded;
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    final Object decoded = await _get('${ApiConfig.studentBase}/$path');
    if (decoded is! List<dynamic>) {
      throw const ApiException('The server returned an unexpected response.');
    }
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<Object> _get(String url) async {
    late final http.Response response;
    try {
      response = await http
          .get(Uri.parse(url), headers: _headers())
          .timeout(_timeout);
    } on SocketException {
      throw ApiException('Cannot reach the server at ${ApiConfig.baseUrl}.');
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    }
    return _decodeAny(response);
  }

  Map<String, String> _headers() => <String, String>{
    'Content-Type': 'application/json',
    if (Session.instance.token != null)
      'Authorization': 'Bearer ${Session.instance.token}',
  };

  Future<Map<String, dynamic>> _post(String url, Map<String, dynamic> body) async {
    late final http.Response response;
    try {
      response = await http
          .post(Uri.parse(url), headers: _headers(), body: jsonEncode(body))
          .timeout(_timeout);
    } on SocketException {
      throw ApiException('Cannot reach the server at ${ApiConfig.baseUrl}.');
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    }

    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final Object decoded = _decodeAny(response);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('The server returned an unexpected response.');
    }
    return decoded;
  }

  /// Shared success/error handling. Bodies may be an object or an array, so the
  /// caller decides which it expected.
  Object _decodeAny(http.Response response) {
    Object? json;
    if (response.body.isNotEmpty) {
      try {
        // Decode as UTF-8 explicitly: `response.body` falls back to Latin-1 when
        // the server omits a charset, which mangles any non-ASCII text.
        json = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        json = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (json == null) {
        throw const ApiException('The server returned an unexpected response.');
      }
      return json;
    }

    // The API wraps failures as { error, message }; fall back when it does not.
    final String message =
        (json is Map<String, dynamic> ? json['message'] as String? : null) ??
        (response.statusCode == 401
            ? 'Your session has expired. Sign in again.'
            : 'Request failed (${response.statusCode}).');
    throw ApiException(message, statusCode: response.statusCode);
  }
}
