import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/staff_models.dart';
import 'platform_plan_form_screen.dart';
import 'staff_widgets.dart';

/// The price list: every plan a school can be sold, and how many are on each.
///
/// Writing and editing a plan happen here too. Retiring one is kept as its own
/// control rather than a field on the form: taking a plan off sale is a
/// commercial decision, and burying it among the prices would let it happen
/// while someone meant to change a number.
class PlatformPlansScreen extends StatefulWidget {
  const PlatformPlansScreen({super.key});

  @override
  State<PlatformPlansScreen> createState() => _PlatformPlansScreenState();
}

class _PlatformPlansScreenState extends State<PlatformPlansScreen> {
  final SuperAdminApi _api = SuperAdminApi.instance;

  List<SubscriptionPlan>? _items;
  bool _loading = true;
  int? _working;
  String? _error;

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
      final List<SubscriptionPlan> list = await _api.plans();
      if (!mounted) return;
      setState(() {
        _items = list;
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

  Future<void> _toggle(SubscriptionPlan plan) async {
    // Retiring a plan that schools are paying for is the one move worth
    // pausing over: they keep their subscription, but nobody says so unless
    // the dialog does.
    if (plan.isActive && plan.subscriberCount > 0) {
      final bool? go = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text('Retire ${plan.name}?'),
          content: Text(
            '${plan.subscriberCount} school(s) are on this plan. They keep '
            'their subscription and their price — it just stops being offered '
            'to anyone new.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Retire'),
            ),
          ],
        ),
      );
      if (go != true) return;
    }

    setState(() => _working = plan.id);
    try {
      await _api.setPlanActive(planId: plan.id, active: !plan.isActive);
      if (!mounted) return;
      setState(() => _working = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            plan.isActive
                ? '${plan.name} is no longer on sale'
                : '${plan.name} is back on sale',
          ),
        ),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _working = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Opens the form, and reloads if it saved.
  Future<void> _openForm({SubscriptionPlan? existing}) async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext _) =>
            PlatformPlanFormScreen(existing: existing),
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final List<SubscriptionPlan> items = _items ?? const <SubscriptionPlan>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription plans'),
        actions: <Widget>[
          IconButton(
            onPressed: _openForm,
            tooltip: 'New plan',
            icon: const Icon(Icons.add),
          ),
          const SignOutAction(),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? centredMessage(context, _error!, onRetry: _load)
              : items.isEmpty
              ? centredMessage(context, 'No plans have been set up yet.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (BuildContext _, int index) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (BuildContext context, int i) =>
                      _PlanCard(
                        plan: items[i],
                        busy: _working == items[i].id,
                        onToggle: () => _toggle(items[i]),
                        onEdit: () => _openForm(existing: items[i]),
                      ),
                ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
  });

  final SubscriptionPlan plan;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

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
                    Text(plan.name, style: theme.textTheme.titleSmall),
                    Text(
                      '${plan.subscriberCount} school(s) · ${plan.trialDays}-day trial',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusPill(
                plan.isActive ? 'On sale' : 'Retired',
                color: plan.isActive ? AppColors.green : AppColors.indigo,
                dense: true,
              ),
            ],
          ),

          if ((plan.description ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(plan.description!, style: theme.textTheme.bodyMedium),
          ],

          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              _figure(context, 'Monthly', Format.money(plan.priceMonthly)),
              _figure(context, 'Yearly', Format.money(plan.priceYearly)),
              // "No cap" rather than a dash: an unlimited plan and one whose
              // limit nobody recorded should not look the same.
              _figure(
                context,
                'Students',
                plan.maxStudents == null ? 'No cap' : '${plan.maxStudents}',
              ),
              _figure(
                context,
                'Staff',
                plan.maxStaff == null ? 'No cap' : '${plan.maxStaff}',
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onEdit,
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onToggle,
                  child: Text(
                    busy
                        ? '…'
                        : plan.isActive
                        ? 'Take off sale'
                        : 'Put back on sale',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _figure(BuildContext context, String label, String value) {
    final ThemeData theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.bodySmall),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
