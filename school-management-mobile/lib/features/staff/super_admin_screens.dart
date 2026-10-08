import 'package:flutter/material.dart';

import '../../core/loadable.dart';
import '../../core/staff_stores.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/staff_models.dart';
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => SuperAdminStore.instance.loadStats(),
    );
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
          builder: (BuildContext context, PlatformStats s) => MetricGrid(
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => SuperAdminStore.instance.loadSchools(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreBuilder<SuperAdminStore>(
      store: SuperAdminStore.instance,
      builder: (BuildContext context, SuperAdminStore store) => StaffPage(
        title: 'Schools',
        subtitle: store.schools.hasValue
            ? '${store.schools.value!.length} onboarded'
            : null,
        onRefresh: () => store.loadSchools(force: true),
        child: StaffSection<List<PlatformSchool>>(
          state: store.schools,
          onRetry: () => store.loadSchools(force: true),
          builder: (BuildContext context, List<PlatformSchool> rows) =>
              rows.isEmpty
              ? const EmptyState(
                  icon: Icons.apartment_outlined,
                  title: 'No schools yet',
                )
              : Column(
                  children: <Widget>[
                    for (final PlatformSchool s in rows)
                      StaffRow(
                        title: s.name,
                        subtitle: <String>[
                          if (s.schoolCode != null) s.schoolCode!,
                          if (s.city != null && s.city!.isNotEmpty) s.city!,
                          if (s.planName != null) s.planName!,
                        ].join(' · '),
                        trailing: '${s.studentCount}',
                        status: s.status,
                      ),
                  ],
                ),
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => SuperAdminStore.instance.loadSubscriptions(),
    );
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
        onRefresh: () => store.loadSubscriptions(force: true),
        child: StaffSection<List<PlatformSubscription>>(
          state: store.subscriptions,
          onRetry: () => store.loadSubscriptions(force: true),
          builder: (BuildContext context, List<PlatformSubscription> rows) =>
              rows.isEmpty
              ? const EmptyState(
                  icon: Icons.workspace_premium_outlined,
                  title: 'No subscriptions',
                )
              : Column(
                  children: <Widget>[
                    for (final PlatformSubscription s in rows)
                      StaffRow(
                        title: s.schoolName ?? 'School',
                        subtitle:
                            '${s.planName ?? ''} · ${s.billingCycle} ${_renews(s.endDate)}',
                        trailing: Format.money(s.price),
                        status: s.status,
                      ),
                  ],
                ),
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
                    for (final SupportTicket t in rows)
                      StaffRow(
                        title: t.subject,
                        subtitle: <String>[
                          if (t.ticketNo != null) t.ticketNo!,
                          if (t.schoolName != null) t.schoolName!,
                          if (t.commentCount > 0) '${t.commentCount} replies',
                        ].join(' · '),
                        // Priority earns the chip over status: an urgent ticket
                        // is the one worth opening first, and every ticket in
                        // this list is open anyway.
                        status: t.priority == 'urgent' ? 'urgent' : t.status,
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
