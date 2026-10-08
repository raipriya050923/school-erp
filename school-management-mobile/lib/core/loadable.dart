import 'package:flutter/widgets.dart';

import 'api/api_http.dart';

/// Load state for one section of a portal.
class Loadable<T> {
  const Loadable._({this.value, this.error, required this.loading});

  const Loadable.idle() : this._(loading: false);
  const Loadable.loading() : this._(loading: true);
  const Loadable.data(T v) : this._(value: v, loading: false);
  const Loadable.failed(String e) : this._(error: e, loading: false);

  final T? value;
  final String? error;
  final bool loading;

  bool get hasValue => value != null;
}

/// Fetch-once-and-cache behaviour shared by every role's store.
///
/// Each section loads independently so one failing endpoint does not blank the
/// whole portal, and each is fetched once until forced. Roles differ only in
/// which sections they hold, not in how loading works.
abstract class PortalStore extends ChangeNotifier {
  /// Drops every cached section so a different account cannot be shown the
  /// previous one's data.
  void reset();

  Future<void> load<T>({
    required Loadable<T> Function() current,
    required void Function(Loadable<T>) set,
    required Future<T> Function() fetch,
    required bool force,
  }) async {
    final Loadable<T> now = current();
    if (now.loading) return;
    if (now.hasValue && !force) return;

    set(Loadable<T>.loading());
    notifyListeners();
    try {
      set(Loadable<T>.data(await fetch()));
    } on ApiException catch (e) {
      set(Loadable<T>.failed(e.message));
    } catch (_) {
      set(Loadable<T>.failed('Something went wrong.'));
    }
    notifyListeners();
  }
}

/// Rebuilds [builder] whenever [store] changes.
class StoreBuilder<S extends PortalStore> extends StatelessWidget {
  const StoreBuilder({super.key, required this.store, required this.builder});

  final S store;
  final Widget Function(BuildContext context, S store) builder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (BuildContext context, _) => builder(context, store),
  );
}
