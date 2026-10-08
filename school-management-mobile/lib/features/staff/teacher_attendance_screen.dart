import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// Daily attendance for a class teacher's own section.
///
/// The screen a teacher actually uses standing in front of the room, which is
/// why it is built for thumbs: everyone starts present, and marking is one tap
/// on the exceptions rather than a decision per child. A full class of forty
/// is then three taps, not forty.
///
/// Only sections this teacher is class teacher of are offered. Teaching a
/// subject in a section is not enough — the API refuses it, and offering a
/// section it will refuse is a trap.
class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  State<TeacherAttendanceScreen> createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  final TeacherApi _api = TeacherApi.instance;

  List<TeacherClass>? _sections;
  TeacherClass? _section;
  DateTime _date = DateTime.now();

  List<AttendanceRow>? _rows;
  bool _loadingRows = false;
  bool _saving = false;
  String? _error;
  /// True once anything has been changed but not yet saved.
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    try {
      final List<TeacherClass> list = await _api.attendanceSections();
      if (!mounted) return;
      setState(() {
        _sections = list;
        _section = list.isEmpty ? null : list.first;
        _error = null;
      });
      if (_section != null) await _loadRows();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _loadRows() async {
    final TeacherClass? s = _section;
    if (s == null) return;
    setState(() {
      _loadingRows = true;
      _error = null;
    });
    try {
      final List<AttendanceRow> rows = await _api.attendance(
        className: s.className,
        sectionName: s.sectionName,
        date: _date,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loadingRows = false;
        _dirty = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRows = false;
        _error = e.message;
      });
    }
  }

  Future<void> _save() async {
    final TeacherClass? s = _section;
    final List<AttendanceRow>? rows = _rows;
    if (s == null || rows == null) return;

    setState(() => _saving = true);
    try {
      await _api.saveAttendance(
        className: s.className,
        sectionName: s.sectionName,
        date: _date,
        rows: rows,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance saved for ${s.label}')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      // No future attendance: a register for a day that has not happened is
      // a guess, and the API would be storing it as fact.
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _date = picked);
    await _loadRows();
  }

  void _setAll(String status) {
    final List<AttendanceRow>? rows = _rows;
    if (rows == null) return;
    setState(() {
      for (final AttendanceRow r in rows) {
        r.status = status;
      }
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<AttendanceRow> rows = _rows ?? const <AttendanceRow>[];
    final int present = rows.where((AttendanceRow r) => r.status == 'present').length;
    final int absent = rows.where((AttendanceRow r) => r.status == 'absent').length;
    final int late = rows.where((AttendanceRow r) => r.status == 'late').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: const <Widget>[SignOutAction()],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            _controls(context),
            if (_rows != null && rows.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    _tally('Present', present, AppColors.green),
                    _tally('Absent', absent, AppColors.red),
                    _tally('Late', late, AppColors.amber),
                  ],
                ),
              ),
            Expanded(child: _body(context, rows)),
          ],
        ),
      ),
      bottomNavigationBar: _rows == null || rows.isEmpty
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
                        ? 'Save attendance'
                        : 'Saved',
                  ),
                ),
              ),
            ),
    );
  }

  Widget _controls(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<TeacherClass> sections = _sections ?? const <TeacherClass>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: DropdownButtonFormField<TeacherClass>(
              initialValue: _section,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Section',
                isDense: true,
              ),
              items: <DropdownMenuItem<TeacherClass>>[
                for (final TeacherClass c in sections)
                  DropdownMenuItem<TeacherClass>(value: c, child: Text(c.label)),
              ],
              onChanged: sections.isEmpty
                  ? null
                  : (TeacherClass? c) {
                      if (c == null) return;
                      setState(() => _section = c);
                      _loadRows();
                    },
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_outlined, size: 17),
            label: Text(_formatDate(_date), style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _tally(String label, int count, Color colour) => Expanded(
    child: Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label $count'),
      ],
    ),
  );

  Widget _body(BuildContext context, List<AttendanceRow> rows) {
    if (_error != null) {
      return _message(context, _error!, onRetry: _loadRows);
    }
    if (_sections != null && _sections!.isEmpty) {
      return _message(
        context,
        'You are not the class teacher of any section, so there is no register '
        'for you to take. Marking attendance is a class-teacher duty.',
      );
    }
    if (_loadingRows || _rows == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (rows.isEmpty) {
      return _message(context, 'No students in this section yet.');
    }

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: <Widget>[
              Text('Mark all', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: () => _setAll('present'),
                child: const Text('Present'),
              ),
              TextButton(
                onPressed: () => _setAll('absent'),
                child: const Text('Absent'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl,
            ),
            itemCount: rows.length,
            separatorBuilder: (BuildContext _, int index) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int i) => AttendanceStatusRow(
              title: rows[i].name,
              subtitle: (rows[i].rollNo ?? '').isEmpty
                  ? null
                  : 'Roll ${rows[i].rollNo}',
              status: rows[i].status,
              states: AttendanceStatusRow.studentStates,
              onChanged: (String status) => setState(() {
                rows[i].status = status;
                _dirty = true;
              }),
            ),
          ),
        ),
      ],
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

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';
