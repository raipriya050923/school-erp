import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// The staff register for one day.
///
/// Marked first thing in the morning, which is the strongest case for having
/// it on a phone at all — whoever walks the staff room can do it there instead
/// of carrying a sheet back to a desk and typing it up twice.
///
/// Everyone is present until said otherwise, and the day's register is posted
/// whole. A remark can be attached to any row and is what payroll reads later,
/// so it is offered on the statuses that need explaining rather than on all.
class AdminStaffAttendanceScreen extends StatefulWidget {
  const AdminStaffAttendanceScreen({super.key});

  @override
  State<AdminStaffAttendanceScreen> createState() =>
      _AdminStaffAttendanceScreenState();
}

class _AdminStaffAttendanceScreenState
    extends State<AdminStaffAttendanceScreen> {
  final AdminApi _api = AdminApi.instance;

  DateTime _date = DateTime.now();
  List<StaffAttendanceRow>? _rows;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
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
      final List<StaffAttendanceRow> rows = await _api.staffAttendance(_date);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
        _dirty = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _save() async {
    final List<StaffAttendanceRow>? rows = _rows;
    if (rows == null) return;

    setState(() => _saving = true);
    try {
      await _api.saveStaffAttendance(date: _date, rows: rows);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Staff register saved for ${_formatDate(_date)}')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _date = picked);
    await _load();
  }

  void _setAll(String status) {
    final List<StaffAttendanceRow>? rows = _rows;
    if (rows == null) return;
    setState(() {
      for (final StaffAttendanceRow r in rows) {
        r.status = status;
      }
      _dirty = true;
    });
  }

  Future<void> _editRemarks(StaffAttendanceRow row) async {
    final TextEditingController controller =
        TextEditingController(text: row.remarks ?? '');
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(row.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Remarks',
            hintText: 'Why, in a few words',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    setState(() {
      row.remarks = value.isEmpty ? null : value;
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<StaffAttendanceRow> rows = _rows ?? const <StaffAttendanceRow>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff attendance'),
        actions: <Widget>[
          IconButton(
            onPressed: _pickDate,
            tooltip: 'Change date',
            icon: const Icon(Icons.event_outlined),
          ),
          const SignOutAction(),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _formatDate(_date),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (rows.isNotEmpty) ...<Widget>[
                    Text('Mark all', style: Theme.of(context).textTheme.bodySmall),
                    TextButton(
                      onPressed: () => _setAll('present'),
                      child: const Text('Present'),
                    ),
                  ],
                ],
              ),
            ),
            if (rows.isNotEmpty) _tallies(context, rows),
            Expanded(child: _body(context, rows)),
          ],
        ),
      ),
      bottomNavigationBar: rows.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: FilledButton(
                  onPressed: _saving || !_dirty ? null : _save,
                  child: Text(
                    _saving
                        ? 'Saving…'
                        : _dirty
                        ? 'Save register'
                        : 'Saved',
                  ),
                ),
              ),
            ),
    );
  }

  Widget _tallies(BuildContext context, List<StaffAttendanceRow> rows) {
    int count(String status) =>
        rows.where((StaffAttendanceRow r) => r.status == status).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm,
      ),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: 4,
        children: <Widget>[
          _tally('Present', count('present'), AppColors.green),
          _tally('Absent', count('absent'), AppColors.red),
          _tally('Late', count('late'), AppColors.amber),
          _tally('Half day', count('half_day'), AppColors.blue),
          _tally('On leave', count('on_leave'), AppColors.indigo),
        ],
      ),
    );
  }

  Widget _tally(String label, int count, Color colour) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text('$label $count'),
    ],
  );

  Widget _body(BuildContext context, List<StaffAttendanceRow> rows) {
    final ThemeData theme = Theme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            'No staff on record yet.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl,
      ),
      itemCount: rows.length,
      separatorBuilder: (BuildContext _, int index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (BuildContext context, int i) {
        final StaffAttendanceRow r = rows[i];
        // A remark only means something next to an exception; on a present
        // row it is a box nobody will ever read.
        final bool explainable = r.status != 'present';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AttendanceStatusRow(
              title: r.name,
              subtitle: (r.employeeCode ?? '').isEmpty ? null : r.employeeCode,
              status: r.status,
              states: AttendanceStatusRow.staffStates,
              onChanged: (String status) => setState(() {
                r.status = status;
                _dirty = true;
              }),
            ),
            if (explainable)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: InkWell(
                  onTap: () => _editRemarks(r),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      (r.remarks ?? '').isEmpty ? 'Add a remark' : '“${r.remarks}”',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: (r.remarks ?? '').isEmpty
                            ? theme.colorScheme.primary
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
