import 'package:flutter/material.dart';

import '../../core/student_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/api_section.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../../data/api_models.dart';
import '../attendance/attendance_screen.dart';
import '../notifications/notifications_screen.dart';
import '../results/results_screen.dart';
import '../shell/app_shell.dart';

/// Home tab, from `GET /api/student/dashboard/stats`.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StudentStore.instance.loadDashboard();
      StudentStore.instance.loadTimetable();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StudentStoreBuilder(
          builder: (BuildContext context, StudentStore store) {
            return ApiSection<StudentDashboard>(
              state: store.dashboard,
              onRetry: () => store.loadDashboard(force: true),
              loadingHeight: 420,
              builder: (BuildContext context, StudentDashboard d) => RefreshIndicator(
                onRefresh: () async {
                  await store.loadDashboard(force: true);
                  await store.loadTimetable(force: true);
                },
                child: _DashboardBody(data: d, timetable: store.timetable.value),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data, required this.timetable});

  final StudentDashboard data;
  final StudentTimetable? timetable;

  /// `day_of_week` is 1 = Sunday … 7 = Saturday.
  int get _today => DateTime.now().weekday % 7 + 1;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<TimetableSlot> todays =
        (timetable?.slots ?? <TimetableSlot>[])
            .where((TimetableSlot s) => s.dayOfWeek == _today)
            .toList()
          ..sort((TimetableSlot a, TimetableSlot b) =>
              a.periodNo.compareTo(b.periodNo));

    final String classLabel = <String?>[data.className, data.sectionName]
        .where((String? s) => s != null && s.isNotEmpty)
        .join(' · ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Welcome back', style: theme.textTheme.bodySmall),
                  Text(data.name, style: theme.textTheme.headlineSmall),
                  if (classLabel.isNotEmpty || data.rollNo != null)
                    Text(
                      <String>[
                        if (classLabel.isNotEmpty) classLabel,
                        if (data.rollNo != null) 'Roll ${data.rollNo}',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const NotificationBell(),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // ------------------------------------------------------- key figures
        Row(
          children: <Widget>[
            Expanded(
              child: StatTile(
                label: 'Attendance',
                tint: 0,
                value: '${data.attendancePercent}%',
                caption: '${data.presentDays}/${data.totalDays} days',
                icon: Icons.fact_check_outlined,
                color: _attendanceColour(data.attendancePercent),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AttendanceScreen()),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatTile(
                label: 'Fees due',
                tint: 1,
                value: _money(data.feeDue),
                caption: data.feeDue > 0 ? 'Outstanding' : 'All settled',
                icon: Icons.account_balance_wallet_outlined,
                color: data.feeDue > 0 ? AppColors.red : AppColors.primary600,
                onTap: () =>
                    ShellController.maybeOf(context)?.goToTab(ShellTab.fees),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: StatTile(
                label: 'Homework',
                tint: 2,
                value: '${data.pendingHomework}',
                caption: data.pendingHomework == 1 ? 'Pending task' : 'Pending tasks',
                icon: Icons.assignment_outlined,
                color: data.pendingHomework > 0 ? AppColors.amber : AppColors.primary600,
                onTap: () =>
                    ShellController.maybeOf(context)?.goToTab(ShellTab.assignments),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatTile(
                label: 'Next exam',
                tint: 3,
                value: data.nextExamName ?? '—',
                caption: data.nextExamDate != null
                    ? _formatDate(data.nextExamDate!)
                    : 'Nothing scheduled',
                icon: Icons.school_outlined,
                color: AppColors.violet,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ResultsScreen()),
                ),
              ),
            ),
          ],
        ),

        // ---------------------------------------------------- today's classes
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(
          "Today's classes",
          subtitle: '${todays.length} ${todays.length == 1 ? 'period' : 'periods'}',
          actionLabel: 'See all',
          onAction: () =>
              ShellController.maybeOf(context)?.goToTab(ShellTab.timetable),
        ),
        const SizedBox(height: AppSpacing.md),
        if (todays.isEmpty)
          AppCard(
            child: Row(
              children: <Widget>[
                SoftIcon(Icons.free_breakfast_outlined, color: AppColors.slate),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    timetable == null
                        ? 'Loading your timetable…'
                        : 'No classes scheduled today.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else
          AppCard(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < todays.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: AppSpacing.lg * 2),
                  _PeriodRow(slot: todays[i]),
                ],
              ],
            ),
          ),

        // -------------------------------------------------- upcoming homework
        if (data.upcomingHomework.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            'Upcoming homework',
            actionLabel: 'See all',
            onAction: () =>
                ShellController.maybeOf(context)?.goToTab(ShellTab.assignments),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final StudentHomework h in data.upcomingHomework) ...<Widget>[
            AppCard(
              child: Row(
                children: <Widget>[
                  SoftIcon(
                    Icons.assignment_outlined,
                    color: AppColors.forSubject(h.subject ?? 'General'),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(h.title, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          <String>[
                            if (h.subject != null) h.subject!,
                            if (h.dueDate != null) 'Due ${_formatDate(h.dueDate!)}',
                          ].join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ],
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.slot});

  final TimetableSlot slot;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String subject = slot.subject ?? 'Subject';
    return Row(
      children: <Widget>[
        SoftIcon(Icons.menu_book_outlined, color: AppColors.forSubject(subject)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(subject, style: theme.textTheme.titleSmall),
              if (slot.room != null && slot.room!.isNotEmpty)
                Text(slot.room!, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        Text(slot.time ?? '—', style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Bell button — reused by several screens. Opens the notices list.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
        ),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: theme.dividerTheme.color ?? theme.dividerColor,
            ),
          ),
          child: const Icon(Icons.notifications_none_rounded, size: 22),
        ),
      ),
    );
  }
}

Color _attendanceColour(int percent) {
  // Green is the web's --good. The top band used to be the emerald brand and
  // the next one blue; now that the brand IS blue, the top band has to move to
  // green or the two best scores render identically.
  if (percent >= 90) return AppColors.green;
  if (percent >= 75) return AppColors.blue;
  if (percent >= 60) return AppColors.amber;
  return AppColors.red;
}

String _money(double v) {
  final String whole = v.round().toString();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) out.write(',');
    out.write(whole[i]);
  }
  return '₹$out';
}

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';
