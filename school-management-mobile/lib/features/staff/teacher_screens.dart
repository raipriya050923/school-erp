import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/loadable.dart';
import '../../core/staff_stores.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/api_models.dart' show StudentTimetable, TimetableSlot;
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

const List<String> _dayNames = <String>[
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

/* ------------------------------------------------------------ dashboard -- */

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => TeacherStore.instance.loadDashboard(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreBuilder<TeacherStore>(
      store: TeacherStore.instance,
      builder: (BuildContext context, TeacherStore store) => StaffPage(
        title: 'Dashboard',
        subtitle: store.dashboard.value?.profile.name,
        onRefresh: () => store.loadDashboard(force: true),
        child: StaffSection<TeacherDashboard>(
          state: store.dashboard,
          onRetry: () => store.loadDashboard(force: true),
          builder: (BuildContext context, TeacherDashboard d) => MetricGrid(
            tiles: <MetricTile>[
              MetricTile(
                label: 'My classes',
                value: '${d.myClassesCount}',
                tint: 0,
                icon: Icons.class_outlined,
              ),
              MetricTile(
                label: 'Students taught',
                value: '${d.studentsTaught}',
                tint: 1,
                icon: Icons.groups_outlined,
              ),
              MetricTile(
                label: 'To grade',
                value: '${d.submissionsToGrade}',
                tint: 2,
                icon: Icons.rate_review_outlined,
              ),
              MetricTile(
                label: 'Open homework',
                value: '${d.openHomework}',
                tint: 3,
                icon: Icons.assignment_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------- classes -- */

class TeacherClassesScreen extends StatefulWidget {
  const TeacherClassesScreen({super.key});

  @override
  State<TeacherClassesScreen> createState() => _TeacherClassesScreenState();
}

class _TeacherClassesScreenState extends State<TeacherClassesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => TeacherStore.instance.loadClasses(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreBuilder<TeacherStore>(
      store: TeacherStore.instance,
      builder: (BuildContext context, TeacherStore store) => StaffPage(
        title: 'My Classes',
        subtitle: store.classes.hasValue
            ? '${store.classes.value!.length} assignments'
            : null,
        onRefresh: () => store.loadClasses(force: true),
        child: StaffSection<List<TeacherClass>>(
          state: store.classes,
          onRetry: () => store.loadClasses(force: true),
          builder: (BuildContext context, List<TeacherClass> rows) => rows.isEmpty
              ? const EmptyState(
                  icon: Icons.class_outlined,
                  title: 'No classes assigned',
                  message:
                      'Ask your admin to assign you a subject under Classes & Sections.',
                )
              : Column(
                  children: <Widget>[
                    for (final TeacherClass c in rows)
                      StaffRow(
                        title: c.label,
                        subtitle:
                            '${c.subject ?? 'No subject'} · ${c.studentCount} students'
                            '${c.room == null ? '' : ' · ${c.room}'}',
                        // Being class teacher is the distinction that decides
                        // what a teacher may do, so it is the badge.
                        status: c.isClassTeacher ? 'class teacher' : null,
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------ timetable -- */

class TeacherTimetableScreen extends StatefulWidget {
  const TeacherTimetableScreen({super.key});

  @override
  State<TeacherTimetableScreen> createState() => _TeacherTimetableScreenState();
}

class _TeacherTimetableScreenState extends State<TeacherTimetableScreen> {
  late int _day = DateTime.now().weekday % 7 + 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => TeacherStore.instance.loadTimetable(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return StoreBuilder<TeacherStore>(
      store: TeacherStore.instance,
      builder: (BuildContext context, TeacherStore store) => StaffPage(
        title: 'My Timetable',
        subtitle: _dayNames[_day - 1],
        onRefresh: () => store.loadTimetable(force: true),
        child: StaffSection<StudentTimetable>(
          state: store.timetable,
          onRetry: () => store.loadTimetable(force: true),
          builder: (BuildContext context, StudentTimetable t) {
            // The teacher endpoint sends periods but no working-day list, so
            // the strip is built from the days that actually hold a slot.
            final List<int> days =
                t.slots.map((TimetableSlot s) => s.dayOfWeek).toSet().toList()
                  ..sort();
            final List<int> strip = days.isEmpty ? <int>[_day] : days;
            final List<TimetableSlot> today =
                t.slots.where((TimetableSlot s) => s.dayOfWeek == _day).toList()
                  ..sort(
                    (TimetableSlot a, TimetableSlot b) =>
                        a.periodNo.compareTo(b.periodNo),
                  );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: strip.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (BuildContext context, int i) {
                      final int d = strip[i];
                      final bool on = d == _day;
                      return GestureDetector(
                        onTap: () => setState(() => _day = d),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: on
                                ? theme.colorScheme.primary
                                : theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: on
                                  ? theme.colorScheme.primary
                                  : theme.dividerColor,
                            ),
                          ),
                          child: Text(
                            _dayNames[d - 1].substring(0, 3),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: on ? Colors.white : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (today.isEmpty)
                  const EmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'Nothing scheduled',
                    message: 'You have no periods on this day.',
                  )
                else
                  for (final TimetableSlot s in today)
                    StaffRow(
                      title: s.subject ?? 'Free period',
                      subtitle:
                          '${t.labelFor(s.periodNo)} · ${s.time ?? ''}'
                          '${s.room == null ? '' : ' · ${s.room}'}',
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------- leave -- */

class TeacherLeaveScreen extends StatefulWidget {
  const TeacherLeaveScreen({super.key});

  @override
  State<TeacherLeaveScreen> createState() => _TeacherLeaveScreenState();
}

class _TeacherLeaveScreenState extends State<TeacherLeaveScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TeacherStore.instance.loadLeave();
      TeacherStore.instance.loadLeaveTypes();
    });
  }

  Future<void> _apply() async {
    final List<LeaveType> types = TeacherStore.instance.leaveTypes.value ?? <LeaveType>[];
    if (types.isEmpty) return;
    final bool? applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _ApplyLeaveSheet(types: types),
    );
    if (applied == true) await TeacherStore.instance.loadLeave(force: true);
  }

  @override
  Widget build(BuildContext context) {
    return StoreBuilder<TeacherStore>(
      store: TeacherStore.instance,
      builder: (BuildContext context, TeacherStore store) => Scaffold(
        appBar: AppBar(
          title: const Text('My Leave'),
          actions: <Widget>[
            IconButton(
              onPressed: store.leaveTypes.hasValue ? _apply : null,
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Apply for leave',
            ),
            const SignOutAction(),
          ],
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: () => store.loadLeave(force: true),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                StaffSection<List<LeaveApplication>>(
                  state: store.leave,
                  onRetry: () => store.loadLeave(force: true),
                  builder:
                      (BuildContext context, List<LeaveApplication> rows) =>
                          rows.isEmpty
                          ? const EmptyState(
                              icon: Icons.beach_access_outlined,
                              title: 'No leave requests',
                              message: 'Tap + to apply for leave.',
                            )
                          : Column(
                              children: <Widget>[
                                for (final LeaveApplication a in rows)
                                  StaffRow(
                                    title: a.leaveTypeName ?? 'Leave',
                                    subtitle: a.reason,
                                    trailing:
                                        '${a.days.toStringAsFixed(a.days % 1 == 0 ? 0 : 1)} d',
                                    status: a.status,
                                  ),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ApplyLeaveSheet extends StatefulWidget {
  const _ApplyLeaveSheet({required this.types});

  final List<LeaveType> types;

  @override
  State<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends State<_ApplyLeaveSheet> {
  late int _typeId = widget.types.first.id;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  final TextEditingController _reason = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool from}) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
        // Keep the range valid rather than letting the server reject it.
        if (_to.isBefore(_from)) _to = picked;
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'A reason is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await TeacherApi.instance.applyLeave(
        leaveTypeId: _typeId,
        from: _from,
        to: _to,
        reason: _reason.text.trim(),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Apply for leave', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<int>(
              initialValue: _typeId,
              decoration: const InputDecoration(labelText: 'Leave type'),
              items: <DropdownMenuItem<int>>[
                for (final LeaveType t in widget.types)
                  DropdownMenuItem<int>(value: t.id, child: Text(t.name)),
              ],
              onChanged: (int? v) => setState(() => _typeId = v ?? _typeId),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pick(from: true),
                    child: Text('From ${_fmt(_from)}'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pick(from: false),
                    child: Text('To ${_fmt(_to)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _reason,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Text('Submit request'),
            ),
          ],
        ),
      ),
    );
  }
}
