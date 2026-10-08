import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../staff/staff_widgets.dart';

/// One entry on a More menu.
class MoreEntry {
  const MoreEntry(this.label, this.icon, this.builder, {this.subtitle});

  final String label;
  final IconData icon;
  final String? subtitle;

  /// Built on tap rather than held, so a dozen screens on the menu do not mean
  /// a dozen live states behind it.
  final WidgetBuilder builder;
}

/// The overflow tab.
///
/// A bottom bar stops being usable past about five destinations, and the admin
/// role alone has more than a dozen screens. Rather than cram them in or drop
/// them, the handful used daily stay on the bar and the rest live here — which
/// is also where a phone user expects to find the things they reach for
/// occasionally.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.title, required this.entries});

  final String title;
  final List<MoreEntry> entries;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: const <Widget>[SignOutAction()],
      ),
      body: SafeArea(
        top: false,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          itemCount: entries.length,
          separatorBuilder: (BuildContext context, int index) =>
              Divider(height: 1, color: theme.dividerColor),
          itemBuilder: (BuildContext context, int i) {
            final MoreEntry e = entries[i];
            return ListTile(
              leading: Icon(e.icon),
              title: Text(e.label),
              subtitle: e.subtitle == null ? null : Text(e.subtitle!),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: e.builder),
              ),
            );
          },
        ),
      ),
    );
  }
}
