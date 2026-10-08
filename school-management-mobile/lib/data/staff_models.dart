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
    this.reason,
    this.fromDate,
    this.toDate,
  });

  final int id;
  final String status;
  final double days;
  final String? leaveTypeName;
  final String? reason;
  final DateTime? fromDate;
  final DateTime? toDate;

  factory LeaveApplication.fromJson(Map<String, dynamic> j) => LeaveApplication(
    id: _int(j['id']),
    status: j['status'] as String? ?? 'pending',
    days: _dbl(j['days']),
    leaveTypeName: j['leaveTypeName'] as String?,
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
