import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_theme.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// The school's notice board, and posting to it.
///
/// Posting belongs on a phone more than most admin work: a notice is usually
/// written the moment something happens — a closure, a changed time — and
/// waiting to get back to a desk is how it reaches people late.
class AdminNoticesScreen extends StatefulWidget {
  const AdminNoticesScreen({super.key});

  @override
  State<AdminNoticesScreen> createState() => _AdminNoticesScreenState();
}

class _AdminNoticesScreenState extends State<AdminNoticesScreen> {
  final AdminApi _api = AdminApi.instance;

  List<SchoolNotice>? _items;
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
      final List<SchoolNotice> list = await _api.notices();
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

  Future<void> _compose() async {
    final bool? posted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => Padding(
        // Lifted clear of the keyboard: the body field is the one that matters
        // and it is the lowest thing on the sheet.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: const _ComposeSheet(),
      ),
    );
    if (posted == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final List<SchoolNotice> items = _items ?? const <SchoolNotice>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notice board'),
        actions: const <Widget>[SignOutAction()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text('Post'),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: _body(context, items),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<SchoolNotice> items) {
    final ThemeData theme = Theme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: <Widget>[
          Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Try again')),
          ),
        ],
      );
    }
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: <Widget>[
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'No notices yet. Post the first one.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96,
      ),
      itemCount: items.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int i) {
        final SchoolNotice n = items[i];
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
                    child: Text(n.title, style: theme.textTheme.titleSmall),
                  ),
                  Text(_audienceLabel(n.audience), style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(n.body, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                <String>[
                  _formatDate(n.publishDate),
                  if ((n.createdByName ?? '').isNotEmpty) n.createdByName!,
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

String _audienceLabel(String a) {
  switch (a.toLowerCase()) {
    case 'students':
      return 'Students';
    case 'teachers':
      return 'Teachers';
    case 'parents':
      return 'Parents';
    case 'staff':
      return 'Staff';
    default:
      return 'Everyone';
  }
}

/// Composing a notice. Kept apart from the list so the list does not rebuild
/// on every keystroke of a draft.
class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet();

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  String _audience = 'all';
  bool _posting = false;

  static const List<(String, String)> _audiences = <(String, String)>[
    ('all', 'Everyone'),
    ('students', 'Students'),
    ('teachers', 'Teachers'),
    ('parents', 'Parents'),
    ('staff', 'Staff'),
  ];

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final String title = _title.text.trim();
    final String body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A notice needs a title and a body.')),
      );
      return;
    }

    setState(() => _posting = true);
    try {
      await AdminApi.instance.createNotice(
        title: title,
        body: body,
        audience: _audience,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('New notice', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _body,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notice'),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _audience,
              decoration: const InputDecoration(labelText: 'Who sees it'),
              items: <DropdownMenuItem<String>>[
                for (final (String, String) a in _audiences)
                  DropdownMenuItem<String>(value: a.$1, child: Text(a.$2)),
              ],
              onChanged: (String? v) => setState(() => _audience = v ?? 'all'),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _posting ? null : _post,
                child: Text(_posting ? 'Posting…' : 'Post notice'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
