import '../../data/api_models.dart' show FeePayment, FeeReceipt, StudentTimetable;
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

  /// Sections this teacher is class teacher of — the ones whose attendance
  /// they may take. Marking is a class-teacher duty; teaching a subject in a
  /// section is not enough.
  Future<List<TeacherClass>> attendanceSections() async =>
      (await classes()).where((TeacherClass c) => c.isClassTeacher).toList();

  Future<List<AttendanceRow>> attendance({
    required String className,
    required String sectionName,
    required DateTime date,
  }) async => (await getList(
    'attendance?className=${Uri.encodeQueryComponent(className)}'
    '&sectionName=${Uri.encodeQueryComponent(sectionName)}'
    '&date=${_day(date)}',
  )).map(AttendanceRow.fromJson).toList();

  /// Posts the whole sheet. The API upserts, so re-saving a day it already has
  /// corrects it rather than doubling it.
  Future<void> saveAttendance({
    required String className,
    required String sectionName,
    required DateTime date,
    required List<AttendanceRow> rows,
  }) => post('attendance', <String, dynamic>{
    'className': className,
    'sectionName': sectionName,
    'date': _day(date),
    'entries': <Map<String, dynamic>>[
      for (final AttendanceRow r in rows)
        <String, dynamic>{'studentId': r.studentId, 'status': r.status},
    ],
  });

  /// Exams this school has set, for the marks and results pickers.
  Future<List<SchoolExam>> exams() async =>
      (await getList('exams')).map(SchoolExam.fromJson).toList();

  /// Sections this teacher may enter marks for, with their subjects in each.
  Future<List<TeachingSection>> markSections() async =>
      (await getList('marks/sections')).map(TeachingSection.fromJson).toList();

  Future<MarksGrid> marksGrid({
    required int examId,
    required String className,
    required String sectionName,
  }) async => MarksGrid.fromJson(await getObject(
    'marks/grid?examId=$examId'
    '&className=${Uri.encodeQueryComponent(className)}'
    '&sectionName=${Uri.encodeQueryComponent(sectionName)}',
  ));

  /// Saves marks for one section. Only the cells given are written, so a
  /// teacher can fill one subject at a time without clearing the others.
  Future<void> saveMarksGrid({
    required int examId,
    required String className,
    required String sectionName,
    required List<Map<String, dynamic>> entries,
  }) => post('marks/grid', <String, dynamic>{
    'examId': examId,
    'className': className,
    'sectionName': sectionName,
    'entries': entries,
  });

  /// Sections this teacher is class teacher of — whose result sheets they may
  /// review and sign off.
  Future<List<MyClassSection>> resultSections() async =>
      (await getList('results/sections')).map(MyClassSection.fromJson).toList();

  Future<ClassResult> classResult({
    required int examId,
    required String className,
    required String sectionName,
  }) async => ClassResult.fromJson(await getObject(
    'results/class?examId=$examId'
    '&className=${Uri.encodeQueryComponent(className)}'
    '&sectionName=${Uri.encodeQueryComponent(sectionName)}',
  ));

  /// Signs the sheet off, or withdraws it. The admin cannot publish an exam
  /// until every section that sat it has been approved, so this is the step
  /// that releases the result.
  Future<void> approveResult({
    required int examId,
    required String className,
    required String sectionName,
    required bool approve,
    String? remarks,
  }) => post('results/approve', <String, dynamic>{
    'examId': examId,
    'className': className,
    'sectionName': sectionName,
    'approve': approve,
    'remarks': remarks,
  });

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

  /// Unlike every other admin list, this one is paged: the endpoint answers
  /// `{items, total, page, pageSize}`, not a bare array. Asking for a plain
  /// list here used to throw "the server returned an unexpected response" and
  /// left the Students tab showing an error instead of the school's roll.
  ///
  /// 500 is the server's ceiling, and the screen filters in memory, so one
  /// page is fetched rather than paging a picker the user is searching anyway.
  Future<List<AdminStudent>> students({String? search}) async {
    final String q = (search ?? '').trim();
    final Map<String, dynamic> page = await getObject(
      'students?page=1&pageSize=500'
      '${q.isEmpty ? '' : '&search=${Uri.encodeQueryComponent(q)}'}',
    );
    final List<dynamic> items = page['items'] as List<dynamic>? ?? <dynamic>[];
    return items
        .cast<Map<String, dynamic>>()
        .map(AdminStudent.fromJson)
        .toList();
  }

  /// Everything the edit form needs, which the list row does not carry.
  Future<StudentDetail> studentDetail(int id) async =>
      StudentDetail.fromJson(await getObject('students/\$id'));

  Future<void> createStudent(Map<String, dynamic> body) =>
      post('students', body);

  Future<void> updateStudent(int id, Map<String, dynamic> body) =>
      put('students/$id', body);

  /// active | inactive. There is no hard delete: a student who has sat an exam
  /// or been invoiced cannot vanish without taking that history with them, so
  /// the API retires the record instead.
  Future<void> setStudentStatus({required int id, required String status}) =>
      patch('students/$id/status', <String, dynamic>{'status': status});

  /// Issues a new portal password and hands back the plaintext. It exists only
  /// in this response — the database keeps a bcrypt hash and nothing else.
  Future<GeneratedCredentials> resetStudentPassword(int id) async {
    final Object decoded = await postJson(
      '${ApiConfig.baseUrl}/admin/students/$id/reset-password',
      const <String, dynamic>{},
    );
    return GeneratedCredentials.fromJson(ApiHttp.asObject(decoded));
  }

  /// The next free roll number in a section, so a new admission does not have
  /// to be told one. Null when the section has no numbering to continue.
  Future<String?> nextRoll({
    required String className,
    required String sectionName,
  }) async {
    final Map<String, dynamic> r = await getObject(
      'students/next-roll'
      '?className=${Uri.encodeQueryComponent(className)}'
      '&sectionName=${Uri.encodeQueryComponent(sectionName)}',
    );
    final Object? v = r['rollNo'] ?? r['nextRoll'] ?? r['value'];
    return v == null ? null : '$v';
  }

  Future<List<AdminTeacher>> teachers({String? search}) async {
    final String q = (search ?? '').trim();
    return (await getList(
      q.isEmpty ? 'teachers' : 'teachers?search=${Uri.encodeQueryComponent(q)}',
    )).map(AdminTeacher.fromJson).toList();
  }

  Future<TeacherDetail> teacherDetail(int id) async =>
      TeacherDetail.fromJson(await getObject('teachers/\$id'));

  Future<void> createTeacher(Map<String, dynamic> body) =>
      post('teachers', body);

  Future<void> updateTeacher(int id, Map<String, dynamic> body) =>
      put('teachers/$id', body);

  /// active | inactive — retired rather than deleted, same as a student.
  Future<void> setTeacherStatus({required int id, required String status}) =>
      patch('teachers/$id/status', <String, dynamic>{'status': status});

  Future<GeneratedCredentials> resetTeacherPassword(int id) async {
    final Object decoded = await postJson(
      '${ApiConfig.baseUrl}/admin/teachers/$id/reset-password',
      const <String, dynamic>{},
    );
    return GeneratedCredentials.fromJson(ApiHttp.asObject(decoded));
  }

  Future<FeeSummary> feeSummary() async =>
      FeeSummary.fromJson(await getObject('fees/summary'));

  Future<List<AdminInvoice>> invoices() async =>
      (await getList('fees/invoices')).map(AdminInvoice.fromJson).toList();

  /// Payments taken against one invoice, oldest first — one receipt each.
  Future<List<FeePayment>> invoicePayments(int invoiceId) async =>
      (await getList('fees/invoices/$invoiceId/payments'))
          .map(FeePayment.fromJson)
          .toList();

  /// The receipt for one payment. The same document the family sees, down to
  /// the receipt number.
  Future<FeeReceipt> paymentReceipt(int paymentId) async =>
      FeeReceipt.fromJson(await getObject('fees/payments/$paymentId/receipt'));

  /// Staff leave applications. A null status returns every one, pending first.
  Future<List<LeaveApplication>> leave({String? status}) async =>
      (await getList(status == null ? 'leave' : 'leave?status=$status'))
          .map(LeaveApplication.fromJson)
          .toList();

  /// Approves or rejects one application. Remarks are what the applicant sees,
  /// so a rejection without one leaves them guessing.
  Future<void> reviewLeave({
    required int id,
    required String status,
    String? remarks,
  }) => patch('leave/$id/review', <String, dynamic>{
    'status': status,
    'remarks': remarks,
  });

  /// The school's subject master. Only the active ones are offered for a new
  /// assignment; a retired subject still has to be listed for a teacher who
  /// already holds it, or saving them would silently drop it.
  Future<List<SchoolSubject>> subjects() async =>
      (await getList('subjects')).map(SchoolSubject.fromJson).toList();

  /// The class master, with each class's sections. Backs every picker that
  /// needs a class and a section together.
  Future<List<SchoolClass>> schoolClasses() async =>
      (await getList('classes')).map(SchoolClass.fromJson).toList();

  /// Every class/section pair in the school, in master order. An admin may
  /// take any register, unlike a teacher who is held to their own sections.
  Future<List<ClassSection>> classSections() async => <ClassSection>[
    for (final SchoolClass c in await schoolClasses())
      for (final SchoolSection s in c.sections)
        ClassSection(className: c.name, sectionName: s.name),
  ];

  Future<List<AttendanceRow>> attendance({
    required String className,
    required String sectionName,
    required DateTime date,
  }) async => (await getList(
    'attendance?className=${Uri.encodeQueryComponent(className)}'
    '&sectionName=${Uri.encodeQueryComponent(sectionName)}'
    '&date=${_day(date)}',
  )).map(AttendanceRow.fromJson).toList();

  /// Posts the whole sheet; the API upserts, so re-saving a day corrects it
  /// rather than doubling it.
  Future<void> saveAttendance({
    required String className,
    required String sectionName,
    required DateTime date,
    required List<AttendanceRow> rows,
  }) => post('attendance', <String, dynamic>{
    'className': className,
    'sectionName': sectionName,
    'date': _day(date),
    'entries': <Map<String, dynamic>>[
      for (final AttendanceRow r in rows)
        <String, dynamic>{'studentId': r.studentId, 'status': r.status},
    ],
  });

  /// The staff register for one day.
  Future<List<StaffAttendanceRow>> staffAttendance(DateTime date) async =>
      (await getList('staff-attendance?date=${_day(date)}'))
          .map(StaffAttendanceRow.fromJson)
          .toList();

  Future<void> saveStaffAttendance({
    required DateTime date,
    required List<StaffAttendanceRow> rows,
  }) => post('staff-attendance', <String, dynamic>{
    'date': _day(date),
    'entries': <Map<String, dynamic>>[
      for (final StaffAttendanceRow r in rows)
        <String, dynamic>{
          'staffId': r.staffId,
          'status': r.status,
          'remarks': r.remarks,
        },
    ],
  });

  Future<List<SchoolExam>> exams() async =>
      (await getList('exams')).map(SchoolExam.fromJson).toList();

  /// Which sections have signed their result sheet off. Publishing is refused
  /// until every one of them has.
  Future<List<ExamApproval>> examApprovals(int examId) async =>
      (await getList('exams/$examId/approvals'))
          .map(ExamApproval.fromJson)
          .toList();

  /// Moves an exam's status. `auto` hands control back to the dates; publishing
  /// is the one value the API guards, and it throws naming the sections it is
  /// still waiting on.
  Future<void> setExamStatus({required int examId, required String status}) =>
      patch('exams/$examId/status', <String, dynamic>{'status': status});

  Future<List<SchoolNotice>> notices() async =>
      (await getList('notices')).map(SchoolNotice.fromJson).toList();

  Future<void> createNotice({
    required String title,
    required String body,
    required String audience,
  }) => post('notices', <String, dynamic>{
    'title': title,
    'body': body,
    'audience': audience,
  });

  /// One student's attendance between two dates.
  Future<AttendanceReport> attendanceReport({
    required int studentId,
    required DateTime from,
    required DateTime to,
  }) async => AttendanceReport.fromJson(await getObject(
    'attendance/report?studentId=$studentId&from=${_day(from)}&to=${_day(to)}',
  ));

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

/// `GET /api/auth/*` — the endpoints that belong to no single role.
class AuthApi extends ApiHttp {
  const AuthApi._();

  static const AuthApi instance = AuthApi._();

  @override
  String get base => 'auth';

  /// The signed-in user's own profile. Answers for every role, so one screen
  /// serves all of them.
  Future<MyProfile> me() async => MyProfile.fromJson(await getObject('me'));
}

/// `GET /api/geography/*` — the country/state/city master, readable by every
/// signed-in role. The super admin owns the master and edits it through its own
/// endpoints; everyone else reads it from here to fill an address picker.
class GeographyApi extends ApiHttp {
  const GeographyApi._();

  static const GeographyApi instance = GeographyApi._();

  @override
  String get base => 'geography';

  Future<List<GeoCountry>> countries() async =>
      (await getList('countries')).map(GeoCountry.fromJson).toList();

  Future<List<GeoState>> states({int? countryId}) async =>
      (await getList(countryId == null ? 'states' : 'states?countryId=$countryId'))
          .map(GeoState.fromJson)
          .toList();

  Future<List<GeoCity>> cities({int? stateId}) async =>
      (await getList(stateId == null ? 'cities' : 'cities?stateId=$stateId'))
          .map(GeoCity.fromJson)
          .toList();
}

/// `GET /api/super-admin/*`
class SuperAdminApi extends ApiHttp {
  const SuperAdminApi._();

  static const SuperAdminApi instance = SuperAdminApi._();

  @override
  String get base => 'super-admin';

  Future<PlatformStats> dashboard() async =>
      PlatformStats.fromJson(await getObject('dashboard/stats'));

  /// [search] matches name, school code or city, server-side. The joined-date
  /// range is NOT a parameter here — the endpoint has none — so the screen
  /// narrows by date in memory over what this returns.
  Future<List<PlatformSchool>> schools({String? search}) async {
    final String q = (search ?? '').trim();
    return (await getList(
      q.isEmpty ? 'schools' : 'schools?search=${Uri.encodeQueryComponent(q)}',
    )).map(PlatformSchool.fromJson).toList();
  }

  /// [status] is active | trial | past_due, filtered server-side. The start
  /// date range is not a parameter here — the endpoint has none — so the
  /// screen narrows by date over what this returns.
  Future<List<PlatformSubscription>> subscriptions({String? status}) async {
    final String s = (status ?? '').trim();
    return (await getList(
      s.isEmpty ? 'subscriptions' : 'subscriptions?status=$s',
    )).map(PlatformSubscription.fromJson).toList();
  }

  Future<List<SupportTicket>> tickets() async =>
      (await getList('tickets')).map(SupportTicket.fromJson).toList();

  /// One school in full. The list row carries only what a list needs.
  Future<SchoolDetail> school(int id) async =>
      SchoolDetail.fromJson(await getObject('schools/$id'));

  /// Onboards a school and provisions its first administrator. The password in
  /// the result is the only copy that will ever exist in plaintext.
  Future<SchoolOnboarded> createSchool(Map<String, dynamic> body) async {
    final Object decoded =
        await postJson('${ApiConfig.baseUrl}/super-admin/schools', body);
    return SchoolOnboarded.fromJson(ApiHttp.asObject(decoded));
  }

  Future<void> updateSchool(int id, Map<String, dynamic> body) =>
      put('schools/$id', body);

  /// Activate, suspend or terminate. Separate from the edit form because it is
  /// the one change that takes a school's people offline.
  Future<void> setSchoolStatus({required int id, required String status}) =>
      patch('schools/$id/status', <String, dynamic>{'status': status});

  /// Issues the school administrator a new password and returns it once. The
  /// old one is unrecoverable, so this is the only way back in.
  Future<GeneratedCredentials> resetSchoolAdminPassword(int id) async {
    final Object decoded = await postJson(
      '${ApiConfig.baseUrl}/super-admin/schools/$id/admin/reset-password',
      const <String, dynamic>{},
    );
    return GeneratedCredentials.fromJson(ApiHttp.asObject(decoded));
  }

  /// One ticket with its whole conversation.
  Future<SupportTicketDetail> ticket(int id) async =>
      SupportTicketDetail.fromJson(await getObject('tickets/$id'));

  /// open | in_progress | resolved | closed.
  Future<void> setTicketStatus({required int id, required String status}) =>
      patch('tickets/$id/status', <String, dynamic>{'status': status});

  /// Closes a ticket with a note the school can read. [notify] emails them.
  Future<void> resolveTicket({
    required int id,
    required String note,
    bool notify = true,
  }) => post('tickets/$id/resolve', <String, dynamic>{
    'resolutionNote': note,
    'notifySchool': notify,
  });

  /// Replies on the thread. The acting user is sent explicitly rather than
  /// inferred from the token, because that is what the endpoint takes.
  Future<void> addTicketComment({
    required int id,
    required int userId,
    required String message,
  }) => post('tickets/$id/comments', <String, dynamic>{
    'userId': userId,
    'message': message,
  });

  Future<void> createPlan(Map<String, dynamic> body) => post('plans', body);

  /// Note the API takes no name on update: a plan's name is its identity once
  /// schools are on it, so renaming is not offered rather than silently ignored.
  Future<void> updatePlan(int id, Map<String, dynamic> body) =>
      put('plans/$id', body);

  Future<void> createCountry(Map<String, dynamic> body) =>
      post('geography/countries', body);
  Future<void> updateCountry(int id, Map<String, dynamic> body) =>
      put('geography/countries/$id', body);
  Future<void> setCountryActive({required int id, required bool active}) =>
      patch('geography/countries/$id/active?value=$active', const <String, dynamic>{});

  Future<void> createState(Map<String, dynamic> body) =>
      post('geography/states', body);
  Future<void> updateState(int id, Map<String, dynamic> body) =>
      put('geography/states/$id', body);
  Future<void> setStateActive({required int id, required bool active}) =>
      patch('geography/states/$id/active?value=$active', const <String, dynamic>{});

  Future<void> createCity(Map<String, dynamic> body) =>
      post('geography/cities', body);
  Future<void> updateCity(int id, Map<String, dynamic> body) =>
      put('geography/cities/$id', body);
  Future<void> setCityActive({required int id, required bool active}) =>
      patch('geography/cities/$id/active?value=$active', const <String, dynamic>{});

  /// The price list every subscription is sold from.
  Future<List<SubscriptionPlan>> plans() async =>
      (await getList('plans')).map(SubscriptionPlan.fromJson).toList();

  /// Retires a plan or puts it back on sale. Schools already on it keep their
  /// subscription either way — this only governs what can be sold next.
  Future<void> setPlanActive({required int planId, required bool active}) =>
      patch('plans/$planId/active?value=$active', const <String, dynamic>{});

  Future<BillingSummary> billingSummary() async =>
      BillingSummary.fromJson(await getObject('billing/summary'));

  /// Platform invoices. A null status returns every one.
  Future<List<BillingInvoice>> billingInvoices({String? status}) async =>
      (await getList(status == null
              ? 'billing/invoices'
              : 'billing/invoices?status=$status'))
          .map(BillingInvoice.fromJson)
          .toList();

  /// Nudges a school about an unpaid invoice. The API stamps remindedAt, which
  /// is what stops a second person sending a second one an hour later.
  Future<void> sendBillingReminder(int invoiceId) =>
      post('billing/invoices/$invoiceId/reminder', const <String, dynamic>{});

  Future<List<GeoCountry>> countries() async =>
      (await getList('geography/countries')).map(GeoCountry.fromJson).toList();

  Future<List<GeoState>> states({int? countryId}) async =>
      (await getList(countryId == null
              ? 'geography/states'
              : 'geography/states?countryId=$countryId'))
          .map(GeoState.fromJson)
          .toList();

  Future<List<GeoCity>> cities({int? stateId}) async =>
      (await getList(stateId == null
              ? 'geography/cities'
              : 'geography/cities?stateId=$stateId'))
          .map(GeoCity.fromJson)
          .toList();
}

/// A date as the API wants it on a query string or in a body: calendar day
/// only. Sending a local timestamp made attendance land on the previous day
/// for anyone east of UTC.
String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
