import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/loadable.dart';
import '../../core/staff_stores.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../../data/api_models.dart' show FeePayment;
import '../../data/staff_models.dart';
import '../fees/record_payment_sheet.dart';
import '../fees/receipt_sheet.dart';
import 'admin_people_actions.dart';
import 'admin_student_form_screen.dart';
import 'admin_teacher_form_screen.dart';
import 'staff_widgets.dart';

/* ------------------------------------------------------------ dashboard -- */

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AdminStore.instance.loadDashboard(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreBuilder<AdminStore>(
      store: AdminStore.instance,
      builder: (BuildContext context, AdminStore store) => StaffPage(
        title: store.dashboard.value?.schoolName ?? 'Dashboard',
        subtitle: store.dashboard.value?.academicYear,
        onRefresh: () => store.loadDashboard(force: true),
        child: StaffSection<AdminDashboard>(
          state: store.dashboard,
          onRetry: () => store.loadDashboard(force: true),
          builder: (BuildContext context, AdminDashboard d) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (d.subscription != null)
                SubscriptionNotices(status: d.subscription!),
              MetricGrid(
                tiles: <MetricTile>[
                  MetricTile(
                    label: 'Students',
                    value: '${d.totalStudents}',
                    tint: 0,
                    icon: Icons.groups_outlined,
                  ),
                  MetricTile(
                    label: 'Teachers',
                    value: '${d.totalTeachers}',
                    caption: d.teachersOnLeave > 0
                        ? '${d.teachersOnLeave} on leave'
                        : null,
                    tint: 1,
                    icon: Icons.co_present_outlined,
                  ),
                  MetricTile(
                    label: 'Classes',
                    value: '${d.totalClasses}',
                    caption: '${d.totalSections} sections',
                    tint: 2,
                    icon: Icons.meeting_room_outlined,
                  ),
                  MetricTile(
                    label: 'Unpaid invoices',
                    value: '${d.unpaidInvoices}',
                    tint: 3,
                    icon: Icons.receipt_long_outlined,
                  ),
                  MetricTile(
                    label: 'Attendance today',
                    // Nobody has marked it yet is not the same as nobody came,
                    // so it shows a dash rather than 0%.
                    value: d.attendanceToday == null
                        ? '—'
                        : Format.percent(d.attendanceToday!),
                    caption: d.attendanceToday == null
                        ? 'not marked yet'
                        : null,
                    tint: 1,
                    icon: Icons.fact_check_outlined,
                  ),
                  MetricTile(
                    label: 'Avg attendance',
                    value: d.averageAttendance == null
                        ? '—'
                        : Format.percent(d.averageAttendance!),
                    caption: d.attendanceTrend.isEmpty
                        ? null
                        : 'last ${d.attendanceTrend.length} marked days',
                    tint: 2,
                    icon: Icons.insights_outlined,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const SectionHeader('Fees'),
              MetricGrid(
                tiles: <MetricTile>[
                  MetricTile(
                    label: 'Billed',
                    value: Format.money(d.feesBilled),
                    tint: 0,
                  ),
                  MetricTile(
                    label: 'Collected',
                    value: Format.money(d.feesCollected),
                    tint: 1,
                  ),
                  MetricTile(
                    label: 'Overdue',
                    value: Format.money(d.feesOverdue),
                    tint: 3,
                  ),
                  MetricTile(
                    label: 'Outstanding',
                    value: Format.money(d.feesDue),
                    caption: '${d.unpaidInvoices} open invoices',
                    tint: 2,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(child: _FeesCollection(d: d)),

              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('Attendance overview'),
              AppCard(child: _AttendanceTrend(points: d.attendanceTrend)),

              const SizedBox(height: AppSpacing.xl),
              SectionHeader(
                'Recent admissions',
                subtitle: d.recentAdmissions.isEmpty
                    ? null
                    : 'newest ${d.recentAdmissions.length}',
              ),
              if (d.recentAdmissions.isEmpty)
                const EmptyState(
                  icon: Icons.person_add_alt_outlined,
                  title: 'No admissions yet',
                  message: 'Students you admit appear here.',
                )
              else
                for (final RecentAdmission a in d.recentAdmissions)
                  StaffRow(
                    title: a.name,
                    subtitle: a.classLabel.isEmpty ? null : a.classLabel,
                    trailing: a.admissionDate == null
                        ? null
                        : _formatDate(a.admissionDate!),
                  ),

              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('Latest notices'),
              if (d.latestNotices.isEmpty)
                const EmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'No notices yet',
                  message: 'Notices you publish appear here.',
                )
              else
                for (final SchoolNotice n in d.latestNotices)
                  StaffRow(
                    title: n.title,
                    subtitle: n.body,
                    trailing: _formatDate(n.publishDate),
                    status: n.audience == 'all' ? null : n.audience,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the billed money stands, as one bar.
///
/// A bar rather than the web's donut: three parts of a whole read as
/// proportions either way, and a bar keeps its legend readable at phone width,
/// which is the same reason the platform dashboard's subscription mix is one.
class _FeesCollection extends StatelessWidget {
  const _FeesCollection({required this.d});

  final AdminDashboard d;

  /// Billed, less what is collected and what is already overdue. Clamped: the
  /// three figures are computed separately by the API and need not reconcile
  /// to the penny, and a negative flex would throw.
  double get _pending =>
      (d.feesBilled - d.feesCollected - d.feesOverdue).clamp(0, d.feesBilled);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double billed = d.feesBilled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Fees collection', style: theme.textTheme.titleSmall),
            ),
            Text(
              '${Format.money(billed)} billed',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (billed <= 0)
          Text('Nothing billed yet.', style: theme.textTheme.bodyMedium)
        else ...<Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: Row(
                // Stretch, or each segment takes its own (zero) height and the
                // bar is an invisible 10px gap above the legend.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Rounded to whole rupees: Expanded takes an int flex, and a
                  // school's fees are large enough that the rounding is invisible.
                  if (d.feesCollected > 0)
                    Expanded(
                      flex: d.feesCollected.round(),
                      child: const ColoredBox(color: AppColors.green),
                    ),
                  if (_pending > 0)
                    Expanded(
                      flex: _pending.round(),
                      child: const ColoredBox(color: AppColors.amber),
                    ),
                  if (d.feesOverdue > 0)
                    Expanded(
                      flex: d.feesOverdue.round(),
                      child: const ColoredBox(color: AppColors.red),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _legend(
            context,
            'Collected',
            d.feesCollected,
            billed,
            AppColors.green,
          ),
          _legend(context, 'Pending', _pending, billed, AppColors.amber),
          _legend(context, 'Overdue', d.feesOverdue, billed, AppColors.red),
        ],
      ],
    );
  }

  Widget _legend(
    BuildContext context,
    String label,
    double amount,
    double billed,
    Color colour,
  ) {
    final ThemeData theme = Theme.of(context);
    final double share = billed <= 0 ? 0 : amount / billed * 100;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(Format.money(amount), style: theme.textTheme.bodyMedium),
          const SizedBox(width: AppSpacing.sm),
          Text('(${Format.percent(share)})', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// School-wide attendance over the marked days, as a column per day.
///
/// Columns rather than the web's line: at phone width a line over thirty points
/// is a scribble, while columns stay separable and a bad day still reads as a
/// short bar. Scaled from zero so the heights are the percentages themselves.
class _AttendanceTrend extends StatelessWidget {
  const _AttendanceTrend({required this.points});

  final List<AttendancePoint> points;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (points.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Attendance', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No attendance has been marked yet.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Attendance', style: theme.textTheme.titleSmall),
            ),
            Text(
              'last ${points.length} marked days',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (final AttendancePoint p in points)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        // A marked day at 0% would otherwise be indistinguishable
                        // from no bar at all.
                        heightFactor: (p.percent / 100).clamp(0.02, 1.0),
                        // Without this the column takes the DecoratedBox's own
                        // (zero) width and the chart draws nothing.
                        widthFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _colourFor(p.percent, theme),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Text(
              _formatDate(points.first.date),
              style: theme.textTheme.bodySmall,
            ),
            const Spacer(),
            Text(
              _formatDate(points.last.date),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }

  /// A day worth looking at is coloured like one: the thresholds match the
  /// attendance report's own bands.
  Color _colourFor(double percent, ThemeData theme) {
    if (percent >= 90) return AppColors.green;
    if (percent >= 75) return AppColors.amber;
    return AppColors.red;
  }
}

/* ------------------------------------------------------------- students -- */

class AdminStudentsScreen extends StatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  State<AdminStudentsScreen> createState() => _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends State<AdminStudentsScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AdminStore.instance.loadStudents(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreBuilder<AdminStore>(
      store: AdminStore.instance,
      builder: (BuildContext context, AdminStore store) {
        final List<AdminStudent> all = store.students.value ?? <AdminStudent>[];
        final String q = _query.trim().toLowerCase();
        final List<AdminStudent> rows = q.isEmpty
            ? all
            : all
                  .where(
                    (AdminStudent s) =>
                        s.name.toLowerCase().contains(q) ||
                        s.admissionNo.toLowerCase().contains(q) ||
                        s.classLabel.toLowerCase().contains(q),
                  )
                  .toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Students'),
            actions: const <Widget>[SignOutAction()],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(58),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: TextField(
                  onChanged: (String v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search name, admission no or class',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                  ),
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<bool>(
                builder: (BuildContext _) => const AdminStudentFormScreen(),
              ),
            ),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Admit'),
          ),
          body: SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: () => store.loadStudents(force: true),
              child: StaffSection<List<AdminStudent>>(
                state: store.students,
                onRetry: () => store.loadStudents(force: true),
                builder: (BuildContext context, List<AdminStudent> _) =>
                    rows.isEmpty
                    ? ListView(
                        children: const <Widget>[
                          SizedBox(height: 60),
                          EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No students match',
                          ),
                        ],
                      )
                    // A school can hold thousands of students, so the list is
                    // built lazily rather than all at once.
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.xxl,
                        ),
                        itemCount: rows.length,
                        itemBuilder: (BuildContext context, int i) => StaffRow(
                          title: rows[i].name,
                          subtitle:
                              '${rows[i].admissionNo} · ${rows[i].classLabel}'
                              '${rows[i].rollNo == null || rows[i].rollNo!.isEmpty ? '' : ' · Roll ${rows[i].rollNo}'}',
                          trailing: rows[i].feeDue > 0
                              ? Format.money(rows[i].feeDue)
                              : null,
                          status: rows[i].status,
                          // A menu now rather than straight to the parent-login
                          // sheet: editing, password resets and retiring a
                          // student all hang off the same row.
                          onTap: () => showStudentActions(context, rows[i]),
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ------------------------------------------------------------- teachers -- */

class AdminTeachersScreen extends StatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  State<AdminTeachersScreen> createState() => _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends State<AdminTeachersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AdminStore.instance.loadTeachers(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreBuilder<AdminStore>(
      store: AdminStore.instance,
      builder: (BuildContext context, AdminStore store) => StaffPage(
        title: 'Teachers',
        subtitle: store.teachers.hasValue
            ? '${store.teachers.value!.length} on staff'
            : null,
        onRefresh: () => store.loadTeachers(force: true),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<bool>(
              builder: (BuildContext _) => const AdminTeacherFormScreen(),
            ),
          ),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Add'),
        ),
        child: StaffSection<List<AdminTeacher>>(
          state: store.teachers,
          onRetry: () => store.loadTeachers(force: true),
          builder: (BuildContext context, List<AdminTeacher> rows) =>
              rows.isEmpty
              ? const EmptyState(
                  icon: Icons.co_present_outlined,
                  title: 'No teachers yet',
                )
              : Column(
                  children: <Widget>[
                    for (final AdminTeacher t in rows)
                      StaffRow(
                        title: t.name,
                        subtitle: <String>[
                          if (t.employeeCode != null) t.employeeCode!,
                          if (t.subjects.isNotEmpty)
                            t.subjects.join(', ')
                          else if (t.subject != null)
                            t.subject!,
                          if (t.classTeacherOf != null &&
                              t.classTeacherOf!.isNotEmpty)
                            'Class teacher: ${t.classTeacherOf}',
                        ].join(' · '),
                        status: t.status,
                        onTap: () => showTeacherActions(context, t),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// What a tap on an invoice offers.
///
/// Split by what the invoice actually allows rather than always showing a
/// menu: with one thing to do, a menu is a step that teaches nothing.
Future<void> _invoiceActions(BuildContext context, AdminInvoice inv) async {
  final bool owes = inv.balance > 0;
  final bool hasReceipt = inv.paid > 0;

  if (owes && !hasReceipt) {
    await _takePayment(context, inv);
    return;
  }
  if (!owes) {
    await _showReceipts(context, inv);
    return;
  }

  // Part paid: there is a receipt for what came in, and a balance still to
  // take.
  final String? choice = await showModalBottomSheet<String>(
    context: context,
    builder: (BuildContext sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: AppSpacing.md),
          ListTile(
            title: Text(inv.studentName ?? 'Invoice',
                style: Theme.of(sheet).textTheme.titleMedium),
            subtitle: Text(
              '${Format.money(inv.paid)} paid · '
              '${Format.money(inv.balance)} outstanding',
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: const Text('Record payment'),
            onTap: () => Navigator.of(sheet).pop('pay'),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('View receipts'),
            onTap: () => Navigator.of(sheet).pop('receipt'),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'pay') {
    await _takePayment(context, inv);
  } else {
    await _showReceipts(context, inv);
  }
}

/// Takes a payment and reloads, so the row's balance and the summary above it
/// both reflect it without a manual refresh.
Future<void> _takePayment(BuildContext context, AdminInvoice inv) async {
  final bool recorded = await RecordPaymentSheet.show(context, inv);
  if (!recorded || !context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Payment recorded')),
  );
  await AdminStore.instance.loadInvoices(force: true);
  await AdminStore.instance.loadFeeSummary(force: true);
  // The dashboard carries the same figures, and a stale tile beside a fresh
  // one is worse than both being stale.
  await AdminStore.instance.loadDashboard(force: true);
}

/// Opens the receipt for an invoice's payment, or lets the office pick when
/// the invoice was settled in instalments. Shared by the admin fee screen; the
/// student portal has its own copy of the same flow against its own endpoints,
/// because the two are scoped differently even though the sheet is identical.
Future<void> _showReceipts(BuildContext context, AdminInvoice inv) async {
  final List<FeePayment> payments;
  try {
    payments = await AdminApi.instance.invoicePayments(inv.id);
  } on ApiException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.message)));
    return;
  }

  if (!context.mounted) return;

  if (payments.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No payment has been recorded against this invoice.'),
      ),
    );
    return;
  }

  if (payments.length == 1) {
    await ReceiptSheet.show(
      context,
      load: () => AdminApi.instance.paymentReceipt(payments.first.id),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              '${inv.invoiceNo ?? 'Invoice'} — ${payments.length} payments',
              style: Theme.of(sheetContext).textTheme.titleSmall,
            ),
          ),
          for (final FeePayment p in payments)
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(p.receiptNo),
              subtitle: Text((p.method ?? '').isEmpty ? '—' : p.method!),
              trailing: Text(Format.money(p.amount)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ReceiptSheet.show(
                  context,
                  load: () => AdminApi.instance.paymentReceipt(p.id),
                );
              },
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

/* ----------------------------------------------------------------- fees -- */

class AdminFeesScreen extends StatefulWidget {
  const AdminFeesScreen({super.key});

  @override
  State<AdminFeesScreen> createState() => _AdminFeesScreenState();
}

class _AdminFeesScreenState extends State<AdminFeesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdminStore.instance.loadFeeSummary();
      AdminStore.instance.loadInvoices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StoreBuilder<AdminStore>(
      store: AdminStore.instance,
      builder: (BuildContext context, AdminStore store) {
        final List<AdminInvoice> all = store.invoices.value ?? <AdminInvoice>[];
        // Newest first, and only a page of them: the seeded school carries over
        // a thousand invoices and a phone has no use for all of them at once.
        final List<AdminInvoice> recent = all.take(60).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Fees'),
            actions: const <Widget>[SignOutAction()],
          ),
          body: SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: () async {
                await store.loadFeeSummary(force: true);
                await store.loadInvoices(force: true);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                physics: const AlwaysScrollableScrollPhysics(),
                children: <Widget>[
                  StaffSection<FeeSummary>(
                    state: store.feeSummary,
                    onRetry: () => store.loadFeeSummary(force: true),
                    builder: (BuildContext context, FeeSummary s) => MetricGrid(
                      tiles: <MetricTile>[
                        MetricTile(
                          label: 'Billed',
                          value: Format.money(s.totalBilled),
                          tint: 0,
                        ),
                        MetricTile(
                          label: 'Collected',
                          value: Format.money(s.collected),
                          tint: 1,
                        ),
                        MetricTile(
                          label: 'Outstanding',
                          value: Format.money(s.outstanding),
                          caption: '${s.unpaid} unpaid',
                          tint: 3,
                        ),
                        MetricTile(
                          label: 'Overdue',
                          value: '${s.overdue}',
                          caption: 'invoices',
                          tint: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SectionHeader(
                    'Recent invoices',
                    subtitle: all.length > recent.length
                        ? 'Showing ${recent.length} of ${all.length}'
                        : null,
                  ),
                  StaffSection<List<AdminInvoice>>(
                    state: store.invoices,
                    onRetry: () => store.loadInvoices(force: true),
                    builder: (BuildContext context, List<AdminInvoice> _) => Column(
                      children: <Widget>[
                        for (final AdminInvoice inv in recent)
                          StaffRow(
                            title: inv.studentName ?? 'Invoice',
                            subtitle:
                                '${inv.invoiceNo ?? ''} · ${inv.classLabel ?? ''} · ${inv.month ?? ''}',
                            trailing: Format.money(
                              inv.balance > 0 ? inv.balance : inv.amount,
                            ),
                            status: inv.status,
                            // Every row now does something: an unpaid one
                            // takes a payment, a settled one shows its
                            // receipt, and one that is part paid offers both.
                            onTap: () => _invoiceActions(context, inv),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

const List<String> _months = <String>[
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

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
