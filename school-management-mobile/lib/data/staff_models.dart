/// Models for the teacher, school-admin and super-admin portals.
///
/// Field names mirror the API's JSON exactly; every one here was read off a
/// live response rather than inferred from the C# DTOs, so the two cannot
/// disagree about casing or nullability.
library;

int _int(Object? v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
double _dbl(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
DateTime? _date(Object? v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

/* ======================================================== teacher portal == */

class TeacherProfile {
  const TeacherProfile({required this.name, this.employeeCode, this.subject});

  final String name;
  final String? employeeCode;
  final String? subject;

  factory TeacherProfile.fromJson(Map<String, dynamic> j) => TeacherProfile(
    name: j['name'] as String? ?? '',
    employeeCode: j['employeeCode'] as String?,
    subject: j['subject'] as String?,
  );
}

class TeacherDashboard {
  const TeacherDashboard({
    required this.profile,
    required this.myClassesCount,
    required this.studentsTaught,
    required this.submissionsToGrade,
    required this.openHomework,
  });

  final TeacherProfile profile;
  final int myClassesCount;
  final int studentsTaught;
  final int submissionsToGrade;
  final int openHomework;

  factory TeacherDashboard.fromJson(Map<String, dynamic> j) => TeacherDashboard(
    profile: TeacherProfile.fromJson(
      (j['profile'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    ),
    myClassesCount: _int(j['myClassesCount']),
    studentsTaught: _int(j['studentsTaught']),
    submissionsToGrade: _int(j['submissionsToGrade']),
    openHomework: _int(j['openHomework']),
  );
}

class TeacherClass {
  const TeacherClass({
    required this.className,
    required this.sectionName,
    required this.studentCount,
    required this.isClassTeacher,
    this.subject,
    this.room,
  });

  final String className;
  final String sectionName;
  final int studentCount;
  final bool isClassTeacher;
  final String? subject;
  final String? room;

  String get label => '$className — $sectionName';

  factory TeacherClass.fromJson(Map<String, dynamic> j) => TeacherClass(
    className: j['className'] as String? ?? '',
    sectionName: j['sectionName'] as String? ?? '',
    studentCount: _int(j['studentCount']),
    isClassTeacher: j['isClassTeacher'] == true,
    subject: j['subject'] as String?,
    room: j['room'] as String?,
  );
}

class LeaveApplication {
  const LeaveApplication({
    required this.id,
    required this.status,
    required this.days,
    this.leaveTypeName,
    this.applicantName,
    this.reason,
    this.fromDate,
    this.toDate,
    this.reviewedByName,
    this.reviewRemarks,
  });

  final int id;
  final String status;
  final double days;
  final String? leaveTypeName;

  /// Who applied. Null on a teacher's own list, where it would only repeat
  /// the person reading it; the admin queue cannot do without it.
  final String? applicantName;
  final String? reviewedByName;
  final String? reviewRemarks;
  final String? reason;
  final DateTime? fromDate;
  final DateTime? toDate;

  factory LeaveApplication.fromJson(Map<String, dynamic> j) => LeaveApplication(
    id: _int(j['id']),
    status: j['status'] as String? ?? 'pending',
    days: _dbl(j['days']),
    leaveTypeName: j['leaveTypeName'] as String?,
    applicantName: j['applicantName'] as String?,
    reviewedByName: j['reviewedByName'] as String?,
    reviewRemarks: j['reviewRemarks'] as String?,
    reason: j['reason'] as String?,
    fromDate: _date(j['fromDate']),
    toDate: _date(j['toDate']),
  );
}

class LeaveType {
  const LeaveType({required this.id, required this.name, this.maxDaysPerYear});

  final int id;
  final String name;
  final int? maxDaysPerYear;

  factory LeaveType.fromJson(Map<String, dynamic> j) => LeaveType(
    id: _int(j['id']),
    name: j['name'] as String? ?? '',
    maxDaysPerYear: j['maxDaysPerYear'] == null
        ? null
        : _int(j['maxDaysPerYear']),
  );
}

/* =================================================== school-admin portal == */

class AdminDashboard {
  const AdminDashboard({
    required this.schoolName,
    required this.academicYear,
    required this.totalStudents,
    required this.totalTeachers,
    required this.teachersOnLeave,
    required this.totalClasses,
    required this.totalSections,
    required this.feesBilled,
    required this.feesCollected,
    required this.feesOverdue,
    required this.unpaidInvoices,
    this.subscription,
  });

  final String schoolName;
  final String academicYear;
  final int totalStudents;
  final int totalTeachers;
  final int teachersOnLeave;
  final int totalClasses;
  final int totalSections;
  final double feesBilled;
  final double feesCollected;
  final double feesOverdue;
  final int unpaidInvoices;

  /// Null for a school onboarded before plans existed.
  final SubscriptionStatus? subscription;

  factory AdminDashboard.fromJson(Map<String, dynamic> j) => AdminDashboard(
    schoolName: j['schoolName'] as String? ?? '',
    academicYear: j['academicYear'] as String? ?? '',
    totalStudents: _int(j['totalStudents']),
    totalTeachers: _int(j['totalTeachers']),
    teachersOnLeave: _int(j['teachersOnLeave']),
    totalClasses: _int(j['totalClasses']),
    totalSections: _int(j['totalSections']),
    feesBilled: _dbl(j['feesBilled']),
    feesCollected: _dbl(j['feesCollected']),
    feesOverdue: _dbl(j['feesOverdue']),
    unpaidInvoices: _int(j['unpaidInvoices']),
    subscription: j['subscription'] == null
        ? null
        : SubscriptionStatus.fromJson(j['subscription'] as Map<String, dynamic>),
  );
}

/// The school's live plan entitlement, as the API computes it: seats used, days
/// left, and whether access has lapsed. Everything here comes from the end date
/// and the plan's seat count, not from the stored status word.
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.status,
    required this.isTrial,
    required this.studentCount,
    required this.atStudentCap,
    required this.isLapsed,
    required this.isExpiringSoon,
    this.planName,
    this.endDate,
    this.daysRemaining,
    this.maxStudents,
    this.seatsRemaining,
  });

  final String status;
  final bool isTrial;
  final int studentCount;
  final bool atStudentCap;
  final bool isLapsed;
  final bool isExpiringSoon;
  final String? planName;
  final DateTime? endDate;

  /// Negative once the end date has passed.
  final int? daysRemaining;

  /// Null means the plan is unlimited.
  final int? maxStudents;
  final int? seatsRemaining;

  factory SubscriptionStatus.fromJson(Map<String, dynamic> j) => SubscriptionStatus(
    status: j['status'] as String? ?? '',
    isTrial: j['isTrial'] == true,
    studentCount: _int(j['studentCount']),
    atStudentCap: j['atStudentCap'] == true,
    isLapsed: j['isLapsed'] == true,
    isExpiringSoon: j['isExpiringSoon'] == true,
    planName: j['planName'] as String?,
    endDate: _date(j['endDate']),
    daysRemaining: j['daysRemaining'] == null ? null : _int(j['daysRemaining']),
    maxStudents: j['maxStudents'] == null ? null : _int(j['maxStudents']),
    seatsRemaining: j['seatsRemaining'] == null ? null : _int(j['seatsRemaining']),
  );
}

/// The guardian recorded against a student, and whether they can sign in.
class ParentAccount {
  const ParentAccount({
    required this.guardianId,
    required this.name,
    required this.relation,
    required this.phone,
    required this.hasLogin,
    this.email,
    this.username,
  });

  final int guardianId;
  final String name;
  final String relation;
  final String phone;
  final bool hasLogin;
  final String? email;
  final String? username;

  factory ParentAccount.fromJson(Map<String, dynamic> j) => ParentAccount(
    guardianId: _int(j['guardianId']),
    name: j['name'] as String? ?? '',
    relation: j['relation'] as String? ?? 'guardian',
    phone: j['phone'] as String? ?? '',
    hasLogin: j['hasLogin'] == true,
    email: j['email'] as String?,
    username: j['username'] as String?,
  );
}

/// A freshly issued login. The password exists only in this response — the
/// database holds a hash — so the screen must show it before it is discarded.
class GeneratedCredentials {
  const GeneratedCredentials({
    required this.userId,
    required this.fullName,
    required this.username,
    required this.temporaryPassword,
    this.email,
  });

  final int userId;
  final String fullName;
  final String username;
  final String temporaryPassword;
  final String? email;

  factory GeneratedCredentials.fromJson(Map<String, dynamic> j) => GeneratedCredentials(
    userId: _int(j['userId']),
    fullName: j['fullName'] as String? ?? '',
    username: j['username'] as String? ?? '',
    temporaryPassword: j['temporaryPassword'] as String? ?? '',
    email: j['email'] as String?,
  );
}

class AdminStudent {
  const AdminStudent({
    required this.id,
    required this.name,
    required this.admissionNo,
    required this.feeDue,
    required this.status,
    this.className,
    this.sectionName,
    this.rollNo,
    this.guardianName,
    this.guardianPhone,
  });

  final int id;
  final String name;
  final String admissionNo;
  final double feeDue;
  final String status;
  final String? className;
  final String? sectionName;
  final String? rollNo;
  final String? guardianName;
  final String? guardianPhone;

  /// Blank for a student not yet placed in a class, which the seeded imports
  /// leave empty rather than null.
  String get classLabel {
    final String c = className ?? '';
    final String s = sectionName ?? '';
    if (c.isEmpty && s.isEmpty) return 'Unassigned';
    return s.isEmpty ? c : '$c — $s';
  }

  factory AdminStudent.fromJson(Map<String, dynamic> j) => AdminStudent(
    id: _int(j['id']),
    name: j['name'] as String? ?? '',
    admissionNo: j['admissionNo'] as String? ?? '',
    feeDue: _dbl(j['feeDue']),
    status: j['status'] as String? ?? 'active',
    className: j['className'] as String?,
    sectionName: j['sectionName'] as String?,
    rollNo: j['rollNo'] as String?,
    guardianName: j['guardianName'] as String?,
    guardianPhone: j['guardianPhone'] as String?,
  );
}

class AdminTeacher {
  const AdminTeacher({
    required this.id,
    required this.name,
    required this.status,
    this.employeeCode,
    this.subject,
    this.phone,
    this.email,
    this.classTeacherOf,
    this.subjects = const <String>[],
  });

  final int id;
  final String name;
  final String status;
  final String? employeeCode;
  final String? subject;
  final String? phone;
  final String? email;
  final String? classTeacherOf;
  final List<String> subjects;

  factory AdminTeacher.fromJson(Map<String, dynamic> j) => AdminTeacher(
    id: _int(j['id']),
    name: j['name'] as String? ?? '',
    status: j['status'] as String? ?? 'active',
    employeeCode: j['employeeCode'] as String?,
    subject: j['subject'] as String?,
    phone: j['phone'] as String?,
    email: j['email'] as String?,
    classTeacherOf: j['classTeacherOf'] as String?,
    subjects: (j['subjects'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) => '$e')
        .toList(),
  );
}

class FeeSummary {
  const FeeSummary({
    required this.totalBilled,
    required this.collected,
    required this.outstanding,
    required this.unpaid,
    required this.overdue,
  });

  final double totalBilled;
  final double collected;
  final double outstanding;
  final int unpaid;
  final int overdue;

  factory FeeSummary.fromJson(Map<String, dynamic> j) => FeeSummary(
    totalBilled: _dbl(j['totalBilled']),
    collected: _dbl(j['collected']),
    outstanding: _dbl(j['outstanding']),
    unpaid: _int(j['unpaid']),
    overdue: _int(j['overdue']),
  );
}

/// A section of a class, as the class master holds it.
class SchoolSection {
  const SchoolSection({
    required this.id,
    required this.classId,
    required this.name,
    this.teacher,
    required this.studentCount,
  });

  final int id;
  final int classId;
  final String name;

  /// The class teacher, by name. The master stores a name rather than a staff
  /// id, so this is for showing, not for looking anyone up.
  final String? teacher;
  final int studentCount;

  factory SchoolSection.fromJson(Map<String, dynamic> j) => SchoolSection(
    id: _int(j['id']),
    classId: _int(j['classId']),
    name: j['name'] as String? ?? '',
    teacher: j['teacher'] as String?,
    studentCount: _int(j['studentCount']),
  );
}

/// A class and its sections.
class SchoolClass {
  const SchoolClass({
    required this.id,
    required this.name,
    required this.sections,
  });

  final int id;
  final String name;
  final List<SchoolSection> sections;

  int get studentCount =>
      sections.fold(0, (int sum, SchoolSection s) => sum + s.studentCount);

  factory SchoolClass.fromJson(Map<String, dynamic> j) => SchoolClass(
    id: _int(j['id']),
    name: j['name'] as String? ?? '',
    sections: ((j['sections'] as List<dynamic>?) ?? const <dynamic>[])
        .map((dynamic e) => SchoolSection.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// One class and one of its sections, flattened — what a register is taken
/// for. The master is nested, but every picker on these screens needs the pair.
class ClassSection {
  const ClassSection({required this.className, required this.sectionName});

  final String className;
  final String sectionName;

  String get label => '$className-$sectionName';

  /// Used as a dropdown value, so equality has to be by content: the list is
  /// rebuilt on every load and identity would silently clear the selection.
  @override
  bool operator ==(Object other) =>
      other is ClassSection &&
      other.className == className &&
      other.sectionName == sectionName;

  @override
  int get hashCode => Object.hash(className, sectionName);
}

/// One staff member on the day's staff register.
class StaffAttendanceRow {
  StaffAttendanceRow({
    required this.staffId,
    this.employeeCode,
    required this.name,
    required this.status,
    this.remarks,
  });

  final int staffId;
  final String? employeeCode;
  final String name;

  /// present | absent | late | half_day | on_leave. Mutable: the register is
  /// edited in place and posted whole, so the row is the working copy.
  String status;
  String? remarks;

  factory StaffAttendanceRow.fromJson(Map<String, dynamic> j) =>
      StaffAttendanceRow(
        staffId: _int(j['staffId']),
        employeeCode: j['employeeCode'] as String?,
        name: j['name'] as String? ?? '',
        status: (j['status'] as String? ?? 'present').toLowerCase(),
        remarks: j['remarks'] as String?,
      );
}

/// One paper of an exam: a subject, for a class, on a date.
class ExamPaper {
  const ExamPaper({
    required this.id,
    this.classLabel,
    required this.subject,
    this.examDate,
    this.time,
    this.room,
    required this.fullMarks,
  });

  final int id;
  final String? classLabel;
  final String subject;
  final DateTime? examDate;
  final String? time;
  final String? room;
  final int fullMarks;

  factory ExamPaper.fromJson(Map<String, dynamic> j) => ExamPaper(
    id: _int(j['id']),
    classLabel: j['classLabel'] as String?,
    subject: j['subject'] as String? ?? '',
    examDate: _date(j['examDate']),
    time: j['time'] as String?,
    room: j['room'] as String?,
    fullMarks: _int(j['fullMarks']),
  );
}

/// Whether one section of an exam has been signed off by its class teacher.
/// Results cannot be published until every one of these is approved, so this
/// is the admin's list of who they are waiting on.
class ExamApproval {
  const ExamApproval({
    required this.className,
    required this.sectionName,
    required this.status,
    this.approvedByName,
    this.approvedAt,
    this.remarks,
    required this.studentCount,
    required this.completeCount,
  });

  final String className;
  final String sectionName;
  final String status;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? remarks;

  /// How far the marking has got. A section can be fully marked and still
  /// unapproved, which is a nudge rather than a blocker.
  final int studentCount;
  final int completeCount;

  String get label => '$className-$sectionName';
  bool get isApproved => status.toLowerCase() == 'approved';

  factory ExamApproval.fromJson(Map<String, dynamic> j) => ExamApproval(
    className: j['className'] as String? ?? '',
    sectionName: j['sectionName'] as String? ?? '',
    status: j['status'] as String? ?? 'pending',
    approvedByName: j['approvedByName'] as String?,
    approvedAt: _date(j['approvedAt']),
    remarks: j['remarks'] as String?,
    studentCount: _int(j['studentCount']),
    completeCount: _int(j['completeCount']),
  );
}

/// A notice the school has published.
class SchoolNotice {
  const SchoolNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.publishDate,
    required this.createdBy,
    this.createdByName,
  });

  final int id;
  final String title;
  final String body;

  /// all | students | teachers | parents | staff
  final String audience;
  final DateTime publishDate;

  /// Compared with the signed-in user to offer a "mine" filter without a
  /// second round trip.
  final int createdBy;
  final String? createdByName;

  factory SchoolNotice.fromJson(Map<String, dynamic> j) => SchoolNotice(
    id: _int(j['id']),
    title: j['title'] as String? ?? '',
    body: j['body'] as String? ?? '',
    audience: j['audience'] as String? ?? 'all',
    publishDate: _date(j['publishDate']) ?? DateTime.now(),
    createdBy: _int(j['createdBy']),
    createdByName: j['createdByName'] as String?,
  );
}

/// One day on a student's attendance report.
class AttendanceDay {
  const AttendanceDay({
    required this.date,
    required this.day,
    required this.status,
  });

  /// Sent as a string by the API — it is a label on a report, not a date to
  /// compute with, and parsing it only to print it back invites a timezone bug.
  final String date;
  final String day;
  final String status;

  factory AttendanceDay.fromJson(Map<String, dynamic> j) => AttendanceDay(
    date: j['date'] as String? ?? '',
    day: j['day'] as String? ?? '',
    status: j['status'] as String? ?? '',
  );
}

/// One student's attendance over a date range.
class AttendanceReport {
  const AttendanceReport({
    required this.studentName,
    required this.present,
    required this.absent,
    required this.late,
    required this.schoolDays,
    required this.percent,
    required this.days,
  });

  final String studentName;
  final int present;
  final int absent;
  final int late;
  final int schoolDays;
  final int percent;
  final List<AttendanceDay> days;

  factory AttendanceReport.fromJson(Map<String, dynamic> j) => AttendanceReport(
    studentName: j['studentName'] as String? ?? '',
    present: _int(j['present']),
    absent: _int(j['absent']),
    late: _int(j['late']),
    schoolDays: _int(j['schoolDays']),
    percent: _int(j['percent']),
    days: ((j['days'] as List<dynamic>?) ?? const <dynamic>[])
        .map((dynamic e) => AttendanceDay.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// A section this teacher is class teacher of — the ones whose result sheet
/// they may review and sign off.
class MyClassSection {
  const MyClassSection({
    required this.className,
    required this.sectionName,
    required this.studentCount,
  });

  final String className;
  final String sectionName;
  final int studentCount;

  String get label => '$className-$sectionName';

  factory MyClassSection.fromJson(Map<String, dynamic> j) => MyClassSection(
    className: j['className'] as String? ?? '',
    sectionName: j['sectionName'] as String? ?? '',
    studentCount: (j['studentCount'] as num?)?.toInt() ?? 0,
  );
}

/// One subject column of a class result sheet, with how much of it is marked.
class ClassResultSubject {
  const ClassResultSubject({
    required this.subject,
    required this.fullMarks,
    required this.entered,
    required this.total,
    this.teacherName,
  });

  final String subject;
  final int fullMarks;

  /// How many of the section's students have a mark for this paper, out of
  /// how many sat it. The gap is what stops the sheet being approvable.
  final int entered;
  final int total;
  final String? teacherName;

  bool get isComplete => entered >= total;

  factory ClassResultSubject.fromJson(Map<String, dynamic> j) => ClassResultSubject(
    subject: j['subject'] as String? ?? '',
    fullMarks: (j['fullMarks'] as num?)?.toInt() ?? 100,
    entered: (j['entered'] as num?)?.toInt() ?? 0,
    total: (j['total'] as num?)?.toInt() ?? 0,
    teacherName: j['teacherName'] as String?,
  );
}

/// One student's line on the result sheet.
class ClassResultStudent {
  const ClassResultStudent({
    required this.studentId,
    this.rollNo,
    required this.name,
    required this.marks,
    required this.total,
    required this.fullTotal,
    required this.percent,
    required this.grade,
    required this.missing,
  });

  final int studentId;
  final String? rollNo;
  final String name;
  final Map<String, double?> marks;
  final double total;
  final double fullTotal;
  final double percent;
  final String grade;

  /// Papers with no mark recorded for this student yet.
  final int missing;

  factory ClassResultStudent.fromJson(Map<String, dynamic> j) => ClassResultStudent(
    studentId: (j['studentId'] as num?)?.toInt() ?? 0,
    rollNo: j['rollNo'] as String?,
    name: j['name'] as String? ?? '',
    marks: <String, double?>{
      for (final MapEntry<String, dynamic> e
          in ((j['marks'] as Map<String, dynamic>?) ?? const <String, dynamic>{}).entries)
        e.key: e.value == null ? null : (e.value as num).toDouble(),
    },
    total: _dbl(j['total']),
    fullTotal: _dbl(j['fullTotal']),
    percent: _dbl(j['percent']),
    grade: j['grade'] as String? ?? '',
    missing: (j['missing'] as num?)?.toInt() ?? 0,
  );
}

/// A section's whole result sheet for one exam, read-only, plus whether the
/// class teacher has signed it off. An admin can only publish once every
/// section that sat the exam is approved.
class ClassResult {
  const ClassResult({
    required this.examId,
    required this.examName,
    required this.isPublished,
    required this.className,
    required this.sectionName,
    required this.subjects,
    required this.students,
    required this.missingMarks,
    required this.approvalStatus,
    this.approvedByName,
    this.approvedAt,
    this.approvalRemarks,
    required this.canApprove,
  });

  final int examId;
  final String examName;
  final bool isPublished;
  final String className;
  final String sectionName;
  final List<ClassResultSubject> subjects;
  final List<ClassResultStudent> students;

  /// Marks still missing across the section — what stops it being publishable.
  final int missingMarks;

  /// pending | approved
  final String approvalStatus;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? approvalRemarks;

  /// True once every student has every paper marked. Approval is refused
  /// before that, so the button is disabled rather than failing on press.
  final bool canApprove;

  bool get isApproved => approvalStatus.toLowerCase() == 'approved';

  factory ClassResult.fromJson(Map<String, dynamic> j) => ClassResult(
    examId: (j['examId'] as num?)?.toInt() ?? 0,
    examName: j['examName'] as String? ?? '',
    isPublished: j['isPublished'] == true,
    className: j['className'] as String? ?? '',
    sectionName: j['sectionName'] as String? ?? '',
    subjects: ((j['subjects'] as List<dynamic>?) ?? const <dynamic>[])
        .map((dynamic e) => ClassResultSubject.fromJson(e as Map<String, dynamic>))
        .toList(),
    students: ((j['students'] as List<dynamic>?) ?? const <dynamic>[])
        .map((dynamic e) => ClassResultStudent.fromJson(e as Map<String, dynamic>))
        .toList(),
    missingMarks: (j['missingMarks'] as num?)?.toInt() ?? 0,
    approvalStatus: j['approvalStatus'] as String? ?? 'pending',
    approvedByName: j['approvedByName'] as String?,
    approvedAt: _date(j['approvedAt']),
    approvalRemarks: j['approvalRemarks'] as String?,
    canApprove: j['canApprove'] == true,
  );
}

/// An exam, as the marks and results pickers need it. The full record carries
/// its papers too; nothing on a phone has asked for those yet.
class SchoolExam {
  const SchoolExam({
    required this.id,
    required this.name,
    this.type,
    required this.status,
    this.startDate,
    this.endDate,
    required this.paperCount,
    this.classes,
    this.isManualStatus = false,
    this.derivedStatus = '',
    this.papers = const <ExamPaper>[],
  });

  final int id;
  final String name;
  final String? type;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final int paperCount;

  /// The classes sitting the exam, as the school typed them.
  final String? classes;

  /// True when an admin pinned the status by hand. False means the dates are
  /// driving it, and [derivedStatus] is what they say.
  final bool isManualStatus;
  final String derivedStatus;
  final List<ExamPaper> papers;

  factory SchoolExam.fromJson(Map<String, dynamic> j) => SchoolExam(
    id: (j['id'] as num?)?.toInt() ?? 0,
    name: j['name'] as String? ?? '',
    type: j['type'] as String?,
    status: j['status'] as String? ?? '',
    startDate: _date(j['startDate']),
    endDate: _date(j['endDate']),
    paperCount: (j['paperCount'] as num?)?.toInt() ?? 0,
    classes: j['classes'] as String?,
    isManualStatus: j['isManualStatus'] as bool? ?? false,
    derivedStatus: j['derivedStatus'] as String? ?? '',
    papers: ((j['papers'] as List<dynamic>?) ?? const <dynamic>[])
        .map((dynamic e) => ExamPaper.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// A section this teacher may mark, with the subjects they are assigned in it.
/// Empty subjects means they teach nothing there — being its class teacher is
/// not enough, because marks belong to the subject teacher.
class TeachingSection {
  const TeachingSection({
    required this.className,
    required this.sectionName,
    required this.studentCount,
    required this.subjects,
  });

  final String className;
  final String sectionName;
  final int studentCount;
  final List<String> subjects;

  String get label => '$className-$sectionName';

  factory TeachingSection.fromJson(Map<String, dynamic> j) => TeachingSection(
    className: j['className'] as String? ?? '',
    sectionName: j['sectionName'] as String? ?? '',
    studentCount: (j['studentCount'] as num?)?.toInt() ?? 0,
    subjects: ((j['subjects'] as List<dynamic>?) ?? const <dynamic>[])
        .map((dynamic e) => e.toString())
        .toList(),
  );
}

/// One student on the attendance sheet for a day.
class AttendanceRow {
  AttendanceRow({
    required this.studentId,
    this.rollNo,
    required this.name,
    required this.status,
  });

  final int studentId;
  final String? rollNo;
  final String name;

  /// present | absent | late | leave. Mutable: the sheet is edited in place
  /// and posted as a whole, so the row is the working copy.
  String status;

  factory AttendanceRow.fromJson(Map<String, dynamic> j) => AttendanceRow(
    studentId: (j['studentId'] as num?)?.toInt() ?? 0,
    rollNo: j['rollNo'] as String?,
    name: j['name'] as String? ?? '',
    status: (j['status'] as String? ?? 'present').toLowerCase(),
  );
}

/// One subject column of the marks grid.
class MarksSubject {
  const MarksSubject({
    required this.subject,
    required this.fullMarks,
    this.examDate,
  });

  final String subject;
  final int fullMarks;
  final DateTime? examDate;

  factory MarksSubject.fromJson(Map<String, dynamic> j) => MarksSubject(
    subject: j['subject'] as String? ?? '',
    fullMarks: (j['fullMarks'] as num?)?.toInt() ?? 100,
    examDate: _date(j['examDate']),
  );
}

/// One student row of the marks grid, with their mark per subject.
class MarksStudent {
  MarksStudent({
    required this.studentId,
    this.rollNo,
    required this.name,
    required this.marks,
  });

  final int studentId;
  final String? rollNo;
  final String name;

  /// Subject name to mark. A subject absent from the map has nothing recorded;
  /// a null value is an explicit blank. Mutable — this is the working copy.
  final Map<String, double?> marks;

  factory MarksStudent.fromJson(Map<String, dynamic> j) => MarksStudent(
    studentId: (j['studentId'] as num?)?.toInt() ?? 0,
    rollNo: j['rollNo'] as String?,
    name: j['name'] as String? ?? '',
    marks: <String, double?>{
      for (final MapEntry<String, dynamic> e
          in ((j['marks'] as Map<String, dynamic>?) ?? const <String, dynamic>{}).entries)
        e.key: e.value == null ? null : (e.value as num).toDouble(),
    },
  );
}

/// Every subject of an exam against every student of a section, so a teacher
/// can work down one subject or across one student without reloading.
class MarksGrid {
  const MarksGrid({required this.subjects, required this.students});

  final List<MarksSubject> subjects;
  final List<MarksStudent> students;

  factory MarksGrid.fromJson(Map<String, dynamic> j) => MarksGrid(
    subjects: ((j['subjects'] as List<dynamic>?) ?? const <dynamic>[])
        .map((dynamic e) => MarksSubject.fromJson(e as Map<String, dynamic>))
        .toList(),
    students: ((j['students'] as List<dynamic>?) ?? const <dynamic>[])
        .map((dynamic e) => MarksStudent.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class AdminInvoice {
  const AdminInvoice({
    required this.id,
    required this.amount,
    required this.paid,
    required this.balance,
    required this.status,
    this.invoiceNo,
    this.studentName,
    this.classLabel,
    this.month,
    this.dueDate,
  });

  final int id;
  final double amount;
  final double paid;
  final double balance;
  final String status;
  final String? invoiceNo;
  final String? studentName;
  final String? classLabel;
  final String? month;
  final DateTime? dueDate;

  factory AdminInvoice.fromJson(Map<String, dynamic> j) => AdminInvoice(
    id: _int(j['id']),
    amount: _dbl(j['amount']),
    paid: _dbl(j['paid']),
    balance: _dbl(j['balance']),
    status: j['status'] as String? ?? 'unpaid',
    invoiceNo: j['invoiceNo'] as String?,
    studentName: j['studentName'] as String?,
    classLabel: j['classLabel'] as String?,
    month: j['month'] as String?,
    dueDate: _date(j['dueDate']),
  );
}

/* ==================================================== super-admin portal == */

class PlatformStats {
  const PlatformStats({
    required this.totalSchools,
    required this.activeSubscriptions,
    required this.trialSubscriptions,
    required this.monthlyRecurringRevenue,
    required this.openTickets,
  });

  final int totalSchools;
  final int activeSubscriptions;
  final int trialSubscriptions;
  final double monthlyRecurringRevenue;
  final int openTickets;

  factory PlatformStats.fromJson(Map<String, dynamic> j) => PlatformStats(
    totalSchools: _int(j['totalSchools']),
    activeSubscriptions: _int(j['activeSubscriptions']),
    trialSubscriptions: _int(j['trialSubscriptions']),
    monthlyRecurringRevenue: _dbl(j['monthlyRecurringRevenue']),
    openTickets: _int(j['openTickets']),
  );
}

class PlatformSchool {
  const PlatformSchool({
    required this.id,
    required this.name,
    required this.status,
    required this.studentCount,
    this.schoolCode,
    this.city,
    this.planName,
  });

  final int id;
  final String name;
  final String status;
  final int studentCount;
  final String? schoolCode;
  final String? city;
  final String? planName;

  factory PlatformSchool.fromJson(Map<String, dynamic> j) => PlatformSchool(
    id: _int(j['id']),
    name: j['name'] as String? ?? '',
    status: j['status'] as String? ?? '',
    studentCount: _int(j['studentCount']),
    schoolCode: j['schoolCode'] as String?,
    city: j['city'] as String?,
    planName: j['planName'] as String?,
  );
}

class PlatformSubscription {
  const PlatformSubscription({
    required this.id,
    required this.price,
    required this.status,
    required this.billingCycle,
    this.schoolName,
    this.planName,
    this.endDate,
  });

  final int id;
  final double price;
  final String status;
  final String billingCycle;
  final String? schoolName;
  final String? planName;
  final DateTime? endDate;

  factory PlatformSubscription.fromJson(Map<String, dynamic> j) =>
      PlatformSubscription(
        id: _int(j['id']),
        price: _dbl(j['price']),
        status: j['status'] as String? ?? '',
        billingCycle: j['billingCycle'] as String? ?? '',
        schoolName: j['schoolName'] as String?,
        planName: j['planName'] as String?,
        endDate: _date(j['endDate']),
      );
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.priority,
    required this.status,
    required this.commentCount,
    this.ticketNo,
    this.schoolName,
    this.raisedByName,
    this.createdAt,
  });

  final int id;
  final String subject;
  final String priority;
  final String status;
  final int commentCount;
  final String? ticketNo;
  final String? schoolName;
  final String? raisedByName;
  final DateTime? createdAt;

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
    id: _int(j['id']),
    subject: j['subject'] as String? ?? '',
    priority: j['priority'] as String? ?? 'normal',
    status: j['status'] as String? ?? 'open',
    commentCount: _int(j['commentCount']),
    ticketNo: j['ticketNo'] as String?,
    schoolName: j['schoolName'] as String?,
    raisedByName: j['raisedByName'] as String?,
    createdAt: _date(j['createdAt']),
  );
}
