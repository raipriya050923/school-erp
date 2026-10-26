import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// The shape of the school day: how many periods, how long, and where the
/// breaks fall.
///
/// A period is entered as a start time plus a duration, which is how a school
/// day is actually decided; the end time follows, so the two can never
/// disagree. Position in the day follows from the start time rather than being
/// typed, so periods cannot be numbered out of order.
class AdminPeriodsScreen extends StatefulWidget {
  const AdminPeriodsScreen({super.key});

  @override
  State<AdminPeriodsScreen> createState() => _AdminPeriodsScreenState();
}

class _AdminPeriodsScreenState extends State<AdminPeriodsScreen> {
  final AdminApi _api = AdminApi.instance;

  List<AdminPeriod>? _items;
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
      final List<AdminPeriod> list = await _api.periods();
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

  Future<void> _edit([AdminPeriod? existing]) async {
    final _PeriodDraft? d = await showModalBottomSheet<_PeriodDraft>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: _PeriodSheet(existing: existing, after: _lastEnd()),
      ),
    );
    if (d == null || !mounted) return;

    if (existing == null) {
      await runAndReload(
        context,
        () => _api.createPeriod(
          name: d.name,
          startTime: d.startTime,
          durationMinutes: d.minutes,
          isBreak: d.isBreak,
        ),
        'Period added',
        _load,
      );
    } else {
      await runAndReload(
        context,
        () => _api.updatePeriod(
          existing.id,
          name: d.name,
          startTime: d.startTime,
          durationMinutes: d.minutes,
          isBreak: d.isBreak,
        ),
        'Period saved',
        _load,
      );
    }
  }

  /// When the last period ends — where a new one naturally starts.
  String? _lastEnd() {
    final List<AdminPeriod> items = _items ?? const <AdminPeriod>[];
    if (items.isEmpty) return null;
    return items.last.endTime;
  }

  Future<void> _actions(AdminPeriod p) async {
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            ListTile(
              title:
                  Text(p.name, style: Theme.of(sheet).textTheme.titleMedium),
              subtitle: Text(_periodLine(p)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit period'),
              onTap: () => Navigator.of(sheet).pop('edit'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(sheet).colorScheme.error),
              title: Text('Delete period',
                  style: TextStyle(color: Theme.of(sheet).colorScheme.error)),
              onTap: () => Navigator.of(sheet).pop('delete'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'edit') {
      await _edit(p);
      return;
    }
    final bool ok = await confirmAction(
      context,
      title: 'Delete ${p.name}?',
      message: p.scheduledCount > 0
          ? '${p.scheduledCount} scheduled periods sit in this slot across the '
              'school. Deleting it strands them.'
          : 'This cannot be undone.',
    );
    if (!ok || !mounted) return;
    await runAndReload(
      context,
      () => _api.deletePeriod(p.id),
      'Period deleted',
      _load,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<AdminPeriod> rows = _items ?? const <AdminPeriod>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Periods')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('Period'),
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
              icon: Icons.schedule_outlined,
              title: 'No periods yet',
              message: 'Add the first period and the day builds from there.',
            ),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'Periods are ordered by start time. Breaks hold no class.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              for (final AdminPeriod p in rows)
                StaffRow(
                  title: p.name,
                  subtitle: _periodLine(p),
                  trailing: p.timeLabel,
                  status: p.isBreak ? 'break' : null,
                  onTap: () => _actions(p),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _periodLine(AdminPeriod p) => <String>[
      '${p.durationMinutes} min',
      if (!p.isBreak && p.scheduledCount > 0)
        '${p.scheduledCount} scheduled',
    ].join(' · ');

class _PeriodDraft {
  const _PeriodDraft(this.name, this.startTime, this.minutes, this.isBreak);

  final String name;
  final String startTime;
  final int minutes;
  final bool isBreak;
}

class _PeriodSheet extends StatefulWidget {
  const _PeriodSheet({this.existing, this.after});

  final AdminPeriod? existing;

  /// When the last period ends; a new one starts there by default, because
  /// periods almost always run back to back.
  final String? after;

  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _minutes = TextEditingController(
    text: '${widget.existing?.durationMinutes ?? 45}',
  );
  late TimeOfDay _start = _parse(
    widget.existing?.startTime ?? widget.after ?? '10:00',
  );
  late bool _isBreak = widget.existing?.isBreak ?? false;
  String? _error;

  static TimeOfDay _parse(String hhmm) {
    final List<String> parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 10,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
  }

  /// The API wants "HH:mm" on a 24-hour clock, whatever the phone's locale
  /// shows the picker in.
  String get _startText =>
      '${_start.hour.toString().padLeft(2, '0')}:'
      '${_start.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _name.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final TimeOfDay? picked =
        await showTimePicker(context: context, initialTime: _start);
    if (picked != null) setState(() => _start = picked);
  }

  void _save() {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the period a name, such as P1 or Break.');
      return;
    }
    final int? minutes = int.tryParse(_minutes.text.trim());
    if (minutes == null || minutes <= 0) {
      setState(() => _error = 'How many minutes does it run for?');
      return;
    }
    Navigator.of(context)
        .pop(_PeriodDraft(name, _startText, minutes, _isBreak));
  }

  @override
  Widget build(BuildContext context) => SheetFrame(
        title: widget.existing == null ? 'New period' : 'Edit period',
        onSave: _save,
        children: <Widget>[
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'P1',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickStart,
                  icon: const Icon(Icons.schedule_outlined, size: 18),
                  label: Text('Starts $_startText'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Runs for',
                    suffixText: 'min',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            value: _isBreak,
            onChanged: (bool v) => setState(() => _isBreak = v),
            title: const Text('This is a break'),
            subtitle: const Text('No class can be scheduled in it.'),
            contentPadding: EdgeInsets.zero,
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      );
}
