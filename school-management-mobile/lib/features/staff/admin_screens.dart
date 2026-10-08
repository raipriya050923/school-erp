import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/loadable.dart';
import '../../core/staff_stores.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/api_models.dart' show FeePayment;
import '../../data/staff_models.dart';
import '../fees/receipt_sheet.dart';
import 'parent_login_sheet.dart';
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
              if (d.subscription != null) SubscriptionNotices(status: d.subscription!),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
                          // Tapping a student opens the parent-login sheet: it is
                          // the only per-student action this portal has, so it
                          // does not need a menu of one.
                          onTap: () => ParentLoginSheet.show(context, rows[i]),
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
        child: StaffSection<List<AdminTeacher>>(
          state: store.teachers,
          onRetry: () => store.loadTeachers(force: true),
          builder: (BuildContext context, List<AdminTeacher> rows) => rows.isEmpty
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
                      ),
                  ],
                ),
        ),
      ),
    );
  }
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
                    builder: (BuildContext context, List<AdminInvoice> _) =>
                        Column(
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
                                // Tappable only where there is something to
                                // show: an invoice with nothing paid has no
                                // receipt, and a row that opens an apology is
                                // worse than a row that does not react.
                                onTap: inv.paid > 0
                                    ? () => _showReceipts(context, inv)
                                    : null,
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
