import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
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
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ink,
                    height: 1.45,
                  ),
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
/// The tint/ink pair a status is drawn in.
///
/// Lifted out of [StatusChip] so a row and the chip sitting on it cannot
/// disagree about what "overdue" looks like — the row tints its background from
/// the same pair the chip fills itself with.
class StatusPalette {
  const StatusPalette._();

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

  /// Grey for a status nobody has given a colour — unknown is not an alarm.
  static (Color, Color) of(String status) =>
      _map[status.toLowerCase()] ??
      (AppColors.neutralTint, AppColors.lightTextSecondary);
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = StatusPalette.of(status);
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
    this.floatingActionButton,
  });

  final String title;
  final String? subtitle;
  final Future<void> Function() onRefresh;
  final Widget child;

  /// Extra app-bar actions, placed before the sign-out button.
  final List<Widget>? actions;

  /// The page's primary create action. A button rather than an app-bar icon
  /// because it is the one thing a list page is most often opened to do, and
  /// the bottom-right corner is where a thumb already is.
  final Widget? floatingActionButton;

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
                // Against the brand bar, not the page: the body's grey would
                // all but disappear on it.
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.appBarTheme.foregroundColor?.withValues(
                    alpha: 0.78,
                  ),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: <Widget>[...?actions, const SignOutAction()],
      ),
      floatingActionButton: floatingActionButton,
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
///
/// Rows alternate between two light grounds, and carry a bar of their status
/// colour down the leading edge.
///
/// The banding is what separates one row from the next while scrolling — a page
/// of identical white cards gives the eye nothing to count by, and on a long
/// list it becomes easy to read a title against the wrong figure. Status stays
/// on the bar and the chip rather than in the background: tinting whole rows by
/// status looked arbitrary once most of a list shared one status, and it fought
/// the banding for the same surface.
class StaffRow extends StatelessWidget {
  const StaffRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.status,
    this.onTap,
    this.leading,
    this.index = 0,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final String? status;
  final VoidCallback? onTap;

  /// Shown before the title — a monogram or an icon. Optional: a ticket subject
  /// has no initials worth showing, a school name does.
  final Widget? leading;

  /// Position in the list, which decides which of the two grounds this row
  /// takes. Left at zero every row is the lighter one, so a caller that does
  /// not care simply gets no banding.
  final int index;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? s = status;

    // The ground alternates; only the accent bar comes from the status, and a
    // row without one simply has no bar.
    final Color ground = index.isEven ? AppColors.rowEven : AppColors.rowOdd;
    final Color ink = s == null ? theme.dividerColor : StatusPalette.of(s).$2;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        color: ground,
        // The bar runs the full height of the card, so it has to be clipped to
        // the corner radius rather than drawn inside the padding.
        clip: true,
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (s != null) SizedBox(width: 3, child: ColoredBox(color: ink)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: <Widget>[
                      if (leading != null) ...<Widget>[
                        leading!,
                        const SizedBox(width: AppSpacing.md),
                      ],
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                            if (subtitle != null) ...<Widget>[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          if (trailing != null)
                            Text(trailing!, style: theme.textTheme.titleSmall),
                          if (s != null) ...<Widget>[
                            if (trailing != null) const SizedBox(height: 4),
                            StatusChip(s),
                          ],
                        ],
                      ),
                      // A row that goes somewhere says so; one that does not
                      // keeps the space, so the trailing figures stay aligned
                      // down a mixed list.
                      if (onTap != null) ...<Widget>[
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: theme.dividerColor,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
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

/* ------------------------------------------------------------- small shared --
   Four screens had grown their own copy of each of these, which is three too
   many: a detail row that is 108px wide on one screen and 96 on another reads
   as a rendering fault.
*/

/// A message in the middle of the screen that can still be pulled to refresh.
///
/// A plain Center cannot: RefreshIndicator needs a scrollable child, and the
/// empty state is exactly when someone wants to pull for a new one.
Widget centredMessage(
  BuildContext context,
  String text, {
  VoidCallback? onRetry,
}) => ListView(
  padding: const EdgeInsets.all(AppSpacing.xxl),
  children: <Widget>[
    const SizedBox(height: AppSpacing.xxl),
    Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    ),
    if (onRetry != null) ...<Widget>[
      const SizedBox(height: AppSpacing.lg),
      Center(
        child: OutlinedButton(
          onPressed: onRetry,
          child: const Text('Try again'),
        ),
      ),
    ],
  ],
);

/// A heading over a group of [detailRow]s.
Widget sectionTitle(BuildContext context, String title) => Padding(
  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
  child: Text(title, style: Theme.of(context).textTheme.titleSmall),
);

/// One labelled line of a record. An empty value prints as a dash rather than
/// a blank, so a missing field looks deliberate instead of broken.
Widget detailRow(BuildContext context, String label, String value) {
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
            value.trim().isEmpty ? '—' : value,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

String titleCase(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

const List<String> kMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "9 Oct 2026" — for a date that could be any year.
String formatDay(DateTime d) => '${d.day} ${kMonths[d.month - 1]} ${d.year}';

/// "9 Oct" — for a date within the current cycle, where the year is noise.
String formatShortDay(DateTime d) => '${d.day} ${kMonths[d.month - 1]}';

/* ------------------------------------------------- the config masters -- */

/// The body every master list wears: spinner, retryable error, empty state, or
/// the rows. [StaffSection] does this for a [Loadable]; these screens hold
/// their own state because they write as well as read, and a write has to be
/// able to reload without going through a store.
class MasterBody extends StatelessWidget {
  const MasterBody({
    super.key,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.isEmpty,
    required this.empty,
    required this.children,
  });

  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final bool isEmpty;
  final Widget empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (loading) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      // A ListView rather than a Column, so pull-to-refresh still works on the
      // screen you most want to retry from.
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: <Widget>[
          Text(
            error!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: OutlinedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    if (isEmpty) {
      return ListView(children: <Widget>[const SizedBox(height: 80), empty]);
    }

    return ListView(
      // Bottom padding clears the floating action button, which otherwise sits
      // on top of the last row.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        96,
      ),
      children: children,
    );
  }
}

/// The shell a master's edit sheet wears: title, fields, Cancel and Save.
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.title,
    required this.onSave,
    required this.children,
    this.saveLabel = 'Save',
  });

  final String title;
  final VoidCallback onSave;
  final List<Widget> children;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            ...children,
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: onSave,
                    child: Text(saveLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Runs a write, says what happened, and reloads.
///
/// The API refuses the destructive ones it should — a class with students in
/// it, a year already invoiced against — and its wording explains why better
/// than anything a screen could invent, so the message is shown as it came.
Future<void> runAndReload(
  BuildContext context,
  Future<void> Function() action,
  String done,
  Future<void> Function() reload,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final Color errorColour = Theme.of(context).colorScheme.error;
  try {
    await action();
    messenger.showSnackBar(SnackBar(content: Text(done)));
    await reload();
  } on ApiException catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(e.message), backgroundColor: errorColour),
    );
  }
}

/// A yes/no before something that cannot be undone, or that changes what every
/// other screen files its work under.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  bool destructive = true,
}) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext d) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(d).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(d).pop(true),
          style: destructive
              ? TextButton.styleFrom(
                  foregroundColor: Theme.of(d).colorScheme.error,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}
