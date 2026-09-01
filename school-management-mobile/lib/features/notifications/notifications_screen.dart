import 'package:flutter/material.dart';

import '../../core/student_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/api_section.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../../data/api_models.dart';

/// School notices for the signed-in student, from `GET /api/student/notices`.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => StudentStore.instance.loadNotices(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notices')),
      body: SafeArea(
        top: false,
        child: StudentStoreBuilder(
          builder: (BuildContext context, StudentStore store) {
            return ApiSection<List<StudentNotice>>(
              state: store.notices,
              onRetry: () => store.loadNotices(force: true),
              loadingHeight: 320,
              builder: (BuildContext context, List<StudentNotice> notices) =>
                  RefreshIndicator(
                    onRefresh: () => store.loadNotices(force: true),
                    child: notices.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const <Widget>[
                              EmptyState(
                                icon: Icons.notifications_none_rounded,
                                title: 'No notices',
                                message: 'Announcements from your school appear here.',
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
                            itemCount: notices.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.md),
                            itemBuilder: (BuildContext context, int i) =>
                                _NoticeCard(notice: notices[i]),
                          ),
                  ),
            );
          },
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice});

  final StudentNotice notice;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SoftIcon(Icons.campaign_outlined, color: AppColors.blue),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(notice.title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDate(notice.publishDate)} · ${notice.audience}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(notice.body, style: theme.textTheme.bodyMedium),
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
