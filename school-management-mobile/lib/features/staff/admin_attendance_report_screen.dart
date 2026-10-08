import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// One student's attendance over a date range.
///
/// The question this answers is always about a particular child — a parent has
/// rung, or a pattern has been noticed — so it opens on a search rather than a
/// list of everyone. A roster of a thousand names is not a starting point.
class AdminAttendanceReportScreen extends StatefulWidget {
  const AdminAttendanceReportScreen({super.key});

  @override
  State<AdminAttendanceReportScreen> createState() =>
      _AdminAttendanceReportScreenState();
}

class _AdminAttendanceReportScreenState
    extends State<AdminAttendanceReportScreen> {
  final AdminApi _api = AdminApi.instance;
  final TextEditingController _search = TextEditingController();

  List<AdminStudent>? _students;
  AdminStudent? _student;
  late DateTime _from;
  late DateTime _to;

  AttendanceReport? _report;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    // The current month is what someone asking about attendance almost always
    // means, and it is one tap to widen.
    _from = DateTime(now.year, now.month, 1);
    _to = now;
    _loadStudents();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    try {
      final List<AdminStudent> list = await _api.students();
      if (!mounted) return;
      setState(() => _students = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _run() async {
    final AdminStudent? s = _student;
    if (s == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final AttendanceReport r = await _api.attendanceReport(
        studentId: s.id,
        from: _from,
        to: _to,
      );
      if (!mounted) return;
      setState(() {
        _report = r;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _report = null;
        _error = e.message;
      });
    }
  }

  Future<void> _pickRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _from, end: _to),
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _from = picked.start;
      _to = picked.end;
    });
    await _run();
  }

  List<AdminStudent> get _matches {
    final String q = _search.text.trim().toLowerCase();
    final List<AdminStudent> all = _students ?? const <AdminStudent>[];
    if (q.isEmpty) return const <AdminStudent>[];
    return all
        .where((AdminStudent s) =>
            s.name.toLowerCase().contains(q) ||
            s.admissionNo.toLowerCase().contains(q) ||
            s.classLabel.toLowerCase().contains(q))
        .take(12)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance report'),
        actions: const <Widget>[SignOutAction()],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl,
          ),
          children: <Widget>[
            TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: 'Student',
                hintText: 'Name, admission no or class',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _student == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _student = null;
                          _report = null;
                          _search.clear();
                        }),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),

            // The matches only while choosing: once a student is picked the
            // list is noise, and the report below is what is being read.
            if (_student == null)
              for (final AdminStudent s in _matches)
                ListTile(
                  dense: true,
                  title: Text(s.name),
                  subtitle: Text(
                    <String>[
                      if (s.admissionNo.isNotEmpty) s.admissionNo,
                      s.classLabel,
                    ].join(' · '),
                  ),
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _student = s;
                      _search.text = s.name;
                    });
                    _run();
                  },
                ),

            if (_student != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${_formatDate(_from)} → ${_formatDate(_to)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range_outlined, size: 17),
                    label: const Text('Change'),
                  ),
                ],
              ),
            ],

            if (_loading) ...<Widget>[
              const SizedBox(height: AppSpacing.xxl),
              const Center(child: CircularProgressIndicator()),
            ],

            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              Text(_error!, style: theme.textTheme.bodyMedium),
            ],

            if (_report != null && !_loading) ..._reportBody(context, _report!),
          ],
        ),
      ),
    );
  }

  List<Widget> _reportBody(BuildContext context, AttendanceReport r) {
    final ThemeData theme = Theme.of(context);
    return <Widget>[
      const SizedBox(height: AppSpacing.lg),
      Row(
        children: <Widget>[
          _tile(context, 'Present', '${r.present}', AppColors.green),
          _tile(context, 'Absent', '${r.absent}', AppColors.red),
          _tile(context, 'Late', '${r.late}', AppColors.amber),
          _tile(context, 'Rate', '${r.percent}%', AppColors.blue),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        '${r.schoolDays} school day(s) in this range',
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: AppSpacing.lg),
      if (r.days.isEmpty)
        Text('Nothing was marked in this range.', style: theme.textTheme.bodyMedium)
      else
        for (final AttendanceDay d in r.days)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: <Widget>[
                SizedBox(width: 96, child: Text(d.date, style: theme.textTheme.bodySmall)),
                Expanded(child: Text(d.day, style: theme.textTheme.bodySmall)),
                StatusPill(
                  _titleCase(d.status),
                  color: _dayColour(d.status),
                  dense: true,
                ),
              ],
            ),
          ),
    ];
  }

  Widget _tile(BuildContext context, String label, String value, Color colour) {
    final ThemeData theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.bodySmall),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(color: colour),
          ),
        ],
      ),
    );
  }

  Color _dayColour(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return AppColors.green;
      case 'absent':
        return AppColors.red;
      case 'late':
        return AppColors.amber;
      default:
        return AppColors.indigo;
    }
  }
}

String _titleCase(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';
