import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// Who is in a class.
///
/// "32 students" on the classes list is a number; this is the thirty-two
/// people, which is what a teacher standing in front of them actually needs —
/// to check a name, or to find who is missing from a register.
///
/// Sorted by roll number where the school uses them, because that is the order
/// a register is called in; names come last so an unnumbered section still
/// reads sensibly.
class TeacherRosterScreen extends StatefulWidget {
  const TeacherRosterScreen({
    super.key,
    required this.className,
    required this.sectionName,
    this.subject,
  });

  final String className;
  final String sectionName;
  final String? subject;

  @override
  State<TeacherRosterScreen> createState() => _TeacherRosterScreenState();
}

class _TeacherRosterScreenState extends State<TeacherRosterScreen> {
  final TeacherApi _api = TeacherApi.instance;

  List<RosterStudent>? _items;
  bool _loading = true;
  String? _error;
  String _query = '';

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
      final List<RosterStudent> list = await _api.roster(
        className: widget.className,
        sectionName: widget.sectionName,
      );
      list.sort((RosterStudent a, RosterStudent b) {
        final int? ra = int.tryParse(a.rollNo ?? '');
        final int? rb = int.tryParse(b.rollNo ?? '');
        if (ra != null && rb != null) return ra.compareTo(rb);
        if (ra != null) return -1;
        if (rb != null) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
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
    final ThemeData theme = Theme.of(context);
    final List<RosterStudent> all = _items ?? const <RosterStudent>[];
    final String q = _query.trim().toLowerCase();
    final List<RosterStudent> rows = q.isEmpty
        ? all
        : all
            .where((RosterStudent s) =>
                s.name.toLowerCase().contains(q) ||
                (s.rollNo ?? '').toLowerCase().contains(q))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.className} — ${widget.sectionName}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: TextField(
              onChanged: (String v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search name or roll no',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                isDense: true,
              ),
            ),
          ),
        ),
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
            empty: EmptyState(
              icon: q.isEmpty
                  ? Icons.groups_outlined
                  : Icons.person_search_outlined,
              title: q.isEmpty ? 'Nobody enrolled' : 'No students match',
              message: q.isEmpty
                  ? 'This section has no students yet.'
                  : null,
            ),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  <String>[
                    if (widget.subject != null && widget.subject!.isNotEmpty)
                      widget.subject!,
                    rows.length == 1 ? '1 student' : '${rows.length} students',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              for (final RosterStudent s in rows)
                StaffRow(
                  title: s.name,
                  // The roll leads, because a register is called by it.
                  leading: _RollChip(roll: s.rollNo),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RollChip extends StatelessWidget {
  const _RollChip({required this.roll});

  final String? roll;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        // A dash rather than a blank: an unnumbered student should look
        // deliberate, not like a failed lookup.
        roll == null || roll!.isEmpty ? '—' : roll!,
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
