import 'package:flutter_test/flutter_test.dart';

import 'package:school_management_mobile/data/staff_models.dart';

/// The dashboard payload, parsed.
///
/// `recentHomework` used to be absent from the model, so the API sent the list
/// and `fromJson` threw it away in silence. A shape test is what catches that:
/// nothing crashes when a field is dropped, it simply never appears.
void main() {
  // Trimmed from a real GET /api/teacher/dashboard/stats response.
  const Map<String, dynamic> payload = <String, dynamic>{
    'profile': <String, dynamic>{
      'name': 'Sunita Gurung',
      'employeeCode': 'EMP-008',
      'subject': 'English',
    },
    'myClassesCount': 2,
    'studentsTaught': 64,
    'submissionsToGrade': 12,
    'openHomework': 2,
    'recentHomework': <dynamic>[
      <String, dynamic>{
        'id': 1,
        'title': 'Essay on monsoon',
        'subject': 'English',
        'classLabel': 'Grade 6 - A',
        'assignedDate': '2026-11-01T00:00:00',
        'dueDate': '2026-11-14T00:00:00',
        'submitted': 18,
        'total': 30,
        'status': 'open',
      },
    ],
  };

  test('the homework list survives parsing', () {
    final TeacherDashboard d = TeacherDashboard.fromJson(payload);

    expect(d.recentHomework, hasLength(1));
    final TeacherHomework h = d.recentHomework.single;
    expect(h.id, 1);
    expect(h.title, 'Essay on monsoon');
    expect(h.classLabel, 'Grade 6 - A');
    expect(h.submitted, 18);
    expect(h.total, 30);
    expect(h.status, 'open');
    expect(h.dueDate, DateTime(2026, 11, 14));
  });

  test('the profile keeps the subject and employee code the header shows', () {
    final TeacherDashboard d = TeacherDashboard.fromJson(payload);

    expect(d.profile.name, 'Sunita Gurung');
    expect(d.profile.subject, 'English');
    expect(d.profile.employeeCode, 'EMP-008');
  });

  test('an older API that sends no homework array still parses', () {
    // The field is read defensively: a deployment one version behind must not
    // crash the dashboard, it should simply show an empty list.
    final TeacherDashboard d = TeacherDashboard.fromJson(<String, dynamic>{
      'profile': <String, dynamic>{'name': 'Kamala Tamang'},
      'myClassesCount': 1,
      'studentsTaught': 30,
      'submissionsToGrade': 0,
      'openHomework': 0,
    });

    expect(d.recentHomework, isEmpty);
    expect(d.profile.name, 'Kamala Tamang');
  });
}
