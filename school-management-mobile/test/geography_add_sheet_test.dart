// Reproduction for the "'_dependents.isEmpty': is not true" crash seen when
// adding a state or a city on the geography screen.
//
// The assertion lives in InheritedElement.debugDeactivated: an InheritedWidget
// was torn down while widgets still depended on it. This test drives the same
// shape the screen uses — an AppBar action that awaits a modal bottom sheet
// with an autofocusing TextField, then disposes the controllers and reloads —
// so the failure can be seen without the API or a device.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('adding through the sheet does not trip _dependents.isEmpty',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Screen()));
    await tester.pumpAndSettle();

    // Open the sheet from the AppBar, exactly as "Add a city" does.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Kirtipur');
    await tester.pump();

    // Save: pops the sheet with a value, which the screen then acts on.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Kirtipur'), findsOneWidget);
  });
}

/// The screen under test, mirroring _CitiesScreen: a list that swaps for a
/// spinner while loading, a snack bar after the write, and a reload.
class _Screen extends StatefulWidget {
  const _Screen();

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  List<String>? _items;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    if (!mounted) return;
    setState(() {
      _items = <String>[..._items ?? const <String>[]];
      _loading = false;
    });
  }

  Future<void> _add() async {
    final String? name = await _namedSheet(context);
    if (name == null) return;
    _items = <String>[...?_items, name];
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$name added')));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> items = _items ?? const <String>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cities'),
        actions: <Widget>[
          IconButton(onPressed: _add, icon: const Icon(Icons.add)),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? const Center(child: Text('No cities.'))
                  : ListView(
                      children: <Widget>[
                        for (final String s in items) Text(s),
                      ],
                    ),
        ),
      ),
    );
  }
}

/// The sheet, in the same shape as _namedSheet: the controller belongs to a
/// StatefulWidget, so it is disposed when the sheet is unmounted rather than
/// when the route is popped. Creating it in this function and disposing after
/// the await is what caused the crash — the sheet is still animating out and
/// still using it at that point.
Future<String?> _namedSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => const _Sheet(),
  );
}

class _Sheet extends StatefulWidget {
  const _Sheet();

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(controller: _name, autofocus: true),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  final String n = _name.text.trim();
                  if (n.isEmpty) return;
                  Navigator.of(context).pop(n);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
