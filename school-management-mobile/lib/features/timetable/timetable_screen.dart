import 'package:flutter/material.dart';

import '../../core/student_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/api_section.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../../data/api_models.dart';
import '../dashboard/dashboard_screen.dart' show NotificationBell;

/// `timetable_slot.day_of_week` is 1 = Sunday … 7 = Saturday.
const List<String> _dayNames = <String>[
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  /// Defaults to today so the screen opens on the day the student cares about.
  late int _day = DateTime.now().weekday % 7 + 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StudentStore.instance.loadTimetable();
      StudentStore.instance.loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable'),
        actions: const <Widget>[NotificationBell(), SizedBox(width: AppSpacing.lg)],
      ),
      body: SafeArea(
        top: false,
        child: StudentStoreBuilder(
          builder: (BuildContext context, StudentStore store) {
            return ApiSection<StudentTimetable>(
              state: store.timetable,
              onRetry: () => store.loadTimetable(force: true),
              loadingHeight: 320,
              builder: (BuildContext context, StudentTimetable data) =>
                  _Timetable(
                    data: data,
                    day: _day,
                    classLabel: store.profile.value?.classLabel,
                    onDaySelected: (int d) => setState(() => _day = d),
                    onRefresh: () => store.loadTimetable(force: true),
                  ),
            );
          },
        ),
      ),
    );
  }
}

class _Timetable extends StatelessWidget {
  const _Timetable({
    required this.data,
    required this.day,
    required this.classLabel,
    required this.onDaySelected,
    required this.onRefresh,
  });

  final StudentTimetable data;
  final int day;
  final String? classLabel;
  final ValueChanged<int> onDaySelected;
  final Future<void> Function() onRefresh;

  List<TimetableSlot> _forDay(int d) {
    final List<TimetableSlot> today =
        data.slots.where((TimetableSlot s) => s.dayOfWeek == d).toList()
          ..sort((TimetableSlot a, TimetableSlot b) =>
              a.periodNo.compareTo(b.periodNo));
    return today;
  }

  /// The days this school actually runs, in order. A school that has not set
  /// its week still needs a strip to draw, so fall back to Sunday-Friday.
  List<int> get _days {
    final List<int> days = data.workingDays.where((int d) => d >= 1 && d <= 7).toList()
      ..sort();
    return days.isEmpty ? const <int>[1, 2, 3, 4, 5, 6] : days;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<TimetableSlot> periods = _forDay(day);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      classLabel?.isNotEmpty == true ? classLabel! : 'My timetable',
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(_dayNames[day - 1], style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              StatusPill(
                '${periods.length} ${periods.length == 1 ? 'period' : 'periods'}',
                color: theme.colorScheme.primary,
                icon: Icons.schedule_rounded,
              ),
            ],
          ),
        ),
        _DaySelector(
          days: _days,
          selected: day,
          countFor: (int d) => _forDay(d).length,
          onSelected: onDaySelected,
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: periods.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: <Widget>[
                      EmptyState(
                        icon: Icons.event_busy_outlined,
                        title: data.slots.isEmpty
                            ? 'No timetable published'
                            : 'No classes scheduled',
                        message: data.slots.isEmpty
                            ? 'Your school has not published a timetable yet.'
                            : 'Enjoy the day off.',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: periods.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (BuildContext context, int index) =>
                        _PeriodCard(slot: periods[index], label: data.labelFor(periods[index].periodNo)),
                  ),
          ),
        ),
      ],
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.days,
    required this.selected,
    required this.countFor,
    required this.onSelected,
  });

  /// Only the days the school runs — a permanently empty Sunday column is not
  /// information.
  final List<int> days;
  final int selected;
  final int Function(int day) countFor;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.page,
        physics: const BouncingScrollPhysics(),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) {
          final int day = days[index];
          final bool isSelected = day == selected;
          final int classCount = countFor(day);

          return GestureDetector(
            onTap: () => onSelected(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 62,
              decoration: BoxDecoration(
                color: isSelected ? scheme.primary : theme.cardTheme.color,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isSelected
                      ? scheme.primary
                      : theme.dividerTheme.color ?? theme.dividerColor,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    _dayNames[index].substring(0, 3).toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: isSelected
                          ? scheme.onPrimary.withValues(alpha: 0.85)
                          : theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$classCount',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: isSelected
                          ? scheme.onPrimary
                          : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({required this.slot, required this.label});

  final TimetableSlot slot;

  /// The school's own name for this column, e.g. "P4". Not the raw period_no:
  /// that counts breaks, so it runs one ahead of the school's numbering from
  /// the first break onwards.
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String subject = slot.subject ?? 'Subject';
    final Color accent = AppColors.forSubject(subject);

    return AppCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(width: 4, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          slot.time ?? '—',
                          style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
                        ),
                        Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      color: theme.dividerTheme.color,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            subject,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (slot.room != null && slot.room!.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4),
                            Row(
                              children: <Widget>[
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    slot.room!,
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
