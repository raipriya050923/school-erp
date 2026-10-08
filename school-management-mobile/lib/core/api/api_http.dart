import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

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

/// Transport shared by every role's client.
///
/// One implementation of the timeout, the bearer header, the UTF-8 decode and
/// the error unwrapping, so the four portals cannot drift into reporting the
/// same failure four different ways.
abstract class ApiHttp {
  const ApiHttp();

  static const Duration timeout = Duration(seconds: 15);

  /// Path prefix under the API root, e.g. `student` or `admin/fees`.
  String get base;

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}/$base/$path');

  Map<String, String> headers() => <String, String>{
    'Content-Type': 'application/json',
    if (Session.instance.token != null)
      'Authorization': 'Bearer ${Session.instance.token}',
  };

  /// GET returning a JSON object.
  Future<Map<String, dynamic>> getObject(String path) async =>
      asObject(await getAny(path));

  /// GET returning a JSON array of objects.
  Future<List<Map<String, dynamic>>> getList(String path) async {
    final Object decoded = await getAny(path);
    if (decoded is! List<dynamic>) {
      throw const ApiException('The server returned an unexpected response.');
    }
    return decoded.cast<Map<String, dynamic>>();
  }

  /// [allowEmpty] for endpoints that answer 204 to mean "there is no such
  /// record" — an empty body is an answer there, not a broken response.
  Future<Object> getAny(String path, {bool allowEmpty = false}) async {
    late final http.Response response;
    try {
      response = await http.get(_uri(path), headers: headers()).timeout(timeout);
    } on SocketException {
      throw ApiException('Cannot reach the server at ${ApiConfig.baseUrl}.');
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    }
    return decodeAny(response, allowEmpty: allowEmpty);
  }

  /// POST whose response may be an object or nothing at all (204).
  Future<void> post(String path, Map<String, dynamic> body) async {
    late final http.Response response;
    try {
      response = await http
          .post(_uri(path), headers: headers(), body: jsonEncode(body))
          .timeout(timeout);
    } on SocketException {
      throw ApiException('Cannot reach the server at ${ApiConfig.baseUrl}.');
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    }
    decodeAny(response, allowEmpty: true);
  }

  /// POST to a full URL rather than one under [base] — used for `/auth/*`,
  /// which belongs to no single role.
  Future<Object> postJson(String url, Map<String, dynamic> body) =>
      _send(Uri.parse(url), body, allowEmpty: false);

  /// As [postJson], for endpoints that answer 204 with no body.
  Future<void> postAbsolute(String url, Map<String, dynamic> body) async {
    await _send(Uri.parse(url), body, allowEmpty: true);
  }

  Future<Object> _send(Uri uri, Map<String, dynamic> body,
      {required bool allowEmpty}) async {
    late final http.Response response;
    try {
      response = await http
          .post(uri, headers: headers(), body: jsonEncode(body))
          .timeout(timeout);
    } on SocketException {
      throw ApiException('Cannot reach the server at ${ApiConfig.baseUrl}.');
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    }
    return decodeAny(response, allowEmpty: allowEmpty);
  }

  static Map<String, dynamic> asObject(Object decoded) {
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('The server returned an unexpected response.');
    }
    return decoded;
  }

  /// Shared success/error handling. Bodies may be an object, an array, or —
  /// for a 204 — nothing, so the caller decides what it expected.
  static Object decodeAny(http.Response response, {bool allowEmpty = false}) {
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
        if (allowEmpty) return const <String, dynamic>{};
        throw const ApiException('The server returned an unexpected response.');
      }
      return json;
    }

    // The API wraps failures as { error, message }; fall back when it does not.
    final String message =
        (json is Map<String, dynamic> ? json['message'] as String? : null) ??
        (response.statusCode == 401
            ? 'Your session has expired. Sign in again.'
            : response.statusCode == 403
            ? 'Your account does not have access to this.'
            : 'Request failed (${response.statusCode}).');
    throw ApiException(message, statusCode: response.statusCode);
  }
}
