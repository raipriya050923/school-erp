import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_http.dart';
import '../../core/api/staff_api.dart';
import '../../core/staff_stores.dart';
import '../../core/theme/app_theme.dart';
import '../../data/staff_models.dart';
import 'admin_student_form_screen.dart';
import 'admin_teacher_form_screen.dart';
import 'credentials_dialog.dart';
import 'parent_login_sheet.dart';

/// What a Students or Teachers row offers when tapped.
///
/// Kept together rather than on each screen because the two sets are nearly
/// identical — edit, reset the portal password, retire — and the differences
/// (only a student has a parent login) are easier to see side by side than
/// spread across two files.
///
/// Neither list hard-deletes. Someone who has sat an exam, taken a register or
/// been invoiced cannot vanish without taking that history with them, so the
/// API retires the record and this menu says so.
Future<void> showStudentActions(BuildContext context, AdminStudent s) async {
  final bool active = s.status == 'active';
  final RowAction? choice = await _pickAction(
    context,
    title: s.name,
    subtitle: '${s.admissionNo} · ${s.classLabel}',
    actions: <RowAction>[
      const RowAction('edit', 'Edit details', Icons.edit_outlined),
      const RowAction('parent', 'Parent login', Icons.family_restroom_outlined),
      const RowAction('password', 'Reset portal password', Icons.key_outlined),
      RowAction(
        'status',
        active ? 'Mark inactive' : 'Mark active',
        active ? Icons.person_off_outlined : Icons.person_outline,
        danger: active,
      ),
    ],
  );
  if (choice == null || !context.mounted) return;

  switch (choice.id) {
    case 'edit':
      await _editStudent(context, s.id);
    case 'parent':
      await ParentLoginSheet.show(context, s);
    case 'password':
      await _resetPassword(
        context,
        who: s.name,
        reset: () => AdminApi.instance.resetStudentPassword(s.id),
      );
    case 'status':
      await _setStatus(
        context,
        who: s.name,
        toActive: !active,
        warning: 'They lose portal access until they are made active again.',
        apply: (String status) =>
            AdminApi.instance.setStudentStatus(id: s.id, status: status),
        reload: () => AdminStore.instance.loadStudents(force: true),
      );
  }
}

Future<void> showTeacherActions(BuildContext context, AdminTeacher t) async {
  final bool active = t.status == 'active';
  final RowAction? choice = await _pickAction(
    context,
    title: t.name,
    subtitle: <String>[
      if (t.employeeCode?.isNotEmpty ?? false) t.employeeCode!,
      if (t.subject?.isNotEmpty ?? false) t.subject!,
    ].join(' · '),
    actions: <RowAction>[
      const RowAction('edit', 'Edit details', Icons.edit_outlined),
      const RowAction('password', 'Reset portal password', Icons.key_outlined),
      RowAction(
        'status',
        active ? 'Mark inactive' : 'Mark active',
        active ? Icons.person_off_outlined : Icons.person_outline,
        danger: active,
      ),
    ],
  );
  if (choice == null || !context.mounted) return;

  switch (choice.id) {
    case 'edit':
      await _editTeacher(context, t.id);
    case 'password':
      await _resetPassword(
        context,
        who: t.name,
        reset: () => AdminApi.instance.resetTeacherPassword(t.id),
      );
    case 'status':
      await _setStatus(
        context,
        who: t.name,
        toActive: !active,
        warning: 'They lose portal access, and cannot be timetabled, until '
            'they are made active again.',
        apply: (String status) =>
            AdminApi.instance.setTeacherStatus(id: t.id, status: status),
        reload: () => AdminStore.instance.loadTeachers(force: true),
      );
  }
}

/// The list row is a summary; the form needs the whole record, so editing
/// fetches it first rather than opening a half-filled form.
Future<void> _editStudent(BuildContext context, int id) async {
  final StudentDetail? detail =
      await _load(context, () => AdminApi.instance.studentDetail(id));
  if (detail == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<bool>(
      builder: (BuildContext _) => AdminStudentFormScreen(existing: detail),
    ),
  );
}

Future<void> _editTeacher(BuildContext context, int id) async {
  final TeacherDetail? detail =
      await _load(context, () => AdminApi.instance.teacherDetail(id));
  if (detail == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<bool>(
      builder: (BuildContext _) => AdminTeacherFormScreen(existing: detail),
    ),
  );
}

/// Runs a fetch behind a modal spinner and surfaces the failure, rather than
/// leaving a tap that appears to do nothing.
Future<T?> _load<T>(BuildContext context, Future<T> Function() fetch) async {
  final NavigatorState navigator = Navigator.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext _) =>
          const Center(child: CircularProgressIndicator()),
    ),
  );
  try {
    final T value = await fetch();
    navigator.pop();
    return value;
  } on ApiException catch (e) {
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return null;
  }
}

/// Issues a new password and shows it once. The plaintext exists only in that
/// response — the database keeps a bcrypt hash — so the dialog is the one
/// chance to write it down, and it asks before burning the old one.
Future<void> _resetPassword(
  BuildContext context, {
  required String who,
  required Future<GeneratedCredentials> Function() reset,
}) async {
  final bool ok = await _confirm(
    context,
    title: 'Reset the password for $who?',
    message: 'Their current password stops working straight away.',
    confirmLabel: 'Reset',
  );
  if (!ok || !context.mounted) return;

  final GeneratedCredentials? c = await _load(context, reset);
  if (c == null || !context.mounted) return;

  await showCredentialsDialog(
    context,
    title: 'New password for $who',
    note: 'Copy it now — it cannot be shown again.',
    rows: <(String, String)>[
      ('Username', c.username),
      ('Password', c.temporaryPassword),
    ],
  );
}

/// Retiring asks first; restoring does not. Turning someone back on is not a
/// decision anyone regrets, and a confirm on it is just a tap to dismiss.
Future<void> _setStatus(
  BuildContext context, {
  required String who,
  required bool toActive,
  required String warning,
  required Future<void> Function(String status) apply,
  required Future<void> Function() reload,
}) async {
  final String status = toActive ? 'active' : 'inactive';
  if (!toActive) {
    final bool ok = await _confirm(
      context,
      title: 'Mark $who inactive?',
      message: warning,
      confirmLabel: 'Mark inactive',
      danger: true,
    );
    if (!ok || !context.mounted) return;
  }

  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    await apply(status);
    await reload();
    messenger.showSnackBar(SnackBar(content: Text('$who is now $status')));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

/// One entry on the row menu.
class RowAction {
  const RowAction(this.id, this.label, this.icon, {this.danger = false});

  final String id;
  final String label;
  final IconData icon;
  final bool danger;
}

Future<RowAction?> _pickAction(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<RowAction> actions,
}) {
  return showModalBottomSheet<RowAction>(
    context: context,
    builder: (BuildContext sheetContext) {
      final ThemeData theme = Theme.of(sheetContext);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(title, style: theme.textTheme.titleMedium),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            for (final RowAction a in actions)
              ListTile(
                leading: Icon(
                  a.icon,
                  color: a.danger ? theme.colorScheme.error : null,
                ),
                title: Text(
                  a.label,
                  style: a.danger
                      ? TextStyle(color: theme.colorScheme.error)
                      : null,
                ),
                onTap: () => Navigator.of(sheetContext).pop(a),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      );
    },
  );
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}
