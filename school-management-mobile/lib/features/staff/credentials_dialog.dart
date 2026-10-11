import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// Shows credentials that exist in plaintext exactly once.
///
/// Every provisioning endpoint in this product returns a password that is
/// hashed the moment it is stored and can never be read back. If this dialog
/// is dismissed without the password being written down, the only way forward
/// is to issue a new one — so it cannot be dismissed by tapping outside or by
/// the back button, and it offers a copy button rather than relying on someone
/// transcribing a generated string correctly.
Future<void> showCredentialsDialog(
  BuildContext context, {
  required String title,
  required String note,
  required List<(String, String)> rows,
  /// What the copy button puts on the clipboard. Defaults to the rows joined,
  /// which is usually "username / password".
  String? copyText,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      return PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(note, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.lg),
                for (final (String, String) row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 96,
                          child: Text(row.$1, style: theme.textTheme.bodySmall),
                        ),
                        Expanded(
                          child: SelectableText(
                            row.$2,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(
                  text: copyText ??
                      rows.map(((String, String) r) => '${r.$1}: ${r.$2}').join('\n'),
                ));
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Copied')),
                );
              },
              child: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    },
  );
}
