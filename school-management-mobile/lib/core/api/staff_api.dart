import '../../data/api_models.dart' show StudentTimetable;
import '../../data/staff_models.dart';
import 'api_config.dart';
import 'api_http.dart';

/// `GET /api/teacher/*`
class TeacherApi extends ApiHttp {
  const TeacherApi._();

  static const TeacherApi instance = TeacherApi._();

  @override
  String get base => 'teacher';

  Future<TeacherDashboard> dashboard() async =>
      TeacherDashboard.fromJson(await getObject('dashboard/stats'));

  Future<List<TeacherClass>> classes() async =>
      (await getList('classes')).map(TeacherClass.fromJson).toList();

  /// Same payload shape as the student timetable — periods, working days and
  /// slots — so it reuses that model rather than duplicating it.
  Future<StudentTimetable> timetable() async =>
      StudentTimetable.fromJson(await getObject('timetable'));

  Future<List<LeaveApplication>> leave() async =>
      (await getList('leave')).map(LeaveApplication.fromJson).toList();

  Future<List<LeaveType>> leaveTypes() async =>
      (await getList('leave/types')).map(LeaveType.fromJson).toList();

  Future<void> applyLeave({
    required int leaveTypeId,
    required DateTime from,
    required DateTime to,
    required String reason,
  }) => post('leave', <String, dynamic>{
    'leaveTypeId': leaveTypeId,
    'fromDate': from.toIso8601String(),
    'toDate': to.toIso8601String(),
    'reason': reason,
  });
}

/// `GET /api/admin/*`
class AdminApi extends ApiHttp {
  const AdminApi._();

  static const AdminApi instance = AdminApi._();

  @override
  String get base => 'admin';

  Future<AdminDashboard> dashboard() async =>
      AdminDashboard.fromJson(await getObject('dashboard/stats'));

  Future<List<AdminStudent>> students() async =>
      (await getList('students')).map(AdminStudent.fromJson).toList();

  Future<List<AdminTeacher>> teachers() async =>
      (await getList('teachers')).map(AdminTeacher.fromJson).toList();

  Future<FeeSummary> feeSummary() async =>
      FeeSummary.fromJson(await getObject('fees/summary'));

  Future<List<AdminInvoice>> invoices() async =>
      (await getList('fees/invoices')).map(AdminInvoice.fromJson).toList();

  /// The guardian on a student. Answers 204 with no body when the school has
  /// never recorded one, which is a null result rather than an error.
  Future<ParentAccount?> parentAccount(int studentId) async {
    final Object decoded =
        await getAny('students/$studentId/parent-login', allowEmpty: true);
    if (decoded is! Map<String, dynamic> || decoded.isEmpty) return null;
    return ParentAccount.fromJson(decoded);
  }

  /// Issues the parent login. The password is in this response and nowhere else.
  Future<GeneratedCredentials> createParentLogin(
    int studentId, {
    required String firstName,
    required String lastName,
    required String relation,
    required String phone,
    String? email,
  }) async {
    final Object decoded = await postJson(
      '${ApiConfig.baseUrl}/admin/students/$studentId/parent-login',
      <String, dynamic>{
        'firstName': firstName,
        'lastName': lastName,
        'relation': relation,
        'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    return GeneratedCredentials.fromJson(ApiHttp.asObject(decoded));
  }
}

/// `GET /api/super-admin/*`
class SuperAdminApi extends ApiHttp {
  const SuperAdminApi._();

  static const SuperAdminApi instance = SuperAdminApi._();

  @override
  String get base => 'super-admin';

  Future<PlatformStats> dashboard() async =>
      PlatformStats.fromJson(await getObject('dashboard/stats'));

  Future<List<PlatformSchool>> schools() async =>
      (await getList('schools')).map(PlatformSchool.fromJson).toList();

  Future<List<PlatformSubscription>> subscriptions() async =>
      (await getList('subscriptions')).map(PlatformSubscription.fromJson).toList();

  Future<List<SupportTicket>> tickets() async =>
      (await getList('tickets')).map(SupportTicket.fromJson).toList();
}
