import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/staff_models.dart';

/// Records money received against an invoice.
///
/// The same fields as the web's Record Payment dialog, in the same order, so
/// an office that does this on a desk and on a phone is doing one job rather
/// than two. The amount defaults to the whole balance because that is what is
/// usually handed over, and is editable because part payments are normal.
///
/// The invoice stays open until the balance reaches zero; the API decides
/// that, not this sheet.
class RecordPaymentSheet extends StatefulWidget {
  const RecordPaymentSheet({super.key, required this.invoice});

  final AdminInvoice invoice;

  /// Returns true when a payment was recorded, so the caller can reload.
  static Future<bool> show(BuildContext context, AdminInvoice inv) async {
    final bool? done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: RecordPaymentSheet(invoice: inv),
      ),
    );
    return done ?? false;
  }

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

/// What the API accepts, in the order the web lists them.
const List<String> _methods = <String>[
  'cash',
  'esewa',
  'khalti',
  'bank_transfer',
  'cheque',
  'card',
];

String _methodLabel(String m) => switch (m) {
      'bank_transfer' => 'Bank transfer',
      'esewa' => 'eSewa',
      'khalti' => 'Khalti',
      _ => '${m[0].toUpperCase()}${m.substring(1)}',
    };

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: _asText(widget.invoice.balance),
  );
  final TextEditingController _reference = TextEditingController();
  String _method = 'cash';
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  static String _asText(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      // Not beyond today: money cannot have been received tomorrow, and a
      // mistyped future date quietly breaks every monthly total it lands in.
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final double? amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter the amount received.');
      return;
    }
    if (amount > widget.invoice.balance) {
      setState(() => _error =
          'That is more than the ${Format.money(widget.invoice.balance)} '
          'outstanding on this invoice.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AdminApi.instance.recordPayment(
        widget.invoice.id,
        amount: amount,
        method: _method,
        reference:
            _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        paymentDate: _date,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AdminInvoice inv = widget.invoice;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Record payment${inv.invoiceNo == null ? '' : ' — ${inv.invoiceNo}'}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            _line(theme, 'Student', inv.studentName ?? '—'),
            _line(
              theme,
              'Balance',
              Format.money(inv.balance),
              emphasis: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _amount,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: Format.currencySymbol,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(_formatDate(_date)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Method'),
              items: <DropdownMenuItem<String>>[
                for (final String m in _methods)
                  DropdownMenuItem<String>(
                    value: m,
                    child: Text(_methodLabel(m)),
                  ),
              ],
              onChanged: (String? v) => setState(() => _method = v ?? 'cash'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _reference,
              decoration: const InputDecoration(
                labelText: 'Reference (optional)',
                helperText: 'Cheque number, transaction id, whatever you have.',
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Record'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(ThemeData theme, String label, String value,
          {bool emphasis = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
            Text(
              value,
              style: emphasis
                  ? theme.textTheme.titleSmall
                      ?.copyWith(color: theme.colorScheme.error)
                  : theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
}

const List<String> _monthNames = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) =>
    '${d.day} ${_monthNames[d.month - 1]} ${d.year}';
