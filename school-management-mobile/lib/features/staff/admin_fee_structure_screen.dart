import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// What each class is charged, head by head.
///
/// The web portal draws this as a grid — classes down, heads across. A grid of
/// that shape is unreadable at phone width, so here it is one level deeper: the
/// classes are the list, and pressing one opens its own prices. Each class
/// carries the monthly total the grid's footer shows, which is the number an
/// admin actually checks.
class AdminFeeStructureScreen extends StatefulWidget {
  const AdminFeeStructureScreen({super.key});

  @override
  State<AdminFeeStructureScreen> createState() =>
      _AdminFeeStructureScreenState();
}

class _AdminFeeStructureScreenState extends State<AdminFeeStructureScreen> {
  final AdminApi _api = AdminApi.instance;

  FeeStructureGrid? _grid;
  bool _loading = true;
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
      final FeeStructureGrid g = await _api.feeStructure();
      if (!mounted) return;
      setState(() {
        _grid = g;
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

  Future<void> _priceClass(int classId, String className) async {
    final FeeStructureGrid g = _grid!;
    final Map<int, double>? saved = await Navigator.of(context).push(
      MaterialPageRoute<Map<int, double>>(
        builder: (BuildContext _) => _ClassPricingScreen(
          className: className,
          heads: g.heads.where((FeeHead h) => h.isActive).toList(),
          current: <int, double?>{
            for (final FeeHead h in g.heads) h.id: g.amountFor(classId, h.id),
          },
        ),
      ),
    );
    if (saved == null || !mounted) return;

    await runAndReload(
      context,
      () => _api.saveFeeStructure(
        academicYearId: g.academicYearId,
        cells: <Map<String, dynamic>>[
          for (final MapEntry<int, double> e in saved.entries)
            <String, dynamic>{
              'classId': classId,
              'headId': e.key,
              'amount': e.value,
            },
        ],
      ),
      '$className priced',
      _load,
    );
  }

  Future<void> _openHeads() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => const AdminFeeHeadsScreen(),
      ),
    );
    // Heads may have been added or retired while we were away, and both change
    // what this screen can price.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final FeeStructureGrid? g = _grid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee structure'),
        actions: <Widget>[
          IconButton(
            onPressed: _openHeads,
            icon: const Icon(Icons.sell_outlined),
            tooltip: 'Fee heads',
          ),
          const SignOutAction(),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: MasterBody(
            loading: _loading,
            error: _error,
            onRetry: _load,
            isEmpty: g == null || g.classes.isEmpty,
            empty: const EmptyState(
              icon: Icons.payments_outlined,
              title: 'Nothing to price yet',
              message: 'Add classes and fee heads first.',
            ),
            children: <Widget>[
              if (g != null) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    'Pricing ${g.academicYearName ?? 'the current year'}. '
                    'Press a class to set what it is charged.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                for (final MapEntry<int, String> c in g.classes)
                  StaffRow(
                    title: c.value,
                    subtitle: _pricedLine(g, c.key),
                    trailing: Format.money(g.monthlyTotals[c.value] ?? 0),
                    onTap: () => _priceClass(c.key, c.value),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    'The amount on the right is one monthly invoice: the '
                    'monthly heads only.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// "3 of 4 heads priced" — what is still blank is the thing worth seeing from
  /// the list, since an unpriced head simply is not billed.
  String _pricedLine(FeeStructureGrid g, int classId) {
    final List<FeeHead> priceable = g.heads
        .where((FeeHead h) => h.isActive && !h.isDistancePriced)
        .toList();
    final int priced = priceable
        .where((FeeHead h) => (g.amountFor(classId, h.id) ?? 0) > 0)
        .length;
    return '$priced of ${priceable.length} heads priced';
  }
}

/* ------------------------------------------------- one class's prices -- */

/// The amounts for one class. Returns head id → amount, or null if cancelled.
class _ClassPricingScreen extends StatefulWidget {
  const _ClassPricingScreen({
    required this.className,
    required this.heads,
    required this.current,
  });

  final String className;
  final List<FeeHead> heads;
  final Map<int, double?> current;

  @override
  State<_ClassPricingScreen> createState() => _ClassPricingScreenState();
}

class _ClassPricingScreenState extends State<_ClassPricingScreen> {
  late final Map<int, TextEditingController> _fields =
      <int, TextEditingController>{
        for (final FeeHead h in widget.heads)
          if (!h.isDistancePriced)
            h.id: TextEditingController(text: _asText(widget.current[h.id])),
      };
  String? _error;

  static String _asText(double? v) {
    if (v == null || v == 0) return '';
    // Whole rupees read better than 10500.0 in a field someone is editing.
    return v == v.roundToDouble() ? v.round().toString() : v.toString();
  }

  @override
  void dispose() {
    for (final TextEditingController c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final Map<int, double> out = <int, double>{};
    for (final MapEntry<int, TextEditingController> e in _fields.entries) {
      final String raw = e.value.text.trim();
      if (raw.isEmpty) {
        // Blank means "not charged": sent as zero, which is how the API clears
        // a price. Omitting it would leave the old amount in place.
        out[e.key] = 0;
        continue;
      }
      final double? v = double.tryParse(raw);
      if (v == null || v < 0) {
        setState(() => _error = 'Amounts must be numbers, and not negative.');
        return;
      }
      out[e.key] = v;
    }
    Navigator.of(context).pop(out);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<FeeHead> distance = widget.heads
        .where((FeeHead h) => h.isDistancePriced)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.className)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            Text(
              'Leave a head blank and this class is not charged for it.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final FeeHead h in widget.heads)
              if (!h.isDistancePriced)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: TextField(
                    controller: _fields[h.id],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: h.name,
                      helperText: _frequencyLabel(h.frequency),
                      prefixText: Format.currencySymbol,
                    ),
                  ),
                ),
            if (distance.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              for (final FeeHead h in distance)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    // Shown rather than hidden: an admin looking for Transport
                    // Fee here should be told where it lives, not left to
                    // wonder why it is missing.
                    '${h.name} is priced per student by distance, on the '
                    'Transport fee screen.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: _save, child: const Text('Save prices')),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------- the fee heads -- */

/// The charges a school levies, before any class is priced for them.
class AdminFeeHeadsScreen extends StatefulWidget {
  const AdminFeeHeadsScreen({super.key});

  @override
  State<AdminFeeHeadsScreen> createState() => _AdminFeeHeadsScreenState();
}

class _AdminFeeHeadsScreenState extends State<AdminFeeHeadsScreen> {
  final AdminApi _api = AdminApi.instance;

  List<FeeHead>? _items;
  bool _loading = true;
  String? _error;
  bool _showRetired = false;

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
      final List<FeeHead> list = await _api.feeHeads();
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

  Future<void> _edit([FeeHead? existing]) async {
    final _HeadDraft? d = await showModalBottomSheet<_HeadDraft>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: _HeadSheet(existing: existing),
      ),
    );
    if (d == null || !mounted) return;

    if (existing == null) {
      await runAndReload(
        context,
        () => _api.createFeeHead(
          name: d.name,
          description: d.description,
          frequency: d.frequency,
          pricingMode: d.pricingMode,
          isRefundable: d.isRefundable,
        ),
        'Fee head added',
        _load,
      );
    } else {
      await runAndReload(
        context,
        () => _api.updateFeeHead(
          existing.id,
          name: d.name,
          description: d.description,
          frequency: d.frequency,
          pricingMode: d.pricingMode,
          isRefundable: d.isRefundable,
        ),
        'Fee head saved',
        _load,
      );
    }
  }

  Future<void> _actions(FeeHead h) async {
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            ListTile(
              title: Text(h.name, style: Theme.of(sheet).textTheme.titleMedium),
              subtitle: Text(_headLine(h)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit head'),
              onTap: () => Navigator.of(sheet).pop('edit'),
            ),
            ListTile(
              leading: Icon(
                h.isActive
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              title: Text(h.isActive ? 'Retire head' : 'Bring back'),
              onTap: () => Navigator.of(sheet).pop('active'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'edit') {
      await _edit(h);
    } else {
      await runAndReload(
        context,
        () => _api.setFeeHeadActive(h.id, !h.isActive),
        h.isActive ? 'Fee head retired' : 'Fee head brought back',
        _load,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<FeeHead> all = _items ?? const <FeeHead>[];
    final List<FeeHead> rows = _showRetired
        ? all
        : all.where((FeeHead h) => h.isActive).toList();
    final int retired = all.where((FeeHead h) => !h.isActive).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Fee heads')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('Head'),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: MasterBody(
            loading: _loading,
            error: _error,
            onRetry: _load,
            isEmpty: rows.isEmpty,
            empty: const EmptyState(
              icon: Icons.sell_outlined,
              title: 'No fee heads yet',
              message: 'Add what this school charges for.',
            ),
            children: <Widget>[
              for (final FeeHead h in rows)
                StaffRow(
                  title: h.name,
                  subtitle: _headLine(h),
                  trailing: h.inUse > 0 ? '${h.inUse} classes' : null,
                  status: h.isActive ? null : 'retired',
                  onTap: () => _actions(h),
                ),
              if (retired > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _showRetired = !_showRetired),
                    icon: Icon(
                      _showRetired
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    label: Text(
                      _showRetired ? 'Hide retired' : 'Show $retired retired',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _headLine(FeeHead h) => <String>[
  _frequencyLabel(h.frequency),
  if (h.isDistancePriced) 'by distance',
  if (h.isRefundable) 'refundable',
].where((String s) => s.isNotEmpty).join(' · ');

String _frequencyLabel(String f) {
  switch (f) {
    case 'one_time':
      return 'One time';
    case 'monthly':
      return 'Monthly';
    case 'quarterly':
      return 'Quarterly';
    case 'half_yearly':
      return 'Half yearly';
    case 'yearly':
      return 'Yearly';
    default:
      return f;
  }
}

class _HeadDraft {
  const _HeadDraft(
    this.name,
    this.description,
    this.frequency,
    this.pricingMode,
    this.isRefundable,
  );

  final String name;
  final String? description;
  final String frequency;
  final String pricingMode;
  final bool isRefundable;
}

class _HeadSheet extends StatefulWidget {
  const _HeadSheet({this.existing});

  final FeeHead? existing;

  @override
  State<_HeadSheet> createState() => _HeadSheetState();
}

class _HeadSheetState extends State<_HeadSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _desc = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late String _frequency = widget.existing?.frequency ?? 'monthly';
  late String _pricing = widget.existing?.pricingMode ?? 'class';
  late bool _refundable = widget.existing?.isRefundable ?? false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _save() {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the head a name.');
      return;
    }
    Navigator.of(context).pop(
      _HeadDraft(
        name,
        _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        _frequency,
        _pricing,
        _refundable,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SheetFrame(
    title: widget.existing == null ? 'New fee head' : 'Edit fee head',
    onSave: _save,
    children: <Widget>[
      TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'Tuition Fee',
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      DropdownButtonFormField<String>(
        initialValue: _frequency,
        decoration: const InputDecoration(labelText: 'Charged'),
        items: const <DropdownMenuItem<String>>[
          DropdownMenuItem<String>(value: 'one_time', child: Text('One time')),
          DropdownMenuItem<String>(value: 'monthly', child: Text('Monthly')),
          DropdownMenuItem<String>(
            value: 'quarterly',
            child: Text('Quarterly'),
          ),
          DropdownMenuItem<String>(
            value: 'half_yearly',
            child: Text('Half yearly'),
          ),
          DropdownMenuItem<String>(value: 'yearly', child: Text('Yearly')),
        ],
        onChanged: (String? v) => setState(() => _frequency = v ?? 'monthly'),
      ),
      const SizedBox(height: AppSpacing.md),
      DropdownButtonFormField<String>(
        initialValue: _pricing,
        decoration: const InputDecoration(
          labelText: 'Priced',
          helperText: 'By distance makes it a per-student transport charge.',
        ),
        items: const <DropdownMenuItem<String>>[
          DropdownMenuItem<String>(value: 'class', child: Text('Per class')),
          DropdownMenuItem<String>(
            value: 'distance',
            child: Text('By distance'),
          ),
        ],
        onChanged: (String? v) => setState(() => _pricing = v ?? 'class'),
      ),
      const SizedBox(height: AppSpacing.sm),
      SwitchListTile(
        value: _refundable,
        onChanged: (bool v) => setState(() => _refundable = v),
        title: const Text('Refundable'),
        contentPadding: EdgeInsets.zero,
      ),
      if (_error != null) ...<Widget>[
        const SizedBox(height: AppSpacing.md),
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    ],
  );
}
