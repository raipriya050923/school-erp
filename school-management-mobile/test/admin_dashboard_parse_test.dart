import 'package:flutter_test/flutter_test.dart';

import 'package:school_management_mobile/data/staff_models.dart';

/// The admin dashboard payload, parsed.
///
/// The counters were read and the rest of the payload — today's attendance, the
/// trend, the admissions and the notices — was discarded by `fromJson`, so the
/// web dashboard's charts and tables had no data to render from on mobile.
void main() {
  const Map<String, dynamic> payload = <String, dynamic>{
    'schoolName': 'Sunrise Public School',
    'academicYear': '2026-27',
    'totalStudents': 1249,
    'totalTeachers': 12,
    'teachersOnLeave': 1,
    'totalClasses': 5,
    'totalSections': 10,
    'feesDue': 34201000,
    'feesBilled': 34341000,
    'feesCollected': 140000,
    'feesOverdue': 16015500,
    'unpaidInvoices': 2716,
    'attendanceToday': null,
    'attendanceTrend': <dynamic>[
      <String, dynamic>{
        'date': '2026-06-01T00:00:00',
        'percent': 94.0,
        'present': 1170,
        'total': 1245,
      },
      <String, dynamic>{
        'date': '2026-06-02T00:00:00',
        'percent': 71.0,
        'present': 884,
        'total': 1245,
      },
    ],
    'recentAdmissions': <dynamic>[
      <String, dynamic>{
        'name': 'Sunil Rai',
        'className': 'Grade 6',
        'sectionName': 'A',
        'admissionDate': '2026-10-25T00:00:00',
      },
    ],
    'latestNotices': <dynamic>[
      <String, dynamic>{
        'id': 3,
        'title': 'Parent-teacher meeting',
        'body': 'Saturday at 10am.',
        'audience': 'parents',
        'publishDate': '2026-10-20T00:00:00',
        'createdBy': 11,
        'createdByName': 'Anita Sharma',
      },
    ],
  };

  test('the attendance trend survives parsing', () {
    final AdminDashboard d = AdminDashboard.fromJson(payload);

    expect(d.attendanceTrend, hasLength(2));
    expect(d.attendanceTrend.first.percent, 94.0);
    expect(d.attendanceTrend.first.present, 1170);
    expect(d.attendanceTrend.first.date, DateTime(2026, 6, 1));
  });

  test('the average is the mean of the trend', () {
    final AdminDashboard d = AdminDashboard.fromJson(payload);

    // (94 + 71) / 2
    expect(d.averageAttendance, 82.5);
  });

  test('a null attendanceToday stays null rather than becoming zero', () {
    final AdminDashboard d = AdminDashboard.fromJson(payload);

    // Nobody has marked it yet, which the dashboard shows as a dash. Zero would
    // read as "nobody came".
    expect(d.attendanceToday, isNull);
  });

  test('admissions and notices survive parsing', () {
    final AdminDashboard d = AdminDashboard.fromJson(payload);

    expect(d.recentAdmissions, hasLength(1));
    expect(d.recentAdmissions.single.name, 'Sunil Rai');
    expect(d.recentAdmissions.single.classLabel, 'Grade 6-A');

    expect(d.latestNotices, hasLength(1));
    expect(d.latestNotices.single.title, 'Parent-teacher meeting');
    expect(d.latestNotices.single.audience, 'parents');
  });

  test('outstanding fees are read', () {
    expect(AdminDashboard.fromJson(payload).feesDue, 34201000);
  });

  test('an older API that omits the new fields still parses', () {
    final AdminDashboard d = AdminDashboard.fromJson(<String, dynamic>{
      'schoolName': 'Sunrise Public School',
      'totalStudents': 10,
    });

    expect(d.attendanceTrend, isEmpty);
    expect(d.recentAdmissions, isEmpty);
    expect(d.latestNotices, isEmpty);
    expect(d.averageAttendance, isNull);
    expect(d.totalStudents, 10);
  });
}
