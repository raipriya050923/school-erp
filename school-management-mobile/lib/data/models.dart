import 'package:flutter/material.dart';

// ---------------------------------------------------------------- timetable

@immutable
class ClassPeriod {
  const ClassPeriod({
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.teacher,
    required this.room,
  });

  final String startTime;
  final String endTime;
  final String subject;
  final String teacher;
  final String room;

  String get timeRange => '$startTime - $endTime';
}

// --------------------------------------------------------------- attendance

enum DayStatus { present, absent, late, holiday, weekend }

extension DayStatusX on DayStatus {
  String get label => switch (this) {
    DayStatus.present => 'Present',
    DayStatus.absent => 'Absent',
    DayStatus.late => 'Late',
    DayStatus.holiday => 'Holiday',
    DayStatus.weekend => 'Weekend',
  };
}

@immutable
class AttendanceDay {
  const AttendanceDay({required this.date, required this.status, this.note});

  final int date;
  final DayStatus status;
  final String? note;
}

@immutable
class AttendanceMonth {
  const AttendanceMonth({
    required this.name,
    required this.year,
    required this.firstWeekdayOffset,
    required this.totalDays,
    required this.present,
    required this.absent,
    required this.late,
    required this.holidays,
    required this.days,
  });

  final String name;
  final int year;

  /// Number of blank cells before day 1 in the calendar grid (Sunday-first).
  final int firstWeekdayOffset;
  final int totalDays;
  final int present;
  final int absent;
  final int late;
  final int holidays;
  final List<AttendanceDay> days;

  double get percentage => totalDays == 0 ? 0 : (present / totalDays) * 100;
}

@immutable
class SubjectAttendance {
  const SubjectAttendance({
    required this.subject,
    required this.total,
    required this.attended,
  });

  final String subject;
  final int total;
  final int attended;

  double get percentage => total == 0 ? 0 : (attended / total) * 100;
}

@immutable
class AttendanceRecord {
  const AttendanceRecord({
    required this.date,
    required this.day,
    required this.status,
    this.checkIn,
    this.checkOut,
    this.note,
  });

  final String date;
  final String day;
  final DayStatus status;
  final String? checkIn;
  final String? checkOut;
  final String? note;
}

// ------------------------------------------------------------------ results

@immutable
class SubjectResult {
  const SubjectResult({
    required this.name,
    required this.maxMarks,
    required this.obtained,
    required this.grade,
    this.passed = true,
  });

  final String name;
  final int maxMarks;
  final int obtained;
  final String grade;
  final bool passed;

  double get percentage => maxMarks == 0 ? 0 : (obtained / maxMarks) * 100;
}

@immutable
class ExamResult {
  const ExamResult({
    required this.exam,
    required this.examDate,
    required this.totalMarks,
    required this.obtained,
    required this.grade,
    required this.rank,
    required this.totalStudents,
    required this.subjects,
  });

  final String exam;
  final String examDate;
  final int totalMarks;
  final int obtained;
  final String grade;
  final int rank;
  final int totalStudents;
  final List<SubjectResult> subjects;

  double get percentage => totalMarks == 0 ? 0 : (obtained / totalMarks) * 100;
}

// -------------------------------------------------------------- assignments

enum AssignmentStatus { pending, submitted, graded, overdue }

extension AssignmentStatusX on AssignmentStatus {
  String get label => switch (this) {
    AssignmentStatus.pending => 'Pending',
    AssignmentStatus.submitted => 'Submitted',
    AssignmentStatus.graded => 'Graded',
    AssignmentStatus.overdue => 'Overdue',
  };
}

@immutable
class Assignment {
  const Assignment({
    required this.id,
    required this.title,
    required this.subject,
    required this.teacher,
    required this.assignedDate,
    required this.dueDate,
    required this.status,
    required this.description,
    required this.maxMarks,
    this.attachments = const <String>[],
    this.submittedDate,
    this.obtainedMarks,
    this.feedback,
  });

  final int id;
  final String title;
  final String subject;
  final String teacher;
  final String assignedDate;
  final String dueDate;
  final AssignmentStatus status;
  final String description;
  final int maxMarks;
  final List<String> attachments;
  final String? submittedDate;
  final int? obtainedMarks;
  final String? feedback;
}

// --------------------------------------------------------------------- fees

@immutable
class FeeComponent {
  const FeeComponent({
    required this.name,
    required this.amount,
    required this.frequency,
  });

  final String name;
  final int amount;
  final String frequency;
}

@immutable
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    required this.receiptNo,
    required this.paymentMethod,
  });

  final String id;
  final String date;
  final String description;
  final int amount;
  final String receiptNo;
  final String paymentMethod;
}

enum PendingStatus { dueSoon, upcoming }

@immutable
class PendingPayment {
  const PendingPayment({
    required this.id,
    required this.description,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.lateFee = 0,
  });

  final String id;
  final String description;
  final int amount;
  final String dueDate;
  final PendingStatus status;
  final int lateFee;
}

// ------------------------------------------------------------ notifications

enum NotificationType { assignment, exam, fee, event, result, general }

extension NotificationTypeX on NotificationType {
  String get label => switch (this) {
    NotificationType.assignment => 'Assignment',
    NotificationType.exam => 'Exam',
    NotificationType.fee => 'Fee',
    NotificationType.event => 'Event',
    NotificationType.result => 'Result',
    NotificationType.general => 'General',
  };
}

enum NotificationPriority { high, medium, low }

extension NotificationPriorityX on NotificationPriority {
  String get label => switch (this) {
    NotificationPriority.high => 'High',
    NotificationPriority.medium => 'Medium',
    NotificationPriority.low => 'Low',
  };
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.date,
    required this.time,
    required this.priority,
    this.read = false,
  });

  final int id;
  final String title;
  final String message;
  final NotificationType type;
  final String date;
  final String time;
  final NotificationPriority priority;
  bool read;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    title: title,
    message: message,
    type: type,
    date: date,
    time: time,
    priority: priority,
    read: read ?? this.read,
  );
}

// ------------------------------------------------------------------ student

@immutable
class Achievement {
  const Achievement({
    required this.title,
    required this.date,
    required this.description,
  });

  final String title;
  final String date;
  final String description;
}

@immutable
class Guardian {
  const Guardian({
    required this.relation,
    required this.name,
    required this.occupation,
    required this.phone,
    required this.email,
  });

  final String relation;
  final String name;
  final String occupation;
  final String phone;
  final String email;
}

@immutable
class Student {
  const Student({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodGroup,
    required this.address,
    required this.nationality,
    required this.studentId,
    required this.className,
    required this.section,
    required this.rollNumber,
    required this.admissionDate,
    required this.academicYear,
    required this.house,
    required this.classTeacher,
    required this.guardians,
    required this.achievements,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String dateOfBirth;
  final String gender;
  final String bloodGroup;
  final String address;
  final String nationality;

  final String studentId;
  final String className;
  final String section;
  final String rollNumber;
  final String admissionDate;
  final String academicYear;
  final String house;
  final String classTeacher;

  final List<Guardian> guardians;
  final List<Achievement> achievements;

  String get fullName => '$firstName $lastName';

  String get initials =>
      '${firstName.substring(0, 1)}${lastName.substring(0, 1)}'.toUpperCase();
}
