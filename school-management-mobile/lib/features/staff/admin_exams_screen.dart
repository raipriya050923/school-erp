import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// The school's exams, their schedules, and the sign-offs publishing waits on.
///
/// Scheduling papers is desk work and stays on the web. What belongs here is
/// the part that happens while the exam is running: checking which sections
/// have approved their marks, chasing the ones that have not, and publishing
/// the results the moment the last one lands.
class AdminExamsScreen extends StatefulWidget {
  const AdminExamsScreen({super.key});

  @override
  State<AdminExamsScreen> createState() => _AdminExamsScreenState();
}

class _AdminExamsScreenState extends State<AdminExamsScreen> {
  final AdminApi _api = AdminApi.instance;

  List<SchoolExam>? _items;
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
      final List<SchoolExam> list = await _api.exams();
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

  @override
  Widget build(BuildContext context) {
    final List<SchoolExam> items = _items ?? const <SchoolExam>[];
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Examinations'),
        actions: const <Widget>[SignOutAction()],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _centred(context, _error!, onRetry: _load)
              : items.isEmpty
              ? _centred(
                  context,
                  'No exams have been set up yet. They are created on the web, '
                  'where the schedule can be typed out in one go.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (BuildContext _, int index) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (BuildContext context, int i) {
                    final SchoolExam e = items[i];
                    return InkWell(
                      borderRadius: AppRadius.cardRadius,
                      onTap: () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (BuildContext _) => ExamDetailScreen(exam: e),
                          ),
                        );
                        // The detail screen can change the status, so the list
                        // behind it is stale by the time it pops.
                        await _load();
                      },
                      child: Container(
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
                                  child: Text(e.name, style: theme.textTheme.titleSmall),
                                ),
                                StatusPill(
                                  examStatusLabel(e.status),
                                  color: examStatusColour(e.status),
                                  dense: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              <String>[
                                if ((e.type ?? '').isNotEmpty) e.type!,
                                formatExamRange(e.startDate, e.endDate),
                                '${e.paperCount} paper(s)',
                              ].where((String s) => s.isNotEmpty).join(' · '),
                              style: theme.textTheme.bodySmall,
                            ),
                            if ((e.classes ?? '').isNotEmpty)
                              Text(e.classes!, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// One exam: its papers, who has signed off, and the status controls.
class ExamDetailScreen extends StatefulWidget {
  const ExamDetailScreen({super.key, required this.exam});

  final SchoolExam exam;

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  final AdminApi _api = AdminApi.instance;

  late SchoolExam _exam;
  List<ExamApproval>? _approvals;
  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _exam = widget.exam;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<ExamApproval> rows = await _api.examApprovals(_exam.id);
      // Re-read the exam too: the status may have moved on its own, since the
      // dates drive it unless an admin has pinned it.
      final List<SchoolExam> exams = await _api.exams();
      if (!mounted) return;
      setState(() {
        _approvals = rows;
        _exam = exams.firstWhere(
          (SchoolExam e) => e.id == _exam.id,
          orElse: () => _exam,
        );
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

  Future<void> _setStatus(String status) async {
    setState(() => _working = true);
    try {
      await _api.setExamStatus(examId: _exam.id, status: status);
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'auto'
                ? 'Status is back to following the dates'
                : 'Status set to ${examStatusLabel(status)}',
          ),
        ),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      // The refusal to publish names every section still outstanding, which is
      // the useful part and too long for a snackbar.
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Not yet'),
          content: Text(e.message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _confirmPublish() async {
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Publish results?'),
        content: const Text(
          'Students and parents see the marks as soon as this is done, and '
          'there is no clean way to take them back.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (go == true) await _setStatus('result_published');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<ExamApproval> approvals = _approvals ?? const <ExamApproval>[];
    final bool allApproved =
        approvals.isNotEmpty && approvals.every((ExamApproval a) => a.isApproved);
    final bool published = _exam.status == 'result_published';

    return Scaffold(
      appBar: AppBar(
        title: Text(_exam.name),
        actions: <Widget>[
          PopupMenuButton<String>(
            tooltip: 'Change status',
            enabled: !_working,
            onSelected: _setStatus,
            itemBuilder: (BuildContext _) => <PopupMenuEntry<String>>[
              for (final String s in const <String>[
                'scheduled', 'ongoing', 'completed', 'cancelled',
              ])
                PopupMenuItem<String>(value: s, child: Text(examStatusLabel(s))),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'auto',
                child: Text('Follow the dates'),
              ),
            ],
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
              ? _centred(context, _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl,
                  ),
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        StatusPill(
                          examStatusLabel(_exam.status),
                          color: examStatusColour(_exam.status),
                          dense: true,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _exam.isManualStatus
                                ? 'Set by hand — the dates would say '
                                      '${examStatusLabel(_exam.derivedStatus)}'
                                : 'Following the dates',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      <String>[
                        if ((_exam.type ?? '').isNotEmpty) _exam.type!,
                        formatExamRange(_exam.startDate, _exam.endDate),
                        if ((_exam.classes ?? '').isNotEmpty) _exam.classes!,
                      ].where((String s) => s.isNotEmpty).join(' · '),
                      style: theme.textTheme.bodyMedium,
                    ),

                    const SizedBox(height: AppSpacing.xl),
                    Text('Sign-off', style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      approvals.isEmpty
                          ? 'No papers are scheduled for any class, so there is '
                                'nothing to sign off yet.'
                          : allApproved
                          ? 'Every section has approved its marks.'
                          : 'Results stay unpublished until every section has '
                                'approved.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final ExamApproval a in approvals)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              a.isApproved
                                  ? Icons.check_circle_outline
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: a.isApproved
                                  ? AppColors.green
                                  : theme.dividerColor,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(a.label, style: theme.textTheme.bodyMedium),
                                  Text(
                                    <String>[
                                      '${a.completeCount}/${a.studentCount} marked',
                                      if ((a.approvedByName ?? '').isNotEmpty)
                                        a.approvedByName!,
                                    ].join(' · '),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  if ((a.remarks ?? '').isNotEmpty)
                                    Text(
                                      '“${a.remarks}”',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (!published) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _working || approvals.isEmpty
                              ? null
                              : _confirmPublish,
                          child: Text(_working ? '…' : 'Publish results'),
                        ),
                      ),
                      if (!allApproved && approvals.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            'It will tell you who it is waiting on.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],

                    const SizedBox(height: AppSpacing.xl),
                    Text('Schedule', style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.md),
                    if (_exam.papers.isEmpty)
                      Text(
                        'No papers scheduled. They are added on the web.',
                        style: theme.textTheme.bodySmall,
                      )
                    else
                      for (final ExamPaper p in _sortedPapers(_exam.papers))
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              SizedBox(
                                width: 64,
                                child: Text(
                                  p.examDate == null
                                      ? '—'
                                      : _formatDate(p.examDate!),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      <String>[
                                        if ((p.classLabel ?? '').isNotEmpty)
                                          p.classLabel!,
                                        p.subject,
                                      ].join(' · '),
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    Text(
                                      <String>[
                                        if ((p.time ?? '').isNotEmpty) p.time!,
                                        if ((p.room ?? '').isNotEmpty)
                                          'Room ${p.room}',
                                        'Max ${p.fullMarks}',
                                      ].join(' · '),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Date order, undated last — a timetable read out of order is no timetable.
  List<ExamPaper> _sortedPapers(List<ExamPaper> papers) {
    final List<ExamPaper> sorted = List<ExamPaper>.of(papers);
    sorted.sort((ExamPaper a, ExamPaper b) {
      if (a.examDate == null && b.examDate == null) {
        return a.subject.compareTo(b.subject);
      }
      if (a.examDate == null) return 1;
      if (b.examDate == null) return -1;
      final int byDate = a.examDate!.compareTo(b.examDate!);
      return byDate != 0
          ? byDate
          : (a.classLabel ?? '').compareTo(b.classLabel ?? '');
    });
    return sorted;
  }
}

String examStatusLabel(String status) {
  switch (status) {
    case 'result_published':
      return 'Results published';
    case 'ongoing':
      return 'Ongoing';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    case 'scheduled':
      return 'Scheduled';
    case 'auto':
      return 'Automatic';
    default:
      return status.isEmpty ? '—' : status;
  }
}

Color examStatusColour(String status) {
  switch (status) {
    case 'result_published':
      return AppColors.green;
    case 'ongoing':
      return AppColors.amber;
    case 'cancelled':
      return AppColors.red;
    case 'completed':
      return AppColors.blue;
    default:
      return AppColors.indigo;
  }
}

String formatExamRange(DateTime? from, DateTime? to) {
  if (from == null && to == null) return '';
  if (from == null) return 'until ${_formatDate(to!)}';
  if (to == null) return 'from ${_formatDate(from)}';
  return '${_formatDate(from)} → ${_formatDate(to)}';
}

/// Centred but scrollable, so a RefreshIndicator above it can still be pulled.
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

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';
