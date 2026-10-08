import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_http.dart';
import '../../core/api/api_config.dart';
import '../../core/api/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../shell/role_shell.dart';

/// Sign-in screen backed by the SchoolErp API. Credentials are verified against
/// `POST /api/auth/login`; only student accounts are accepted in this build.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _obscure = true;
  bool _remember = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Only on a debug build pointed at a dev API on this machine. Two guards,
  /// both required, mirroring the web login: a release build never offers these
  /// however it is configured, and a debug build pointed at a real server does
  /// not either.
  static final bool _showDemoAccounts = kDebugMode && ApiConfig.isLocal;

  void _fill(_DemoAccount account) {
    setState(() {
      _idController.text = account.username;
      _passwordController.text = account.password;
      _error = null;
    });
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final AuthUser user = await ApiClient.instance.login(
        username: _idController.text.trim(),
        password: _passwordController.text,
      );
      await Session.instance.save(user, remember: _remember);
      if (!mounted) return;
      _openPortal();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  void _openPortal() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => const RoleShell(),
        transitionsBuilder: (_, Animation<double> animation, _, Widget child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                  maxWidth: 480,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 32),
                    _Brand(isDark: isDark),
                    const SizedBox(height: 40),
                    Text('Welcome back', style: theme.textTheme.displaySmall),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to view your timetable, results, attendance and fees.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _FieldLabel('Username or email'),
                          TextFormField(
                            controller: _idController,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'e.g. aarav.t',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (String? value) =>
                                (value == null || value.trim().isEmpty)
                                ? 'Enter your username or email'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _FieldLabel('Password'),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _signIn(),
                            decoration: InputDecoration(
                              hintText: 'Enter your password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            // The server decides whether the password is right;
                            // only emptiness is worth catching here.
                            validator: (String? value) =>
                                (value == null || value.isEmpty)
                                ? 'Password is required'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: <Widget>[
                              Checkbox(
                                value: _remember,
                                onChanged: (bool? v) =>
                                    setState(() => _remember = v ?? false),
                                visualDensity: VisualDensity.compact,
                              ),
                              const Expanded(
                                child: Text(
                                  'Remember me',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: const Text(
                                  'Forgot password?',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (_error != null) ...<Widget>[
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Icon(
                                    Icons.error_outline,
                                    size: 20,
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton(
                            onPressed: _busy ? null : _signIn,
                            child: _busy
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Sign in'),
                          ),
                        ],
                      ),
                    ),
                    // Local development only. The screens are all live against
                    // the API now, so the old "sample data" notice that stood
                    // here was simply untrue.
                    if (_showDemoAccounts) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxl),
                      const Divider(height: 1),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Demo accounts — tap to fill',
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          for (final _DemoAccount a in _demoAccounts)
                            ActionChip(
                              label: Text(a.label),
                              onPressed: _busy ? null : () => _fill(a),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    Center(
                      child: Text(
                        '© 2026 Nexa Fusion Technology',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A seeded login offered as a shortcut during local development.
///
/// The password is per account, not shared: accounts seeded with the database
/// use Password@123, while any provisioned later through the admin UI take the
/// Accounts:FixedPassword value instead. One shared password would silently
/// fail for half of them.
class _DemoAccount {
  const _DemoAccount(this.label, this.username, this.password);

  final String label;
  final String username;
  final String password;
}

const List<_DemoAccount> _demoAccounts = <_DemoAccount>[
  _DemoAccount('Super Admin', 'pramod', 'Password@123'),
  _DemoAccount('School Admin', 'anita', 'Password@123'),
  _DemoAccount('Teacher', 'rajesh.k', 'Password@123'),
  _DemoAccount('Student', 'aarav.t', 'Password@123'),
  _DemoAccount('Parent', 'bikash.t', 'Password@123'),
];

class _Brand extends StatelessWidget {
  const _Brand({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary600.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.school_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // The wordmark, set in the brand blue and a size up from a plain
              // title: Devanagari hangs much of its mass below the shirorekha,
              // so at a matched size it reads smaller than Latin would.
              Text(
                'पाठशाला',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary600,
                  height: 1.25,
                ),
              ),
              Text(
                'by Nexa Fusion Technology',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.lightTextTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 2),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}
