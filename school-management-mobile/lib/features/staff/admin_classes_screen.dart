import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/staff_models.dart';
import 'admin_curriculum_screen.dart';
import 'staff_widgets.dart';

/// The class and section master.
///
/// Nested rather than two flat lists, because a section only means anything
/// inside its class: "A" is not a thing, "Grade 6 — A" is. Each class shows its
/// sections underneath with the headcount that makes them real, and the actions
/// hang off whichever row you press.
class AdminClassesScreen extends StatefulWidget {
  const AdminClassesScreen({super.key});

  @override
  State<AdminClassesScreen> createState() => _AdminClassesScreenState();
}

class _AdminClassesScreenState extends State<AdminClassesScreen> {
  final AdminApi _api = AdminApi.instance;

  List<SchoolClass>? _items;
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
      final List<SchoolClass> list = await _api.schoolClasses();
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

  Future<void> _addClass() async {
    final _ClassDraft? draft = await showModalBottomSheet<_ClassDraft>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: const _ClassSheet(),
      ),
    );
    if (draft == null) return;
    await _run(
      () => _api.createClass(
        name: draft.name,
        sectionName: draft.sectionName,
        teacher: draft.teacher,
      ),
      'Class added',
    );
  }

  Future<void> _classActions(SchoolClass c) async {
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            ListTile(
              title: Text(c.name, style: Theme.of(sheet).textTheme.titleMedium),
              subtitle: Text(
                '${c.sections.length} sections · ${c.studentCount} students',
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Subjects & teachers'),
              subtitle: const Text('What it studies, and who teaches it'),
              onTap: () => Navigator.of(sheet).pop('curriculum'),
            ),
            ListTile(
              leading: const Icon(Icons.add_outlined),
              title: const Text('Add section'),
              onTap: () => Navigator.of(sheet).pop('section'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename class'),
              onTap: () => Navigator.of(sheet).pop('rename'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: _errorColour(sheet)),
              title: Text(
                'Delete class',
                style: TextStyle(color: _errorColour(sheet)),
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
      case 'curriculum':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext _) => AdminCurriculumScreen(
              classId: c.id,
              className: c.name,
            ),
          ),
        );
        // Subjects may have changed, which changes nothing on this list but
        // everything on the timetable; reload so the counts stay honest.
        if (mounted) await _load();
      case 'section':
        final _SectionDraft? d = await _askSection();
        if (d == null) return;
        await _run(
          () => _api.createSection(
            classId: c.id,
            name: d.name,
            teacher: d.teacher,
          ),
          'Section added',
        );
      case 'rename':
        final String? name = await _askText(
          title: 'Rename class',
          label: 'Class name',
          initial: c.name,
        );
        if (name == null) return;
        await _run(() => _api.renameClass(c.id, name), 'Class renamed');
      case 'delete':
        final bool ok = await confirmAction(
          context,
          title: 'Delete ${c.name}?',
          message: c.studentCount > 0
              ? 'It has ${c.studentCount} students. The server will refuse '
                    'while anyone is enrolled.'
              : 'This cannot be undone.',
        );
        if (!ok) return;
        await _run(() => _api.deleteClass(c.id), 'Class deleted');
    }
  }

  Future<void> _sectionActions(SchoolClass c, SchoolSection s) async {
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            ListTile(
              title: Text(
                '${c.name} — ${s.name}',
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
              subtitle: Text(
                <String>[
                  '${s.studentCount} students',
                  if (s.teacher != null && s.teacher!.isNotEmpty) s.teacher!,
                ].join(' · '),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit section'),
              onTap: () => Navigator.of(sheet).pop('edit'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: _errorColour(sheet)),
              title: Text(
                'Delete section',
                style: TextStyle(color: _errorColour(sheet)),
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
        final _SectionDraft? d = await _askSection(
          initialName: s.name,
          initialTeacher: s.teacher,
        );
        if (d == null) return;
        await _run(
          () => _api.updateSection(
            s.id,
            classId: c.id,
            name: d.name,
            teacher: d.teacher,
          ),
          'Section saved',
        );
      case 'delete':
        final bool ok = await confirmAction(
          context,
          title: 'Delete ${c.name} — ${s.name}?',
          message: s.studentCount > 0
              ? 'It has ${s.studentCount} students. The server will refuse '
                    'while anyone is enrolled.'
              : 'This cannot be undone.',
        );
        if (!ok) return;
        await _run(() => _api.deleteSection(s.id), 'Section deleted');
    }
  }

  Future<_SectionDraft?> _askSection({
    String? initialName,
    String? initialTeacher,
  }) => showModalBottomSheet<_SectionDraft>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
      child: _SectionSheet(
        initialName: initialName,
        initialTeacher: initialTeacher,
      ),
    ),
  );

  Future<String?> _askText({
    required String title,
    required String label,
    String? initial,
  }) => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
      child: _TextSheet(title: title, label: label, initial: initial),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Classes & sections'),
        actions: const <Widget>[SignOutAction()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addClass,
        icon: const Icon(Icons.add),
        label: const Text('Class'),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(onRefresh: _load, child: _body(context)),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<SchoolClass> items = _items ?? const <SchoolClass>[];

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: <Widget>[
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: OutlinedButton(
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    if (items.isEmpty) {
      return ListView(
        children: const <Widget>[
          SizedBox(height: 80),
          EmptyState(
            icon: Icons.meeting_room_outlined,
            title: 'No classes yet',
            message: 'Add the first class, and its first section with it.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        96,
      ),
      children: <Widget>[
        for (final SchoolClass c in items) ...<Widget>[
          StaffRow(
            title: c.name,
            subtitle:
                '${c.sections.length} sections · ${c.studentCount} students',
            onTap: () => _classActions(c),
          ),
          if (c.sections.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text(
                'No sections yet — press the class to add one.',
                style: theme.textTheme.bodySmall,
              ),
            )
          else
            // Indented, so a section reads as belonging to the class above it
            // rather than as another class.
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xl),
              child: Column(
                children: <Widget>[
                  for (final SchoolSection s in c.sections)
                    StaffRow(
                      title: s.name,
                      subtitle: s.teacher == null || s.teacher!.isEmpty
                          ? null
                          : s.teacher,
                      trailing: '${s.studentCount}',
                      onTap: () => _sectionActions(c, s),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// The theme's error colour. Named rather than reached for inline, because it
/// is wanted in several places here and `Theme.of(x).colorScheme.error` reads
/// as noise at each of them.
Color _errorColour(BuildContext context) => Theme.of(context).colorScheme.error;

/* ------------------------------------------------------------- the sheets -- */

class _ClassDraft {
  const _ClassDraft(this.name, this.sectionName, this.teacher);

  final String name;
  final String? sectionName;
  final String? teacher;
}

class _ClassSheet extends StatefulWidget {
  const _ClassSheet();

  @override
  State<_ClassSheet> createState() => _ClassSheetState();
}

class _ClassSheetState extends State<_ClassSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _section = TextEditingController(text: 'A');
  final TextEditingController _teacher = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _section.dispose();
    _teacher.dispose();
    super.dispose();
  }

  void _save() {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the class a name.');
      return;
    }
    Navigator.of(context).pop(
      _ClassDraft(
        name,
        _section.text.trim().isEmpty ? null : _section.text.trim(),
        _teacher.text.trim().isEmpty ? null : _teacher.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SheetFrame(
    title: 'New class',
    onSave: _save,
    children: <Widget>[
      TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Class name',
          hintText: 'Grade 6',
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _section,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'First section',
          helperText: 'A class with no section holds no students.',
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _teacher,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Class teacher (optional)',
        ),
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

class _SectionDraft {
  const _SectionDraft(this.name, this.teacher);

  final String name;
  final String? teacher;
}

class _SectionSheet extends StatefulWidget {
  const _SectionSheet({this.initialName, this.initialTeacher});

  final String? initialName;
  final String? initialTeacher;

  @override
  State<_SectionSheet> createState() => _SectionSheetState();
}

class _SectionSheetState extends State<_SectionSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName ?? '',
  );
  late final TextEditingController _teacher = TextEditingController(
    text: widget.initialTeacher ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _teacher.dispose();
    super.dispose();
  }

  void _save() {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the section a name.');
      return;
    }
    Navigator.of(context).pop(
      _SectionDraft(
        name,
        _teacher.text.trim().isEmpty ? null : _teacher.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SheetFrame(
    title: widget.initialName == null ? 'New section' : 'Edit section',
    onSave: _save,
    children: <Widget>[
      TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Section name',
          hintText: 'A',
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _teacher,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Class teacher (optional)',
        ),
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

class _TextSheet extends StatefulWidget {
  const _TextSheet({required this.title, required this.label, this.initial});

  final String title;
  final String label;
  final String? initial;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    final String v = _c.text.trim();
    if (v.isEmpty) {
      setState(() => _error = 'This cannot be empty.');
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) => SheetFrame(
    title: widget.title,
    onSave: _save,
    children: <Widget>[
      TextField(
        controller: _c,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: widget.label),
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
