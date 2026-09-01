import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../../data/static_data.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<String> _languages = <String>[
    'English (US)',
    'English (UK)',
    'Spanish',
    'French',
    'German',
  ];

  @override
  Widget build(BuildContext context) {
    return AppStateBuilder(
      builder: (BuildContext context, AppState state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            physics: const BouncingScrollPhysics(),
            children: <Widget>[
              const SectionHeader('Appearance'),
              AppCard(
                padding: EdgeInsets.zero,
                clip: true,
                child: Column(
                  children: <Widget>[
                    _SwitchRow(
                      icon: state.isDarkMode
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      color: AppColors.violet,
                      title: 'Dark mode',
                      subtitle: 'Use the dark colour scheme',
                      value: state.isDarkMode,
                      onChanged: state.setDarkMode,
                    ),
                    const Divider(height: 1, indent: 60),
                    _PickerRow(
                      icon: Icons.language_rounded,
                      color: AppColors.blue,
                      title: 'Language',
                      value: state.language,
                      onTap: () => _pickLanguage(context, state),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const SectionHeader(
                'Notification channels',
                subtitle: 'Where you receive alerts',
              ),
              AppCard(
                padding: EdgeInsets.zero,
                clip: true,
                child: Column(
                  children: <Widget>[
                    _SwitchRow(
                      icon: Icons.mail_outline_rounded,
                      color: AppColors.blue,
                      title: 'Email',
                      subtitle: SchoolData.student.email,
                      value: state.preference('email'),
                      onChanged: (bool v) => state.setPreference('email', v),
                    ),
                    const Divider(height: 1, indent: 60),
                    _SwitchRow(
                      icon: Icons.phone_iphone_rounded,
                      color: AppColors.primary500,
                      title: 'Push notifications',
                      subtitle: 'Alerts on this device',
                      value: state.preference('push'),
                      onChanged: (bool v) => state.setPreference('push', v),
                    ),
                    const Divider(height: 1, indent: 60),
                    _SwitchRow(
                      icon: Icons.sms_outlined,
                      color: AppColors.orange,
                      title: 'SMS',
                      subtitle: SchoolData.student.phone,
                      value: state.preference('sms'),
                      onChanged: (bool v) => state.setPreference('sms', v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const SectionHeader('Notify me about'),
              AppCard(
                padding: EdgeInsets.zero,
                clip: true,
                child: Column(
                  children: <Widget>[
                    for (final ({String key, String label}) item
                        in const <({String key, String label})>[
                          (key: 'assignments', label: 'Assignments & homework'),
                          (key: 'results', label: 'Exam results'),
                          (key: 'fees', label: 'Fee reminders'),
                          (key: 'events', label: 'School events'),
                          (key: 'announcements', label: 'Announcements'),
                        ]) ...<Widget>[
                      if (item.key != 'assignments')
                        const Divider(height: 1, indent: AppSpacing.lg),
                      _CheckRow(
                        label: item.label,
                        value: state.preference(item.key),
                        onChanged: (bool v) => state.setPreference(item.key, v),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const SectionHeader('Security'),
              AppCard(
                padding: EdgeInsets.zero,
                clip: true,
                child: Column(
                  children: <Widget>[
                    _SwitchRow(
                      icon: Icons.fingerprint_rounded,
                      color: AppColors.violet,
                      title: 'Biometric unlock',
                      subtitle: 'Use fingerprint or face to sign in',
                      value: state.preference('biometric'),
                      onChanged: (bool v) => state.setPreference('biometric', v),
                    ),
                    const Divider(height: 1, indent: 60),
                    _PickerRow(
                      icon: Icons.lock_outline_rounded,
                      color: AppColors.slate,
                      title: 'Change password',
                      value: 'Last changed 4 months ago',
                      onTap: () => _changePassword(context),
                    ),
                    const Divider(height: 1, indent: 60),
                    _PickerRow(
                      icon: Icons.verified_user_outlined,
                      color: AppColors.primary500,
                      title: 'Two-factor authentication',
                      value: 'Not enabled',
                      onTap: () =>
                          showDemoSnack(context, 'Two-factor setup (demo)'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const SectionHeader('About'),
              AppCard(
                child: Column(
                  children: <Widget>[
                    InfoRow(
                      label: 'School',
                      value: SchoolData.schoolName,
                      icon: Icons.school_outlined,
                    ),
                    InfoRow(
                      label: 'Academic year',
                      value: SchoolData.academicYear,
                      icon: Icons.calendar_today_outlined,
                    ),
                    InfoRow(
                      label: 'App version',
                      value: '1.0.0 (demo build)',
                      icon: Icons.info_outline_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'This build ships with static sample data and does not connect to a server.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickLanguage(BuildContext context, AppState state) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Language',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            RadioGroup<String>(
              groupValue: state.language,
              onChanged: (String? value) {
                if (value != null) state.setLanguage(value);
                Navigator.of(context).pop();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final String language in _languages)
                    RadioListTile<String>(
                      value: language,
                      title: Text(language),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const _ChangePasswordSheet(),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Password updated (demo)')));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Change password',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xl),
              TextFormField(
                controller: _current,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Current password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (String? v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _next,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (String? v) => (v == null || v.length < 8)
                    ? 'Use at least 8 characters'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                validator: (String? v) =>
                    v != _next.text ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _submit,
                child: const Text('Update password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            SoftIcon(icon, color: color, size: 36, iconSize: 18),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            SoftIcon(icon, color: color, size: 36, iconSize: 18),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.textTheme.bodySmall?.color,
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: <Widget>[
            Checkbox(
              value: value,
              onChanged: (bool? v) => onChanged(v ?? false),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
