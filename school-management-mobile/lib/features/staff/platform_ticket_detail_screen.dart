import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/session.dart';
import '../../core/api/staff_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/staff_models.dart';
import 'staff_widgets.dart';

/// One support ticket, its conversation, and the two ways it ends.
///
/// Replying is the thing this screen is for, so the composer is pinned to the
/// bottom and the thread scrolls under it. Resolving asks for a note rather
/// than just flipping a status, because "resolved" with no explanation is what
/// makes a school open the same ticket again a week later.
class PlatformTicketDetailScreen extends StatefulWidget {
  const PlatformTicketDetailScreen({super.key, required this.ticketId});

  final int ticketId;

  @override
  State<PlatformTicketDetailScreen> createState() =>
      _PlatformTicketDetailScreenState();
}

class _PlatformTicketDetailScreenState
    extends State<PlatformTicketDetailScreen> {
  final SuperAdminApi _api = SuperAdminApi.instance;
  final TextEditingController _reply = TextEditingController();
  final ScrollController _scroll = ScrollController();

  SupportTicketDetail? _ticket;
  bool _loading = true;
  bool _working = false;
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool toBottom = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final SupportTicketDetail t = await _api.ticket(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _ticket = t;
        _loading = false;
      });
      if (toBottom) _jumpToBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  /// After sending, the new message is the point — not the top of the thread.
  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final String message = _reply.text.trim();
    if (message.isEmpty) return;

    final int? userId = Session.instance.user?.id;
    if (userId == null) {
      _toast('You are signed out.');
      return;
    }

    setState(() => _working = true);
    try {
      await _api.addTicketComment(
        id: widget.ticketId,
        userId: userId,
        message: message,
      );
      if (!mounted) return;
      _reply.clear();
      setState(() {
        _working = false;
        _changed = true;
      });
      await _load(toBottom: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      _toast(e.message);
    }
  }

  Future<void> _changeStatus() async {
    final SupportTicketDetail? t = _ticket;
    if (t == null) return;

    final String? next = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final (String, String, String) o in const <(String, String, String)>[
              ('open', 'Open', 'Waiting to be picked up'),
              ('in_progress', 'In progress', 'Someone is on it'),
              ('closed', 'Closed', 'Shut without a resolution note'),
            ])
              ListTile(
                title: Text(o.$2),
                subtitle: Text(o.$3),
                trailing: t.status.toLowerCase() == o.$1
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(o.$1),
              ),
          ],
        ),
      ),
    );
    if (next == null || next == t.status.toLowerCase()) return;
    if (!mounted) return;

    setState(() => _working = true);
    try {
      await _api.setTicketStatus(id: t.id, status: next);
      if (!mounted) return;
      setState(() {
        _working = false;
        _changed = true;
      });
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      _toast(e.message);
    }
  }

  Future<void> _resolve() async {
    final SupportTicketDetail? t = _ticket;
    if (t == null) return;

    final TextEditingController note = TextEditingController();
    bool notify = true;

    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setLocal) => AlertDialog(
          title: const Text('Resolve ticket'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: note,
                autofocus: true,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What fixed it',
                  hintText: 'The school reads this',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                value: notify,
                onChanged: (bool? v) => setLocal(() => notify = v ?? true),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Email the school'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Resolve'),
            ),
          ],
        ),
      ),
    );

    final String text = note.text.trim();
    note.dispose();
    if (go != true) return;
    if (text.isEmpty) {
      _toast('A resolution note is what stops the ticket coming back.');
      return;
    }
    if (!mounted) return;

    setState(() => _working = true);
    try {
      await _api.resolveTicket(id: t.id, note: text, notify: notify);
      if (!mounted) return;
      setState(() {
        _working = false;
        _changed = true;
      });
      _toast('${t.ticketNo} resolved');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      _toast(e.message);
    }
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final SupportTicketDetail? t = _ticket;
    final bool settled = t != null &&
        (t.status.toLowerCase() == 'resolved' ||
            t.status.toLowerCase() == 'closed');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(t?.ticketNo ?? 'Ticket'),
          actions: <Widget>[
            if (t != null)
              IconButton(
                onPressed: _working ? null : _changeStatus,
                tooltip: 'Change status',
                icon: const Icon(Icons.flag_outlined),
              ),
            const SignOutAction(),
          ],
        ),
        body: SafeArea(
          top: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? centredMessage(context, _error!, onRetry: _load)
              : _body(context, t!),
        ),
        bottomNavigationBar: t == null || settled
            ? null
            : SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _reply,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Reply to the school',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.filled(
                        onPressed: _working ? null : _send,
                        icon: const Icon(Icons.send_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _body(BuildContext context, SupportTicketDetail t) {
    final ThemeData theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl,
        ),
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(t.subject, style: theme.textTheme.titleMedium),
              ),
              StatusPill(
                ticketStatusLabel(t.status),
                color: ticketStatusColour(t.status),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${t.schoolName} · ${t.raisedByName} · ${formatDay(t.createdAt)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              StatusPill(
                titleCase(t.priority),
                color: _priorityColour(t.priority),
                dense: true,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),
          Text(t.description, style: theme.textTheme.bodyMedium),

          const SizedBox(height: AppSpacing.xl),
          sectionTitle(context, 'Conversation'),
          if (t.comments.isEmpty)
            Text('Nothing said yet.', style: theme.textTheme.bodySmall)
          else
            for (final TicketReply r in t.comments) _Bubble(reply: r),

          if (t.status.toLowerCase() != 'resolved' &&
              t.status.toLowerCase() != 'closed') ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: _working ? null : _resolve,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Resolve with a note'),
            ),
          ],
        ],
      ),
    );
  }

  Color _priorityColour(String p) {
    switch (p.toLowerCase()) {
      case 'urgent':
        return AppColors.red;
      case 'high':
        return AppColors.amber;
      case 'low':
        return AppColors.indigo;
      default:
        return AppColors.blue;
    }
  }
}

/// One message. Platform replies sit right and tinted, the school's left — the
/// same arrangement as any message thread, so which side said what is read
/// from the shape rather than from the name.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.reply});

  final TicketReply reply;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool mine = reply.isPlatform;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${reply.authorName} · ${formatShortDay(reply.createdAt)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 3),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: mine
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                  : theme.cardTheme.color,
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(mine ? 12 : 3),
                bottomRight: Radius.circular(mine ? 3 : 12),
              ),
            ),
            child: Text(reply.message, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

String ticketStatusLabel(String s) {
  switch (s.toLowerCase()) {
    case 'in_progress':
      return 'In progress';
    case 'resolved':
      return 'Resolved';
    case 'closed':
      return 'Closed';
    default:
      return 'Open';
  }
}

Color ticketStatusColour(String s) {
  switch (s.toLowerCase()) {
    case 'resolved':
      return AppColors.green;
    case 'closed':
      return AppColors.indigo;
    case 'in_progress':
      return AppColors.blue;
    default:
      return AppColors.amber;
  }
}
