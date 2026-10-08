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

  Future<List<AdminStudent>> students() async =>
      (await getList('students')).map(AdminStudent.fromJson).toList();

  Future<List<AdminTeacher>> teachers() async =>
      (await getList('teachers')).map(AdminTeacher.fromJson).toList();

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

/// A date as the API wants it on a query string or in a body: calendar day
/// only. Sending a local timestamp made attendance land on the previous day
/// for anyone east of UTC.
String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
