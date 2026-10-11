import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// What the platform is owed, and chasing it.
///
/// Opens on Overdue, because that is the list this screen exists for — an
/// invoice that has gone past its date is the only one anybody needs to act on
/// away from a desk. Raising an invoice and recording a bank transfer both
/// need fields a phone is a poor place to type, so they stay on the web; the
/// one action here is the reminder.
class PlatformBillingScreen extends StatefulWidget {
  const PlatformBillingScreen({super.key});

  @override
  State<PlatformBillingScreen> createState() => _PlatformBillingScreenState();
}

class _PlatformBillingScreenState extends State<PlatformBillingScreen> {
  final SuperAdminApi _api = SuperAdminApi.instance;

  /// null means every status.
  String? _filter = 'overdue';

  /// The issue-date window, applied over whatever the status filter returned.
  /// The API's invoices endpoint takes only a status, so this is filtered here
  /// — which is also how the web console does it.
  DateTime? _from;
  DateTime? _to;
  BillingSummary? _summary;
  List<BillingInvoice>? _items;
  bool _loading = true;
  int? _working;
  String? _error;

  static const List<(String?, String)> _filters = <(String?, String)>[
    ('overdue', 'Overdue'),
    ('sent', 'Sent'),
    ('paid', 'Paid'),
    (null, 'All'),
  ];

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
      // Both at once: the figures and the list are one screen, and two spinners
      // arriving a moment apart reads as the page redrawing itself.
      final List<Object> both = await Future.wait(<Future<Object>>[
        _api.billingSummary(),
        _api.billingInvoices(status: _filter),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = both[0] as BillingSummary;
        _items = both[1] as List<BillingInvoice>;
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

  /// Invoices issued inside the window, inclusive at both ends.
  ///
  /// Compared by calendar day rather than by instant: an invoice issued at
  /// 17:45 on the closing date is inside a range that ends that day, which a
  /// raw DateTime comparison would exclude.
  ///
  /// An invoice with no issue date drops out as soon as a window is set —
  /// a draft that was never issued cannot be said to fall within one.
  List<BillingInvoice> _inWindow(List<BillingInvoice> all) {
    if (_from == null && _to == null) return all;
    return all.where((BillingInvoice v) {
      final DateTime? issued = v.issuedAt;
      if (issued == null) return false;
      final DateTime day = DateTime(issued.year, issued.month, issued.day);
      if (_from != null && day.isBefore(_from!)) return false;
      if (_to != null && day.isAfter(_to!)) return false;
      return true;
    }).toList();
  }

  Future<void> _pickWindow() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Issued between',
    );
    if (picked == null) return;
    setState(() {
      _from = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _to = DateTime(picked.end.year, picked.end.month, picked.end.day);
    });
  }

  void _clearWindow() => setState(() {
    _from = null;
    _to = null;
  });

  Future<void> _remind(BillingInvoice invoice) async {
    setState(() => _working = invoice.id);
    try {
      await _api.sendBillingReminder(invoice.id);
      if (!mounted) return;
      setState(() => _working = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminder sent to ${invoice.schoolName}')),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _working = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<BillingInvoice> items = _items ?? const <BillingInvoice>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing & payments'),
        actions: const <Widget>[SignOutAction()],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            if (_summary != null) _summaryStrip(context, _summary!),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  for (final (String?, String) f in _filters)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(f.$2),
                        selected: _filter == f.$1,
                        onSelected: (_) {
                          setState(() => _filter = f.$1);
                          _load();
                        },
                      ),
                    ),
                ],
              ),
            ),
            _issuedFilter(context, items),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _body(context, _inWindow(items)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A range rather than two date fields and a Search button.
  ///
  /// The web shows "Issued from" and "Issued to" side by side because it has
  /// the width for them; at phone width two date pickers and a button would
  /// each be a thumb-wide. One control opening a range picker asks the same
  /// question, and the chip states the answer so the list is never silently
  /// filtered.
  Widget _issuedFilter(BuildContext context, List<BillingInvoice> all) {
    final ThemeData theme = Theme.of(context);
    final bool on = _from != null || _to != null;
    final int shown = _inWindow(all).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          ActionChip(
            avatar: const Icon(Icons.date_range_outlined, size: 17),
            label: Text(
              on
                  ? 'Issued ${formatShortDay(_from!)} – ${formatShortDay(_to!)}'
                  : 'Issued: any date',
            ),
            onPressed: _pickWindow,
          ),
          if (on) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              tooltip: 'Clear dates',
              visualDensity: VisualDensity.compact,
              onPressed: _clearWindow,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
          const Spacer(),
          // Says what is being hidden. A filtered list that looks like the
          // whole list is how someone concludes an invoice has vanished.
          Text(
            on ? '$shown of ${all.length}' : '${all.length} invoice(s)',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _summaryStrip(BuildContext context, BillingSummary s) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0,
    ),
    child: Row(
      children: <Widget>[
        _figure(context, 'Collected', Format.money(s.collected),
            '${s.paidCount} paid', AppColors.green),
        _figure(context, 'Outstanding', Format.money(s.outstanding),
            '${s.sentCount} sent', AppColors.amber),
        _figure(context, 'Overdue', Format.money(s.overdue),
            '${s.overdueCount} late', AppColors.red),
      ],
    ),
  );

  Widget _figure(
    BuildContext context,
    String label,
    String value,
    String caption,
    Color colour,
  ) {
    final ThemeData theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.bodySmall),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(color: colour)),
          Text(caption, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, List<BillingInvoice> items) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return centredMessage(context, _error!, onRetry: _load);
    if (items.isEmpty) {
      final bool windowed = _from != null || _to != null;
      return centredMessage(
        context,
        windowed
            ? 'No invoices were issued in that date range.'
            : _filter == 'overdue'
            ? 'Nothing is overdue. Every school is up to date.'
            : 'No invoices with that status.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.xxl,
      ),
      itemCount: items.length,
      separatorBuilder: (BuildContext _, int index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int i) => _InvoiceCard(
        invoice: items[i],
        busy: _working == items[i].id,
        onRemind: () => _remind(items[i]),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.busy,
    required this.onRemind,
  });

  final BillingInvoice invoice;
  final bool busy;
  final VoidCallback onRemind;

  Color _statusColour(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return AppColors.green;
      case 'overdue':
        return AppColors.red;
      case 'cancelled':
        return AppColors.indigo;
      case 'draft':
        return AppColors.indigo;
      default:
        return AppColors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BillingInvoice v = invoice;
    final bool chaseable = !v.isPaid &&
        v.status.toLowerCase() != 'draft' &&
        v.status.toLowerCase() != 'cancelled';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        border: Border.all(color: theme.dividerColor),
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(v.schoolName, style: theme.textTheme.titleSmall),
                    Text(v.invoiceNo, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              StatusPill(
                titleCase(v.status),
                color: _statusColour(v.status),
                dense: true,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  Format.money(v.totalAmount),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                v.isPaid && v.paidAt != null
                    ? 'Paid ${formatShortDay(v.paidAt!)}'
                    : 'Due ${formatShortDay(v.dueDate)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),

          if (chaseable) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    // Saying when the last one went stops a second person
                    // sending a second reminder an hour after the first.
                    v.remindedAt == null
                        ? 'Not reminded yet'
                        : 'Reminded ${formatShortDay(v.remindedAt!)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                OutlinedButton(
                  onPressed: busy ? null : onRemind,
                  child: Text(busy ? '…' : 'Send reminder'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
