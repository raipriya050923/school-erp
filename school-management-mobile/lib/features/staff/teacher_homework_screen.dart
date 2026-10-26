import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// Homework this teacher has set.
///
/// The dashboard lists what needs attention; this is the whole book, and the
/// only place a new piece can be set. Setting homework belongs on a phone more
/// than most of this app: it is usually decided at the end of a lesson, and
/// waiting to get back to a desk is how it reaches the class a day late.
class TeacherHomeworkScreen extends StatefulWidget {
  const TeacherHomeworkScreen({super.key});

  @override
  State<TeacherHomeworkScreen> createState() => _TeacherHomeworkScreenState();
}

class _TeacherHomeworkScreenState extends State<TeacherHomeworkScreen> {
  final TeacherApi _api = TeacherApi.instance;

  List<TeacherHomework>? _items;
  List<TeachingSection> _sections = const <TeachingSection>[];
  bool _loading = true;
  String? _error;

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
      final List<TeacherHomework> list = await _api.homework();
      // The sections this teacher takes, so setting homework offers the
      // classes they actually teach rather than a free-text box.
      final List<TeachingSection> sections = await _api.markSections();
      if (!mounted) return;
      setState(() {
        _items = list;
        _sections = sections;
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

  Future<void> _compose() async {
    final _HomeworkDraft? d = await showModalBottomSheet<_HomeworkDraft>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: _ComposeSheet(sections: _sections),
      ),
    );
    if (d == null || !mounted) return;

    await runAndReload(
      context,
      () => _api.createHomework(
        title: d.title,
        subject: d.subject,
        classLabel: d.classLabel,
        dueDate: d.dueDate,
        totalCount: d.totalCount,
      ),
      'Homework set',
      _load,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<TeacherHomework> rows = _items ?? const <TeacherHomework>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Homework'),
        actions: const <Widget>[SignOutAction()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        icon: const Icon(Icons.assignment_add),
        label: const Text('Set'),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: MasterBody(
            loading: _loading,
            error: _error,
            onRetry: _load,
            isEmpty: rows.isEmpty,
            empty: const EmptyState(
              icon: Icons.assignment_outlined,
              title: 'No homework yet',
              message: 'Anything you set appears here.',
            ),
            children: <Widget>[
              for (final TeacherHomework h in rows)
                StaffRow(
                  title: h.title,
                  subtitle: _line(h),
                  trailing: '${h.submitted}/${h.total}',
                  status: h.status.isEmpty ? null : h.status,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _line(TeacherHomework h) => <String>[
        if (h.classLabel != null && h.classLabel!.isNotEmpty) h.classLabel!,
        if (h.subject != null && h.subject!.isNotEmpty) h.subject!,
        if (h.dueDate != null) 'Due ${formatDay(h.dueDate!)}',
      ].join(' · ');
}

class _HomeworkDraft {
  const _HomeworkDraft({
    required this.title,
    required this.subject,
    required this.classLabel,
    required this.dueDate,
    required this.totalCount,
  });

  final String title;
  final String? subject;
  final String? classLabel;
  final DateTime? dueDate;

  /// How many students it was set to — the denominator of "18 of 30 handed in".
  final int totalCount;
}

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({required this.sections});

  final List<TeachingSection> sections;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final TextEditingController _title = TextEditingController();
  TeachingSection? _section;
  String? _subject;
  late DateTime _due = DateTime.now().add(const Duration(days: 1));
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.sections.isNotEmpty) {
      _section = widget.sections.first;
      _subject = _section!.subjects.isEmpty ? null : _section!.subjects.first;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _due,
      // Not in the past: homework due before it was set is a typo, not a
      // deadline.
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _due = picked);
  }

  void _save() {
    final String title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'What is the homework?');
      return;
    }
    final TeachingSection? section = _section;
    if (section == null) {
      setState(() => _error = 'You teach no sections to set this for.');
      return;
    }
    Navigator.of(context).pop(
      _HomeworkDraft(
        title: title,
        subject: _subject,
        classLabel: '${section.className}-${section.sectionName}',
        dueDate: _due,
        // The class size, so the submitted count has a denominator that means
        // something rather than being counted up from zero.
        totalCount: section.studentCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TeachingSection? section = _section;

    return SheetFrame(
      title: 'Set homework',
      saveLabel: 'Set',
      onSave: _save,
      children: <Widget>[
        TextField(
          controller: _title,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'What to do',
            hintText: 'Exercise 4, questions 1–10',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (widget.sections.isEmpty)
          Text(
            'You are not teaching any section, so there is nobody to set this '
            'for.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else ...<Widget>[
          DropdownButtonFormField<TeachingSection>(
            initialValue: section,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Class'),
            items: <DropdownMenuItem<TeachingSection>>[
              for (final TeachingSection s in widget.sections)
                DropdownMenuItem<TeachingSection>(
                  value: s,
                  child: Text(
                    '${s.className}-${s.sectionName} · ${s.studentCount} students',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (TeachingSection? v) => setState(() {
              _section = v;
              _subject =
                  v == null || v.subjects.isEmpty ? null : v.subjects.first;
            }),
          ),
          if (section != null && section.subjects.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _subject,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Subject'),
              items: <DropdownMenuItem<String>>[
                for (final String s in section.subjects)
                  DropdownMenuItem<String>(value: s, child: Text(s)),
              ],
              onChanged: (String? v) => setState(() => _subject = v),
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: _pickDue,
          icon: const Icon(Icons.event_outlined, size: 18),
          label: Text('Due ${formatDay(_due)}'),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }
}
