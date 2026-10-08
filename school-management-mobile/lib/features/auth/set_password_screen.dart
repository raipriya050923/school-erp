import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_http.dart';
import '../../core/api/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../shell/role_shell.dart';
import 'login_screen.dart';

/// Forced password change for a newly issued account.
///
/// The API refuses every other endpoint while the token carries the
/// must-change flag, so there is nothing useful to show behind this — a portal
/// would render nothing but permission errors. There is deliberately no skip.
class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _saving = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_next.text.length < 6) {
      setState(() => _error = 'Use at least 6 characters.');
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = 'The two passwords do not match.');
      return;
    }
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
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
      return;
    }
    if (!mounted) return;
    // The old token still carries the must-change claim, so signing in again is
    // what actually clears it. Sending them back to login is honest about that
    // rather than leaving a stale token in place.
    await Session.instance.clear();
    RoleShell.resetAllStores();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Password set. Sign in with your new password.')),
      );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = Session.instance.user?.fullName ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Set your password')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.infoTint,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                name.isEmpty
                    ? 'Choose your own password before you continue.'
                    : 'Welcome, $name. Choose your own password before you continue.',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.infoText),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextField(
              controller: _current,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password you were given',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm new password'),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: const TextStyle(color: AppColors.critText)),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Text('Set password'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () async {
                await Session.instance.clear();
                RoleShell.resetAllStores();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
