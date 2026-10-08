import 'package:flutter/material.dart';

import '../../core/loadable.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../data/staff_models.dart';
import '../profile/profile_screen.dart' show confirmSignOut;

/// Renders one [Loadable] section for the staff portals: spinner, a retryable
/// message, or the data. The student portal's `ApiSection` does the same job
/// but is typed against its own store, so this is the role-agnostic twin.
class StaffSection<T> extends StatelessWidget {
  const StaffSection({
    super.key,
    required this.state,
    required this.onRetry,
    required this.builder,
  });

  final Loadable<T> state;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, T value) builder;

  @override
  Widget build(BuildContext context) {
    if (state.hasValue) return builder(context, state.value as T);
    if (state.error != null) {
      return _Failed(message: state.error!, onRetry: onRetry);
    }
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(strokeWidth: 2.4),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off_rounded, color: AppColors.critText, size: 30),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A figure with a caption, filling one of the four web pastels by position.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.tint,
    this.caption,
    this.icon,
  });

  final String label;
  final String value;
  final int tint;
  final String? caption;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool tinted = theme.brightness == Brightness.light;
    return AppCard(
      color: tinted ? AppColors.tileFill(tint) : null,
      borderColor: tinted ? AppColors.tileBorder(tint) : null,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(height: 1.1),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          if (caption != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Two metric tiles per row, which is all that fits legibly on a phone.
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.tiles});

  final List<MetricTile> tiles;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < tiles.length; i += 2) {
      final bool hasSecond = i + 1 < tiles.length;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          // IntrinsicHeight is required, not decorative. These rows sit inside a
          // scrolling list, so their height is unbounded, and a Row cannot
          // stretch its children against an infinite constraint — it asserts
          // "BoxConstraints forces an infinite height" and the whole dashboard
          // renders as blank space. This measures the taller tile first, which
          // also keeps a pair level when only one of them carries a caption.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: tiles[i]),
                const SizedBox(width: AppSpacing.md),
                // An empty spacer, not a stretched tile: a lone odd tile
                // spanning the full width reads as more important than its
                // neighbours.
                Expanded(child: hasSecond ? tiles[i + 1] : const SizedBox()),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

/// Plan warnings for the school admin: expiry inside the notice window, and the
/// student seat cap.
///
/// Only rendered when there is something to act on. A banner that is always
/// there stops being read, and the admin dashboard is the screen they open
/// first — which is the point of putting the warning here rather than leaving
/// them to discover it at a refused login.
class SubscriptionNotices extends StatelessWidget {
  const SubscriptionNotices({super.key, required this.status});

  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    final List<Widget> notices = <Widget>[];

    if (status.isExpiringSoon) {
      final int days = status.daysRemaining ?? 0;
      final String what = status.isTrial ? 'Trial' : 'Subscription';
      notices.add(
        _Notice(
          icon: Icons.schedule_rounded,
          tint: AppColors.warnTint,
          ink: AppColors.warnText,
          title: days == 0
              ? 'Your ${what.toLowerCase()} ends today.'
              : '$what ends in $days day${days == 1 ? '' : 's'}.',
          body:
              'Service will be suspended and nobody at your school will be able '
              'to sign in. Contact your platform administrator to renew.',
        ),
      );
    }

    if (status.atStudentCap) {
      notices.add(
        _Notice(
          icon: Icons.groups_rounded,
          tint: AppColors.critTint,
          ink: AppColors.critText,
          title: 'Student limit reached.',
          body:
              'The ${status.planName ?? 'current'} plan allows ${status.maxStudents} '
              'students and you have ${status.studentCount}. New admissions are '
              'blocked until the plan is upgraded.',
        ),
      );
    } else if (status.maxStudents != null &&
        status.seatsRemaining != null &&
        status.seatsRemaining! <= 20) {
      notices.add(
        _Notice(
          icon: Icons.groups_outlined,
          tint: AppColors.warnTint,
          ink: AppColors.warnText,
          title:
              '${status.seatsRemaining} student place'
              '${status.seatsRemaining == 1 ? '' : 's'} left on the '
              '${status.planName ?? 'current'} plan.',
          body: '${status.studentCount} of ${status.maxStudents} used.',
        ),
      );
    }

    if (notices.isEmpty) return const SizedBox.shrink();
    return Column(children: notices);
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.tint,
    required this.ink,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color tint;
  final Color ink;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: ink),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(color: ink),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(color: ink, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A status word as a filled chip, using the web's semantic tint/text pairs.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final String status;

  static const Map<String, (Color, Color)> _map = <String, (Color, Color)>{
    'active': (AppColors.goodTint, AppColors.goodText),
    'paid': (AppColors.goodTint, AppColors.goodText),
    'approved': (AppColors.goodTint, AppColors.goodText),
    'resolved': (AppColors.goodTint, AppColors.goodText),
    'trial': (AppColors.infoTint, AppColors.infoText),
    'open': (AppColors.infoTint, AppColors.infoText),
    'pending': (AppColors.warnTint, AppColors.warnText),
    'partial': (AppColors.warnTint, AppColors.warnText),
    'suspended': (AppColors.seriousTint, AppColors.seriousText),
    'unpaid': (AppColors.seriousTint, AppColors.seriousText),
    'overdue': (AppColors.critTint, AppColors.critText),
    'urgent': (AppColors.critTint, AppColors.critText),
    'rejected': (AppColors.critTint, AppColors.critText),
    'cancelled': (AppColors.critTint, AppColors.critText),
    'terminated': (AppColors.critTint, AppColors.critText),
  };

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) =
        _map[status.toLowerCase()] ??
        (AppColors.neutralTint, AppColors.lightTextSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// Sign-out, as an app-bar action.
///
/// Every staff screen carries this. Sign-out used to live only on the Settings
/// tab, which the super-admin shell does not have — so a platform owner could
/// sign in and then had no way back out of the app.
class SignOutAction extends StatelessWidget {
  const SignOutAction({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Sign out',
    icon: const Icon(Icons.logout_rounded),
    onPressed: () => confirmSignOut(context),
  );
}

/// The standard scrollable page body for a staff screen, with pull to refresh.
class StaffPage extends StatelessWidget {
  const StaffPage({
    super.key,
    required this.title,
    required this.onRefresh,
    required this.child,
    this.subtitle,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final Future<void> Function() onRefresh;
  final Widget child;

  /// Extra app-bar actions, placed before the sign-out button.
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title),
            if (subtitle != null)
              Text(
                subtitle!,
                style: theme.textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: <Widget>[...?actions, const SignOutAction()],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            children: <Widget>[child],
          ),
        ),
      ),
    );
  }
}

/// A row in one of the staff list screens.
class StaffRow extends StatelessWidget {
  const StaffRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.status,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final String? status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (trailing != null)
                  Text(trailing!, style: theme.textTheme.titleSmall),
                if (status != null) ...<Widget>[
                  if (trailing != null) const SizedBox(height: 4),
                  StatusChip(status!),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}


/// One line of a register: a name, and the statuses as a segmented control.
///
/// Segments rather than a dropdown because the status stays visible without
/// opening anything and changing it is one tap — a register read at a glance
/// is the whole point. Shared by the student and staff registers, which differ
/// only in which statuses they offer.
class AttendanceStatusRow extends StatelessWidget {
  const AttendanceStatusRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.status,
    required this.states,
    required this.onChanged,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String status;

  /// status value -> (the letter on the chip, its colour). Order is the order
  /// they appear in.
  final Map<String, (String, Color)> states;
  final ValueChanged<String> onChanged;

  /// Sits after the chips. Used by the staff register for its remarks button.
  final Widget? trailing;

  /// present / absent / late / leave — a student register.
  static const Map<String, (String, Color)> studentStates =
      <String, (String, Color)>{
    'present': ('P', AppColors.green),
    'absent': ('A', AppColors.red),
    'late': ('L', AppColors.amber),
    'leave': ('E', AppColors.indigo),
  };

  /// The staff register adds a half day, and distinguishes approved leave from
  /// simply not turning up.
  static const Map<String, (String, Color)> staffStates =
      <String, (String, Color)>{
    'present': ('P', AppColors.green),
    'absent': ('A', AppColors.red),
    'late': ('L', AppColors.amber),
    'half_day': ('H', AppColors.blue),
    'on_leave': ('E', AppColors.indigo),
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.titleSmall),
              if ((subtitle ?? '').isNotEmpty)
                Text(subtitle!, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        for (final MapEntry<String, (String, Color)> e in states.entries)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _StatusChip(
              label: e.value.$1,
              colour: e.value.$2,
              selected: status == e.key,
              onTap: () => onChanged(e.key),
            ),
          ),
        ?trailing,
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.colour,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color colour;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colour : Colors.transparent,
          border: Border.all(color: selected ? colour : theme.dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : theme.textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }
}
