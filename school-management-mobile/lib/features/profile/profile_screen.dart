import 'package:flutter/material.dart';

import '../../core/api/session.dart';
import '../../core/student_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/api_section.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../../data/api_models.dart';
import '../attendance/attendance_screen.dart';
import '../auth/login_screen.dart';
import '../shell/role_shell.dart';
import '../notifications/notifications_screen.dart';
import '../results/results_screen.dart';
import '../settings/settings_screen.dart';

/// The student's own record, from `GET /api/student/profile`.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => StudentStore.instance.loadProfile(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        top: false,
        child: StudentStoreBuilder(
          builder: (BuildContext context, StudentStore store) {
            return ApiSection<StudentProfile>(
              state: store.profile,
              onRetry: () => store.loadProfile(force: true),
              loadingHeight: 320,
              builder: (BuildContext context, StudentProfile p) => RefreshIndicator(
                onRefresh: () => store.loadProfile(force: true),
                child: _ProfileBody(profile: p),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthUser? account = Session.instance.user;

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
          child: Row(
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Text(
                  profile.initials,
                  style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(profile.name, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      profile.classLabel.isEmpty
                          ? 'Student'
                          : profile.classLabel,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader('Academic'),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            children: <Widget>[
              InfoRow(
                label: 'Admission no',
                value: profile.admissionNo.isEmpty ? '—' : profile.admissionNo,
                icon: Icons.badge_outlined,
              ),
              InfoRow(
                label: 'Class',
                value: profile.className ?? '—',
                icon: Icons.class_outlined,
              ),
              InfoRow(
                label: 'Section',
                value: profile.sectionName ?? '—',
                icon: Icons.groups_outlined,
              ),
              InfoRow(
                label: 'Roll no',
                value: profile.rollNo ?? '—',
                icon: Icons.tag_rounded,
              ),
            ],
          ),
        ),
        if (account != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader('Account'),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              children: <Widget>[
                InfoRow(
                  label: 'Username',
                  value: account.username,
                  icon: Icons.person_outline_rounded,
                ),
                InfoRow(
                  label: 'Email',
                  value: account.email?.isNotEmpty == true ? account.email! : '—',
                  icon: Icons.mail_outline_rounded,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader('More'),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: EdgeInsets.zero,
          clip: true,
          child: Column(
            children: <Widget>[
              _LinkTile(
                icon: Icons.fact_check_outlined,
                label: 'Attendance',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AttendanceScreen()),
                ),
              ),
              _LinkTile(
                icon: Icons.school_outlined,
                label: 'Results',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ResultsScreen()),
                ),
              ),
              _LinkTile(
                icon: Icons.campaign_outlined,
                label: 'Notices',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton.icon(
          onPressed: () => confirmSignOut(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.red,
            side: const BorderSide(color: AppColors.red),
          ),
          icon: const Icon(Icons.logout_rounded, size: 19),
          label: const Text('Log out'),
        ),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label, style: theme.textTheme.bodyLarge),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

Future<void> confirmSignOut(BuildContext context) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text('You will need to sign in again to view your portal.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.red),
          child: const Text('Log out'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  // Drop the token and cached portal data before leaving, so the next account
  // cannot see the previous student's information.
  await Session.instance.clear();
  RoleShell.resetAllStores();
  if (!context.mounted) return;

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    (Route<dynamic> route) => false,
  );
}
