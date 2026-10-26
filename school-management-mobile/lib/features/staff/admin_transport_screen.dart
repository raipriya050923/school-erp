import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// Transport charges: the distance bands, and who rides.
///
/// Two jobs on one screen because they only make sense together — a band is an
/// abstraction until you see who falls in it, and a student's amount is
/// unexplainable without the band that produced it.
///
/// The student list is every student in the school, which here is 1,249 of
/// them and nearly all not riding. So it opens filtered to riders and to
/// whatever needs attention, with the rest behind a search.
class AdminTransportScreen extends StatefulWidget {
  const AdminTransportScreen({super.key});

  @override
  State<AdminTransportScreen> createState() => _AdminTransportScreenState();
}

enum _Filter { needsAttention, riders, all }

class _AdminTransportScreenState extends State<AdminTransportScreen> {
  final AdminApi _api = AdminApi.instance;

  TransportGrid? _grid;
  bool _loading = true;
  String? _error;
  String _query = '';
  _Filter _filter = _Filter.riders;

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
      final TransportGrid g = await _api.transport();
      if (!mounted) return;
      setState(() {
        _grid = g;
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

  Future<void> _editSlabs() async {
    final List<Map<String, dynamic>>? slabs = await Navigator.of(context)
        .push<List<Map<String, dynamic>>>(
          MaterialPageRoute<List<Map<String, dynamic>>>(
            builder: (BuildContext _) =>
                TransportBandsScreen(slabs: _grid?.slabs ?? const <TransportSlab>[]),
          ),
        );
    if (slabs == null || !mounted) return;
    await runAndReload(
      context,
      () => _api.saveTransportSlabs(slabs: slabs),
      'Distance bands saved',
      _load,
    );
  }

  Future<void> _editStudent(TransportStudent s) async {
    final Map<String, dynamic>? row =
        await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext c) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(c).viewInsets.bottom,
            ),
            child: TransportStudentSheet(student: s),
          ),
        );
    if (row == null || !mounted) return;
    await runAndReload(
      context,
      () => _api.saveTransportStudents(<Map<String, dynamic>>[row]),
      '${s.name} saved',
      _load,
    );
  }

  List<TransportStudent> _rows(TransportGrid g) {
    final String q = _query.trim().toLowerCase();
    Iterable<TransportStudent> rows = g.students;

    switch (_filter) {
      case _Filter.needsAttention:
        // The rows an admin has to do something about: riding but unpriceable.
        rows = rows.where(
          (TransportStudent s) =>
              s.status == 'no_distance' || s.status == 'beyond_slabs',
        );
      case _Filter.riders:
        rows = rows.where((TransportStudent s) => s.usesTransport);
      case _Filter.all:
        break;
    }

    if (q.isNotEmpty) {
      // A search is a deliberate act, so it looks past the filter: someone
      // typing a name wants that student whether or not they ride today.
      rows = g.students.where(
        (TransportStudent s) =>
            s.name.toLowerCase().contains(q) ||
            s.admissionNo.toLowerCase().contains(q) ||
            s.classLabel.toLowerCase().contains(q),
      );
    }
    return rows.toList();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TransportGrid? g = _grid;
    final List<TransportStudent> rows = g == null
        ? const <TransportStudent>[]
        : _rows(g);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transport fee'),
        actions: const <Widget>[SignOutAction()],
        bottom: g == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(58),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: TextField(
                    onChanged: (String v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search name, admission no or class',
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                    ),
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
              if (g != null) ...<Widget>[
                if (g.feeHeadName == null)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'No transport head yet',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Nothing here can be charged until a fee head is '
                          'set to be priced by distance. Fee structure → Fee '
                          'heads.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                else ...<Widget>[
                  MetricGrid(
                    tiles: <MetricTile>[
                      MetricTile(
                        label: 'Riders',
                        value: '${g.summary.riders}',
                        tint: 0,
                        icon: Icons.directions_bus_outlined,
                      ),
                      MetricTile(
                        label: 'Monthly',
                        value: Format.money(g.summary.monthlyTotal),
                        tint: 1,
                        icon: Icons.payments_outlined,
                      ),
                      MetricTile(
                        label: 'Needs distance',
                        value: '${g.summary.needsDistance}',
                        tint: 2,
                        icon: Icons.help_outline,
                      ),
                      MetricTile(
                        label: 'Beyond bands',
                        value: '${g.summary.beyondSlabs}',
                        tint: 3,
                        icon: Icons.warning_amber_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  SectionHeader(
                    'Distance bands',
                    subtitle: g.slabs.isEmpty
                        ? 'None set — nobody can be priced yet'
                        : '${g.slabs.length} bands',
                    actionLabel: 'Edit',
                    onAction: _editSlabs,
                  ),
                  if (g.slabs.isEmpty)
                    const EmptyState(
                      icon: Icons.straighten_outlined,
                      title: 'No bands yet',
                      message: 'Add bands and every rider is priced at once.',
                    )
                  else
                    for (final TransportSlab s in g.slabs)
                      StaffRow(
                        title: '${_km(s.fromKm)} – ${_km(s.upToKm)} km',
                        subtitle: s.riders == 1
                            ? '1 rider'
                            : '${s.riders} riders',
                        trailing: Format.money(s.amount),
                      ),

                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    'Students',
                    subtitle: _filterLine(g, rows.length),
                  ),
                  SegmentedButton<_Filter>(
                    segments: <ButtonSegment<_Filter>>[
                      ButtonSegment<_Filter>(
                        value: _Filter.needsAttention,
                        label: Text('Needs work (${_needsWork(g)})'),
                      ),
                      ButtonSegment<_Filter>(
                        value: _Filter.riders,
                        label: Text('Riders (${g.summary.riders})'),
                      ),
                      const ButtonSegment<_Filter>(
                        value: _Filter.all,
                        label: Text('All'),
                      ),
                    ],
                    selected: <_Filter>{_filter},
                    showSelectedIcon: false,
                    onSelectionChanged: (Set<_Filter> v) =>
                        setState(() => _filter = v.first),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (rows.isEmpty)
                    EmptyState(
                      icon: Icons.person_search_outlined,
                      title: _query.isNotEmpty
                          ? 'No students match'
                          : 'Nobody here',
                      message: _query.isNotEmpty
                          ? null
                          : 'Press a student on All to put them on transport.',
                    )
                  else
                    // Capped: 1,249 rows built at once is a stutter on a phone,
                    // and nobody scrolls that far — the search is the way in.
                    for (final TransportStudent s in rows.take(100))
                      StaffRow(
                        title: s.name,
                        subtitle: _studentLine(s),
                        trailing: s.amount > 0 ? Format.money(s.amount) : null,
                        status: _statusChip(s.status),
                        onTap: () => _editStudent(s),
                      ),
                  if (rows.length > 100)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Text(
                        'Showing the first 100 of ${rows.length}. '
                        'Search to narrow it.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  int _needsWork(TransportGrid g) =>
      g.summary.needsDistance + g.summary.beyondSlabs;

  String _filterLine(TransportGrid g, int shown) {
    if (_query.isNotEmpty) return '$shown matching "$_query"';
    return '$shown of ${g.students.length}';
  }
}

String _km(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toString();

String _studentLine(TransportStudent s) => <String>[
  s.admissionNo,
  if (s.classLabel.isNotEmpty) s.classLabel,
  if (s.distanceKm != null) '${_km(s.distanceKm!)} km',
  if (s.pickupPoint != null && s.pickupPoint!.isNotEmpty) s.pickupPoint!,
].join(' · ');

/// Only the states worth a chip. "priced" is the expected one and needs no
/// label; "not riding" is the default for most of the school and would put a
/// chip on a thousand rows.
String? _statusChip(String status) {
  switch (status) {
    case 'no_distance':
      return 'needs distance';
    case 'beyond_slabs':
      return 'beyond bands';
    case 'no_slabs':
      return 'no bands';
    default:
      return null;
  }
}

/* ------------------------------------------------------ distance bands -- */

/// The whole band set, edited together.
///
/// The API replaces them in one call because they are not independent: moving
/// a ceiling moves students between bands. Returns the list to save, or null.
class TransportBandsScreen extends StatefulWidget {
  const TransportBandsScreen({super.key, required this.slabs});

  final List<TransportSlab> slabs;

  @override
  State<TransportBandsScreen> createState() => TransportBandsScreenState();
}

class _SlabRow {
  _SlabRow(this.upTo, this.amount);

  final TextEditingController upTo;
  final TextEditingController amount;

  void dispose() {
    upTo.dispose();
    amount.dispose();
  }
}

class TransportBandsScreenState extends State<TransportBandsScreen> {
  late final List<_SlabRow> _rows = <_SlabRow>[
    for (final TransportSlab s in widget.slabs)
      _SlabRow(
        TextEditingController(text: _km(s.upToKm)),
        TextEditingController(text: _km(s.amount)),
      ),
  ];
  String? _error;

  @override
  void dispose() {
    for (final _SlabRow r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _add() => setState(
    () => _rows.add(_SlabRow(TextEditingController(), TextEditingController())),
  );

  void _save() {
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    double previous = 0;

    for (int i = 0; i < _rows.length; i++) {
      final String upRaw = _rows[i].upTo.text.trim();
      final String amtRaw = _rows[i].amount.text.trim();
      if (upRaw.isEmpty && amtRaw.isEmpty) continue; // a row left blank

      final double? upTo = double.tryParse(upRaw);
      final double? amount = double.tryParse(amtRaw);
      if (upTo == null || amount == null || upTo <= 0 || amount < 0) {
        setState(
          () => _error =
              'Band ${i + 1}: give a distance above zero and an amount.',
        );
        return;
      }
      // Ascending, because each band starts where the one below it ended. Out
      // of order the ceilings overlap and a student falls in two bands.
      if (upTo <= previous) {
        setState(
          () => _error =
              'Band ${i + 1}: ${_km(upTo)} km must be further than '
              '${_km(previous)} km.',
        );
        return;
      }
      previous = upTo;
      out.add(<String, dynamic>{'upToKm': upTo, 'amount': amount});
    }

    Navigator.of(context).pop(out);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Distance bands')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Band'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            96,
          ),
          children: <Widget>[
            Text(
              'Each band runs from where the one above it ended. A student is '
              'charged by the first band their distance fits.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (int i = 0; i < _rows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _rows[i].upTo,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Band ${i + 1} up to',
                          suffixText: 'km',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextField(
                        controller: _rows[i].amount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          prefixText: Format.currencySymbol,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() {
                        _rows.removeAt(i).dispose();
                      }),
                      icon: const Icon(Icons.close),
                      tooltip: 'Remove band',
                    ),
                  ],
                ),
              ),
            if (_rows.isEmpty)
              Text(
                'No bands yet. Add the first one.',
                style: theme.textTheme.bodyMedium,
              ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: _save, child: const Text('Save bands')),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------------------------------- one student -- */

class TransportStudentSheet extends StatefulWidget {
  const TransportStudentSheet({super.key, required this.student});

  final TransportStudent student;

  @override
  State<TransportStudentSheet> createState() => TransportStudentSheetState();
}

class TransportStudentSheetState extends State<TransportStudentSheet> {
  late bool _rides = widget.student.usesTransport;
  late final TextEditingController _distance = TextEditingController(
    text: widget.student.distanceKm == null
        ? ''
        : _km(widget.student.distanceKm!),
  );
  late final TextEditingController _pickup = TextEditingController(
    text: widget.student.pickupPoint ?? '',
  );
  late final TextEditingController _override = TextEditingController(
    text: widget.student.amountOverride == null
        ? ''
        : _km(widget.student.amountOverride!),
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.student.note ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _distance.dispose();
    _pickup.dispose();
    _override.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    double? distance;
    if (_distance.text.trim().isNotEmpty) {
      distance = double.tryParse(_distance.text.trim());
      if (distance == null || distance < 0) {
        setState(() => _error = 'Distance must be a number.');
        return;
      }
    }
    double? override;
    if (_override.text.trim().isNotEmpty) {
      override = double.tryParse(_override.text.trim());
      if (override == null || override < 0) {
        setState(() => _error = 'The override must be a number.');
        return;
      }
    }
    if (_rides && distance == null && override == null) {
      setState(
        () => _error =
            'A rider needs either a distance or an amount of their own.',
      );
      return;
    }

    Navigator.of(context).pop(<String, dynamic>{
      'studentId': widget.student.studentId,
      'usesTransport': _rides,
      'distanceKm': distance,
      'pickupPoint': _pickup.text.trim().isEmpty ? null : _pickup.text.trim(),
      'amountOverride': override,
      'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SheetFrame(
      title: widget.student.name,
      onSave: _save,
      children: <Widget>[
        SwitchListTile(
          value: _rides,
          onChanged: (bool v) => setState(() => _rides = v),
          title: const Text('Uses transport'),
          contentPadding: EdgeInsets.zero,
        ),
        if (_rides) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _distance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Distance',
              suffixText: 'km',
              helperText: 'The band this falls in sets the amount.',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _pickup,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Pickup point'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _override,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount of their own (optional)',
              prefixText: Format.currencySymbol,
              helperText:
                  'Overrides the band — for a case the bands do not fit.',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          if (widget.student.matchedSlabKm != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Currently priced by the band up to '
              '${_km(widget.student.matchedSlabKm!)} km.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
      ],
    );
  }
}
