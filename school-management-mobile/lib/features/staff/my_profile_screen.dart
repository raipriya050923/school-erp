import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_theme.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// The signed-in user's own record, for whichever role they hold.
///
/// One screen rather than one per portal: `GET /auth/me` answers for everybody
/// and hands back the role-specific rows already labelled, so a super admin, a
/// school admin and a teacher all render from the same list without this screen
/// knowing anything about roles.
///
/// It is read-only, because the API has no endpoint to change it — `/auth/me`
/// is a GET and nothing else. The one thing a person can change about their own
/// account is their password, which is why that sits here as an action rather
/// than as a field.
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  MyProfile? _profile;
  bool _loading = true;
  String? _error;

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
      final MyProfile p = await AuthApi.instance.me();
      if (!mounted) return;
      setState(() {
        _profile = p;
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

  Future<void> _changePassword() async {
    final bool? changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: const ChangePasswordSheet(),
      ),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
        actions: const <Widget>[SignOutAction()],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? centredMessage(context, _error!, onRetry: _load)
              : _body(context, _profile!),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, MyProfile p) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl,
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primary,
              child: Text(
                p.initials,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(p.fullName, style: theme.textTheme.titleMedium),
                  Text(p.title, style: theme.textTheme.bodySmall),
                  if ((p.schoolName ?? '').isNotEmpty)
                    Text(p.schoolName!, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),
        sectionTitle(context, 'Account'),
        detailRow(context, 'Username', p.username),
        detailRow(context, 'Email', p.email ?? '—'),
        detailRow(context, 'Phone', p.phone ?? '—'),

        // Whatever the API decided matters for this role — a teacher's employee
        // code, a student's class, a platform owner's scope.
        if (p.details.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          sectionTitle(context, 'Details'),
          for (final ProfileDetail d in p.details)
            detailRow(context, d.label, d.value ?? '—'),
        ],

        const SizedBox(height: AppSpacing.xl),
        OutlinedButton.icon(
          onPressed: _changePassword,
          icon: const Icon(Icons.key_outlined, size: 18),
          label: const Text('Change password'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Your name, email and phone are held by the school office — ask them '
          'to change those for you.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Changing your own password.
///
/// Lifted out of the settings screen so the profile can offer it too, rather
/// than each screen growing its own copy of a form that posts credentials.
class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiClient.instance.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
    } on ApiException catch (e) {
      // Only the server knows whether the current password was right, so its
      // message is shown rather than a generic failure.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Change password',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: _obscure ? 'Show' : 'Hide',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _current,
                obscureText: _obscure,
                decoration: const InputDecoration(labelText: 'Current password'),
                validator: (String? v) => (v ?? '').isEmpty
                    ? 'Enter your current password.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _next,
                obscureText: _obscure,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (String? v) {
                  final String t = v ?? '';
                  if (t.isEmpty) return 'Enter a new password.';
                  if (t.length < 6) return 'At least 6 characters.';
                  if (t == _current.text) {
                    return 'That is the password you already have.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                decoration: const InputDecoration(labelText: 'Repeat new password'),
                validator: (String? v) =>
                    (v ?? '') == _next.text ? null : 'The two do not match.',
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: Text(_saving ? 'Changing…' : 'Change password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
