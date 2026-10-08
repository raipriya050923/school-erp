import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// A class teacher's review of their section's result sheet, and the sign-off.
///
/// Read-only on the marks themselves: subject teachers own their own entry.
/// What this screen adds is the one decision the class teacher makes — whether
/// the sheet is right — and the admin cannot publish the exam until every
/// section that sat it has been approved here.
///
/// Approval is refused while any paper is unmarked, so the button is disabled
/// with the count showing rather than failing on press.
class TeacherResultsScreen extends StatefulWidget {
  const TeacherResultsScreen({super.key});

  @override
  State<TeacherResultsScreen> createState() => _TeacherResultsScreenState();
}

class _TeacherResultsScreenState extends State<TeacherResultsScreen> {
  final TeacherApi _api = TeacherApi.instance;

  List<SchoolExam>? _exams;
  List<MyClassSection>? _sections;
  SchoolExam? _exam;
  MyClassSection? _section;

  ClassResult? _result;
  bool _loading = false;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPickers();
  }

  Future<void> _loadPickers() async {
    try {
      final List<SchoolExam> exams = await _api.exams();
      final List<MyClassSection> sections = await _api.resultSections();
      if (!mounted) return;
      setState(() {
        _exams = exams;
        _sections = sections;
        _exam = exams.isEmpty ? null : exams.first;
        _section = sections.isEmpty ? null : sections.first;
        _error = null;
      });
      if (_exam != null && _section != null) await _load();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _load() async {
    final SchoolExam? exam = _exam;
    final MyClassSection? section = _section;
    if (exam == null || section == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ClassResult r = await _api.classResult(
        examId: exam.id,
        className: section.className,
        sectionName: section.sectionName,
      );
      if (!mounted) return;
      setState(() {
        _result = r;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _result = null;
        _error = e.message;
      });
    }
  }

  Future<void> _setApproval(bool approve) async {
    final ClassResult? r = _result;
    if (r == null) return;

    String? remarks;
    if (!approve) {
      // Withdrawing is the one that needs explaining: somebody downstream is
      // waiting on this sheet and should be told why it went back.
      remarks = await _askRemarks(context);
      if (remarks == null) return;
    }

    setState(() => _working = true);
    try {
      await _api.approveResult(
        examId: r.examId,
        className: r.className,
        sectionName: r.sectionName,
        approve: approve,
        remarks: remarks,
      );
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Result approved' : 'Approval withdrawn'),
        ),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<String?> _askRemarks(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Withdraw approval'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Why',
            hintText: 'Two marks still look wrong',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class results'),
        actions: const <Widget>[SignOutAction()],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            _pickers(context),
            Expanded(child: _body(context)),
          ],
        ),
      ),
      bottomNavigationBar: _result == null ? null : _approvalBar(context, _result!),
    );
  }

  Widget _pickers(BuildContext context) {
    final List<SchoolExam> exams = _exams ?? const <SchoolExam>[];
    final List<MyClassSection> sections = _sections ?? const <MyClassSection>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: DropdownButtonFormField<SchoolExam>(
              initialValue: _exam,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Exam', isDense: true),
              items: <DropdownMenuItem<SchoolExam>>[
                for (final SchoolExam e in exams)
                  DropdownMenuItem<SchoolExam>(value: e, child: Text(e.name)),
              ],
              onChanged: exams.isEmpty
                  ? null
                  : (SchoolExam? e) {
                      if (e == null) return;
                      setState(() => _exam = e);
                      _load();
                    },
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: DropdownButtonFormField<MyClassSection>(
              initialValue: _section,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Section', isDense: true),
              items: <DropdownMenuItem<MyClassSection>>[
                for (final MyClassSection s in sections)
                  DropdownMenuItem<MyClassSection>(value: s, child: Text(s.label)),
              ],
              onChanged: sections.isEmpty
                  ? null
                  : (MyClassSection? s) {
                      if (s == null) return;
                      setState(() => _section = s);
                      _load();
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (_error != null) return _message(context, _error!, onRetry: _load);
    if (_sections != null && _sections!.isEmpty) {
      return _message(
        context,
        'You are not the class teacher of any section, so there is no result '
        'sheet for you to sign off.',
      );
    }
    if (_exams != null && _exams!.isEmpty) {
      return _message(context, 'No exams have been set for this school yet.');
    }
    if (_loading || _result == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final ClassResult r = _result!;
    if (r.students.isEmpty) {
      return _message(context, 'No students in this section.');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl,
      ),
      children: <Widget>[
        // What is still missing, stated before the marks: it is the only thing
        // standing between this sheet and a published result.
        if (r.missingMarks > 0)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
              borderRadius: AppRadius.cardRadius,
            ),
            child: Text(
              '${r.missingMarks} mark(s) still missing. The sheet cannot be '
              'approved until every paper is entered.',
              style: theme.textTheme.bodySmall,
            ),
          ),

        Text('Papers', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        for (final ClassResultSubject s in r.subjects)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: <Widget>[
                Icon(
                  s.isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 16,
                  color: s.isComplete ? AppColors.green : AppColors.amber,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(s.subject)),
                Text('${s.entered}/${s.total}', style: theme.textTheme.bodySmall),
              ],
            ),
          ),

        const SizedBox(height: AppSpacing.lg),
        Text('Students', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        for (final ClassResultStudent s in r.students)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(s.name, style: theme.textTheme.titleSmall),
                      Text(
                        <String>[
                          if ((s.rollNo ?? '').isNotEmpty) 'Roll ${s.rollNo}',
                          if (s.missing > 0) '${s.missing} unmarked',
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '${s.total.toStringAsFixed(0)}/${s.fullTotal.toStringAsFixed(0)}',
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      '${s.percent.toStringAsFixed(1)}%  ${s.grade}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _approvalBar(BuildContext context, ClassResult r) {
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (r.isApproved && r.approvedByName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Approved by ${r.approvedByName}'
                  '${r.approvedAt == null ? '' : ' on ${_formatDate(r.approvedAt!)}'}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (r.isPublished)
              Text(
                'Published. The result is visible to students.',
                style: theme.textTheme.bodySmall,
              )
            else if (r.isApproved)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _working ? null : () => _setApproval(false),
                  child: Text(_working ? 'Working…' : 'Withdraw approval'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _working || !r.canApprove ? null : () => _setApproval(true),
                  child: Text(
                    _working
                        ? 'Working…'
                        : r.canApprove
                        ? 'Approve result'
                        : '${r.missingMarks} mark(s) missing',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _message(BuildContext context, String text, {VoidCallback? onRetry}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    ),
  );
}

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
