import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/api_models.dart';
import 'receipt_pdf.dart';

/// Shows the receipt for one payment.
///
/// The same document the web console and the printed slip carry, down to the
/// receipt number — if the office and the family end up quoting different
/// numbers for one payment, the receipt has failed at its only job.
///
/// Download hands the same document to the system sheet as a PDF, which is
/// where a phone keeps "save to Downloads", "send" and "print" — the three
/// things the web's print dialog offers, under one button. A screenshot was
/// what families resorted to before; a receipt forwarded to an employer or an
/// auditor needs to be a document, not a picture of a phone.
class ReceiptSheet extends StatelessWidget {
  const ReceiptSheet({super.key, required this.receipt});

  final FeeReceipt receipt;

  /// Loads the receipt, then shows it. The spinner and the failure path live
  /// here so every caller does not repeat the same three states.
  static Future<void> show(
    BuildContext context, {
    required Future<FeeReceipt> Function() load,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    FeeReceipt? loaded;
    String? error;
    try {
      loaded = await load();
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not load the receipt.';
    }

    if (!context.mounted) return;
    Navigator.of(context).pop(); // the spinner

    final FeeReceipt? result = loaded;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Could not load the receipt.')),
      );
      return;
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceiptSheet(receipt: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final FeeReceipt r = receipt;

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (BuildContext context, ScrollController controller) => Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          children: <Widget>[
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xxl,
                ),
                children: <Widget>[
                  _header(context, r),
                  const SizedBox(height: AppSpacing.lg),
                  _meta(context, r),
                  if (r.lines.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    _particulars(context, r),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _money(context, r),
                  const SizedBox(height: AppSpacing.md),
                  _words(context, r),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: <Widget>[
                      Expanded(child: _field(context, 'Paid by', r.methodLabel)),
                      Expanded(child: _field(context, 'Reference', r.reference ?? '—')),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Balance shown as at the time of viewing.\n'
                    'This is a computer-generated receipt.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _download(context, r),
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: const Text('Download'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, FeeReceipt r) {
    final ThemeData theme = Theme.of(context);
    final String contact = <String>[
      if ((r.schoolPhone ?? '').isNotEmpty) r.schoolPhone!,
      if ((r.schoolEmail ?? '').isNotEmpty) r.schoolEmail!,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(r.schoolName, style: theme.textTheme.titleMedium),
                  if ((r.schoolAddress ?? '').isNotEmpty)
                    Text(r.schoolAddress!, style: theme.textTheme.bodySmall),
                  if (contact.isNotEmpty)
                    Text(contact, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  'FEE RECEIPT',
                  style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2),
                ),
                Text(
                  r.receiptNo,
                  style: theme.textTheme.titleSmall?.copyWith(fontFamily: 'monospace'),
                ),
                Text(_formatDate(r.paidDate ?? r.issuedAt), style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Container(height: 2, color: theme.textTheme.titleMedium?.color),
      ],
    );
  }

  Widget _meta(BuildContext context, FeeReceipt r) => Column(
    children: <Widget>[
      Row(
        children: <Widget>[
          Expanded(child: _field(context, 'Received from', r.studentName)),
          Expanded(child: _field(context, 'Admission no', r.admissionNo ?? '—')),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: <Widget>[
          Expanded(child: _field(context, 'Class', r.classLabel ?? '—')),
          Expanded(
            child: _field(
              context,
              'Invoice',
              <String>[
                if ((r.invoiceNo ?? '').isNotEmpty) r.invoiceNo!,
                if ((r.month ?? '').isNotEmpty) r.month!,
              ].join(' · '),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _particulars(BuildContext context, FeeReceipt r) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('PARTICULARS', style: theme.textTheme.labelSmall),
        const SizedBox(height: AppSpacing.sm),
        for (final ReceiptLine l in r.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(l.description)),
                Text(Format.money(l.amount)),
              ],
            ),
          ),
        const Divider(height: AppSpacing.xl),
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Invoice total', style: theme.textTheme.titleSmall),
            ),
            Text(Format.money(r.invoiceTotal), style: theme.textTheme.titleSmall),
          ],
        ),
      ],
    );
  }

  Widget _money(BuildContext context, FeeReceipt r) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border.all(color: theme.dividerColor),
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('Amount received', style: theme.textTheme.titleMedium)),
              Text(Format.money(r.amountPaid), style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _row(context, 'Paid to date', Format.money(r.paidToDate)),
          const SizedBox(height: AppSpacing.xs),
          _row(
            context,
            'Balance outstanding',
            Format.money(r.balanceAfter),
            bold: true,
            colour: r.balanceAfter > 0 ? theme.colorScheme.error : null,
          ),
        ],
      ),
    );
  }

  /// Words beside figures: what stops a 1 becoming a 7 once a screenshot of
  /// this has been forwarded on.
  Widget _words(BuildContext context, FeeReceipt r) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md, vertical: AppSpacing.sm + 1,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border.all(color: theme.dividerColor),
        borderRadius: AppRadius.cardRadius,
      ),
      child: Text(
        r.amountInWords,
        style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }

  Widget _field(BuildContext context, String label, String value) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    Color? colour,
  }) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = (bold ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)
        ?.copyWith(color: colour);
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}

/// Builds the PDF and hands it to the system sheet.
///
/// Building can take a moment on an older phone — the fonts are fetched and
/// cached on first use — so the button reports rather than appearing to do
/// nothing, and a failure says so instead of silently closing.
Future<void> _download(BuildContext context, FeeReceipt r) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final Color errorColour = Theme.of(context).colorScheme.error;
  try {
    await ReceiptPdf.share(r);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Could not prepare the receipt. $e'),
        backgroundColor: errorColour,
      ),
    );
  }
}

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
