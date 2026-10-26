import 'dart:convert';
import 'dart:typed_data';

import 'package:printing/printing.dart';

import '../../data/staff_models.dart';

/// A class result sheet as a CSV file.
///
/// The same columns in the same order as the web's Export CSV, so a sheet
/// exported from a phone and one exported from a desk open identically in a
/// spreadsheet — an office comparing two files should be comparing marks, not
/// column layouts.
///
/// Handed to the system share sheet, which is where a phone keeps "save to
/// Downloads" and "send"; there is no download folder to write to directly.
class ClassResultCsv {
  const ClassResultCsv._();

  /// `Terminal-Exam-Grade-6-A.csv`, with anything a file system dislikes
  /// replaced — the web strips the same set.
  static String fileName(ClassResult r) =>
      '${r.examName}-${r.className}-${r.sectionName}.csv'
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');

  static Future<void> share(ClassResult r) async {
    await Printing.sharePdf(bytes: build(r), filename: fileName(r));
  }

  static Uint8List build(ClassResult r) {
    // Quote every cell and double any quote inside it: a subject called
    // "Maths, Applied" would otherwise split into two columns.
    String esc(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';

    final List<String> header = <String>[
      'Roll',
      'Student',
      for (final ClassResultSubject p in r.subjects)
        '${p.subject} (/${p.fullMarks})',
      'Total',
      '%',
      'Grade',
    ];

    final List<String> lines = <String>[header.map(esc).join(',')];

    for (final ClassResultStudent s in r.students) {
      final List<Object?> cells = <Object?>[
        s.rollNo,
        s.name,
        for (final ClassResultSubject p in r.subjects) s.marks[p.subject] ?? '',
        '${_num(s.total)}/${_num(s.fullTotal)}',
        // Blank while a paper is unmarked: a percentage that can only rise is
        // not a result, and printing it invites someone to quote it.
        s.missing > 0 ? '' : _num(s.percent),
        s.grade,
      ];
      lines.add(cells.map(esc).join(','));
    }

    // CRLF and a BOM, because the spreadsheet most of these will be opened in
    // assumes the local code page without one and mangles any non-ASCII name.
    final String csv = '﻿${lines.join('\r\n')}';
    return Uint8List.fromList(utf8.encode(csv));
  }

  /// `88.0` -> `88`, `87.4` -> `87.4`.
  static String _num(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();
}
