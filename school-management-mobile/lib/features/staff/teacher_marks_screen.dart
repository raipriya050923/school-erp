import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_theme.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// Marks entry for the subjects a teacher is assigned.
///
/// The web shows every subject against every student as one grid. A phone has
/// no room for that, so this works one subject at a time: pick the exam, the
/// section and the subject, then run down the class entering marks. The
/// underlying call is the same grid endpoint, and only the cells for the
/// chosen subject are sent — so a teacher filling in Mathematics cannot wipe
/// somebody else's English.
///
/// Only sections and subjects this teacher is assigned appear. The API refuses
/// anything else, and offering a choice it will refuse is a trap.
class TeacherMarksScreen extends StatefulWidget {
  const TeacherMarksScreen({super.key});

  @override
  State<TeacherMarksScreen> createState() => _TeacherMarksScreenState();
}

class _TeacherMarksScreenState extends State<TeacherMarksScreen> {
  final TeacherApi _api = TeacherApi.instance;

  List<SchoolExam>? _exams;
  List<TeachingSection>? _sections;
  SchoolExam? _exam;
  TeachingSection? _section;
  String? _subject;

  MarksGrid? _grid;
  bool _loadingGrid = false;
  bool _saving = false;
  String? _error;

  /// Student id to the text being typed, so a half-entered mark survives a
  /// rebuild and the field does not fight the keyboard.
  final Map<int, TextEditingController> _fields = <int, TextEditingController>{};
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _loadPickers();
  }

  @override
  void dispose() {
    for (final TextEditingController c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPickers() async {
    try {
      final List<SchoolExam> exams = await _api.exams();
      final List<TeachingSection> sections = await _api.markSections();
      if (!mounted) return;
      setState(() {
        _exams = exams;
        _sections = sections;
        _exam = exams.isEmpty ? null : exams.first;
        _section = sections.isEmpty ? null : sections.first;
        _subject = _section?.subjects.isNotEmpty == true ? _section!.subjects.first : null;
        _error = null;
      });
      if (_exam != null && _section != null && _subject != null) await _loadGrid();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _loadGrid() async {
    final SchoolExam? exam = _exam;
    final TeachingSection? section = _section;
    if (exam == null || section == null) return;

    setState(() {
      _loadingGrid = true;
      _error = null;
    });
    try {
      final MarksGrid grid = await _api.marksGrid(
        examId: exam.id,
        className: section.className,
        sectionName: section.sectionName,
      );
      if (!mounted) return;
      setState(() {
        _grid = grid;
        _loadingGrid = false;
        _dirty = false;
        _seedFields(grid);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingGrid = false;
        _grid = null;
        _error = e.message;
      });
    }
  }

  void _seedFields(MarksGrid grid) {
    for (final TextEditingController c in _fields.values) {
      c.dispose();
    }
    _fields.clear();
    final String? subject = _subject;
    for (final MarksStudent s in grid.students) {
      final double? mark = subject == null ? null : s.marks[subject];
      _fields[s.studentId] = TextEditingController(
        text: mark == null ? '' : _trim(mark),
      );
    }
  }

  /// Marks are whole numbers far more often than not; 47 reads better than 47.0.
  static String _trim(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  int get _fullMarks {
    final String? subject = _subject;
    final MarksGrid? grid = _grid;
    if (subject == null || grid == null) return 100;
    for (final MarksSubject s in grid.subjects) {
      if (s.subject == subject) return s.fullMarks;
    }
    return 100;
  }

  Future<void> _save() async {
    final SchoolExam? exam = _exam;
    final TeachingSection? section = _section;
    final String? subject = _subject;
    final MarksGrid? grid = _grid;
    if (exam == null || section == null || subject == null || grid == null) return;

    final int full = _fullMarks;
    final List<Map<String, dynamic>> entries = <Map<String, dynamic>>[];
    for (final MarksStudent s in grid.students) {
      final String text = (_fields[s.studentId]?.text ?? '').trim();
      if (text.isEmpty) {
        // An empty box clears the mark rather than being skipped, so a mark
        // entered by mistake can be taken back off.
        entries.add(<String, dynamic>{
          'studentId': s.studentId,
          'subject': subject,
          'marks': null,
        });
        continue;
      }
      final double? value = double.tryParse(text);
      if (value == null || value < 0 || value > full) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.name}: "$text" is not a mark between 0 and $full.'),
          ),
        );
        return;
      }
      entries.add(<String, dynamic>{
        'studentId': s.studentId,
        'subject': subject,
        'marks': value,
      });
    }

    setState(() => _saving = true);
    try {
      await _api.saveMarksGrid(
        examId: exam.id,
        className: section.className,
        sectionName: section.sectionName,
        entries: entries,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$subject marks saved for ${section.label}')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final MarksGrid? grid = _grid;
    final bool canSave = grid != null && grid.students.isNotEmpty && _subject != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marks entry'),
        actions: const <Widget>[SignOutAction()],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            _pickers(context),
            Expanded(child: _body(context)),
          ],
        ),
      ),
      bottomNavigationBar: !canSave
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: FilledButton(
                  onPressed: _saving || !_dirty ? null : _save,
                  child: Text(
                    _saving
                        ? 'Saving…'
                        : _dirty
                        ? 'Save $_subject marks'
                        : 'Saved',
                  ),
                ),
              ),
            ),
    );
  }

  Widget _pickers(BuildContext context) {
    final List<SchoolExam> exams = _exams ?? const <SchoolExam>[];
    final List<TeachingSection> sections = _sections ?? const <TeachingSection>[];
    final List<String> subjects = _section?.subjects ?? const <String>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm,
      ),
      child: Column(
        children: <Widget>[
          DropdownButtonFormField<SchoolExam>(
            initialValue: _exam,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Exam', isDense: true),
            items: <DropdownMenuItem<SchoolExam>>[
              for (final SchoolExam e in exams)
                DropdownMenuItem<SchoolExam>(value: e, child: Text(e.name)),
            ],
            onChanged: exams.isEmpty
                ? null
                : (SchoolExam? e) {
                    if (e == null) return;
                    setState(() => _exam = e);
                    _loadGrid();
                  },
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<TeachingSection>(
                  initialValue: _section,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Section', isDense: true),
                  items: <DropdownMenuItem<TeachingSection>>[
                    for (final TeachingSection s in sections)
                      DropdownMenuItem<TeachingSection>(value: s, child: Text(s.label)),
                  ],
                  onChanged: sections.isEmpty
                      ? null
                      : (TeachingSection? s) {
                          if (s == null) return;
                          setState(() {
                            _section = s;
                            // The old subject may not be taught here.
                            _subject = s.subjects.isEmpty ? null : s.subjects.first;
                          });
                          _loadGrid();
                        },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _subject,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Subject', isDense: true),
                  items: <DropdownMenuItem<String>>[
                    for (final String s in subjects)
                      DropdownMenuItem<String>(value: s, child: Text(s)),
                  ],
                  onChanged: subjects.isEmpty
                      ? null
                      : (String? s) {
                          if (s == null) return;
                          setState(() => _subject = s);
                          // No reload: the grid already holds every subject,
                          // only the column in view changes.
                          final MarksGrid? g = _grid;
                          if (g != null) setState(() => _seedFields(g));
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (_error != null) {
      return _message(context, _error!, onRetry: _loadGrid);
    }
    if (_sections != null && _sections!.isEmpty) {
      return _message(
        context,
        'You are not assigned any subject yet, so there is nothing to mark. '
        'Ask the office to set you against a subject under Classes & Sections.',
      );
    }
    if (_exams != null && _exams!.isEmpty) {
      return _message(context, 'No exams have been set for this school yet.');
    }
    if (_loadingGrid || _grid == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final MarksGrid grid = _grid!;
    if (grid.students.isEmpty) {
      return _message(context, 'No students in this section.');
    }
    if (_subject == null) {
      return _message(context, 'You teach no subject in this section.');
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl,
      ),
      itemCount: grid.students.length + 1,
      separatorBuilder: (BuildContext _, int index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (BuildContext context, int i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              '$_subject · out of $_fullMarks · ${grid.students.length} students',
              style: theme.textTheme.bodySmall,
            ),
          );
        }
        final MarksStudent s = grid.students[i - 1];
        return Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(s.name, style: theme.textTheme.titleSmall),
                  if ((s.rollNo ?? '').isNotEmpty)
                    Text('Roll ${s.rollNo}', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            SizedBox(
              width: 92,
              child: TextField(
                controller: _fields[s.studentId],
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '–',
                  suffixText: '/$_fullMarks',
                ),
                onChanged: (_) {
                  if (!_dirty) setState(() => _dirty = true);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _message(BuildContext context, String text, {VoidCallback? onRetry}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    ),
  );
}
