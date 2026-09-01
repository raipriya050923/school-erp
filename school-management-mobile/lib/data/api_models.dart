/// Dart mirrors of the `/api/student/*` DTOs. Field names and nullability match
/// the server exactly — anything the API does not send stays null here rather
/// than being invented locally.
library;

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse(v as String);

double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

// ------------------------------------------------------------------ profile

class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.admissionNo,
    required this.name,
    this.className,
    this.sectionName,
    this.rollNo,
  });

  final int id;
  final String admissionNo;
  final String name;
  final String? className;
  final String? sectionName;
  final String? rollNo;

  String get classLabel => <String?>[className, sectionName]
      .where((String? s) => s != null && s.isNotEmpty)
      .join(' · ');

  String get initials {
    final List<String> parts =
        name.trim().split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((String p) => p[0].toUpperCase()).join();
  }

  factory StudentProfile.fromJson(Map<String, dynamic> j) => StudentProfile(
    id: _int(j['id']),
    admissionNo: j['admissionNo'] as String? ?? '',
    name: j['name'] as String? ?? '',
    className: j['className'] as String?,
    sectionName: j['sectionName'] as String?,
    rollNo: j['rollNo'] as String?,
  );
}

// ---------------------------------------------------------------- dashboard

class StudentDashboard {
  const StudentDashboard({
    required this.name,
    this.className,
    this.sectionName,
    this.rollNo,
    required this.attendancePercent,
    required this.presentDays,
    required this.totalDays,
    required this.pendingHomework,
    this.nextExamName,
    this.nextExamDate,
    required this.feeDue,
    required this.upcomingHomework,
  });

  final String name;
  final String? className;
  final String? sectionName;
  final String? rollNo;
  final int attendancePercent;
  final int presentDays;
  final int totalDays;
  final int pendingHomework;
  final String? nextExamName;
  final DateTime? nextExamDate;
  final double feeDue;
  final List<StudentHomework> upcomingHomework;

  factory StudentDashboard.fromJson(Map<String, dynamic> j) => StudentDashboard(
    name: j['name'] as String? ?? '',
    className: j['className'] as String?,
    sectionName: j['sectionName'] as String?,
    rollNo: j['rollNo'] as String?,
    attendancePercent: _int(j['attendancePercent']),
    presentDays: _int(j['presentDays']),
    totalDays: _int(j['totalDays']),
    pendingHomework: _int(j['pendingHomework']),
    nextExamName: j['nextExamName'] as String?,
    nextExamDate: _date(j['nextExamDate']),
    feeDue: _num(j['feeDue']),
    upcomingHomework: (j['upcomingHomework'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) => StudentHomework.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// --------------------------------------------------------------- attendance

class AttendanceMonthSummary {
  const AttendanceMonthSummary({
    required this.month,
    required this.present,
    required this.absent,
    required this.late,
    required this.percent,
  });

  final String month;
  final int present;
  final int absent;
  final int late;
  final int percent;

  factory AttendanceMonthSummary.fromJson(Map<String, dynamic> j) =>
      AttendanceMonthSummary(
        month: j['month'] as String? ?? '',
        present: _int(j['present']),
        absent: _int(j['absent']),
        late: _int(j['late']),
        percent: _int(j['percent']),
      );
}

class AttendanceEntry {
  const AttendanceEntry({
    required this.date,
    required this.day,
    required this.status,
  });

  final String date;
  final String day;
  final String status;

  factory AttendanceEntry.fromJson(Map<String, dynamic> j) => AttendanceEntry(
    date: j['date'] as String? ?? '',
    day: j['day'] as String? ?? '',
    status: j['status'] as String? ?? '',
  );
}

class StudentAttendance {
  const StudentAttendance({
    required this.overallPercent,
    required this.presentDays,
    required this.totalDays,
    required this.months,
    required this.recent,
  });

  final int overallPercent;
  final int presentDays;
  final int totalDays;
  final List<AttendanceMonthSummary> months;
  final List<AttendanceEntry> recent;

  factory StudentAttendance.fromJson(Map<String, dynamic> j) => StudentAttendance(
    overallPercent: _int(j['overallPercent']),
    presentDays: _int(j['presentDays']),
    totalDays: _int(j['totalDays']),
    months: (j['months'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) =>
            AttendanceMonthSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
    recent: (j['recent'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) => AttendanceEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// ---------------------------------------------------------------- timetable

class TimetableSlot {
  const TimetableSlot({
    required this.dayOfWeek,
    required this.periodNo,
    this.time,
    this.subject,
    this.room,
  });

  /// 1 = Sunday through 7 = Saturday, as stored by the API.
  final int dayOfWeek;
  final int periodNo;
  final String? time;
  final String? subject;
  final String? room;

  factory TimetableSlot.fromJson(Map<String, dynamic> j) => TimetableSlot(
    dayOfWeek: _int(j['dayOfWeek']),
    periodNo: _int(j['periodNo']),
    time: j['time'] as String?,
    subject: j['subject'] as String?,
    room: j['room'] as String?,
  );
}

// ----------------------------------------------------------------- homework

class StudentHomework {
  const StudentHomework({
    required this.title,
    this.subject,
    this.dueDate,
    required this.status,
  });

  final String title;
  final String? subject;
  final DateTime? dueDate;
  final String status;

  factory StudentHomework.fromJson(Map<String, dynamic> j) => StudentHomework(
    title: j['title'] as String? ?? '',
    subject: j['subject'] as String?,
    dueDate: _date(j['dueDate']),
    status: j['status'] as String? ?? '',
  );
}

// -------------------------------------------------------------------- exams

class SubjectResultRow {
  const SubjectResultRow({
    required this.subject,
    required this.fullMarks,
    this.marks,
    required this.grade,
  });

  final String subject;
  final double fullMarks;
  final double? marks;
  final String grade;

  double get percent => fullMarks == 0 || marks == null ? 0 : marks! / fullMarks * 100;

  factory SubjectResultRow.fromJson(Map<String, dynamic> j) => SubjectResultRow(
    subject: j['subject'] as String? ?? '',
    fullMarks: _num(j['fullMarks']),
    marks: (j['marks'] as num?)?.toDouble(),
    grade: j['grade'] as String? ?? '',
  );
}

class UpcomingPaper {
  const UpcomingPaper({this.date, required this.subject, this.time, this.room});

  final DateTime? date;
  final String subject;
  final String? time;
  final String? room;

  factory UpcomingPaper.fromJson(Map<String, dynamic> j) => UpcomingPaper(
    date: _date(j['date']),
    subject: j['subject'] as String? ?? '',
    time: j['time'] as String?,
    room: j['room'] as String?,
  );
}

class StudentExams {
  const StudentExams({
    this.examName,
    required this.total,
    required this.fullTotal,
    required this.percent,
    required this.grade,
    required this.results,
    required this.upcoming,
  });

  final String? examName;
  final double total;
  final double fullTotal;
  final int percent;
  final String grade;
  final List<SubjectResultRow> results;
  final List<UpcomingPaper> upcoming;

  factory StudentExams.fromJson(Map<String, dynamic> j) => StudentExams(
    examName: j['examName'] as String?,
    total: _num(j['total']),
    fullTotal: _num(j['fullTotal']),
    percent: _int(j['percent']),
    grade: j['grade'] as String? ?? '',
    results: (j['results'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) => SubjectResultRow.fromJson(e as Map<String, dynamic>))
        .toList(),
    upcoming: (j['upcoming'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) => UpcomingPaper.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// --------------------------------------------------------------------- fees

class StudentFee {
  const StudentFee({
    this.invoiceNo,
    this.month,
    required this.amount,
    required this.paid,
    required this.balance,
    this.dueDate,
    required this.status,
  });

  final String? invoiceNo;
  final String? month;
  final double amount;
  final double paid;
  final double balance;
  final DateTime? dueDate;
  final String status;

  bool get isSettled => status.toLowerCase() == 'paid' || balance <= 0;

  factory StudentFee.fromJson(Map<String, dynamic> j) => StudentFee(
    invoiceNo: j['invoiceNo'] as String?,
    month: j['month'] as String?,
    amount: _num(j['amount']),
    paid: _num(j['paid']),
    balance: _num(j['balance']),
    dueDate: _date(j['dueDate']),
    status: j['status'] as String? ?? '',
  );
}

// ------------------------------------------------------------------ notices

class StudentNotice {
  const StudentNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.publishDate,
  });

  final int id;
  final String title;
  final String body;
  final String audience;
  final DateTime publishDate;

  factory StudentNotice.fromJson(Map<String, dynamic> j) => StudentNotice(
    id: _int(j['id']),
    title: j['title'] as String? ?? '',
    body: j['body'] as String? ?? '',
    audience: j['audience'] as String? ?? '',
    publishDate: _date(j['publishDate']) ?? DateTime.now(),
  );
}
