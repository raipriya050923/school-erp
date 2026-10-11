import 'package:flutter/material.dart';

import '../../core/loadable.dart';
import '../../core/staff_stores.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../../data/staff_models.dart';
import 'platform_school_detail_screen.dart';
import 'platform_ticket_detail_screen.dart';
import 'platform_school_form_screen.dart';
import 'staff_widgets.dart';

/* ------------------------------------------------------ platform figures -- */

class PlatformHomeScreen extends StatefulWidget {
  const PlatformHomeScreen({super.key});

  @override
  State<PlatformHomeScreen> createState() => _PlatformHomeScreenState();
}

class _PlatformHomeScreenState extends State<PlatformHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SuperAdminStore.instance.loadStats();
      // Recent Signups is the school list in date order rather than an
      // endpoint of its own, which is also how the web dashboard builds it.
      SuperAdminStore.instance.loadSchools();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StoreBuilder<SuperAdminStore>(
      store: SuperAdminStore.instance,
      builder: (BuildContext context, SuperAdminStore store) => StaffPage(
        title: 'Platform',
        subtitle: 'Nexa Fusion Technology',
        onRefresh: () => store.loadStats(force: true),
        child: StaffSection<PlatformStats>(
          state: store.stats,
          onRetry: () => store.loadStats(force: true),
          builder: (BuildContext context, PlatformStats s) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              MetricGrid(
                tiles: <MetricTile>[
                  MetricTile(
                    label: 'Schools',
                    value: '${s.totalSchools}',
                    tint: 0,
                    icon: Icons.apartment_outlined,
                  ),
                  MetricTile(
                    label: 'MRR',
                    value: Format.money(s.monthlyRecurringRevenue),
                    tint: 1,
                    icon: Icons.trending_up_rounded,
                  ),
                  MetricTile(
                    label: 'Active plans',
                    value: '${s.activeSubscriptions}',
                    caption: '${s.trialSubscriptions} on trial',
                    tint: 2,
                    icon: Icons.workspace_premium_outlined,
                  ),
                  MetricTile(
                    label: 'Open tickets',
                    value: '${s.openTickets}',
                    tint: 3,
                    icon: Icons.confirmation_number_outlined,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _SubscriptionMix(stats: s),
              const SizedBox(height: AppSpacing.xl),
              _RecentSignups(schools: store.schools.value),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------- schools -- */

class PlatformSchoolsScreen extends StatefulWidget {
  const PlatformSchoolsScreen({super.key});

  @override
  State<PlatformSchoolsScreen> createState() => _PlatformSchoolsScreenState();
}

class _PlatformSchoolsScreenState extends State<PlatformSchoolsScreen> {
  final TextEditingController _search = TextEditingController();

  /// The applied joined-date range, or null for "any time".
  ///
  /// Narrowed here rather than in the request because the endpoint takes no
  /// date parameters — only `search` — so the dates filter what came back.
  /// That is the same split the web portal makes.
  DateTimeRange? _joined;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => SuperAdminStore.instance.loadSchools(),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The text term goes to the server; a new one always refetches.
  Future<void> _applySearch() async {
    FocusScope.of(context).unfocus();
    await SuperAdminStore.instance.loadSchools(search: _search.text);
  }

  Future<void> _pickJoined() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      // A school cannot have joined before the product existed, and one
      // cannot join tomorrow.
      firstDate: DateTime(2015),
      lastDate: now,
      initialDateRange: _joined,
      helpText: 'Joined between',
    );
    if (picked == null || !mounted) return;
    setState(() => _joined = picked);
  }

  Future<void> _clearFilters() async {
    setState(() {
      _search.clear();
      _joined = null;
    });
    await SuperAdminStore.instance.loadSchools(search: '');
  }

  /// Applies the date range to what the server returned. Compared on the date
  /// alone: `createdAt` carries a time, and a school onboarded at 14:00 on the
  /// "to" day is inside a range that ends that day.
  List<PlatformSchool> _inRange(List<PlatformSchool> rows) {
    final DateTimeRange? r = _joined;
    if (r == null) return rows;
    final DateTime from = DateTime(r.start.year, r.start.month, r.start.day);
    final DateTime to = DateTime(r.end.year, r.end.month, r.end.day);
    return rows.where((PlatformSchool s) {
      final DateTime? c = s.createdAt;
      if (c == null) return false;
      final DateTime day = DateTime(c.year, c.month, c.day);
      return !day.isBefore(from) && !day.isAfter(to);
    }).toList();
  }

  /// Opens one school. Reloads the list on the way back, since the detail
  /// screen can rename it, move its plan or suspend it.
  Future<void> _open(int schoolId) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext _) =>
            PlatformSchoolDetailScreen(schoolId: schoolId),
      ),
    );
    if (changed == true) await SuperAdminStore.instance.loadSchools(force: true);
  }

  Future<void> _add() async {
    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext _) => const PlatformSchoolFormScreen(),
      ),
    );
    if (created == true) await SuperAdminStore.instance.loadSchools(force: true);
  }

  /// Says what is being counted. "12 onboarded" under a filtered list reads
  /// as the platform total, which it is not.
  String _subtitleFor(List<PlatformSchool> all) {
    final List<PlatformSchool> shown = _inRange(all);
    final bool filtered = SuperAdminStore.instance.schoolSearch.isNotEmpty ||
        _joined != null;
    if (!filtered) return '${all.length} onboarded';
    return '${shown.length} of ${all.length} onboarded';
  }

  /// Search, and a joined-date range.
  ///
  /// The web puts the term and two date boxes on one row; at phone width that
  /// is three cramped fields, so the range collapses into a single chip that
  /// opens the platform range picker and reads back the dates it chose.
  Widget _filterBar(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool filtered =
        SuperAdminStore.instance.schoolSearch.isNotEmpty || _joined != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _applySearch(),
            decoration: InputDecoration(
              hintText: 'Search by name, code or city',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                tooltip: 'Search',
                onPressed: _applySearch,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: const Icon(Icons.date_range_outlined, size: 18),
                    label: Text(_joinedLabel()),
                    onPressed: _pickJoined,
                  ),
                ),
              ),
              if (filtered)
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear'),
                ),
            ],
          ),
          if (SuperAdminStore.instance.schoolSearch.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Matching "${SuperAdminStore.instance.schoolSearch}"',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  String _joinedLabel() {
    final DateTimeRange? r = _joined;
    if (r == null) return 'Joined: any time';
    String d(DateTime x) =>
        '${x.day.toString().padLeft(2, '0')}/'
        '${x.month.toString().padLeft(2, '0')}/${x.year}';
    return 'Joined ${d(r.start)} – ${d(r.end)}';
  }

  @override
  Widget build(BuildContext context) {
    return StoreBuilder<SuperAdminStore>(
      store: SuperAdminStore.instance,
      builder: (BuildContext context, SuperAdminStore store) => StaffPage(
        title: 'Schools',
        subtitle: store.schools.hasValue
            ? _subtitleFor(store.schools.value!)
            : null,
        onRefresh: () => store.loadSchools(force: true),
        actions: <Widget>[
          IconButton(
            onPressed: _add,
            tooltip: 'Onboard a school',
            icon: const Icon(Icons.add),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _filterBar(context),
            StaffSection<List<PlatformSchool>>(
              state: store.schools,
              onRetry: () => store.loadSchools(force: true),
              builder: (BuildContext context, List<PlatformSchool> all) {
                final List<PlatformSchool> rows = _inRange(all);
                if (rows.isEmpty) {
                  // Three different nothings, and conflating them is how
                  // someone concludes the platform has lost its schools.
                  final bool filtered =
                      store.schoolSearch.isNotEmpty || _joined != null;
                  return EmptyState(
                    icon: filtered
                        ? Icons.search_off_rounded
                        : Icons.apartment_outlined,
                    title: filtered
                        ? 'No schools match'
                        : 'No schools yet',
                  );
                }
                return Column(
                  children: <Widget>[
                    for (int i = 0; i < rows.length; i++)
                      StaffRow(
                        index: i,
                        leading: _Monogram(name: rows[i].name),
                        title: rows[i].name,
                        subtitle: <String>[
                          if (rows[i].schoolCode != null) rows[i].schoolCode!,
                          if ((rows[i].city ?? '').isNotEmpty) rows[i].city!,
                          if (rows[i].planName != null) rows[i].planName!,
                        ].join(' · '),
                        // Students, not a bare number: a column of integers
                        // beside a column of money needs saying which is which.
                        trailing: '${rows[i].studentCount} students',
                        status: rows[i].status,
                        onTap: () => _open(rows[i].id),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------- subscriptions -- */

class PlatformSubscriptionsScreen extends StatefulWidget {
  const PlatformSubscriptionsScreen({super.key});

  @override
  State<PlatformSubscriptionsScreen> createState() =>
      _PlatformSubscriptionsScreenState();
}

class _PlatformSubscriptionsScreenState
    extends State<PlatformSubscriptionsScreen> {
  /// The applied start-date range, or null for "any time". Narrowed here, not
  /// in the request: the endpoint takes `status` and `planId` only.
  DateTimeRange? _started;

  /// The statuses the endpoint recognises. An empty value means no filter.
  static const List<(String, String)> _statuses = <(String, String)>[
    ('', 'All statuses'),
    ('active', 'Active'),
    ('trial', 'Trial'),
    ('past_due', 'Past due'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => SuperAdminStore.instance.loadSubscriptions(),
    );
  }

  Future<void> _pickStarted() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      // A subscription can legitimately start in the future - a renewal
      // booked ahead - so the ceiling is not today.
      lastDate: DateTime(now.year + 5),
      initialDateRange: _started,
      helpText: 'Started between',
    );
    if (picked == null || !mounted) return;
    setState(() => _started = picked);
  }

  Future<void> _clearFilters() async {
    setState(() => _started = null);
    await SuperAdminStore.instance.loadSubscriptions(status: '');
  }

  /// Applies the range to what the server returned, on the date alone - a
  /// period beginning at 14:00 on the "to" day is inside a range ending then.
  List<PlatformSubscription> _inRange(List<PlatformSubscription> rows) {
    final DateTimeRange? r = _started;
    if (r == null) return rows;
    final DateTime from = DateTime(r.start.year, r.start.month, r.start.day);
    final DateTime to = DateTime(r.end.year, r.end.month, r.end.day);
    return rows.where((PlatformSubscription s) {
      final DateTime? d = s.startDate;
      if (d == null) return false;
      final DateTime day = DateTime(d.year, d.month, d.day);
      return !day.isBefore(from) && !day.isAfter(to);
    }).toList();
  }

  /// Says what is being counted, so a filtered list is not read as the total.
  String _subtitleFor(List<PlatformSubscription> all) {
    final int shown = _inRange(all).length;
    final bool filtered =
        SuperAdminStore.instance.subscriptionStatus.isNotEmpty ||
        _started != null;
    if (!filtered) return '${all.length} subscriptions';
    return '$shown of ${all.length} subscriptions';
  }

  /// Status and a start-date range.
  ///
  /// Status goes to the server and applies the moment it changes, as on the
  /// web. The range is a chip rather than two date boxes: at phone width the
  /// web's side-by-side pair does not fit.
  Widget _filterBar(BuildContext context) {
    final SuperAdminStore store = SuperAdminStore.instance;
    final bool filtered =
        store.subscriptionStatus.isNotEmpty || _started != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: <Widget>[
          DropdownButton<String>(
            value: store.subscriptionStatus,
            underline: const SizedBox.shrink(),
            items: <DropdownMenuItem<String>>[
              for (final (String value, String label) in _statuses)
                DropdownMenuItem<String>(value: value, child: Text(label)),
            ],
            onChanged: (String? v) => store.loadSubscriptions(status: v ?? ''),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(_startedLabel()),
                onPressed: _pickStarted,
              ),
            ),
          ),
          if (filtered)
            TextButton(onPressed: _clearFilters, child: const Text('Clear')),
        ],
      ),
    );
  }

  String _startedLabel() {
    final DateTimeRange? r = _started;
    if (r == null) return 'Started: any time';
    String d(DateTime x) =>
        '${x.day.toString().padLeft(2, '0')}/'
        '${x.month.toString().padLeft(2, '0')}/${x.year}';
    return 'Started ${d(r.start)} to ${d(r.end)}';
  }

  String _renews(DateTime? d) {
    if (d == null) return '';
    return 'to ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return StoreBuilder<SuperAdminStore>(
      store: SuperAdminStore.instance,
      builder: (BuildContext context, SuperAdminStore store) => StaffPage(
        title: 'Subscriptions',
        subtitle: store.subscriptions.hasValue
            ? _subtitleFor(store.subscriptions.value!)
            : null,
        onRefresh: () => store.loadSubscriptions(force: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _filterBar(context),
            StaffSection<List<PlatformSubscription>>(
              state: store.subscriptions,
              onRetry: () => store.loadSubscriptions(force: true),
              builder: (BuildContext context, List<PlatformSubscription> all) {
                final List<PlatformSubscription> rows = _inRange(all);
                if (rows.isEmpty) {
                  // "None match" and "none at all" are different answers, and
                  // conflating them reads as the platform having lost them.
                  final bool filtered =
                      store.subscriptionStatus.isNotEmpty || _started != null;
                  return EmptyState(
                    icon: filtered
                        ? Icons.search_off_rounded
                        : Icons.workspace_premium_outlined,
                    title: filtered
                        ? 'No subscriptions match'
                        : 'No subscriptions',
                  );
                }
                return Column(
                  children: <Widget>[
                    for (int i = 0; i < rows.length; i++)
                      StaffRow(
                        index: i,
                        leading: _Monogram(name: rows[i].schoolName ?? 'School'),
                        title: rows[i].schoolName ?? 'School',
                        subtitle:
                            '${rows[i].planName ?? ''} · ${rows[i].billingCycle} ${_renews(rows[i].endDate)}',
                        trailing: Format.money(rows[i].price),
                        status: rows[i].status,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------- tickets -- */

class PlatformTicketsScreen extends StatefulWidget {
  const PlatformTicketsScreen({super.key});

  @override
  State<PlatformTicketsScreen> createState() => _PlatformTicketsScreenState();
}

class _PlatformTicketsScreenState extends State<PlatformTicketsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => SuperAdminStore.instance.loadTickets(),
    );
  }

  /// Opens the thread. Reloads on the way back, since replying or resolving
  /// changes both the status and the reply count shown on the row.
  Future<void> _open(int ticketId) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext _) =>
            PlatformTicketDetailScreen(ticketId: ticketId),
      ),
    );
    if (changed == true) {
      await SuperAdminStore.instance.loadTickets(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreBuilder<SuperAdminStore>(
      store: SuperAdminStore.instance,
      builder: (BuildContext context, SuperAdminStore store) => StaffPage(
        title: 'Support',
        subtitle: store.tickets.hasValue
            ? '${store.tickets.value!.where((SupportTicket t) => t.status == 'open').length} open'
            : null,
        onRefresh: () => store.loadTickets(force: true),
        child: StaffSection<List<SupportTicket>>(
          state: store.tickets,
          onRetry: () => store.loadTickets(force: true),
          builder: (BuildContext context, List<SupportTicket> rows) => rows.isEmpty
              ? const EmptyState(
                  icon: Icons.confirmation_number_outlined,
                  title: 'No tickets',
                  message: 'Nothing needs your attention.',
                )
              : Column(
                  children: <Widget>[
                    for (int i = 0; i < rows.length; i++)
                      StaffRow(
                        index: i,
                        title: rows[i].subject,
                        subtitle: <String>[
                          if (rows[i].ticketNo != null) rows[i].ticketNo!,
                          if (rows[i].schoolName != null) rows[i].schoolName!,
                          if (rows[i].commentCount > 0)
                            '${rows[i].commentCount} replies',
                        ].join(' · '),
                        // Priority earns the chip over status: an urgent ticket
                        // is the one worth opening first, and every ticket in
                        // this list is open anyway.
                        status: rows[i].priority == 'urgent'
                            ? 'urgent'
                            : rows[i].status,
                        onTap: () => _open(rows[i].id),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}


/* ---------------------------------------------- dashboard: mix + signups -- */

/// How the schools split across subscription states, as one bar.
///
/// A bar rather than a pie: three parts of a whole, read as proportions, and a
/// bar stays legible at phone width where a pie's labels do not. "Other" is
/// whatever is neither active nor on trial — lapsed, suspended, never
/// subscribed — and is only shown when there is some, because a legend entry
/// reading zero is a question nobody asked.
class _SubscriptionMix extends StatelessWidget {
  const _SubscriptionMix({required this.stats});

  final PlatformStats stats;

  int get _other => (stats.totalSchools -
          stats.activeSubscriptions -
          stats.trialSubscriptions)
      .clamp(0, stats.totalSchools);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int total = stats.totalSchools;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Subscription mix', style: theme.textTheme.titleSmall),
            ),
            Text('$total schools', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (total == 0)
          Text('No schools yet.', style: theme.textTheme.bodyMedium)
        else ...<Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: Row(
                children: <Widget>[
                  if (stats.activeSubscriptions > 0)
                    Expanded(
                      flex: stats.activeSubscriptions,
                      child: const ColoredBox(color: AppColors.green),
                    ),
                  if (stats.trialSubscriptions > 0)
                    Expanded(
                      flex: stats.trialSubscriptions,
                      child: const ColoredBox(color: AppColors.amber),
                    ),
                  if (_other > 0)
                    Expanded(
                      flex: _other,
                      child: ColoredBox(color: theme.dividerColor),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              _legend(context, 'Active', stats.activeSubscriptions, AppColors.green),
              _legend(context, 'Trial', stats.trialSubscriptions, AppColors.amber),
              if (_other > 0)
                _legend(context, 'Other', _other, theme.dividerColor),
            ],
          ),
        ],
      ],
    );
  }

  Widget _legend(BuildContext context, String label, int count, Color colour) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(width: 4),
        Text('$count', style: theme.textTheme.titleSmall),
      ],
    );
  }
}

/// The five newest schools. Same five the web dashboard shows, built the same
/// way — the school list in date order — so the two cannot disagree.
///
/// Laid out as rows with a monogram, not a list of sentences: at phone width a
/// name, a code, a city and a date set in similar weights read as one grey
/// block, and the thing the section exists to answer — who joined, and how
/// recently — is the part that disappears. The monogram gives each row an
/// anchor to scan down, and the date is relative because "3 days ago" is what
/// "recent" is actually asking.
class _RecentSignups extends StatelessWidget {
  const _RecentSignups({required this.schools});

  final List<PlatformSchool>? schools;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<PlatformSchool>? all = schools;

    final List<PlatformSchool> recent;
    if (all == null) {
      recent = const <PlatformSchool>[];
    } else {
      final List<PlatformSchool> sorted = List<PlatformSchool>.of(all)
        ..sort((PlatformSchool a, PlatformSchool b) {
          // Undated rows sort last rather than crashing the comparison.
          if (a.createdAt == null && b.createdAt == null) return 0;
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          return b.createdAt!.compareTo(a.createdAt!);
        });
      recent = sorted.take(5).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Matches the Subscription mix header above: title left, context right.
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Recent signups', style: theme.textTheme.titleSmall),
            ),
            if (all != null && all.isNotEmpty)
              Text('newest ${recent.length}', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (all == null)
          const _SignupSkeleton()
        else if (recent.isEmpty)
          const EmptyState(
            icon: Icons.apartment_outlined,
            title: 'No schools yet',
            message: 'Onboarded schools appear here.',
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < recent.length; i++) ...<Widget>[
                  if (i > 0)
                    // Inset so the rule starts under the text, not under the
                    // monogram — the monograms then read as one column.
                    const Padding(
                      padding: EdgeInsets.only(left: 60, right: AppSpacing.lg),
                      child: Divider(height: 1),
                    ),
                  _SignupRow(school: recent[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// One school: monogram, name, where and which plan, and how long ago.
class _SignupRow extends StatelessWidget {
  const _SignupRow({required this.school});

  final PlatformSchool school;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // Code and city answer different questions — which record, and where — so
    // they sit on one meta line with the plan, and whichever is missing simply
    // drops out rather than leaving a stray separator.
    final String meta = <String>[
      if ((school.schoolCode ?? '').isNotEmpty) school.schoolCode!,
      if ((school.city ?? '').isNotEmpty) school.city!,
      if ((school.planName ?? '').isNotEmpty) school.planName!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          _Monogram(name: school.name),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  school.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                if (meta.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              if (school.createdAt != null)
                Text(
                  _relativeDate(school.createdAt!),
                  style: theme.textTheme.bodySmall,
                ),
              // Only when it is not the unremarkable case. A column of five
              // identical "active" chips is noise; a lone "suspended" is the
              // reason to look at this list at all.
              if (school.status.isNotEmpty && school.status.toLowerCase() != 'active') ...<Widget>[
                const SizedBox(height: 4),
                StatusChip(school.status),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The school's initials on a tinted disc, coloured from the name so the same
/// school keeps the same colour between builds and between screens.
class _Monogram extends StatelessWidget {
  const _Monogram({required this.name});

  final String name;

  static const List<Color> _palette = <Color>[
    AppColors.blue,
    AppColors.indigo,
    AppColors.violet,
    AppColors.teal,
    AppColors.green,
    AppColors.amber,
  ];

  String get _initials {
    final List<String> words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final String w = words.first;
      return (w.length == 1 ? w : w.substring(0, 2)).toUpperCase();
    }
    return (words.first[0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // hashCode varies between runs for some types but is stable for String
    // within a run, and abs() keeps the modulo in range for negative hashes.
    final Color colour = _palette[name.hashCode.abs() % _palette.length];
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: colour,
        ),
      ),
    );
  }
}

/// Placeholder rows while the school list loads, shaped like the real ones so
/// the section does not jump when they arrive.
class _SignupSkeleton extends StatelessWidget {
  const _SignupSkeleton();

  @override
  Widget build(BuildContext context) {
    final Color bar = Theme.of(context).dividerColor;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < 3; i++) ...<Widget>[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.only(left: 60, right: AppSpacing.lg),
                child: Divider(height: 1),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: bar,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(height: 10, width: 140, color: bar),
                        const SizedBox(height: 6),
                        Container(height: 9, width: 90, color: bar),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// How long ago, in the units a person would say it in. Falls back to the date
/// once "days ago" stops being easier to read than the date itself.
String _relativeDate(DateTime d) {
  final DateTime now = DateTime.now();
  // Compare whole days, so something late last night reads "yesterday" rather
  // than "12h ago" when it is seen over breakfast.
  final int days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(d.year, d.month, d.day))
      .inDays;

  // A createdAt slightly ahead of the phone's clock is a clock-skew artefact,
  // not a signup from the future.
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  if (days < 14) return 'Last week';
  if (days < 31) return '${days ~/ 7} weeks ago';
  return _signupDate(d);
}

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _signupDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
