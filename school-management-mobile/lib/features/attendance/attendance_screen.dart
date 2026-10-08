import 'package:flutter/material.dart';

import '../../core/student_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/api_section.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../../data/api_models.dart';

/// Attendance summary and recent days, from `GET /api/student/attendance`.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => StudentStore.instance.loadAttendance(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: SafeArea(
        top: false,
        child: StudentStoreBuilder(
          builder: (BuildContext context, StudentStore store) {
            return ApiSection<StudentAttendance>(
              state: store.attendance,
              onRetry: () => store.loadAttendance(force: true),
              loadingHeight: 320,
              builder: (BuildContext context, StudentAttendance a) => RefreshIndicator(
                onRefresh: () => store.loadAttendance(force: true),
                child: _AttendanceBody(data: a),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AttendanceBody extends StatelessWidget {
  const _AttendanceBody({required this.data});

  final StudentAttendance data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (data.totalDays == 0 && data.recent.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const <Widget>[
          EmptyState(
            icon: Icons.fact_check_outlined,
            title: 'No attendance recorded',
            message: 'Once your teachers start marking attendance it shows here.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Overall attendance', style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                '${data.overallPercent}%',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: _percentColour(data.overallPercent),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              MeterRow(
                label: 'Days present',
                trailing: '${data.presentDays} of ${data.totalDays}',
                value: data.totalDays == 0
                    ? 0
                    : (data.presentDays / data.totalDays).clamp(0, 1).toDouble(),
                color: _percentColour(data.overallPercent),
              ),
            ],
          ),
        ),
        if (data.months.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader('By month'),
          const SizedBox(height: AppSpacing.md),
          for (final AttendanceMonthSummary m in data.months) ...<Widget>[
            _MonthCard(month: m),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
        if (data.recent.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('Recent days'),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              children: <Widget>[
                for (final AttendanceEntry e in data.recent) _RecentRow(entry: e),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.month});

  final AttendanceMonthSummary month;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(month.month, style: theme.textTheme.titleSmall),
              ),
              StatusPill(
                '${month.percent}%',
                color: _percentColour(month.percent),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              _Tally(label: 'Present', value: month.present, colour: AppColors.primary600),
              _Tally(label: 'Absent', value: month.absent, colour: AppColors.red),
              _Tally(label: 'Late', value: month.late, colour: AppColors.amber),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally({required this.label, required this.value, required this.colour});

  final String label;
  final int value;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$value',
            style: theme.textTheme.titleMedium?.copyWith(color: colour),
          ),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.entry});

  final AttendanceEntry entry;

  Color get _colour {
    switch (entry.status.toLowerCase()) {
      case 'present':
        return AppColors.primary600;
      case 'absent':
        return AppColors.red;
      case 'late':
        return AppColors.amber;
      default:
        return AppColors.slate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(entry.date, style: theme.textTheme.bodyMedium),
                Text(entry.day, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
          StatusPill(entry.status, color: _colour, dense: true),
        ],
      ),
    );
  }
}

Color _percentColour(int percent) {
  // See the note in dashboard_screen: green tops the scale so the four bands
  // stay distinguishable under a blue brand.
  if (percent >= 90) return AppColors.green;
  if (percent >= 75) return AppColors.blue;
  if (percent >= 60) return AppColors.amber;
  return AppColors.red;
}
