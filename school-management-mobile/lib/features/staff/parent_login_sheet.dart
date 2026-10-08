import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/staff_models.dart';

/// Issues a parent login for one student, from the admin portal.
///
/// Mirrors the admin console's dialog: it shows the existing account if there is
/// one, otherwise a short form pre-filled from the guardian already recorded on
/// the student. The generated password comes back once and is displayed here —
/// the database only ever holds a hash.
class ParentLoginSheet extends StatefulWidget {
  const ParentLoginSheet({super.key, required this.student});

  final AdminStudent student;

  static Future<void> show(BuildContext context, AdminStudent student) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext _) => ParentLoginSheet(student: student),
      );

  @override
  State<ParentLoginSheet> createState() => _ParentLoginSheetState();
}

class _ParentLoginSheetState extends State<ParentLoginSheet> {
  static const List<String> _relations = <String>['father', 'mother', 'guardian', 'other'];

  bool _loading = true;
  bool _saving = false;
  String? _error;
  ParentAccount? _account;
  GeneratedCredentials? _created;

  final TextEditingController _first = TextEditingController();
  final TextEditingController _last = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  String _relation = 'guardian';

  @override
  void initState() {
    super.initState();
    // Seed from the student's free-text guardian first, so the form is usable
    // even if the lookup is slow or the school has no guardian row.
    _fill(widget.student.guardianName, widget.student.guardianPhone, 'guardian', null);
    _load();
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _fill(String? name, String? phone, String relation, String? email) {
    final List<String> parts =
        (name ?? '').trim().split(' ').where((String p) => p.isNotEmpty).toList();
    _first.text = parts.isEmpty ? '' : parts.first;
    _last.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    _phone.text = _digits(phone ?? '');
    _email.text = email ?? '';
    _relation = relation;
  }

  static String _digits(String v) {
    final String d = v.replaceAll(RegExp(r'[^0-9]'), '');
    return d.length > 10 ? d.substring(0, 10) : d;
  }

  Future<void> _load() async {
    try {
      final ParentAccount? a = await AdminApi.instance.parentAccount(widget.student.id);
      if (!mounted) return;
      setState(() {
        _account = a;
        _loading = false;
        // A guardian row on file is better data than the student's free text.
        if (a != null && !a.hasLogin) _fill(a.name, a.phone, a.relation, a.email);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _create() async {
    final String first = _first.text.trim();
    if (first.isEmpty) {
      setState(() => _error = 'A first name is required.');
      return;
    }
    if (_phone.text.length != 10) {
      setState(() => _error = 'Enter a 10-digit phone number.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final GeneratedCredentials c = await AdminApi.instance.createParentLogin(
        widget.student.id,
        firstName: first,
        lastName: _last.text.trim(),
        relation: _relation,
        phone: _phone.text,
        email: _email.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _created = c;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Parent login', style: theme.textTheme.titleLarge),
            Text(
              '${widget.student.name} · ${widget.student.classLabel}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
              )
            else if (_created != null)
              _Credentials(credentials: _created!)
            else if (_account?.hasLogin == true)
              _ExistingAccount(account: _account!)
            else
              ..._form(theme),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: const TextStyle(color: AppColors.critText)),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(_created != null ? 'Done' : 'Close'),
                  ),
                ),
                if (!_loading && _created == null && _account?.hasLogin != true) ...<Widget>[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _create,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            )
                          : const Text('Create login'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _form(ThemeData theme) => <Widget>[
    Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _first,
            decoration: const InputDecoration(labelText: 'First name *'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: TextField(
            controller: _last,
            decoration: const InputDecoration(labelText: 'Last name'),
          ),
        ),
      ],
    ),
    const SizedBox(height: AppSpacing.md),
    Row(
      children: <Widget>[
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _relation,
            decoration: const InputDecoration(labelText: 'Relation'),
            items: <DropdownMenuItem<String>>[
              for (final String r in _relations)
                DropdownMenuItem<String>(
                  value: r,
                  child: Text(r[0].toUpperCase() + r.substring(1)),
                ),
            ],
            onChanged: (String? v) => setState(() => _relation = v ?? _relation),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone *'),
            // Filtered on change rather than by a formatter, so a pasted number
            // with spaces or a country code still lands as ten digits.
            onChanged: (String v) {
              final String d = _digits(v);
              if (d == v) return;
              _phone.value = TextEditingValue(
                text: d,
                selection: TextSelection.collapsed(offset: d.length),
              );
            },
          ),
        ),
      ],
    ),
    const SizedBox(height: AppSpacing.md),
    TextField(
      controller: _email,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        labelText: 'Email (optional)',
        helperText: 'Used for password reset',
      ),
    ),
  ];
}

class _ExistingAccount extends StatelessWidget {
  const _ExistingAccount({required this.account});

  final ParentAccount account;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.infoTint,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            account.name,
            style: theme.textTheme.titleSmall?.copyWith(color: AppColors.infoText),
          ),
          const SizedBox(height: 2),
          Text(
            'Signs in as ${account.username}',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.infoText),
          ),
          Text(
            '${account.relation} · ${account.phone}',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.infoText),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'A second account is not issued for the same guardian. Use Forgot '
            'password if they cannot get in.',
            style: theme.textTheme.labelSmall?.copyWith(color: AppColors.infoText),
          ),
        ],
      ),
    );
  }
}

/// The one and only sight of the password. Deliberately loud, because closing
/// this sheet loses it for good.
class _Credentials extends StatelessWidget {
  const _Credentials({required this.credentials});

  final GeneratedCredentials credentials;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.goodTint,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Login created for ${credentials.fullName}',
            style: theme.textTheme.titleSmall?.copyWith(color: AppColors.goodText),
          ),
          const SizedBox(height: AppSpacing.md),
          _Row(label: 'Username', value: credentials.username),
          _Row(label: 'Password', value: credentials.temporaryPassword),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Write this down now — the password is not stored and cannot be shown '
            'again. They will be asked to change it at first sign-in.',
            style: theme.textTheme.labelSmall?.copyWith(color: AppColors.goodText),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: AppColors.goodText),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.titleSmall?.copyWith(color: AppColors.goodText),
            ),
          ),
        ],
      ),
    );
  }
}
