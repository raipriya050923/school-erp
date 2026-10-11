import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/staff_stores.dart';
import '../../core/theme/app_theme.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// Adding a teacher, and editing one.
///
/// One form for both, as with students: `POST /admin/teachers` and
/// `PUT /admin/teachers/{id}` take the same SaveTeacherDto.
///
/// Subjects are picked from the school's subject master rather than typed. The
/// API accepts a legacy single `subject` string as well, but writing through
/// that path is what produced rows reading "Maths, Mathematics, maths" on one
/// teacher — so this screen only ever sends the list.
class AdminTeacherFormScreen extends StatefulWidget {
  const AdminTeacherFormScreen({super.key, this.existing});

  /// Null when adding a new teacher.
  final TeacherDetail? existing;

  @override
  State<AdminTeacherFormScreen> createState() => _AdminTeacherFormScreenState();
}

class _AdminTeacherFormScreenState extends State<AdminTeacherFormScreen> {
  final AdminApi _api = AdminApi.instance;
  final GeographyApi _geo = GeographyApi.instance;
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _pincode;

  String? _gender;
  DateTime? _dob;
  int? _stateId;
  int? _cityId;
  final Set<String> _subjects = <String>{};
  late List<TeacherQualification> _qualifications;

  List<SchoolSubject>? _subjectMaster;
  List<GeoState>? _states;
  List<GeoCity>? _cities;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final TeacherDetail? e = widget.existing;
    _firstName = TextEditingController(text: e?.firstName ?? '');
    _lastName = TextEditingController(text: e?.lastName ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _address = TextEditingController(text: e?.address ?? '');
    _pincode = TextEditingController(text: e?.pincode ?? '');
    _qualifications = <TeacherQualification>[...?e?.qualifications];
    if (e != null) {
      _gender = e.gender;
      _dob = e.dob;
      _stateId = e.stateId;
      _cityId = e.cityId;
      _subjects.addAll(e.subjects);
    }
    _load();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _pincode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<SchoolSubject> subjects = await _api.subjects();
      final List<GeoState> states = await _geo.states();
      if (!mounted) return;
      setState(() {
        // Retired subjects are hidden, except one this teacher already holds:
        // dropping it from the list would quietly unassign them on save.
        _subjectMaster = subjects
            .where((SchoolSubject s) =>
                s.isActive || _subjects.contains(s.name))
            .toList();
        _states = states;
        _loading = false;
      });
      if (_stateId != null) await _loadCities(_stateId!, keepSelection: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _loadCities(int stateId, {bool keepSelection = false}) async {
    try {
      final List<GeoCity> list = await _geo.cities(stateId: stateId);
      if (!mounted) return;
      setState(() {
        _cities = list;
        if (!keepSelection) _cityId = null;
      });
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  String? _orNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Map<String, dynamic> _body() {
    final TeacherDetail? e = widget.existing;
    return <String, dynamic>{
      'firstName': _firstName.text.trim(),
      'lastName': _lastName.text.trim(),
      'subjects': _subjects.toList(),
      'qualifications': <Map<String, dynamic>>[
        for (final TeacherQualification q in _qualifications) q.toJson(),
      ],
      'phone': _orNull(_phone),
      'email': _orNull(_email),
      'gender': _gender,
      'dob': _dob?.toIso8601String(),
      'address': _orNull(_address),
      'pincode': _orNull(_pincode),
      'stateId': _stateId,
      'cityId': _cityId,
      // As on the student form: the ids win, but these back-stop a teacher
      // recorded before the geography master existed.
      'city': e?.city,
      'state': e?.state,
    };
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      if (_isNew) {
        await _api.createTeacher(_body());
      } else {
        await _api.updateTeacher(widget.existing!.id, _body());
      }
      await AdminStore.instance.loadTeachers(force: true);
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('${_firstName.text.trim()} ${_lastName.text.trim()}'.trim() +
          (_isNew ? ' added' : ' saved'));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.message);
    }
  }

  Future<void> _addQualification([int? replaceAt]) async {
    final TeacherQualification? existing =
        replaceAt == null ? null : _qualifications[replaceAt];
    final TeacherQualification? result =
        await showModalBottomSheet<TeacherQualification>(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext sheetContext) =>
              _QualificationSheet(existing: existing),
        );
    if (result == null || !mounted) return;
    setState(() {
      if (replaceAt == null) {
        _qualifications.add(result);
      } else {
        _qualifications[replaceAt] = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'New teacher' : 'Edit teacher')),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? centredMessage(context, _error!, onRetry: _load)
            : _formBody(context),
      ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving
                        ? 'Saving…'
                        : _isNew
                        ? 'Add teacher'
                        : 'Save changes',
                  ),
                ),
              ),
            ),
    );
  }

  Widget _formBody(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl,
        ),
        children: <Widget>[
          if (!_isNew && (widget.existing!.employeeCode).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Text(
                'Employee code ${widget.existing!.employeeCode}',
                style: theme.textTheme.bodySmall,
              ),
            ),

          Text('Teacher', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _firstName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'First name'),
            validator: (String? v) =>
                (v ?? '').trim().isEmpty ? 'A first name is required.' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _lastName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Last name'),
            validator: (String? v) =>
                (v ?? '').trim().isEmpty ? 'A last name is required.' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: const InputDecoration(labelText: 'Gender'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'male', child: Text('Male')),
              DropdownMenuItem<String>(value: 'female', child: Text('Female')),
              DropdownMenuItem<String>(value: 'other', child: Text('Other')),
            ],
            onChanged: (String? v) => setState(() => _gender = v),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              helperText: 'Used for their portal login and password resets',
            ),
            validator: (String? v) {
              final String t = (v ?? '').trim();
              if (t.isEmpty) return null;
              if (!t.contains('@') || !t.contains('.')) {
                return 'That does not look like an email address.';
              }
              return null;
            },
          ),

          const SizedBox(height: AppSpacing.xl),
          Text('Subjects', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'What this teacher can be timetabled for.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          if ((_subjectMaster ?? const <SchoolSubject>[]).isEmpty)
            Text(
              'This school has no subjects yet.',
              style: theme.textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final SchoolSubject s
                    in _subjectMaster ?? const <SchoolSubject>[])
                  FilterChip(
                    label: Text(s.name),
                    selected: _subjects.contains(s.name),
                    onSelected: (bool on) => setState(() {
                      if (on) {
                        _subjects.add(s.name);
                      } else {
                        _subjects.remove(s.name);
                      }
                    }),
                  ),
              ],
            ),

          const SizedBox(height: AppSpacing.xl),
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Qualifications', style: theme.textTheme.titleSmall),
              ),
              TextButton.icon(
                onPressed: () => _addQualification(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_qualifications.isEmpty)
            Text('None recorded.', style: theme.textTheme.bodySmall)
          else
            for (int i = 0; i < _qualifications.length; i++)
              Dismissible(
                key: ValueKey<String>(
                  '${_qualifications[i].name}-$i',
                ),
                direction: DismissDirection.endToStart,
                background: const ColoredBox(
                  color: Color(0x22FF5252),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(right: AppSpacing.lg),
                      child: Icon(Icons.delete_outline),
                    ),
                  ),
                ),
                onDismissed: (_) =>
                    setState(() => _qualifications.removeAt(i)),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_qualifications[i].name),
                  subtitle: Text(
                    <String>[
                      if (_qualifications[i].institution?.isNotEmpty ?? false)
                        _qualifications[i].institution!,
                      if (_qualifications[i].completionYear != null)
                        '${_qualifications[i].completionYear}',
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => _addQualification(i),
                ),
              ),

          const SizedBox(height: AppSpacing.xl),
          Text('Where', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _address,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Street address'),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int>(
            initialValue: _stateId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'State / province'),
            items: <DropdownMenuItem<int>>[
              for (final GeoState s in _states ?? const <GeoState>[])
                DropdownMenuItem<int>(value: s.id, child: Text(s.name)),
            ],
            onChanged: (int? v) {
              if (v == null) return;
              setState(() => _stateId = v);
              _loadCities(v);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int>(
            initialValue: _cityId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'City',
              helperText: _stateId == null ? 'Choose a state first' : null,
            ),
            items: <DropdownMenuItem<int>>[
              for (final GeoCity c in _cities ?? const <GeoCity>[])
                DropdownMenuItem<int>(value: c.id, child: Text(c.name)),
            ],
            onChanged: _stateId == null
                ? null
                : (int? v) => setState(() => _cityId = v),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _pincode,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Postal code'),
          ),
        ],
      ),
    );
  }
}

/// Collects one qualification. A sheet rather than a second route: it is three
/// fields, and pushing a screen for them loses the form behind it.
class _QualificationSheet extends StatefulWidget {
  const _QualificationSheet({this.existing});

  final TeacherQualification? existing;

  @override
  State<_QualificationSheet> createState() => _QualificationSheetState();
}

class _QualificationSheetState extends State<_QualificationSheet> {
  late final TextEditingController _name;
  late final TextEditingController _institution;
  late final TextEditingController _year;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _institution = TextEditingController(
      text: widget.existing?.institution ?? '',
    );
    _year = TextEditingController(
      text: widget.existing?.completionYear?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _institution.dispose();
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        // Clears the keyboard, which otherwise covers the save button.
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.existing == null ? 'Add qualification' : 'Edit qualification',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Qualification',
              hintText: 'B.Ed, M.Sc Physics…',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _institution,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Institution'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _year,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Year completed'),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () {
              final String name = _name.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name the qualification.')),
                );
                return;
              }
              Navigator.of(context).pop(
                TeacherQualification(
                  name: name,
                  institution: _institution.text.trim().isEmpty
                      ? null
                      : _institution.text.trim(),
                  completionYear: int.tryParse(_year.text.trim()),
                ),
              );
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
