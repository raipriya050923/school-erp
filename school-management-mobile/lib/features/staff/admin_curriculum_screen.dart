import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// Subjects & teachers for one class.
///
/// Two steps, in order, because the second depends on the first: pick what the
/// class studies, then say who teaches each subject to each section. Until a
/// subject is picked there is no row to assign a teacher to, which is why the
/// grid below is empty rather than hidden — an empty grid explains itself, a
/// missing one looks broken.
///
/// This is also what the timetable needs: a section with no subjects has
/// nothing a period could hold.
class AdminCurriculumScreen extends StatefulWidget {
  const AdminCurriculumScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  final int classId;
  final String className;

  @override
  State<AdminCurriculumScreen> createState() => _AdminCurriculumScreenState();
}

class _AdminCurriculumScreenState extends State<AdminCurriculumScreen> {
  final AdminApi _api = AdminApi.instance;

  ClassCurriculum? _data;
  List<AdminTeacher> _teachers = const <AdminTeacher>[];
  bool _loading = true;
  String? _error;

  /// The subject picks as edited, before saving. Kept apart from the loaded
  /// data so Cancel is a real option and a half-made selection is never sent.
  Set<int> _picked = <int>{};
  bool get _dirty {
    final ClassCurriculum? d = _data;
    if (d == null) return false;
    final Set<int> saved = d.subjects
        .where((ClassSubjectOption s) => s.selected)
        .map((ClassSubjectOption s) => s.subjectId)
        .toSet();
    return !_setEquals(saved, _picked);
  }

  static bool _setEquals(Set<int> a, Set<int> b) =>
      a.length == b.length && a.every(b.contains);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ClassCurriculum d = await _api.curriculum(widget.classId);
      // The teacher list is what the picker offers; without it a cell could be
      // opened and have nothing to choose.
      final List<AdminTeacher> t = await _api.teachers();
      if (!mounted) return;
      setState(() {
        _data = d;
        _teachers = t;
        _picked = d.subjects
            .where((ClassSubjectOption s) => s.selected)
            .map((ClassSubjectOption s) => s.subjectId)
            .toSet();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _saveSubjects() async {
    final ClassCurriculum d = _data!;
    final List<String> dropped = d.subjects
        .where((ClassSubjectOption s) =>
            s.selected && !_picked.contains(s.subjectId))
        .map((ClassSubjectOption s) => s.name)
        .toList();

    if (dropped.isNotEmpty) {
      // Removing a subject removes its teacher assignments and anything the
      // timetable built on them, which is not obvious from a cleared checkbox.
      final bool ok = await confirmAction(
        context,
        title: dropped.length == 1
            ? 'Remove ${dropped.first}?'
            : 'Remove ${dropped.length} subjects?',
        message: '${dropped.join(', ')} will stop being studied by '
            '${d.className}, and the teachers assigned to it are unassigned.',
        confirmLabel: 'Remove',
      );
      if (!ok || !mounted) return;
    }

    await runAndReload(
      context,
      () => _api.setClassSubjects(widget.classId, _picked.toList()),
      'Subject list saved',
      _load,
    );
  }

  /// Teachers who take this subject, then everyone else.
  ///
  /// Both groups are offered: a subject nobody is recorded as teaching would
  /// otherwise have an empty picker and could never be assigned at all.
  (List<AdminTeacher>, List<AdminTeacher>) _teachersFor(String subject) {
    final String want = subject.trim().toLowerCase();
    bool takes(AdminTeacher t) {
      final List<String> list = t.subjects.isNotEmpty
          ? t.subjects
          : (t.subject ?? '')
              .split(',')
              .map((String x) => x.trim())
              .where((String x) => x.isNotEmpty)
              .toList();
      return list.any((String x) => x.toLowerCase() == want);
    }

    final List<AdminTeacher> active =
        _teachers.where((AdminTeacher t) => t.status == 'active').toList();
    return (
      active.where(takes).toList(),
      active.where((AdminTeacher t) => !takes(t)).toList(),
    );
  }

  Future<void> _assign(AssignmentRow row, AssignmentCell cell) async {
    final (List<AdminTeacher> takes, List<AdminTeacher> others) =
        _teachersFor(row.subjectName);

    final _Pick? pick = await showModalBottomSheet<_Pick>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheet) => _TeacherPicker(
        title: '${row.subjectName} · ${widget.className}-${cell.sectionName}',
        current: cell.staffId,
        takes: takes,
        others: others,
      ),
    );
    if (pick == null || !mounted) return;

    await runAndReload(
      context,
      () => _api.assignSubjectTeacher(
        classId: widget.classId,
        sectionId: cell.sectionId,
        subjectId: row.subjectId,
        staffId: pick.staffId,
      ),
      pick.staffId == null ? 'Teacher cleared' : 'Teacher assigned',
      _load,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ClassCurriculum? d = _data;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        bottom: d?.academicYear == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'Academic year ${d!.academicYear}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onPrimary),
                  ),
                ),
              ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: MasterBody(
            loading: _loading,
            error: _error,
            onRetry: _load,
            isEmpty: false,
            empty: const SizedBox.shrink(),
            children: <Widget>[
              if (d != null) ...<Widget>[
                const SectionHeader(
                  'Subjects this class studies',
                  subtitle: 'Tick what is taught, then save the list.',
                ),
                if (d.subjects.isEmpty)
                  const EmptyState(
                    icon: Icons.menu_book_outlined,
                    title: 'No subjects to choose from',
                    message: 'Add them under Subjects first.',
                  )
                else ...<Widget>[
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final ClassSubjectOption s in d.subjects)
                        FilterChip(
                          label: Text(s.name),
                          selected: _picked.contains(s.subjectId),
                          onSelected: (bool on) => setState(() {
                            if (on) {
                              _picked.add(s.subjectId);
                            } else {
                              _picked.remove(s.subjectId);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      FilledButton(
                        onPressed: _dirty ? _saveSubjects : null,
                        child: const Text('Save subject list'),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      if (_dirty)
                        TextButton(
                          onPressed: () => setState(() {
                            _picked = d.subjects
                                .where((ClassSubjectOption s) => s.selected)
                                .map((ClassSubjectOption s) => s.subjectId)
                                .toSet();
                          }),
                          child: const Text('Cancel'),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(
                  'Subject teachers',
                  subtitle: 'One teacher per subject, per section.',
                ),
                if (d.grid.isEmpty)
                  AppCard(
                    child: Text(
                      'Pick the subjects above first, then assign a teacher '
                      'to each.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else
                  for (final AssignmentRow row in d.grid) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.md,
                        bottom: AppSpacing.xs,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(row.subjectName,
                                style: theme.textTheme.titleSmall),
                          ),
                          Text(
                            '${row.assigned} of ${row.sections.length} set',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    for (final AssignmentCell c in row.sections)
                      StaffRow(
                        title: 'Section ${c.sectionName}',
                        subtitle: c.teacherName ?? 'No teacher yet',
                        onTap: () => _assign(row, c),
                      ),
                  ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pick {
  const _Pick(this.staffId);

  /// Null clears the assignment.
  final int? staffId;
}

class _TeacherPicker extends StatelessWidget {
  const _TeacherPicker({
    required this.title,
    required this.current,
    required this.takes,
    required this.others,
  });

  final String title;
  final int? current;
  final List<AdminTeacher> takes;
  final List<AdminTeacher> others;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        // A school can have many teachers; the sheet scrolls rather than
        // growing past the screen.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.clear),
                    title: const Text('No teacher'),
                    selected: current == null,
                    onTap: () => Navigator.of(context).pop(const _Pick(null)),
                  ),
                  if (takes.isNotEmpty) ...<Widget>[
                    _GroupLabel(text: 'Takes this subject', theme: theme),
                    for (final AdminTeacher t in takes)
                      _TeacherTile(teacher: t, current: current),
                  ],
                  if (others.isNotEmpty) ...<Widget>[
                    // Offered second, and labelled, so assigning someone
                    // outside their subject is a visible choice.
                    _GroupLabel(text: 'Other teachers', theme: theme),
                    for (final AdminTeacher t in others)
                      _TeacherTile(teacher: t, current: current),
                  ],
                  if (takes.isEmpty && others.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: EmptyState(
                        icon: Icons.co_present_outlined,
                        title: 'No active teachers',
                        message: 'Add a teacher before assigning subjects.',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: Text(text, style: theme.textTheme.bodySmall),
      );
}

class _TeacherTile extends StatelessWidget {
  const _TeacherTile({required this.teacher, required this.current});

  final AdminTeacher teacher;
  final int? current;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(teacher.name),
        subtitle: teacher.subject == null || teacher.subject!.isEmpty
            ? null
            : Text(teacher.subject!),
        selected: current == teacher.id,
        trailing: current == teacher.id ? const Icon(Icons.check) : null,
        onTap: () => Navigator.of(context).pop(_Pick(teacher.id)),
      );
}
