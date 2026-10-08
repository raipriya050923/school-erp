import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../../core/theme/app_theme.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// Staff leave applications, and the decision on each.
///
/// Approving leave is the kind of thing done between other things — in a
/// corridor, on the way to a meeting — which is why it earns a place on a
/// phone at all. The queue opens on Pending, because an empty pending list is
/// the answer to "is there anything waiting for me".
class AdminLeaveScreen extends StatefulWidget {
  const AdminLeaveScreen({super.key});

  @override
  State<AdminLeaveScreen> createState() => _AdminLeaveScreenState();
}

class _AdminLeaveScreenState extends State<AdminLeaveScreen> {
  final AdminApi _api = AdminApi.instance;

  /// null means every status.
  String? _filter = 'pending';
  List<LeaveApplication>? _items;
  bool _loading = true;
  int? _working;
  String? _error;

  static const List<(String?, String)> _filters = <(String?, String)>[
    ('pending', 'Pending'),
    ('approved', 'Approved'),
    ('rejected', 'Rejected'),
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
      final List<LeaveApplication> list = await _api.leave(status: _filter);
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

  Future<void> _review(LeaveApplication a, String status) async {
    String? remarks;
    if (status == 'rejected') {
      // The applicant sees this. A rejection with no reason reads as arbitrary
      // and comes straight back as a question.
      remarks = await _askRemarks(context, a);
      if (remarks == null) return;
    }

    setState(() => _working = a.id);
    try {
      await _api.reviewLeave(id: a.id, status: status, remarks: remarks);
      if (!mounted) return;
      setState(() => _working = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${a.applicantName ?? 'Application'} — ${status == 'approved' ? 'approved' : 'rejected'}',
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

  Future<String?> _askRemarks(BuildContext context, LeaveApplication a) async {
    final TextEditingController controller = TextEditingController();
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Reject ${a.applicantName ?? 'application'}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'The applicant will see this',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final List<LeaveApplication> items = _items ?? const <LeaveApplication>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave requests'),
        actions: const <Widget>[SignOutAction()],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
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
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _body(context, items),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<LeaveApplication> items) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _centred(
        context,
        _error!,
        onRetry: _load,
      );
    }
    if (items.isEmpty) {
      return _centred(
        context,
        _filter == 'pending'
            ? 'Nothing waiting for a decision.'
            : 'No applications with that status.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.xxl,
      ),
      itemCount: items.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int i) => _Card(
        application: items[i],
        busy: _working == items[i].id,
        onApprove: () => _review(items[i], 'approved'),
        onReject: () => _review(items[i], 'rejected'),
      ),
    );
  }

  /// Centred, but still scrollable — a RefreshIndicator cannot be pulled over
  /// a child that does not scroll, and an empty queue is exactly when someone
  /// wants to pull for a new one.
  Widget _centred(BuildContext context, String text, {VoidCallback? onRetry}) =>
      ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: <Widget>[
          const SizedBox(height: AppSpacing.xxl),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ),
          ],
        ],
      );
}

class _Card extends StatelessWidget {
  const _Card({
    required this.application,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final LeaveApplication application;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  Color _statusColour(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.green;
      case 'rejected':
        return AppColors.red;
      default:
        return AppColors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LeaveApplication a = application;
    final bool pending = a.status.toLowerCase() == 'pending';

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
                    Text(a.applicantName ?? 'Staff', style: theme.textTheme.titleSmall),
                    Text(
                      <String>[
                        if ((a.leaveTypeName ?? '').isNotEmpty) a.leaveTypeName!,
                        '${_trimDays(a.days)} day(s)',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusPill(
                _titleCase(a.status),
                color: _statusColour(a.status),
                dense: true,
              ),
            ],
          ),
          if (a.fromDate != null && a.toDate != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${_formatDate(a.fromDate!)} → ${_formatDate(a.toDate!)}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if ((a.reason ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(a.reason!, style: theme.textTheme.bodyMedium),
          ],
          if (!pending && (a.reviewRemarks ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '“${a.reviewRemarks}”'
              '${a.reviewedByName == null ? '' : ' — ${a.reviewedByName}'}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (pending) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onReject,
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onApprove,
                    child: Text(busy ? '…' : 'Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _titleCase(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

/// Half-days are real; 1.0 printed as "1" reads better than "1.0".
String _trimDays(double d) =>
    d == d.roundToDouble() ? d.round().toString() : d.toString();

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';
