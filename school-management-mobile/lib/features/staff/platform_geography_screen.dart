import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// The country / state / city master every school's address is picked from.
///
/// A drill-down rather than three tabs: a city only means anything under its
/// state, and the question this screen answers is almost always "is X in the
/// list, and is it switched on" — asked because a school could not find their
/// town on the sign-up form. Which is why adding one is here too: the answer
/// to that question is usually "no, add it".
///
/// Nothing is deleted, only switched off. A city with schools on it cannot
/// vanish without taking their addresses with it.
class PlatformGeographyScreen extends StatefulWidget {
  const PlatformGeographyScreen({super.key});

  @override
  State<PlatformGeographyScreen> createState() => _PlatformGeographyScreenState();
}

class _PlatformGeographyScreenState extends State<PlatformGeographyScreen> {
  final SuperAdminApi _api = SuperAdminApi.instance;
  final TextEditingController _search = TextEditingController();

  List<GeoCountry>? _countries;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<GeoCountry> list = await _api.countries();
      if (!mounted) return;
      setState(() {
        _countries = list;
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

  List<GeoCountry> get _matches {
    final String q = _search.text.trim().toLowerCase();
    final List<GeoCountry> all = _countries ?? const <GeoCountry>[];
    if (q.isEmpty) return all;
    return all
        .where((GeoCountry c) =>
            c.name.toLowerCase().contains(q) || c.iso2.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _addCountry() async {
    final Map<String, String>? v = await _countrySheet(context);
    if (v == null) return;
    await _run(() => _api.createCountry(<String, dynamic>{
      'name': v['name'],
      'iso2': v['iso2'],
      'phoneCode': v['phoneCode'],
      'currency': v['currency'],
    }), '${v['name']} added');
  }

  Future<void> _editCountry(GeoCountry c) async {
    final Map<String, String>? v = await _countrySheet(context, existing: c);
    if (v == null) return;
    await _run(() => _api.updateCountry(c.id, <String, dynamic>{
      'name': v['name'],
      'iso2': v['iso2'],
      'phoneCode': v['phoneCode'],
      'currency': v['currency'],
    }), '${v['name']} saved');
  }

  Future<void> _toggleCountry(GeoCountry c) async {
    await _run(
      () => _api.setCountryActive(id: c.id, active: !c.isActive),
      c.isActive
          ? '${c.name} switched off — no new school can pick it'
          : '${c.name} switched on',
    );
  }

  /// Runs a write and reloads, with one place for the error to surface.
  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(done)));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<GeoCountry> items = _matches;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geography'),
        actions: <Widget>[
          IconButton(
            onPressed: _addCountry,
            tooltip: 'Add a country',
            icon: const Icon(Icons.add),
          ),
          const SignOutAction(),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm,
              ),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Search countries',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? centredMessage(context, _error!, onRetry: _load)
                    : items.isEmpty
                    ? centredMessage(
                        context,
                        _search.text.isEmpty
                            ? 'The country master is empty.'
                            : 'No country matches that.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (BuildContext _, int index) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (BuildContext context, int i) {
                          final GeoCountry c = items[i];
                          return _Row(
                            title: c.name,
                            subtitle: <String>[
                              c.iso2,
                              // The master stores the dialling code with its
                              // own plus sign — "+91", not "91".
                              if ((c.phoneCode ?? '').isNotEmpty) c.phoneCode!,
                              if ((c.currency ?? '').isNotEmpty) c.currency!,
                            ].join(' · '),
                            isActive: c.isActive,
                            onEdit: () => _editCountry(c),
                            onToggle: () => _toggleCountry(c),
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (BuildContext _) =>
                                    _StatesScreen(country: c),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),

    );
  }
}

/// The states of one country.
class _StatesScreen extends StatefulWidget {
  const _StatesScreen({required this.country});

  final GeoCountry country;

  @override
  State<_StatesScreen> createState() => _StatesScreenState();
}

class _StatesScreenState extends State<_StatesScreen> {
  List<GeoState>? _items;
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
      final List<GeoState> list =
          await SuperAdminApi.instance.states(countryId: widget.country.id);
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

  Future<void> _add() async {
    final Map<String, String>? v = await _namedSheet(
      context,
      title: 'Add a state to ${widget.country.name}',
      codeLabel: 'Code',
    );
    if (v == null) return;
    await _run(() => SuperAdminApi.instance.createState(<String, dynamic>{
      'countryId': widget.country.id,
      'name': v['name'],
      'code': v['code'],
    }), '${v['name']} added');
  }

  Future<void> _edit(GeoState st) async {
    final Map<String, String>? v = await _namedSheet(
      context,
      title: 'Edit ${st.name}',
      codeLabel: 'Code',
      name: st.name,
      code: st.code,
    );
    if (v == null) return;
    await _run(() => SuperAdminApi.instance.updateState(st.id, <String, dynamic>{
      'countryId': widget.country.id,
      'name': v['name'],
      'code': v['code'],
    }), '${v['name']} saved');
  }

  Future<void> _toggle(GeoState st) async {
    await _run(
      () => SuperAdminApi.instance.setStateActive(id: st.id, active: !st.isActive),
      st.isActive ? '${st.name} switched off' : '${st.name} switched on',
    );
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(done)));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<GeoState> items = _items ?? const <GeoState>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.country.name),
        actions: <Widget>[
          IconButton(
            onPressed: _add,
            tooltip: 'Add a state',
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? centredMessage(context, _error!, onRetry: _load)
              : items.isEmpty
              ? centredMessage(context, 'No states recorded for ${widget.country.name}.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (BuildContext _, int index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int i) {
                    final GeoState st = items[i];
                    return _Row(
                      title: st.name,
                      subtitle: (st.code ?? '').isEmpty ? null : st.code,
                      isActive: st.isActive,
                      onEdit: () => _edit(st),
                      onToggle: () => _toggle(st),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext _) => _CitiesScreen(state: st),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// The cities of one state. The end of the drill-down, so no chevrons.
class _CitiesScreen extends StatefulWidget {
  const _CitiesScreen({required this.state});

  final GeoState state;

  @override
  State<_CitiesScreen> createState() => _CitiesScreenState();
}

class _CitiesScreenState extends State<_CitiesScreen> {
  List<GeoCity>? _items;
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
      final List<GeoCity> list =
          await SuperAdminApi.instance.cities(stateId: widget.state.id);
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

  Future<void> _add() async {
    final Map<String, String>? v = await _namedSheet(
      context,
      title: 'Add a city to ${widget.state.name}',
    );
    if (v == null) return;
    await _run(() => SuperAdminApi.instance.createCity(<String, dynamic>{
      'stateId': widget.state.id,
      'name': v['name'],
    }), '${v['name']} added');
  }

  Future<void> _edit(GeoCity c) async {
    final Map<String, String>? v = await _namedSheet(
      context,
      title: 'Edit ${c.name}',
      name: c.name,
    );
    if (v == null) return;
    await _run(() => SuperAdminApi.instance.updateCity(c.id, <String, dynamic>{
      'stateId': widget.state.id,
      'name': v['name'],
    }), '${v['name']} saved');
  }

  Future<void> _toggle(GeoCity c) async {
    await _run(
      () => SuperAdminApi.instance.setCityActive(id: c.id, active: !c.isActive),
      c.isActive ? '${c.name} switched off' : '${c.name} switched on',
    );
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(done)));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<GeoCity> items = _items ?? const <GeoCity>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.state.name),
        actions: <Widget>[
          IconButton(
            onPressed: _add,
            tooltip: 'Add a city',
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? centredMessage(context, _error!, onRetry: _load)
              : items.isEmpty
              ? centredMessage(context, 'No cities recorded for ${widget.state.name}.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (BuildContext _, int index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int i) => _Row(
                    title: items[i].name,
                    isActive: items[i].isActive,
                    onEdit: () => _edit(items[i]),
                    onToggle: () => _toggle(items[i]),
                  ),
                ),
        ),
      ),
    );
  }
}

/// One master entry: its name, and whether a school can pick it.
class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    this.subtitle,
    required this.isActive,
    this.onTap,
    this.onEdit,
    this.onToggle,
  });

  final String title;
  final String? subtitle;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  /// Switching off, not deleting — see the note on the screen.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          border: Border.all(color: theme.dividerColor),
          borderRadius: AppRadius.cardRadius,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleSmall),
                  if ((subtitle ?? '').isNotEmpty)
                    Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            // Only the off state is marked. Nearly everything is on, and a
            // green pill against every row of a long list says nothing.
            if (!isActive)
              const StatusPill('Off', color: AppColors.amber, dense: true),
            if (onEdit != null || onToggle != null)
              PopupMenuButton<String>(
                tooltip: 'Actions',
                icon: Icon(Icons.more_vert, size: 18, color: theme.hintColor),
                onSelected: (String v) {
                  if (v == 'edit') onEdit?.call();
                  if (v == 'toggle') onToggle?.call();
                },
                itemBuilder: (BuildContext _) => <PopupMenuEntry<String>>[
                  if (onEdit != null)
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                  if (onToggle != null)
                    PopupMenuItem<String>(
                      value: 'toggle',
                      child: Text(isActive ? 'Switch off' : 'Switch on'),
                    ),
                ],
              ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 18, color: theme.hintColor),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------------------------------------------- sheets -- */
//
// Both sheets put their text controllers on a StatefulWidget rather than
// creating them in the helper and disposing after the await.
//
// showModalBottomSheet's future completes when the route is POPPED, not when it
// has finished leaving: the sheet is still mounted and still animating down at
// that moment. Disposing the controllers there pulls them out from under a live
// TextField, which throws "A TextEditingController was used after being
// disposed" and then takes the frame down with
// "'_dependents.isEmpty': is not true" as the half-built subtree unwinds.
//
// Owning them in State ties disposal to the sheet actually being unmounted,
// which is the only moment that is safe.

/// Name plus an optional code. Serves states and cities, which differ only in
/// whether the code field is offered at all.
Future<Map<String, String>?> _namedSheet(
  BuildContext context, {
  required String title,
  String? codeLabel,
  String? name,
  String? code,
}) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => _NamedSheet(
      title: title,
      codeLabel: codeLabel,
      name: name,
      code: code,
    ),
  );
}

class _NamedSheet extends StatefulWidget {
  const _NamedSheet({
    required this.title,
    this.codeLabel,
    this.name,
    this.code,
  });

  final String title;
  final String? codeLabel;
  final String? name;
  final String? code;

  @override
  State<_NamedSheet> createState() => _NamedSheetState();
}

class _NamedSheetState extends State<_NamedSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.name ?? '');
  late final TextEditingController _code =
      TextEditingController(text: widget.code ?? '');

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  void _save() {
    final String n = _name.text.trim();
    if (n.isEmpty) return;
    Navigator.of(context).pop(<String, String>{
      'name': n,
      'code': _code.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the sheet clear of the keyboard the autofocus brings up.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: widget.codeLabel == null
                    ? TextInputAction.done
                    : TextInputAction.next,
                onSubmitted: (_) {
                  if (widget.codeLabel == null) _save();
                },
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              if (widget.codeLabel != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  decoration: InputDecoration(labelText: widget.codeLabel),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A country carries more than a name: the ISO code is what the rest of the
/// system joins on, and the dialling code and currency are read off it when a
/// school is onboarded.
Future<Map<String, String>?> _countrySheet(
  BuildContext context, {
  GeoCountry? existing,
}) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => _CountrySheet(existing: existing),
  );
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({this.existing});

  final GeoCountry? existing;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _iso =
      TextEditingController(text: widget.existing?.iso2 ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.existing?.phoneCode ?? '');
  late final TextEditingController _currency =
      TextEditingController(text: widget.existing?.currency ?? '');

  @override
  void dispose() {
    _name.dispose();
    _iso.dispose();
    _phone.dispose();
    _currency.dispose();
    super.dispose();
  }

  void _save() {
    final String n = _name.text.trim();
    final String iso = _iso.text.trim().toUpperCase();
    // The server rejects both of these anyway; refusing here saves a round trip
    // and keeps what was typed on screen to be corrected.
    if (n.isEmpty || iso.length != 2) return;
    Navigator.of(context).pop(<String, String>{
      'name': n,
      'iso2': iso,
      'phoneCode': _phone.text.trim(),
      'currency': _currency.text.trim().toUpperCase(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.existing == null ? 'Add a country' : 'Edit ${widget.existing!.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _iso,
                      maxLength: 2,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'ISO code',
                        counterText: '',
                        hintText: 'NP',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Phone code',
                        hintText: '+977',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _currency,
                maxLength: 3,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Currency',
                  counterText: '',
                  hintText: 'NPR',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
