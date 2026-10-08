import '../../data/api_models.dart';
import 'api_config.dart';
import 'api_http.dart';
import 'session.dart';

/// Thin wrapper over the student half of the SchoolErp API.
///
/// Transport lives in [ApiHttp]; this holds only the endpoints and the login
/// call, which is shared by every role.
class ApiClient extends ApiHttp {
  const ApiClient._();

  static const ApiClient instance = ApiClient._();

  @override
  String get base => 'student';

  Future<AuthUser> login({
    required String username,
    required String password,
  }) async {
    final Map<String, dynamic> json = ApiHttp.asObject(
      await postJson('${ApiConfig.authBase}/login', <String, dynamic>{
        'username': username,
        'password': password,
      }),
    );

    // Every role is admitted now: the shell picks the portal from user.role,
    // so a teacher or an admin lands somewhere built for them instead of being
    // turned away or dropped into the student screens.
    return AuthUser.fromJson(json);
  }

  // ------------------------------------------------------------- student portal

  Future<StudentDashboard> dashboard() async =>
      StudentDashboard.fromJson(await getObject('dashboard/stats'));

  Future<StudentProfile> profile() async =>
      StudentProfile.fromJson(await getObject('profile'));

  Future<StudentAttendance> attendance() async =>
      StudentAttendance.fromJson(await getObject('attendance'));

  Future<StudentExams> exams() async =>
      StudentExams.fromJson(await getObject('exams'));

  /// Returns an object, not an array. It was an array until the API started
  /// sending the school's real period list and working days with the slots;
  /// parsing it as a list is what produced "The server returned an unexpected
  /// response." on this screen.
  Future<StudentTimetable> timetable() async =>
      StudentTimetable.fromJson(await getObject('timetable'));

  Future<List<StudentHomework>> homework() async =>
      (await getList('homework')).map(StudentHomework.fromJson).toList();

  Future<List<StudentFee>> fees() async =>
      (await getList('fees')).map(StudentFee.fromJson).toList();

  Future<List<StudentNotice>> notices() async =>
      (await getList('notices')).map(StudentNotice.fromJson).toList();

  /// Changes the signed-in user's password. Returns 204 with no body, so this
  /// posts without decoding — the old sheet claimed success without calling
  /// anything at all, which told people their password had changed when it
  /// had not.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final String? username = Session.instance.user?.username;
    if (username == null) {
      throw const ApiException('You are not signed in.');
    }
    await postAbsolute('${ApiConfig.authBase}/change-password', <String, dynamic>{
      'username': username,
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

}
