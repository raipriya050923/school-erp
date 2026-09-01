import 'package:flutter/material.dart';

import '../../core/student_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/api_section.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../../data/api_models.dart';
import '../dashboard/dashboard_screen.dart' show NotificationBell;

/// Homework for the signed-in student, from `GET /api/student/homework`.
class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => StudentStore.instance.loadHomework(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Homework'),
        actions: const <Widget>[NotificationBell(), SizedBox(width: AppSpacing.lg)],
      ),
      body: SafeArea(
        top: false,
        child: StudentStoreBuilder(
          builder: (BuildContext context, StudentStore store) {
            return ApiSection<List<StudentHomework>>(
              state: store.homework,
              onRetry: () => store.loadHomework(force: true),
              loadingHeight: 320,
              builder: (BuildContext context, List<StudentHomework> all) {
                final List<String> statuses = <String>[
                  'All',
                  ...<String>{for (final StudentHomework h in all) h.status}..removeWhere((String s) => s.isEmpty),
                ];
                final List<StudentHomework> shown = _filter == 'All'
                    ? all
                    : all.where((StudentHomework h) => h.status == _filter).toList();

                return Column(
                  children: <Widget>[
                    if (statuses.length > 1)
                      FilterChipsRow(
                        options: statuses,
                        selected: _filter,
                        onSelected: (String s) => setState(() => _filter = s),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => store.loadHomework(force: true),
                        child: shown.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: <Widget>[
                                  EmptyState(
                                    icon: Icons.task_alt_rounded,
                                    title: all.isEmpty
                                        ? 'No homework yet'
                                        : 'Nothing here',
                                    message: all.isEmpty
                                        ? 'Homework set by your teachers will appear here.'
                                        : 'No homework with this status.',
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
                                itemCount: shown.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: AppSpacing.md),
                                itemBuilder: (BuildContext context, int i) =>
                                    _HomeworkCard(item: shown[i]),
                              ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _HomeworkCard extends StatelessWidget {
  const _HomeworkCard({required this.item});

  final StudentHomework item;

  Color _statusColour(BuildContext context) {
    switch (item.status.toLowerCase()) {
      case 'open':
      case 'pending':
        return AppColors.amber;
      case 'closed':
      case 'submitted':
      case 'graded':
        return AppColors.primary600;
      case 'overdue':
        return AppColors.red;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String subject = item.subject ?? 'General';
    final Color accent = AppColors.forSubject(subject);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SoftIcon(Icons.assignment_outlined, color: accent),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(item.title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(subject, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (item.status.isNotEmpty)
                StatusPill(item.status, color: _statusColour(context), dense: true),
            ],
          ),
          if (item.dueDate != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Icon(
                  Icons.event_outlined,
                  size: 15,
                  color: theme.textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 6),
                Text(
                  'Due ${_formatDate(item.dueDate!)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
