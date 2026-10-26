import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/* ------------------------------------------------------------- subjects -- */

/// The subject master: what can be timetabled, taught and marked against.
///
/// Subjects are retired rather than deleted. One that has ever appeared on a
/// timetable or a mark sheet cannot be removed without taking that history
/// with it, so the API offers an active flag and no delete at all.
class AdminSubjectsScreen extends StatefulWidget {
  const AdminSubjectsScreen({super.key});

  @override
  State<AdminSubjectsScreen> createState() => _AdminSubjectsScreenState();
}

class _AdminSubjectsScreenState extends State<AdminSubjectsScreen> {
  final AdminApi _api = AdminApi.instance;

  List<SchoolSubject>? _items;
  bool _loading = true;
  String? _error;

  /// Retired subjects are hidden by default — the list is for the subjects the
  /// school teaches, and a long tail of retired ones buries them.
  bool _showRetired = false;

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
      final List<SchoolSubject> list = await _api.subjects();
      if (!mounted) return;
      setState(() {
        _items = list;
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

  Future<void> _run(Future<void> Function() action, String done) =>
      runAndReload(context, action, done, _load);

  Future<void> _edit([SchoolSubject? existing]) async {
    final _SubjectDraft? draft = await showModalBottomSheet<_SubjectDraft>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: _SubjectSheet(existing: existing),
      ),
    );
    if (draft == null) return;

    if (existing == null) {
      await _run(
        () => _api.createSubject(
          name: draft.name,
          code: draft.code,
          subjectType: draft.subjectType,
        ),
        'Subject added',
      );
    } else {
      await _run(
        () => _api.updateSubject(
          existing.id,
          name: draft.name,
          code: draft.code,
          subjectType: draft.subjectType,
        ),
        'Subject saved',
      );
    }
  }

  Future<void> _actions(SchoolSubject s) async {
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            ListTile(
              title: Text(s.name, style: Theme.of(sheet).textTheme.titleMedium),
              subtitle: Text(_subjectLine(s)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit subject'),
              onTap: () => Navigator.of(sheet).pop('edit'),
            ),
            ListTile(
              leading: Icon(
                s.isActive
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              title: Text(s.isActive ? 'Retire subject' : 'Bring back'),
              onTap: () => Navigator.of(sheet).pop('active'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    switch (choice) {
      case 'edit':
        await _edit(s);
      case 'active':
        await _run(
          () => _api.setSubjectActive(s.id, !s.isActive),
          s.isActive ? 'Subject retired' : 'Subject brought back',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<SchoolSubject> all = _items ?? const <SchoolSubject>[];
    final List<SchoolSubject> rows = _showRetired
        ? all
        : all.where((SchoolSubject s) => s.isActive).toList();
    final int retired = all.where((SchoolSubject s) => !s.isActive).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subjects'),
        actions: const <Widget>[SignOutAction()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('Subject'),
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
              icon: Icons.menu_book_outlined,
              title: 'No subjects yet',
              message: 'Add what this school teaches.',
            ),
            children: <Widget>[
              for (final SchoolSubject s in rows)
                StaffRow(
                  title: s.name,
                  subtitle: _subjectLine(s),
                  status: s.isActive ? null : 'retired',
                  onTap: () => _actions(s),
                ),
              if (retired > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _showRetired = !_showRetired),
                    icon: Icon(
                      _showRetired
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    label: Text(
                      _showRetired ? 'Hide retired' : 'Show $retired retired',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _subjectLine(SchoolSubject s) => <String>[
    if (s.code != null && s.code!.isNotEmpty) s.code!,
    _typeLabel(s.subjectType),
  ].where((String p) => p.isNotEmpty).join(' · ');
}

String _typeLabel(String? type) {
  switch (type) {
    case 'practical':
      return 'Practical';
    case 'both':
      return 'Theory & practical';
    case 'theory':
      return 'Theory';
    default:
      return '';
  }
}

class _SubjectDraft {
  const _SubjectDraft(this.name, this.code, this.subjectType);

  final String name;
  final String? code;
  final String subjectType;
}

class _SubjectSheet extends StatefulWidget {
  const _SubjectSheet({this.existing});

  final SchoolSubject? existing;

  @override
  State<_SubjectSheet> createState() => _SubjectSheetState();
}

class _SubjectSheetState extends State<_SubjectSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _code = TextEditingController(
    text: widget.existing?.code ?? '',
  );
  late String _type = widget.existing?.subjectType ?? 'theory';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  void _save() {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the subject a name.');
      return;
    }
    Navigator.of(context).pop(
      _SubjectDraft(
        name,
        _code.text.trim().isEmpty ? null : _code.text.trim(),
        _type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SheetFrame(
    title: widget.existing == null ? 'New subject' : 'Edit subject',
    onSave: _save,
    children: <Widget>[
      TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Subject name',
          hintText: 'Mathematics',
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _code,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Code (optional)',
          hintText: 'MATH',
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      DropdownButtonFormField<String>(
        initialValue: _type,
        decoration: const InputDecoration(labelText: 'Type'),
        items: const <DropdownMenuItem<String>>[
          DropdownMenuItem<String>(value: 'theory', child: Text('Theory')),
          DropdownMenuItem<String>(
            value: 'practical',
            child: Text('Practical'),
          ),
          DropdownMenuItem<String>(
            value: 'both',
            child: Text('Theory & practical'),
          ),
        ],
        onChanged: (String? v) => setState(() => _type = v ?? 'theory'),
      ),
      if (_error != null) ...<Widget>[
        const SizedBox(height: AppSpacing.md),
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    ],
  );
}

/* ------------------------------------------------------- academic years -- */

/// The years the school files its work under.
///
/// One is current, and that is the one new admissions, invoices and registers
/// are stamped with. Changing it is the consequential act on this screen, so it
/// asks before doing it.
class AdminAcademicYearsScreen extends StatefulWidget {
  const AdminAcademicYearsScreen({super.key});

  @override
  State<AdminAcademicYearsScreen> createState() =>
      _AdminAcademicYearsScreenState();
}

class _AdminAcademicYearsScreenState extends State<AdminAcademicYearsScreen> {
  final AdminApi _api = AdminApi.instance;

  List<AcademicYear>? _items;
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
      final List<AcademicYear> list = await _api.academicYears();
      if (!mounted) return;
      setState(() {
        _items = list;
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

  Future<void> _run(Future<void> Function() action, String done) =>
      runAndReload(context, action, done, _load);

  /// The furthest date any year on file runs to.
  DateTime? _latestEnd() {
    final List<AcademicYear> years = _items ?? const <AcademicYear>[];
    if (years.isEmpty) return null;
    return years
        .map((AcademicYear y) => y.endDate)
        .reduce((DateTime a, DateTime b) => a.isAfter(b) ? a : b);
  }

  Future<void> _edit([AcademicYear? existing]) async {
    final _YearDraft? draft = await showModalBottomSheet<_YearDraft>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: _YearSheet(existing: existing, after: _latestEnd()),
      ),
    );
    if (draft == null) return;

    if (existing == null) {
      await _run(
        () => _api.createAcademicYear(
          name: draft.name,
          startDate: draft.start,
          endDate: draft.end,
        ),
        'Year added',
      );
    } else {
      await _run(
        () => _api.updateAcademicYear(
          existing.id,
          name: draft.name,
          startDate: draft.start,
          endDate: draft.end,
        ),
        'Year saved',
      );
    }
  }

  Future<void> _actions(AcademicYear y) async {
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            ListTile(
              title: Text(y.name, style: Theme.of(sheet).textTheme.titleMedium),
              subtitle: Text(_yearLine(y)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit year'),
              onTap: () => Navigator.of(sheet).pop('edit'),
            ),
            if (!y.isCurrent)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Make current'),
                onTap: () => Navigator.of(sheet).pop('current'),
              ),
            if (y.canDelete)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(sheet).colorScheme.error,
                ),
                title: Text(
                  'Delete year',
                  style: TextStyle(color: Theme.of(sheet).colorScheme.error),
                ),
                onTap: () => Navigator.of(sheet).pop('delete'),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    switch (choice) {
      case 'edit':
        await _edit(y);
      case 'current':
        final bool ok = await confirmAction(
          context,
          title: 'Make ${y.name} current?',
          message:
              'New admissions, invoices and registers will be filed '
              'under it from now on.',
          confirmLabel: 'Make current',
          destructive: false,
        );
        if (!ok) return;
        await _run(
          () => _api.setCurrentAcademicYear(y.id),
          '${y.name} is now the current year',
        );
      case 'delete':
        final bool ok = await confirmAction(
          context,
          title: 'Delete ${y.name}?',
          message: 'This cannot be undone.',
        );
        if (!ok) return;
        await _run(() => _api.deleteAcademicYear(y.id), 'Year deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<AcademicYear> rows = _items ?? const <AcademicYear>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic years'),
        actions: const <Widget>[SignOutAction()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('Year'),
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
              icon: Icons.event_outlined,
              title: 'No academic years yet',
              message: 'Add the year this school is running.',
            ),
            children: <Widget>[
              for (final AcademicYear y in rows)
                StaffRow(
                  title: y.name,
                  subtitle: _yearLine(y),
                  status: y.isCurrent ? 'current' : null,
                  onTap: () => _actions(y),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _yearLine(AcademicYear y) => <String>[
  '${formatDay(y.startDate)} → ${formatDay(y.endDate)}',
  if (y.usageCount > 0) '${y.usageCount} records',
].join(' · ');

class _YearDraft {
  const _YearDraft(this.name, this.start, this.end);

  final String name;
  final DateTime start;
  final DateTime end;
}

class _YearSheet extends StatefulWidget {
  const _YearSheet({this.existing, this.after});

  final AcademicYear? existing;

  /// The latest year already on file. A new year starts the day after it ends,
  /// because the API refuses overlapping years and today's date almost always
  /// falls inside the current one.
  final DateTime? after;

  @override
  State<_YearSheet> createState() => _YearSheetState();
}

class _YearSheetState extends State<_YearSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late DateTime _start =
      widget.existing?.startDate ??
      (widget.after == null
          ? DateTime.now()
          : widget.after!.add(const Duration(days: 1)));
  late DateTime _end =
      widget.existing?.endDate ?? _start.add(const Duration(days: 364));
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool start}) async {
    final DateTime initial = start ? _start : _end;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 5),
      lastDate: DateTime(initial.year + 5),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  void _save() {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the year a name, such as 2026-27.');
      return;
    }
    if (!_end.isAfter(_start)) {
      setState(() => _error = 'The year has to end after it starts.');
      return;
    }
    Navigator.of(context).pop(_YearDraft(name, _start, _end));
  }

  @override
  Widget build(BuildContext context) => SheetFrame(
    title: widget.existing == null ? 'New academic year' : 'Edit year',
    onSave: _save,
    children: <Widget>[
      TextField(
        controller: _name,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: '2026-27',
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(start: true),
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text('From ${formatDay(_start)}'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(start: false),
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text('To ${formatDay(_end)}'),
            ),
          ),
        ],
      ),
      if (_error != null) ...<Widget>[
        const SizedBox(height: AppSpacing.md),
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    ],
  );
}
