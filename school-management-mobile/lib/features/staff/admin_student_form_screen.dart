import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/staff_stores.dart';
import '../../core/theme/app_theme.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// Admitting a student, and editing one.
///
/// One form for both. The fields the API accepts are identical either way —
/// `POST /admin/students` and `PUT /admin/students/{id}` both take a
/// SaveStudentDto — so keeping two screens in step would only be a way for
/// them to drift.
///
/// Class and section are the school's own master, not free text: attendance,
/// exams and fee generation all match on these names, so a student typed into
/// "Grade 6 " with a trailing space quietly disappears from every register.
///
/// State and city come from the platform geography master for the same reason.
/// The country is not asked for — it follows the school.
class AdminStudentFormScreen extends StatefulWidget {
  const AdminStudentFormScreen({super.key, this.existing});

  /// Null when admitting a new student.
  final StudentDetail? existing;

  @override
  State<AdminStudentFormScreen> createState() => _AdminStudentFormScreenState();
}

class _AdminStudentFormScreenState extends State<AdminStudentFormScreen> {
  final AdminApi _api = AdminApi.instance;
  final GeographyApi _geo = GeographyApi.instance;
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _rollNo;
  late final TextEditingController _bloodGroup;
  late final TextEditingController _email;
  late final TextEditingController _guardianName;
  late final TextEditingController _guardianPhone;
  late final TextEditingController _address;
  late final TextEditingController _pincode;
  late final TextEditingController _previousSchool;
  late final TextEditingController _tcNo;

  String? _className;
  String? _sectionName;
  String? _gender;
  DateTime? _dob;
  int? _stateId;
  int? _cityId;

  List<SchoolClass>? _classes;
  List<GeoState>? _states;
  List<GeoCity>? _cities;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final StudentDetail? e = widget.existing;
    _firstName = TextEditingController(text: e?.firstName ?? '');
    _lastName = TextEditingController(text: e?.lastName ?? '');
    _rollNo = TextEditingController(text: e?.rollNo ?? '');
    _bloodGroup = TextEditingController(text: e?.bloodGroup ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _guardianName = TextEditingController(text: e?.guardianName ?? '');
    _guardianPhone = TextEditingController(text: e?.guardianPhone ?? '');
    _address = TextEditingController(text: e?.address ?? '');
    _pincode = TextEditingController(text: e?.pincode ?? '');
    _previousSchool = TextEditingController(text: e?.previousSchool ?? '');
    _tcNo = TextEditingController(text: e?.tcNo ?? '');
    if (e != null) {
      _className = e.className;
      _sectionName = e.sectionName;
      _gender = e.gender;
      _dob = e.dob;
      _stateId = e.stateId;
      _cityId = e.cityId;
    }
    _load();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _rollNo.dispose();
    _bloodGroup.dispose();
    _email.dispose();
    _guardianName.dispose();
    _guardianPhone.dispose();
    _address.dispose();
    _pincode.dispose();
    _previousSchool.dispose();
    _tcNo.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<SchoolClass> classes = await _api.schoolClasses();
      final List<GeoState> states = await _geo.states();
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _states = states;
        // A class the student is already in but which no longer exists in the
        // master would otherwise silently clear itself on the first save.
        if (_className != null &&
            !classes.any((SchoolClass c) => c.name == _className)) {
          _className = null;
          _sectionName = null;
        }
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

  /// Offers the next free roll number when a section is picked on a new
  /// admission. Only ever fills an empty box — overwriting a number the
  /// registrar has just typed would be worse than not helping at all.
  Future<void> _suggestRoll() async {
    if (!_isNew || _className == null || _sectionName == null) return;
    if (_rollNo.text.trim().isNotEmpty) return;
    try {
      final String? next = await _api.nextRoll(
        className: _className!,
        sectionName: _sectionName!,
      );
      if (!mounted || next == null || next.isEmpty) return;
      if (_rollNo.text.trim().isEmpty) _rollNo.text = next;
    } on ApiException {
      // Not worth a message: the registrar can type one.
    }
  }

  List<String> get _sections {
    final SchoolClass? c = (_classes ?? const <SchoolClass>[])
        .where((SchoolClass c) => c.name == _className)
        .firstOrNull;
    return <String>[for (final SchoolSection s in c?.sections ?? const <SchoolSection>[]) s.name];
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  String? _orNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Map<String, dynamic> _body() {
    final StudentDetail? e = widget.existing;
    return <String, dynamic>{
      'firstName': _firstName.text.trim(),
      'lastName': _lastName.text.trim(),
      'className': _className,
      'sectionName': _sectionName,
      'rollNo': _orNull(_rollNo),
      'gender': _gender,
      'dob': _dob?.toIso8601String(),
      'bloodGroup': _orNull(_bloodGroup),
      'email': _orNull(_email),
      'guardianName': _orNull(_guardianName),
      'guardianPhone': _orNull(_guardianPhone),
      'address': _orNull(_address),
      'pincode': _orNull(_pincode),
      'previousSchool': _orNull(_previousSchool),
      'tcNo': _orNull(_tcNo),
      'stateId': _stateId,
      'cityId': _cityId,
      // The ids are authoritative, but the API falls back to these when one
      // does not resolve. Students recorded before the geography master
      // existed hold text with no ids, and omitting these would wipe their
      // address the first time anyone saved from this screen.
      'city': e?.city,
      'state': e?.state,
    };
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      if (_isNew) {
        await _api.createStudent(_body());
      } else {
        await _api.updateStudent(widget.existing!.id, _body());
      }
      // The list behind this screen is now stale either way.
      await AdminStore.instance.loadStudents(force: true);
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('${_firstName.text.trim()} ${_lastName.text.trim()}'.trim() +
          (_isNew ? ' admitted' : ' saved'));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'New student' : 'Edit student')),
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
                        ? 'Admit student'
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
          if (!_isNew)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Text(
                'Admission no ${widget.existing!.admissionNo}',
                style: theme.textTheme.bodySmall,
              ),
            ),

          Text('Student', style: theme.textTheme.titleSmall),
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
          _DateField(
            label: 'Date of birth',
            value: _dob,
            // Nobody in a school roll was born in the future, and a 120-year
            // window is wide enough for any record worth keeping.
            firstDate: DateTime(DateTime.now().year - 120),
            lastDate: DateTime.now(),
            onChanged: (DateTime? d) => setState(() => _dob = d),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _bloodGroup,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Blood group',
              hintText: 'O+, AB−…',
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          Text('Placement', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _className,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Class'),
            items: <DropdownMenuItem<String>>[
              for (final SchoolClass c in _classes ?? const <SchoolClass>[])
                DropdownMenuItem<String>(value: c.name, child: Text(c.name)),
            ],
            onChanged: (String? v) {
              setState(() {
                _className = v;
                _sectionName = null;
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _sections.contains(_sectionName) ? _sectionName : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Section',
              helperText: _className == null ? 'Choose a class first' : null,
            ),
            items: <DropdownMenuItem<String>>[
              for (final String s in _sections)
                DropdownMenuItem<String>(value: s, child: Text(s)),
            ],
            onChanged: _className == null
                ? null
                : (String? v) {
                    setState(() => _sectionName = v);
                    _suggestRoll();
                  },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _rollNo,
            decoration: const InputDecoration(labelText: 'Roll no'),
          ),

          const SizedBox(height: AppSpacing.xl),
          Text('Guardian & contact', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _guardianName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Guardian name'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _guardianPhone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Guardian phone'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              // Worth saying plainly: an address already on another account is
              // dropped by the API rather than rejected, and the student then
              // has no way to reset their own password.
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

          const SizedBox(height: AppSpacing.xl),
          Text('Previous school', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _previousSchool,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'School name'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _tcNo,
            decoration: const InputDecoration(
              labelText: 'Transfer certificate no',
            ),
          ),
        ],
      ),
    );
  }
}

/// A read-only field that opens a date picker. Typed dates are not accepted on
/// purpose: every locale reads 03/04/2015 differently, and a date of birth
/// entered the wrong way round is not obviously wrong on the screen afterwards.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final DateTime? v = value;
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: v ?? DateTime(lastDate.year - 10),
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: v == null
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                  tooltip: 'Clear',
                ),
        ),
        child: Text(
          v == null
              ? 'Not set'
              : '${v.day.toString().padLeft(2, '0')}/'
                    '${v.month.toString().padLeft(2, '0')}/${v.year}',
          style: v == null
              ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                )
              : null,
        ),
      ),
    );
  }
}
