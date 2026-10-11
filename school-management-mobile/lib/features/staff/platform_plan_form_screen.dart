import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_theme.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// Writing a plan, and editing one.
///
/// The name is only asked for when creating. The API takes no name on update,
/// and it is right not to: once schools are subscribed, the plan's name is on
/// their invoices and in their conversations, so renaming it underneath them
/// would make their records disagree with ours. Offering a field that is
/// silently discarded would be worse than not offering it.
class PlatformPlanFormScreen extends StatefulWidget {
  const PlatformPlanFormScreen({super.key, this.existing});

  /// Null when writing a new plan.
  final SubscriptionPlan? existing;

  @override
  State<PlatformPlanFormScreen> createState() => _PlatformPlanFormScreenState();
}

class _PlatformPlanFormScreenState extends State<PlatformPlanFormScreen> {
  final SuperAdminApi _api = SuperAdminApi.instance;
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _monthly;
  late final TextEditingController _yearly;
  late final TextEditingController _maxStudents;
  late final TextEditingController _maxStaff;
  late final TextEditingController _trialDays;

  bool _saving = false;

  /// Yearly is priced at ten months — two months free. Every plan on the
  /// platform uses this ratio and the web form derives one price from the
  /// other, so a plan written here has to follow it too or the two consoles
  /// would produce differently-priced plans from the same numbers.
  static const int _yearlyMultiplier = 10;

  /// Guards the two price fields against each other: each handler writes only
  /// the opposite field, and this stops that write re-triggering the first.
  bool _syncingPrice = false;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final SubscriptionPlan? p = widget.existing;
    _name = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _monthly = TextEditingController(text: _money(p?.priceMonthly));
    _yearly = TextEditingController(text: _money(p?.priceYearly));
    // Empty means no cap, which is not the same as zero — a plan capped at
    // zero students is one nobody can use.
    _maxStudents = TextEditingController(text: p?.maxStudents?.toString() ?? '');
    _maxStaff = TextEditingController(text: p?.maxStaff?.toString() ?? '');
    _trialDays = TextEditingController(text: (p?.trialDays ?? 14).toString());
  }

  static String _money(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.round().toString() : v.toString();
  }

  void _onMonthlyChanged(String raw) {
    if (_syncingPrice) return;
    final double? v = double.tryParse(raw.trim());
    if (v == null || v < 0) return;
    _syncingPrice = true;
    _yearly.text = (v * _yearlyMultiplier).round().toString();
    _syncingPrice = false;
  }

  void _onYearlyChanged(String raw) {
    if (_syncingPrice) return;
    final double? v = double.tryParse(raw.trim());
    if (v == null || v < 0) return;
    _syncingPrice = true;
    // Kept to two decimals rather than rounded to whole rupees: dividing a
    // yearly price by ten rarely lands on one, and silently rounding would
    // change the figure someone just typed.
    final double monthly = v / _yearlyMultiplier;
    _monthly.text = monthly == monthly.roundToDouble()
        ? monthly.round().toString()
        : monthly.toStringAsFixed(2);
    _syncingPrice = false;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _monthly.dispose();
    _yearly.dispose();
    _maxStudents.dispose();
    _maxStaff.dispose();
    _trialDays.dispose();
    super.dispose();
  }

  int? _capOrNull(TextEditingController c) {
    final String t = c.text.trim();
    return t.isEmpty ? null : int.tryParse(t);
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;

    final Map<String, dynamic> body = <String, dynamic>{
      'description':
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      'priceMonthly': double.parse(_monthly.text.trim()),
      'priceYearly': double.parse(_yearly.text.trim()),
      'maxStudents': _capOrNull(_maxStudents),
      'maxStaff': _capOrNull(_maxStaff),
      'trialDays': int.parse(_trialDays.text.trim()),
      if (_isNew) 'name': _name.text.trim(),
    };

    setState(() => _saving = true);
    try {
      if (_isNew) {
        await _api.createPlan(body);
      } else {
        await _api.updatePlan(widget.existing!.id, body);
      }
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isNew
                ? '${_name.text.trim()} added to the price list'
                : '${widget.existing!.name} saved',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String? _requiredNumber(String? v, {bool allowZero = true}) {
    final String t = (v ?? '').trim();
    if (t.isEmpty) return 'Required.';
    final double? n = double.tryParse(t);
    if (n == null) return 'Numbers only.';
    if (n < 0) return 'Cannot be negative.';
    if (!allowZero && n == 0) return 'Must be more than zero.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SubscriptionPlan? existing = widget.existing;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New plan' : 'Edit plan'),
        actions: const <Widget>[SignOutAction()],
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl,
            ),
            children: <Widget>[
              if (_isNew)
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (String? v) =>
                      (v ?? '').trim().isEmpty ? 'The plan needs a name.' : null,
                )
              else ...<Widget>[
                sectionTitle(context, existing!.name),
                Text(
                  'A plan cannot be renamed once it exists — its name is on '
                  'the invoices of every school already on it.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _description,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What it includes',
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              sectionTitle(context, 'Price'),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _monthly,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Monthly'),
                      onChanged: _onMonthlyChanged,
                      validator: (String? v) =>
                          _requiredNumber(v, allowZero: false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _yearly,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Yearly'),
                      onChanged: _onYearlyChanged,
                      validator: (String? v) =>
                          _requiredNumber(v, allowZero: false),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xs),
              Text(
                'Yearly is $_yearlyMultiplier× monthly '
                '(${12 - _yearlyMultiplier} months free) — editing either one '
                'recalculates the other.',
                style: theme.textTheme.bodySmall,
              ),

              const SizedBox(height: AppSpacing.xl),
              sectionTitle(context, 'Limits'),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _maxStudents,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max students',
                        hintText: 'Blank = no cap',
                      ),
                      validator: (String? v) {
                        final String t = (v ?? '').trim();
                        if (t.isEmpty) return null;
                        final int? n = int.tryParse(t);
                        if (n == null) return 'Whole numbers only.';
                        if (n <= 0) {
                          return 'Leave blank for no cap.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _maxStaff,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max staff',
                        hintText: 'Blank = no cap',
                      ),
                      validator: (String? v) {
                        final String t = (v ?? '').trim();
                        if (t.isEmpty) return null;
                        final int? n = int.tryParse(t);
                        if (n == null) return 'Whole numbers only.';
                        if (n <= 0) return 'Leave blank for no cap.';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _trialDays,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Trial days'),
                validator: (String? v) {
                  final String t = (v ?? '').trim();
                  if (t.isEmpty) return 'Required — use 0 for no trial.';
                  final int? n = int.tryParse(t);
                  if (n == null) return 'Whole numbers only.';
                  if (n < 0) return 'Cannot be negative.';
                  return null;
                },
              ),

              if (!_isNew && existing!.subscriberCount > 0) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '${existing.subscriberCount} school(s) are on this plan. '
                  'Changing the price here does not change what they already '
                  'pay — their subscription keeps the price it was sold at.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving
                  ? 'Saving…'
                  : _isNew
                  ? 'Add plan'
                  : 'Save changes',
            ),
          ),
        ),
      ),
    );
  }
}
