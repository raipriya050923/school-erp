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

/// One column of the school's day, including breaks.
///
/// The API grew this list when the web timetable was fixed: period_no counts
/// breaks, so a school with a break at 4 has teaching periods numbered 1,2,3,
/// 5,6,7. Labelling a slot "Period 5" from its number alone is therefore wrong
/// by one from the break onwards, and drops the last period of the day.
class TimetablePeriod {
  const TimetablePeriod({
    required this.periodNo,
    required this.name,
    required this.timeLabel,
    required this.isBreak,
  });

  final int periodNo;
  final String name;
  final String timeLabel;
  final bool isBreak;

  factory TimetablePeriod.fromJson(Map<String, dynamic> j) => TimetablePeriod(
    periodNo: _int(j['periodNo']),
    name: j['name'] as String? ?? '',
    timeLabel: j['timeLabel'] as String? ?? '',
    isBreak: j['isBreak'] == true,
  );
}

/// The whole timetable payload.
///
/// This endpoint used to return a bare array of slots. It now returns an
/// object carrying the school's real period list and its working days, so the
/// grid can be drawn from what the school actually configured rather than from
/// a hardcoded week.
class StudentTimetable {
  const StudentTimetable({
    required this.periods,
    required this.workingDays,
    required this.slots,
    this.className,
    this.sectionName,
  });

  final List<TimetablePeriod> periods;

  /// Day numbers the school runs, 1 = Sunday. Days outside it are not shown.
  final List<int> workingDays;
  final List<TimetableSlot> slots;
  final String? className;
  final String? sectionName;

  static const StudentTimetable empty = StudentTimetable(
    periods: <TimetablePeriod>[],
    workingDays: <int>[],
    slots: <TimetableSlot>[],
  );

  /// The configured name for a slot's column, e.g. "P4". Falls back to the raw
  /// number for a school whose period list has not been set up.
  String labelFor(int periodNo) {
    for (final TimetablePeriod p in periods) {
      if (p.periodNo == periodNo) return p.name;
    }
    return 'Period $periodNo';
  }

  factory StudentTimetable.fromJson(Map<String, dynamic> j) => StudentTimetable(
    className: j['className'] as String?,
    sectionName: j['sectionName'] as String?,
    periods: (j['periods'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) => TimetablePeriod.fromJson(e as Map<String, dynamic>))
        .toList(),
    workingDays: (j['workingDays'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) => _int(e))
        .toList(),
    slots: (j['slots'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) => TimetableSlot.fromJson(e as Map<String, dynamic>))
        .toList(),
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
    required this.id,
    this.invoiceNo,
    this.month,
    required this.amount,
    required this.paid,
    required this.balance,
    this.dueDate,
    required this.status,
  });

  /// The invoice's own id. Needed to ask for its payments; the model carried
  /// only the printed number before, which the API does not accept as a key.
  final int id;
  final String? invoiceNo;
  final String? month;
  final double amount;
  final double paid;
  final double balance;
  final DateTime? dueDate;
  final String status;

  bool get isSettled => status.toLowerCase() == 'paid' || balance <= 0;

  factory StudentFee.fromJson(Map<String, dynamic> j) => StudentFee(
    id: (j['id'] as num?)?.toInt() ?? 0,
    invoiceNo: j['invoiceNo'] as String?,
    month: j['month'] as String?,
    amount: _num(j['amount']),
    paid: _num(j['paid']),
    balance: _num(j['balance']),
    dueDate: _date(j['dueDate']),
    status: j['status'] as String? ?? '',
  );
}

/// One payment against an invoice, as the list shows it before a receipt is
/// opened. Receipts are per payment, not per invoice: a family paying in two
/// instalments gets two, each showing what was handed over that day.
class FeePayment {
  const FeePayment({
    required this.id,
    required this.receiptNo,
    required this.amount,
    this.method,
    this.reference,
    this.paidDate,
    required this.balanceAfter,
  });

  final int id;
  final String receiptNo;
  final double amount;
  final String? method;
  final String? reference;
  final DateTime? paidDate;
  final double balanceAfter;

  factory FeePayment.fromJson(Map<String, dynamic> j) => FeePayment(
    id: (j['id'] as num?)?.toInt() ?? 0,
    receiptNo: j['receiptNo'] as String? ?? '',
    amount: _num(j['amount']),
    method: j['method'] as String?,
    reference: j['reference'] as String?,
    paidDate: _date(j['paidDate']),
    balanceAfter: _num(j['balanceAfter']),
  );
}

/// One head's share of what the invoice was raised for.
class ReceiptLine {
  const ReceiptLine({required this.description, required this.amount});

  final String description;
  final double amount;

  factory ReceiptLine.fromJson(Map<String, dynamic> j) => ReceiptLine(
    description: j['description'] as String? ?? '',
    amount: _num(j['amount']),
  );
}

/// Everything printed on a receipt. Mirrors FeeReceiptDto on the API, so the
/// paper copy, the web copy and this one cannot disagree.
class FeeReceipt {
  const FeeReceipt({
    required this.schoolName,
    this.schoolAddress,
    this.schoolPhone,
    this.schoolEmail,
    required this.receiptNo,
    this.paidDate,
    required this.issuedAt,
    required this.studentName,
    this.admissionNo,
    this.classLabel,
    this.invoiceNo,
    this.month,
    required this.lines,
    required this.amountPaid,
    required this.amountInWords,
    this.method,
    this.reference,
    required this.invoiceTotal,
    required this.paidToDate,
    required this.balanceAfter,
  });

  final String schoolName;
  final String? schoolAddress;
  final String? schoolPhone;
  final String? schoolEmail;
  final String receiptNo;
  final DateTime? paidDate;
  final DateTime issuedAt;
  final String studentName;
  final String? admissionNo;
  final String? classLabel;
  final String? invoiceNo;
  final String? month;
  final List<ReceiptLine> lines;
  final double amountPaid;
  final String amountInWords;
  final String? method;
  final String? reference;
  final double invoiceTotal;
  final double paidToDate;
  final double balanceAfter;

  /// Methods are stored as slugs; a receipt should not read "bank_transfer".
  String get methodLabel {
    final String m = (method ?? '').replaceAll('_', ' ').trim();
    if (m.isEmpty) return '—';
    return m[0].toUpperCase() + m.substring(1);
  }

  factory FeeReceipt.fromJson(Map<String, dynamic> j) => FeeReceipt(
    schoolName: j['schoolName'] as String? ?? '',
    schoolAddress: j['schoolAddress'] as String?,
    schoolPhone: j['schoolPhone'] as String?,
    schoolEmail: j['schoolEmail'] as String?,
    receiptNo: j['receiptNo'] as String? ?? '',
    paidDate: _date(j['paidDate']),
    issuedAt: _date(j['issuedAt']) ?? DateTime.now(),
    studentName: j['studentName'] as String? ?? '',
    admissionNo: j['admissionNo'] as String?,
    classLabel: j['classLabel'] as String?,
    invoiceNo: j['invoiceNo'] as String?,
    month: j['month'] as String?,
    lines: ((j['lines'] as List<dynamic>?) ?? const <dynamic>[])
        .map((dynamic e) => ReceiptLine.fromJson(e as Map<String, dynamic>))
        .toList(),
    amountPaid: _num(j['amountPaid']),
    amountInWords: j['amountInWords'] as String? ?? '',
    method: j['method'] as String?,
    reference: j['reference'] as String?,
    invoiceTotal: _num(j['invoiceTotal']),
    paidToDate: _num(j['paidToDate']),
    balanceAfter: _num(j['balanceAfter']),
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
