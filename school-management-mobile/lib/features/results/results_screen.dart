import 'package:flutter/material.dart';

import '../../core/student_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/api_section.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../../data/api_models.dart';

/// Exam results and upcoming papers, from `GET /api/student/exams`.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => StudentStore.instance.loadExams(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: SafeArea(
        top: false,
        child: StudentStoreBuilder(
          builder: (BuildContext context, StudentStore store) {
            return ApiSection<StudentExams>(
              state: store.exams,
              onRetry: () => store.loadExams(force: true),
              loadingHeight: 320,
              builder: (BuildContext context, StudentExams exams) => RefreshIndicator(
                onRefresh: () => store.loadExams(force: true),
                child: _ResultsBody(exams: exams),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({required this.exams});

  final StudentExams exams;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasResults = exams.results.isNotEmpty;

    if (!hasResults && exams.upcoming.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const <Widget>[
          EmptyState(
            icon: Icons.school_outlined,
            title: 'No results yet',
            message: 'Marks appear here once your school publishes them.',
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
        if (hasResults) ...<Widget>[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  exams.examName ?? 'Latest exam',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '${exams.percent}%',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: _percentColour(exams.percent.toDouble()),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: StatusPill(
                        'Grade ${exams.grade}',
                        color: _percentColour(exams.percent.toDouble()),
                        dense: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_trim(exams.total)} of ${_trim(exams.fullTotal)} marks',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader('Subjects'),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < exams.results.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: AppSpacing.lg),
                  _SubjectRow(row: exams.results[i]),
                ],
              ],
            ),
          ),
        ],
        if (exams.upcoming.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader('Upcoming papers'),
          const SizedBox(height: AppSpacing.md),
          for (final UpcomingPaper p in exams.upcoming) ...<Widget>[
            _UpcomingCard(paper: p),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ],
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.row});

  final SubjectResultRow row;

  @override
  Widget build(BuildContext context) {
    final bool marked = row.marks != null;
    return MeterRow(
      label: row.subject,
      trailing: marked
          ? '${_trim(row.marks!)}/${_trim(row.fullMarks)} · ${row.grade}'
          : 'Not marked',
      value: marked ? (row.percent / 100).clamp(0, 1).toDouble() : 0,
      color: marked ? _percentColour(row.percent) : AppColors.slate,
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.paper});

  final UpcomingPaper paper;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      child: Row(
        children: <Widget>[
          SoftIcon(
            Icons.event_note_outlined,
            color: AppColors.forSubject(paper.subject),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(paper.subject, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  <String>[
                    if (paper.date != null) _formatDate(paper.date!),
                    if (paper.time != null && paper.time!.isNotEmpty) paper.time!,
                    if (paper.room != null && paper.room!.isNotEmpty) paper.room!,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _percentColour(double percent) {
  // Green tops the scale; the brand blue is the band below it.
  if (percent >= 80) return AppColors.green;
  if (percent >= 60) return AppColors.blue;
  if (percent >= 40) return AppColors.amber;
  return AppColors.red;
}

/// Marks come back as decimals; drop a trailing `.0` so 91.0 reads as 91.
String _trim(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
