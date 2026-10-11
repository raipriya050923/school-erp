import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_theme.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// Onboarding a school, and editing one.
///
/// One form for both, because the fields are the same and keeping two in step
/// is how they drift. The difference is what happens on save: creating
/// provisions an administrator and hands back a password that exists nowhere
/// else, so the screen cannot just pop — it has to show it first.
///
/// Country, state and city are the geography master's ids rather than typed
/// text. The API writes the name columns from whatever they resolve to, so a
/// school that picks "Noida" is in the same Noida as every other school.
class PlatformSchoolFormScreen extends StatefulWidget {
  const PlatformSchoolFormScreen({super.key, this.existing});

  /// Null when onboarding a new school.
  final SchoolDetail? existing;

  @override
  State<PlatformSchoolFormScreen> createState() =>
      _PlatformSchoolFormScreenState();
}

class _PlatformSchoolFormScreenState extends State<PlatformSchoolFormScreen> {
  final SuperAdminApi _api = SuperAdminApi.instance;
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _postalCode;
  late final TextEditingController _board;

  String _theme = 'classic';
  String _status = 'pending';
  String _billingCycle = 'yearly';
  int? _planId;
  int? _countryId;
  int? _stateId;
  int? _cityId;

  List<SubscriptionPlan>? _plans;
  List<GeoCountry>? _countries;
  List<GeoState>? _states;
  List<GeoCity>? _cities;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final SchoolDetail? e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _address = TextEditingController(text: e?.address ?? '');
    _postalCode = TextEditingController(text: e?.postalCode ?? '');
    _board = TextEditingController(text: e?.affiliationBoard ?? '');
    if (e != null) {
      _theme = e.theme;
      _status = e.status.isEmpty ? 'active' : e.status;
      _billingCycle = e.billingCycle ?? 'yearly';
      _planId = e.planId;
      _countryId = e.countryId;
      _stateId = e.stateId;
      _cityId = e.cityId;
    }
    _loadLists();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _postalCode.dispose();
    _board.dispose();
    super.dispose();
  }

  Future<void> _loadLists() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<SubscriptionPlan> plans = await _api.plans();
      final List<GeoCountry> countries = await _api.countries();
      if (!mounted) return;
      setState(() {
        // Only plans still on sale, unless the school is already on a retired
        // one — in which case dropping it from the list would silently move
        // them off it on the next save.
        _plans = plans
            .where((SubscriptionPlan p) => p.isActive || p.id == _planId)
            .toList();
        _countries = countries;
        _loading = false;
      });
      if (_countryId != null) await _loadStates(_countryId!, keepSelection: true);
      if (_stateId != null) await _loadCities(_stateId!, keepSelection: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _loadStates(int countryId, {bool keepSelection = false}) async {
    try {
      final List<GeoState> list = await _api.states(countryId: countryId);
      if (!mounted) return;
      setState(() {
        _states = list;
        if (!keepSelection) {
          _stateId = null;
          _cities = null;
          _cityId = null;
        }
      });
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  Future<void> _loadCities(int stateId, {bool keepSelection = false}) async {
    try {
      final List<GeoCity> list = await _api.cities(stateId: stateId);
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

  Map<String, dynamic> _body() {
    final SchoolDetail? e = widget.existing;
    return <String, dynamic>{
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      'postalCode':
          _postalCode.text.trim().isEmpty ? null : _postalCode.text.trim(),
      'affiliationBoard':
          _board.text.trim().isEmpty ? null : _board.text.trim(),
      'theme': _theme,
      'status': _status,
      'planId': _planId ?? 0,
      'billingCycle': _billingCycle,
      'countryId': _countryId,
      'stateId': _stateId,
      'cityId': _cityId,
      // The ids are authoritative, but the API falls back to these when one
      // does not resolve — `City = place.CityName ?? dto.City`. Older schools
      // were recorded as text with no ids at all, and leaving these out would
      // erase their address the first time anyone saved from here.
      'city': e?.city,
      'state': e?.state,
      'country': e?.country,
    };
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_planId == null) {
      _toast('Pick a plan. A school with no subscription is invisible to '
          'billing and to revenue reporting.');
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isNew) {
        final SchoolOnboarded result = await _api.createSchool(_body());
        if (!mounted) return;
        setState(() => _saving = false);
        await _showCredentials(result);
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        await _api.updateSchool(widget.existing!.id, _body());
        if (!mounted) return;
        setState(() => _saving = false);
        _toast('${_name.text.trim()} saved');
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.message);
    }
  }

  /// The one moment the administrator's password exists in plaintext. Not
  /// dismissible by tapping outside: losing it means resetting it.
  Future<void> _showCredentials(SchoolOnboarded r) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text('${r.schoolName} is onboarded'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Copy these now — the password cannot be shown again.'),
          const SizedBox(height: AppSpacing.lg),
          _credential(dialogContext, 'School code', r.schoolCode),
          _credential(dialogContext, 'Username', r.username),
          _credential(dialogContext, 'Password', r.temporaryPassword),
          _credential(dialogContext, 'Plan', r.planName),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: '${r.username} / ${r.temporaryPassword}'),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied')),
            );
          },
          child: const Text('Copy'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  );

  Widget _credential(BuildContext context, String label, String value) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: SelectableText(value, style: theme.textTheme.titleSmall),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New school' : 'Edit school'),
        actions: const <Widget>[SignOutAction()],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      OutlinedButton(
                        onPressed: _loadLists,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
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
                        ? 'Onboard school'
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
          Text('School', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (String? v) =>
                (v ?? '').trim().isEmpty ? 'The school needs a name.' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (String? v) {
              final String t = (v ?? '').trim();
              if (t.isEmpty) return 'An email is required.';
              // Deliberately loose: the API is the authority, and a strict
              // pattern here only rejects addresses that actually work.
              if (!t.contains('@') || !t.contains('.')) {
                return "That does not look like an email address.";
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
            validator: (String? v) =>
                (v ?? '').trim().isEmpty ? 'A phone number is required.' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _board,
            decoration: const InputDecoration(
              labelText: 'Affiliation board',
              hintText: 'CBSE, ICSE, state board…',
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
            initialValue: _countryId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Country'),
            items: <DropdownMenuItem<int>>[
              for (final GeoCountry c in _countries ?? const <GeoCountry>[])
                DropdownMenuItem<int>(value: c.id, child: Text(c.name)),
            ],
            onChanged: (int? v) {
              if (v == null) return;
              setState(() => _countryId = v);
              _loadStates(v);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int>(
            initialValue: _stateId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'State',
              hintText: _countryId == null ? 'Pick a country first' : null,
            ),
            items: <DropdownMenuItem<int>>[
              for (final GeoState st in _states ?? const <GeoState>[])
                DropdownMenuItem<int>(value: st.id, child: Text(st.name)),
            ],
            onChanged: (_states == null || _states!.isEmpty)
                ? null
                : (int? v) {
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
              hintText: _stateId == null ? 'Pick a state first' : null,
            ),
            items: <DropdownMenuItem<int>>[
              for (final GeoCity c in _cities ?? const <GeoCity>[])
                DropdownMenuItem<int>(value: c.id, child: Text(c.name)),
            ],
            onChanged: (_cities == null || _cities!.isEmpty)
                ? null
                : (int? v) => setState(() => _cityId = v),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _postalCode,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Postal code'),
          ),

          const SizedBox(height: AppSpacing.xl),
          Text('Subscription', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<int>(
            initialValue: _planId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Plan'),
            items: <DropdownMenuItem<int>>[
              for (final SubscriptionPlan p in _plans ?? const <SubscriptionPlan>[])
                DropdownMenuItem<int>(
                  value: p.id,
                  child: Text(p.isActive ? p.name : '${p.name} (retired)'),
                ),
            ],
            onChanged: (int? v) => setState(() => _planId = v),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _billingCycle,
            decoration: const InputDecoration(labelText: 'Billing cycle'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'monthly', child: Text('Monthly')),
              DropdownMenuItem<String>(value: 'yearly', child: Text('Yearly')),
            ],
            onChanged: (String? v) =>
                setState(() => _billingCycle = v ?? 'yearly'),
          ),

          const SizedBox(height: AppSpacing.xl),
          Text('Portal', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _theme,
            decoration: const InputDecoration(labelText: 'Colour'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'classic', child: Text('Classic')),
              DropdownMenuItem<String>(value: 'brand', child: Text('Brand')),
              DropdownMenuItem<String>(value: 'forest', child: Text('Forest')),
              DropdownMenuItem<String>(value: 'mist', child: Text('Mist')),
            ],
            onChanged: (String? v) => setState(() => _theme = v ?? 'classic'),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'pending', child: Text('Pending')),
              DropdownMenuItem<String>(value: 'active', child: Text('Active')),
              DropdownMenuItem<String>(value: 'suspended', child: Text('Suspended')),
              DropdownMenuItem<String>(value: 'terminated', child: Text('Terminated')),
            ],
            onChanged: (String? v) => setState(() => _status = v ?? 'pending'),
          ),

          if (_isNew) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Saving provisions the school administrator and shows their '
              'password once.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
