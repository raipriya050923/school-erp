import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_http.dart';
import '../../core/student_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/api_section.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/common.dart';
import '../../data/api_models.dart';
import '../dashboard/dashboard_screen.dart' show NotificationBell;
import 'receipt_sheet.dart';

/// Fee invoices for the signed-in student, from `GET /api/student/fees`.
class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key});

  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => StudentStore.instance.loadFees(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fees'),
        actions: const <Widget>[NotificationBell(), SizedBox(width: AppSpacing.lg)],
      ),
      body: SafeArea(
        top: false,
        child: StudentStoreBuilder(
          builder: (BuildContext context, StudentStore store) {
            return ApiSection<List<StudentFee>>(
              state: store.fees,
              onRetry: () => store.loadFees(force: true),
              loadingHeight: 320,
              builder: (BuildContext context, List<StudentFee> fees) => RefreshIndicator(
                onRefresh: () => store.loadFees(force: true),
                child: _FeesBody(fees: fees),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FeesBody extends StatelessWidget {
  const _FeesBody({required this.fees});

  final List<StudentFee> fees;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (fees.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const <Widget>[
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No invoices yet',
            message: 'Fee invoices raised by your school will appear here.',
          ),
        ],
      );
    }

    final double billed = fees.fold(0, (double s, StudentFee f) => s + f.amount);
    final double paid = fees.fold(0, (double s, StudentFee f) => s + f.paid);
    final double due = fees.fold(0, (double s, StudentFee f) => s + f.balance);
    final List<StudentFee> outstanding =
        fees.where((StudentFee f) => !f.isSettled).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Outstanding balance', style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                _money(due),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: due > 0 ? AppColors.red : AppColors.primary600,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              MeterRow(
                label: 'Paid',
                trailing: '${_money(paid)} of ${_money(billed)}',
                value: billed == 0 ? 0 : (paid / billed).clamp(0, 1).toDouble(),
                color: AppColors.primary600,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: StatTile(
                label: 'Invoices',
                value: '${fees.length}',
                icon: Icons.receipt_long_outlined,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatTile(
                label: 'Unpaid',
                value: '${outstanding.length}',
                icon: Icons.pending_actions_outlined,
                color: outstanding.isEmpty ? AppColors.primary600 : AppColors.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader('Invoices'),
        const SizedBox(height: AppSpacing.md),
        for (final StudentFee f in fees) ...<Widget>[
          _InvoiceCard(fee: f),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.fee});

  final StudentFee fee;

  Color get _statusColour {
    switch (fee.status.toLowerCase()) {
      case 'paid':
        return AppColors.primary600;
      case 'overdue':
        return AppColors.red;
      case 'partial':
        return AppColors.amber;
      default:
        return AppColors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
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
                    Text(
                      fee.month ?? fee.invoiceNo ?? 'Invoice',
                      style: theme.textTheme.titleSmall,
                    ),
                    if (fee.invoiceNo != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(fee.invoiceNo!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              StatusPill(
                _titleCase(fee.status),
                color: _statusColour,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(child: _Amount(label: 'Amount', value: fee.amount)),
              Expanded(child: _Amount(label: 'Paid', value: fee.paid)),
              Expanded(
                child: _Amount(
                  label: 'Balance',
                  value: fee.balance,
                  colour: fee.balance > 0 ? AppColors.red : null,
                ),
              ),
            ],
          ),
          if (fee.dueDate != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Icon(
                  Icons.event_outlined,
                  size: 15,
                  color: theme.textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 6),
                Text(
                  'Due ${_formatDate(fee.dueDate!)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
          // Offered the moment anything has been paid, not only once the
          // invoice is settled: a family paying in instalments needs the
          // receipt for the first one straight away, which is the whole
          // reason receipts are per payment rather than per invoice.
          if (fee.paid > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _showReceipts(context, fee),
                icon: const Icon(Icons.receipt_long_outlined, size: 17),
                label: const Text('Receipts'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One payment opens its receipt straight away; several raise a picker.
  /// Making someone choose from a list of one is a tap that teaches nothing.
  Future<void> _showReceipts(BuildContext context, StudentFee fee) async {
    final List<FeePayment> payments;
    try {
      payments = await ApiClient.instance.invoicePayments(fee.id);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    if (!context.mounted) return;

    if (payments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nothing has been confirmed against this invoice yet. A payment you '
            'submitted appears here once the school confirms it.',
          ),
        ),
      );
      return;
    }

    if (payments.length == 1) {
      await ReceiptSheet.show(
        context,
        load: () => ApiClient.instance.paymentReceipt(payments.first.id),
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
                '${fee.invoiceNo ?? 'Invoice'} — ${payments.length} payments',
                style: Theme.of(sheetContext).textTheme.titleSmall,
              ),
            ),
            for (final FeePayment p in payments)
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(p.receiptNo),
                subtitle: Text(
                  <String>[
                    if (p.paidDate != null) _formatDate(p.paidDate!),
                    if ((p.method ?? '').isNotEmpty) p.method!,
                  ].join(' · '),
                ),
                trailing: Text(Format.money(p.amount)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ReceiptSheet.show(
                    context,
                    load: () => ApiClient.instance.paymentReceipt(p.id),
                  );
                },
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.value, this.colour});

  final String label;
  final double value;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(
          _money(value),
          style: theme.textTheme.titleSmall?.copyWith(color: colour),
        ),
      ],
    );
  }
}

/// Amounts arrive as plain decimals; the school's currency is not exposed by the
/// student endpoints, so this matches the web portal's rupee formatting.
String _money(double v) {
  final String whole = v.round().toString();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) out.write(',');
    out.write(whole[i]);
  }
  return '₹$out';
}

String _titleCase(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
