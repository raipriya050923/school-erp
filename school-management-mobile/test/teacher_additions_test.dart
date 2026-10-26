import 'package:flutter_test/flutter_test.dart';

import 'package:school_management_mobile/data/staff_models.dart';
import 'package:school_management_mobile/features/staff/class_result_csv.dart';

/// The teacher additions: roster, per-paper marking progress, and the CSV the
/// Class Results screen exports.
void main() {
  group('roster', () {
    test('parses a student', () {
      final RosterStudent s = RosterStudent.fromJson(<String, dynamic>{
        'id': 12,
        'rollNo': '7',
        'name': 'Anisha Rai',
      });
      expect(s.id, 12);
      expect(s.rollNo, '7');
      expect(s.name, 'Anisha Rai');
    });

    test('an unnumbered student parses rather than failing', () {
      final RosterStudent s = RosterStudent.fromJson(<String, dynamic>{
        'id': 13,
        'name': 'Sagar Basnet',
      });
      expect(s.rollNo, isNull);
    });
  });

  group('marks progress', () {
    test('parses, and knows when a paper is finished', () {
      final MarksProgress p = MarksProgress.fromJson(<String, dynamic>{
        'subject': 'Science',
        'fullMarks': 100,
        'examDate': '2026-11-14T00:00:00',
        'entered': 30,
        'total': 30,
      });
      expect(p.subject, 'Science');
      expect(p.fullMarks, 100);
      expect(p.examDate, DateTime(2026, 11, 14));
      expect(p.isComplete, isTrue);
    });

    test('a part-marked paper is not complete', () {
      expect(
        MarksProgress.fromJson(<String, dynamic>{
          'subject': 'English',
          'entered': 18,
          'total': 30,
        }).isComplete,
        isFalse,
      );
    });

    test('a paper with no students is not "complete"', () {
      // 0 of 0 would otherwise read as finished and hide a section with
      // nobody enrolled.
      expect(
        MarksProgress.fromJson(
          <String, dynamic>{'subject': 'Maths', 'entered': 0, 'total': 0},
        ).isComplete,
        isFalse,
      );
    });
  });

  group('class result CSV', () {
    final ClassResult result = ClassResult.fromJson(<String, dynamic>{
      'examId': 3,
      'examName': 'Terminal Exam',
      'className': 'Grade 6',
      'sectionName': 'A',
      'isPublished': false,
      'approvalStatus': 'pending',
      'missingMarks': 1,
      'subjects': <dynamic>[
        <String, dynamic>{'subject': 'English', 'fullMarks': 100},
        <String, dynamic>{'subject': 'Maths, Applied', 'fullMarks': 50},
      ],
      'students': <dynamic>[
        <String, dynamic>{
          'studentId': 1,
          'rollNo': '1',
          'name': 'Anisha Rai',
          'marks': <String, dynamic>{'English': 82, 'Maths, Applied': 40},
          'total': 122,
          'fullTotal': 150,
          'percent': 81.3,
          'grade': 'A',
          'missing': 0,
          'isComplete': true,
        },
        <String, dynamic>{
          'studentId': 2,
          'rollNo': '2',
          'name': 'Sagar "Sam" Basnet',
          'marks': <String, dynamic>{'English': 70},
          'total': 70,
          'fullTotal': 150,
          'percent': 46.7,
          'grade': 'C',
          'missing': 1,
          'isComplete': false,
        },
      ],
    });

    test('header carries every paper with its full marks', () {
      final String csv = String.fromCharCodes(ClassResultCsv.build(result));
      final String header = csv.split('\r\n').first;
      expect(header, contains('"English (/100)"'));
      expect(header, contains('"Maths, Applied (/50)"'));
      expect(header, contains('"Roll"'));
      expect(header, contains('"Grade"'));
    });

    test('a comma in a subject name does not split the column', () {
      final String csv = String.fromCharCodes(ClassResultCsv.build(result));
      // Two papers plus Roll, Student, Total, % and Grade.
      expect(csv.split('\r\n').first.split('","').length, 7);
    });

    test('a quote in a name is doubled, not dropped', () {
      final String csv = String.fromCharCodes(ClassResultCsv.build(result));
      expect(csv, contains('"Sagar ""Sam"" Basnet"'));
    });

    test('percent is blank while a paper is unmarked', () {
      final List<String> rows =
          String.fromCharCodes(ClassResultCsv.build(result)).split('\r\n');
      // Anisha is complete and keeps her percentage.
      expect(rows[1], contains('"81.3"'));
      // Sagar is missing a paper, so the cell is empty rather than a figure
      // that can only rise.
      expect(rows[2], contains('"70/150","","C"'));
    });

    test('the file is named for the exam and section', () {
      expect(ClassResultCsv.fileName(result), 'Terminal Exam-Grade 6-A.csv');
    });

    test('starts with a BOM so a spreadsheet reads it as UTF-8', () {
      expect(ClassResultCsv.build(result).first, 0xEF);
    });
  });
}
