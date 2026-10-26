import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../../data/staff_models.dart';
import 'admin_periods_screen.dart';
import 'staff_widgets.dart';

const List<String> _dayNames = <String>[
  '',
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

String _dayShort(int d) => _dayNames[d].substring(0, 3);

/// The school's timetable.
///
/// The web portal puts the whole school's day in one table — ten sections
/// across seven periods. That does not survive a phone screen, so this is the
/// same data one level deeper: pick a day, pick a section, and the section's
/// periods are a list you can read and press. The counts on each row are what
/// the grid gave at a glance — which sections are still empty.
class AdminTimetableScreen extends StatefulWidget {
  const AdminTimetableScreen({super.key});

  @override
  State<AdminTimetableScreen> createState() => _AdminTimetableScreenState();
}

class _AdminTimetableScreenState extends State<AdminTimetableScreen> {
  final AdminApi _api = AdminApi.instance;

  DayTimetable? _day;
  bool _loading = true;
  String? _error;

  /// Sunday, which every working-day set in this system starts from. Replaced
  /// by the first real working day as soon as the first load lands.
  int _selected = 1;
  bool _pickedDay = false;

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
      final DayTimetable d = await _api.timetableDay(_selected);
      if (!mounted) return;
      setState(() {
        _day = d;
        _loading = false;
        // Land on a day the school actually runs rather than on an empty one.
        if (!_pickedDay &&
            d.workingDays.isNotEmpty &&
            !d.workingDays.contains(_selected)) {
          _selected = d.workingDays.first;
          _pickedDay = true;
        }
      });
      if (_pickedDay && d.dayOfWeek != _selected) await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _openSection(DayRow row) async {
    final DayTimetable d = _day!;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => _SectionDayScreen(
          row: row,
          periods: d.periods,
          dayOfWeek: d.dayOfWeek,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _autoFill() async {
    final DayTimetable d = _day!;
    final bool ok = await confirmAction(
      context,
      title: 'Suggest for ${_dayNames[d.dayOfWeek]}?',
      message: 'Empty periods are filled with subjects each class studies, '
          'without double-booking a teacher. Periods already set are left '
          'alone.',
      confirmLabel: 'Suggest',
      destructive: false,
    );
    if (!ok || !mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final Color errorColour = Theme.of(context).colorScheme.error;
    try {
      final AutoFillResult r = await _api.autoFillDay(d.dayOfWeek);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            r.filled == 0
                ? 'Nothing could be filled. ${r.notes.isEmpty ? '' : r.notes.first}'
                : 'Filled ${r.filled}, left ${r.leftEmpty} empty.',
          ),
        ),
      );
      await _load();
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: errorColour),
      );
    }
  }

  Future<void> _reset() async {
    final DayTimetable d = _day!;
    final String? scope = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            ListTile(
              title: Text('Clear the timetable',
                  style: Theme.of(sheet).textTheme.titleMedium),
              subtitle: const Text('Periods and working days are kept.'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.today_outlined),
              title: Text('Clear ${_dayNames[d.dayOfWeek]} only'),
              onTap: () => Navigator.of(sheet).pop('day'),
            ),
            ListTile(
              leading: Icon(Icons.delete_sweep_outlined,
                  color: Theme.of(sheet).colorScheme.error),
              title: Text('Clear the whole week',
                  style:
                      TextStyle(color: Theme.of(sheet).colorScheme.error)),
              onTap: () => Navigator.of(sheet).pop('week'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (scope == null || !mounted) return;

    final bool ok = await confirmAction(
      context,
      title: scope == 'day'
          ? 'Clear ${_dayNames[d.dayOfWeek]}?'
          : 'Clear the whole week?',
      message: 'Every scheduled period in that range is removed.',
      confirmLabel: 'Clear',
    );
    if (!ok || !mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final Color errorColour = Theme.of(context).colorScheme.error;
    try {
      final ResetResult r = await _api.resetTimetable(
        dayOfWeek: scope == 'day' ? d.dayOfWeek : null,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('Cleared ${r.cleared} periods.')),
      );
      await _load();
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: errorColour),
      );
    }
  }

  Future<void> _workingDays() async {
    final List<int>? days = await showModalBottomSheet<List<int>>(
      context: context,
      builder: (BuildContext c) =>
          _WorkingDaysSheet(selected: _day?.workingDays ?? const <int>[]),
    );
    if (days == null || !mounted) return;
    await runAndReload(
      context,
      () => _api.setWorkingDays(days),
      'Working days saved',
      _load,
    );
  }

  Future<void> _openTeacher() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => const AdminTeacherWeekScreen(),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DayTimetable? d = _day;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable'),
        actions: <Widget>[
          IconButton(
            onPressed: _openTeacher,
            icon: const Icon(Icons.person_search_outlined),
            tooltip: 'One teacher',
          ),
          PopupMenuButton<String>(
            onSelected: (String v) {
              switch (v) {
                case 'periods':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext _) => const AdminPeriodsScreen(),
                    ),
                  ).then((_) {
                    if (mounted) _load();
                  });
                case 'days':
                  _workingDays();
                case 'autofill':
                  _autoFill();
                case 'reset':
                  _reset();
              }
            },
            itemBuilder: (BuildContext _) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'periods', child: Text('Periods')),
              PopupMenuItem<String>(value: 'days', child: Text('Working days')),
              PopupMenuItem<String>(
                  value: 'autofill', child: Text('Suggest for this day')),
              PopupMenuItem<String>(
                  value: 'reset', child: Text('Clear timetable')),
            ],
          ),
          const SignOutAction(),
        ],
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
                if (d.workingDays.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        for (final int day in d.workingDays)
                          Padding(
                            padding:
                                const EdgeInsets.only(right: AppSpacing.sm),
                            child: ChoiceChip(
                              label: Text(_dayShort(day)),
                              selected: day == d.dayOfWeek,
                              onSelected: (_) {
                                setState(() {
                                  _selected = day;
                                  _pickedDay = true;
                                });
                                _load();
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),

                if (d.periods.isEmpty)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('No periods yet',
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'A timetable needs a school day first. Set the '
                          'periods from the menu above.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                else if (d.rows.isEmpty)
                  const EmptyState(
                    icon: Icons.meeting_room_outlined,
                    title: 'No sections yet',
                    message: 'Add classes and sections first.',
                  )
                else ...<Widget>[
                  SectionHeader(
                    _dayNames[d.dayOfWeek],
                    subtitle: '${d.rows.length} sections · '
                        '${d.periods.where((AdminPeriod p) => !p.isBreak).length} teaching periods',
                  ),
                  for (final DayRow r in d.rows)
                    StaffRow(
                      title: r.label,
                      subtitle: _rowLine(r, d),
                      trailing: '${r.filledCount}',
                      onTap: () => _openSection(r),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _rowLine(DayRow r, DayTimetable d) {
    final int teaching =
        d.periods.where((AdminPeriod p) => !p.isBreak).length;
    // A section can hold periods set earlier and still have no subjects to
    // offer now, if the curriculum was changed afterwards. Saying only one of
    // those reads as a contradiction against the count on the right.
    if (r.subjects.isEmpty) {
      return r.filledCount == 0
          ? 'No subjects assigned to this class yet'
          : '${r.filledCount} set · no subjects assigned, so no more can be';
    }
    return '${r.filledCount} of $teaching periods set';
  }
}

/* --------------------------------------------- one section, one day -- */

class _SectionDayScreen extends StatefulWidget {
  const _SectionDayScreen({
    required this.row,
    required this.periods,
    required this.dayOfWeek,
  });

  final DayRow row;
  final List<AdminPeriod> periods;
  final int dayOfWeek;

  @override
  State<_SectionDayScreen> createState() => _SectionDayScreenState();
}

class _SectionDayScreenState extends State<_SectionDayScreen> {
  final AdminApi _api = AdminApi.instance;

  late DayRow _row = widget.row;
  bool _busy = false;

  Future<void> _reload() async {
    try {
      final DayTimetable d = await _api.timetableDay(widget.dayOfWeek);
      final DayRow? fresh = d.rows
          .where((DayRow r) => r.sectionId == _row.sectionId)
          .cast<DayRow?>()
          .firstWhere((DayRow? r) => true, orElse: () => null);
      if (fresh != null && mounted) setState(() => _row = fresh);
    } on ApiException {
      // The list behind this screen reloads on pop regardless; a failed
      // refresh here is not worth a dialog over the work just saved.
    }
  }

  Future<void> _editCell(AdminPeriod p) async {
    if (p.isBreak) return;
    final TimetableCell? cell = _row.cellAt(p.periodNo);

    final _SlotChoice? choice = await showModalBottomSheet<_SlotChoice>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: _SlotSheet(
          period: p,
          cell: cell,
          options: _row.subjects,
        ),
      ),
    );
    if (choice == null || !mounted) return;

    setState(() => _busy = true);
    await runAndReload(
      context,
      () => _api.saveTimetableSlot(
        className: _row.className,
        sectionName: _row.sectionName,
        dayOfWeek: widget.dayOfWeek,
        periodNo: p.periodNo,
        subject: choice.subject,
        room: choice.room,
        teacherStaffId: choice.teacherStaffId,
      ),
      choice.subject == null ? 'Period cleared' : 'Period set',
      _reload,
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_row.label),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              _dayNames[widget.dayOfWeek],
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onPrimary),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: <Widget>[
                if (_row.subjects.isEmpty)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Nothing to schedule',
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'This class has no subjects assigned, so there is '
                          'nothing a period could hold. Assign them under '
                          'Classes & sections first.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                for (final AdminPeriod p in widget.periods)
                  _PeriodTile(
                    period: p,
                    cell: _row.cellAt(p.periodNo),
                    onTap: _row.subjects.isEmpty ? null : () => _editCell(p),
                  ),
              ],
            ),
            if (_busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x22000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PeriodTile extends StatelessWidget {
  const _PeriodTile({required this.period, this.cell, this.onTap});

  final AdminPeriod period;
  final TimetableCell? cell;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool empty = cell == null || cell!.isEmpty;

    if (period.isBreak) {
      // Greyed and inert: a break cannot hold a class, so offering a tap would
      // only teach someone that nothing happens.
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: theme.disabledColor.withValues(alpha: 0.06),
            borderRadius: AppRadius.cardRadius,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text('${period.name} · break',
                    style: theme.textTheme.bodyMedium),
              ),
              Text(period.timeLabel, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: StaffRow(
        title: empty ? period.name : '${period.name} · ${cell!.subject}',
        subtitle: empty
            ? 'Free — press to set'
            : <String>[
                if (cell!.teacherName != null && cell!.teacherName!.isNotEmpty)
                  cell!.teacherName!,
                if (cell!.room != null && cell!.room!.isNotEmpty)
                  'Room ${cell!.room}',
              ].join(' · '),
        trailing: period.timeLabel,
        onTap: onTap,
      ),
    );
  }
}

class _SlotChoice {
  const _SlotChoice(this.subject, this.room, this.teacherStaffId);

  /// Null clears the period.
  final String? subject;
  final String? room;
  final int? teacherStaffId;
}

class _SlotSheet extends StatefulWidget {
  const _SlotSheet({
    required this.period,
    required this.cell,
    required this.options,
  });

  final AdminPeriod period;
  final TimetableCell? cell;
  final List<TimetableSubjectOption> options;

  @override
  State<_SlotSheet> createState() => _SlotSheetState();
}

class _SlotSheetState extends State<_SlotSheet> {
  late String? _subject = widget.cell?.subject;
  late final TextEditingController _room =
      TextEditingController(text: widget.cell?.room ?? '');

  @override
  void dispose() {
    _room.dispose();
    super.dispose();
  }

  TimetableSubjectOption? get _chosen {
    for (final TimetableSubjectOption o in widget.options) {
      if (o.subject == _subject) return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TimetableSubjectOption? chosen = _chosen;

    return SheetFrame(
      title: '${widget.period.name} · ${widget.period.timeLabel}',
      saveLabel: _subject == null ? 'Clear' : 'Set',
      onSave: () => Navigator.of(context).pop(
        _SlotChoice(
          _subject,
          _room.text.trim().isEmpty ? null : _room.text.trim(),
          chosen?.teacherStaffId,
        ),
      ),
      children: <Widget>[
        DropdownButtonFormField<String?>(
          initialValue: _subject,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Subject'),
          items: <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              child: Text('— free period —'),
            ),
            for (final TimetableSubjectOption o in widget.options)
              DropdownMenuItem<String?>(
                value: o.subject,
                child: Text(o.subject, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (String? v) => setState(() => _subject = v),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _room,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Room (optional)'),
        ),
        const SizedBox(height: AppSpacing.md),
        // The teacher follows the subject rather than being picked, so the
        // timetable can never disagree with who is assigned to teach it.
        Text(
          chosen == null
              ? 'Clearing this period frees the class and its teacher.'
              : chosen.teacherName == null || chosen.teacherName!.isEmpty
                  ? 'No teacher is assigned to ${chosen.subject} for this '
                      'section yet.'
                  : 'Taught by ${chosen.teacherName}.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/* ------------------------------------------------------- working days -- */

class _WorkingDaysSheet extends StatefulWidget {
  const _WorkingDaysSheet({required this.selected});

  final List<int> selected;

  @override
  State<_WorkingDaysSheet> createState() => _WorkingDaysSheetState();
}

class _WorkingDaysSheetState extends State<_WorkingDaysSheet> {
  late final Set<int> _days = widget.selected.toSet();

  @override
  Widget build(BuildContext context) => SheetFrame(
        title: 'Working days',
        onSave: () {
          final List<int> out = _days.toList()..sort();
          Navigator.of(context).pop(out);
        },
        children: <Widget>[
          Text(
            'Days the school runs. The timetable offers no others.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (int d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(_dayShort(d)),
                  selected: _days.contains(d),
                  onSelected: (bool on) => setState(() {
                    if (on) {
                      _days.add(d);
                    } else {
                      _days.remove(d);
                    }
                  }),
                ),
            ],
          ),
        ],
      );
}

/* -------------------------------------------------------- one teacher -- */

/// One teacher's week, across every class they teach.
///
/// The counterpart to the section view: a section view answers "what is this
/// class doing", this answers "where is this teacher", which is the question
/// behind every double-booking.
class AdminTeacherWeekScreen extends StatefulWidget {
  const AdminTeacherWeekScreen({super.key});

  @override
  State<AdminTeacherWeekScreen> createState() => _AdminTeacherWeekScreenState();
}

class _AdminTeacherWeekScreenState extends State<AdminTeacherWeekScreen> {
  final AdminApi _api = AdminApi.instance;

  List<AdminTeacher>? _teachers;
  AdminTeacher? _picked;
  TeacherWeek? _week;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<AdminTeacher> list = await _api.teachers();
      if (!mounted) return;
      setState(() {
        _teachers = list;
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

  Future<void> _pick(AdminTeacher t) async {
    setState(() {
      _picked = t;
      _loading = true;
      _error = null;
    });
    try {
      final TeacherWeek w = await _api.teacherWeek(t.id);
      if (!mounted) return;
      setState(() {
        _week = w;
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TeacherWeek? w = _week;

    return Scaffold(
      appBar: AppBar(
        title: Text(_picked == null ? 'One teacher' : _picked!.name),
        leading: _picked == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _picked = null;
                  _week = null;
                }),
              ),
      ),
      body: SafeArea(
        child: MasterBody(
          loading: _loading,
          error: _error,
          onRetry: _picked == null ? _loadTeachers : () => _pick(_picked!),
          isEmpty: _picked == null && (_teachers ?? const <AdminTeacher>[]).isEmpty,
          empty: const EmptyState(
            icon: Icons.co_present_outlined,
            title: 'No teachers yet',
          ),
          children: _picked == null
              ? <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text('Pick a teacher to see their week.',
                        style: theme.textTheme.bodySmall),
                  ),
                  for (final AdminTeacher t
                      in _teachers ?? const <AdminTeacher>[])
                    StaffRow(
                      title: t.name,
                      subtitle: t.subject,
                      onTap: () => _pick(t),
                    ),
                ]
              : <Widget>[
                  if (w != null) ...<Widget>[
                    if (w.cells.isEmpty)
                      const EmptyState(
                        icon: Icons.event_busy_outlined,
                        title: 'Nothing scheduled',
                        message: 'This teacher has no periods this week.',
                      )
                    else
                      for (final int day in w.workingDays)
                        _TeacherDay(week: w, day: day),
                  ],
                ],
        ),
      ),
    );
  }
}

class _TeacherDay extends StatelessWidget {
  const _TeacherDay({required this.week, required this.day});

  final TeacherWeek week;
  final int day;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<TeacherWeekCell> cells = week.cells
        .where((TeacherWeekCell c) => c.dayOfWeek == day)
        .toList()
      ..sort((TeacherWeekCell a, TeacherWeekCell b) =>
          a.periodNo.compareTo(b.periodNo));

    if (cells.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(_dayNames[day], style: theme.textTheme.titleSmall),
            ),
            Text('free', style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          _dayNames[day],
          subtitle: cells.length == 1 ? '1 period' : '${cells.length} periods',
        ),
        for (final TeacherWeekCell c in cells)
          StaffRow(
            title: '${c.subject ?? ''} · ${c.label}',
            subtitle: c.room == null || c.room!.isEmpty
                ? null
                : 'Room ${c.room}',
            trailing: _periodLabel(week, c.periodNo),
          ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  String _periodLabel(TeacherWeek w, int periodNo) {
    for (final AdminPeriod p in w.periods) {
      if (p.periodNo == periodNo) return p.name;
    }
    return 'P$periodNo';
  }
}
