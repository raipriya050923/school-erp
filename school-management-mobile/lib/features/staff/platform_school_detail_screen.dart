import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/staff_models.dart';
import 'platform_school_form_screen.dart';
import 'staff_widgets.dart';

/// One school in full, and the things that can be done to it.
///
/// The three actions are kept apart on purpose. Editing changes the record;
/// changing status takes a school's people offline or puts them back; resetting
/// the password is the only way back in once it is lost. Burying the last two
/// in the edit form would mean saving a name change could also suspend a
/// school by accident.
class PlatformSchoolDetailScreen extends StatefulWidget {
  const PlatformSchoolDetailScreen({super.key, required this.schoolId});

  final int schoolId;

  @override
  State<PlatformSchoolDetailScreen> createState() =>
      _PlatformSchoolDetailScreenState();
}

class _PlatformSchoolDetailScreenState
    extends State<PlatformSchoolDetailScreen> {
  final SuperAdminApi _api = SuperAdminApi.instance;

  SchoolDetail? _school;
  bool _loading = true;
  bool _working = false;
  String? _error;

  /// True once anything has been changed, so the list behind can be refreshed.
  bool _changed = false;

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
      final SchoolDetail s = await _api.school(widget.schoolId);
      if (!mounted) return;
      setState(() {
        _school = s;
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

  Future<void> _edit() async {
    final SchoolDetail? s = _school;
    if (s == null) return;
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext _) => PlatformSchoolFormScreen(existing: s),
      ),
    );
    if (saved == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _changeStatus() async {
    final SchoolDetail? s = _school;
    if (s == null) return;

    final String? next = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final (String, String, String) option in const <(String, String, String)>[
              ('active', 'Active', 'Everyone at the school can sign in'),
              ('suspended', 'Suspended', 'Nobody can sign in; the data is kept'),
              ('terminated', 'Terminated', 'The school has left the platform'),
            ])
              ListTile(
                title: Text(option.$2),
                subtitle: Text(option.$3),
                trailing: s.status.toLowerCase() == option.$1
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option.$1),
              ),
          ],
        ),
      ),
    );
    if (next == null || next == s.status.toLowerCase()) return;
    // The sheet was awaited, so this screen may be gone by now.
    if (!mounted) return;

    // Suspending or terminating locks every teacher, parent and student out,
    // which is not something to do with one stray tap.
    if (next != 'active') {
      final bool? go = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text('${next == 'suspended' ? 'Suspend' : 'Terminate'} ${s.name}?'),
          content: Text(
            'Everyone at this school is signed out and cannot sign back in '
            '${next == 'suspended' ? 'until it is made active again' : ''}. '
            'Their data is kept either way.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(next == 'suspended' ? 'Suspend' : 'Terminate'),
            ),
          ],
        ),
      );
      if (go != true) return;
    }

    setState(() => _working = true);
    try {
      await _api.setSchoolStatus(id: s.id, status: next);
      if (!mounted) return;
      setState(() {
        _working = false;
        _changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${s.name} is now $next')),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _resetPassword() async {
    final SchoolDetail? s = _school;
    if (s == null) return;

    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Issue a new password?'),
        content: Text(
          'The administrator of ${s.name} gets a new password and the current '
          'one stops working immediately. You will be shown the new one once.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (go != true) return;

    setState(() => _working = true);
    try {
      final GeneratedCredentials c = await _api.resetSchoolAdminPassword(s.id);
      if (!mounted) return;
      setState(() => _working = false);
      await _showCredentials(c.username, c.temporaryPassword);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// The password exists in plaintext here and nowhere else, so the dialog is
  /// deliberately hard to dismiss by accident and offers a copy button.
  Future<void> _showCredentials(String username, String password) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('New password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Copy this now — it cannot be shown again.',
              ),
              const SizedBox(height: AppSpacing.lg),
              _credential(dialogContext, 'Username', username),
              const SizedBox(height: AppSpacing.sm),
              _credential(dialogContext, 'Password', password),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: '$username / $password'),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied')),
                );
              },
              child: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );

  Widget _credential(BuildContext context, String label, String value) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        SizedBox(width: 78, child: Text(label, style: theme.textTheme.bodySmall)),
        Expanded(
          child: SelectableText(value, style: theme.textTheme.titleSmall),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final SchoolDetail? s = _school;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(s?.name ?? 'School'),
          actions: <Widget>[
            if (s != null)
              IconButton(
                onPressed: _working ? null : _edit,
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
              ),
            const SignOutAction(),
          ],
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? centredMessage(context, _error!, onRetry: _load)
                : _body(context, s!),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, SchoolDetail s) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl,
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(s.name, style: theme.textTheme.titleMedium),
                  if ((s.schoolCode ?? '').isNotEmpty)
                    Text(s.schoolCode!, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            StatusPill(
              titleCase(s.status),
              color: _statusColour(s.status),
              dense: true,
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),
        sectionTitle(context, 'Subscription'),
        _row(context, 'Plan', s.planName ?? '—'),
        _row(context, 'Billing', titleCase(s.billingCycle ?? '—')),
        _row(context, 'State', titleCase(s.subscriptionStatus ?? '—')),
        if (s.subscriptionEndsOn != null)
          _row(context, 'Renews', formatDay(s.subscriptionEndsOn!)),

        const SizedBox(height: AppSpacing.xl),
        sectionTitle(context, 'Contact'),
        _row(context, 'Email', s.email ?? '—'),
        _row(context, 'Phone', s.phone ?? '—'),
        _row(
          context,
          'Address',
          <String>[
            if ((s.address ?? '').isNotEmpty) s.address!,
            if ((s.city ?? '').isNotEmpty) s.city!,
            if ((s.state ?? '').isNotEmpty) s.state!,
            if ((s.country ?? '').isNotEmpty) s.country!,
            if ((s.postalCode ?? '').isNotEmpty) s.postalCode!,
          ].join(', '),
        ),

        const SizedBox(height: AppSpacing.xl),
        sectionTitle(context, 'School'),
        _row(context, 'Board', s.affiliationBoard ?? '—'),
        _row(context, 'Subdomain', s.subdomain ?? '—'),
        _row(context, 'Currency', s.currency ?? '—'),
        _row(context, 'Timezone', s.timezone ?? '—'),
        _row(context, 'Portal colour', titleCase(s.theme)),
        if (s.onboardedAt != null)
          _row(context, 'Onboarded', formatDay(s.onboardedAt!)),

        const SizedBox(height: AppSpacing.xl),
        sectionTitle(context, 'Administrator'),
        _row(context, 'Username', s.adminUsername ?? '—'),
        _row(context, 'Email', s.adminEmail ?? '—'),

        const SizedBox(height: AppSpacing.xl),
        OutlinedButton.icon(
          onPressed: _working ? null : _changeStatus,
          icon: const Icon(Icons.toggle_on_outlined, size: 18),
          label: const Text('Change status'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: _working ? null : _resetPassword,
          icon: const Icon(Icons.key_outlined, size: 18),
          label: const Text("Reset administrator's password"),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 108,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColour(String status) {
  switch (status.toLowerCase()) {
    case 'active':
      return AppColors.green;
    case 'suspended':
      return AppColors.amber;
    case 'terminated':
      return AppColors.red;
    default:
      return AppColors.indigo;
  }
}
