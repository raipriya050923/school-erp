import 'package:flutter/widgets.dart';

import '../data/api_models.dart';
import 'api/api_client.dart';

/// Load state for one section of the portal.
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

/// Fetches and caches the student portal's data.
///
/// Each section is loaded independently so one failing endpoint does not blank
/// the whole app, and each is fetched once until [refresh] is called.
class StudentStore extends ChangeNotifier {
  StudentStore._();

  static final StudentStore instance = StudentStore._();

  final ApiClient _api = ApiClient.instance;

  Loadable<StudentDashboard> dashboard = const Loadable<StudentDashboard>.idle();
  Loadable<StudentProfile> profile = const Loadable<StudentProfile>.idle();
  Loadable<StudentAttendance> attendance = const Loadable<StudentAttendance>.idle();
  Loadable<StudentExams> exams = const Loadable<StudentExams>.idle();
  Loadable<List<TimetableSlot>> timetable = const Loadable<List<TimetableSlot>>.idle();
  Loadable<List<StudentHomework>> homework = const Loadable<List<StudentHomework>>.idle();
  Loadable<List<StudentFee>> fees = const Loadable<List<StudentFee>>.idle();
  Loadable<List<StudentNotice>> notices = const Loadable<List<StudentNotice>>.idle();

  /// Clears everything so a different account cannot see the previous one's data.
  void reset() {
    dashboard = const Loadable<StudentDashboard>.idle();
    profile = const Loadable<StudentProfile>.idle();
    attendance = const Loadable<StudentAttendance>.idle();
    exams = const Loadable<StudentExams>.idle();
    timetable = const Loadable<List<TimetableSlot>>.idle();
    homework = const Loadable<List<StudentHomework>>.idle();
    fees = const Loadable<List<StudentFee>>.idle();
    notices = const Loadable<List<StudentNotice>>.idle();
    notifyListeners();
  }

  Future<void> loadDashboard({bool force = false}) => _load(
    current: () => dashboard,
    set: (Loadable<StudentDashboard> v) => dashboard = v,
    fetch: _api.dashboard,
    force: force,
  );

  Future<void> loadProfile({bool force = false}) => _load(
    current: () => profile,
    set: (Loadable<StudentProfile> v) => profile = v,
    fetch: _api.profile,
    force: force,
  );

  Future<void> loadAttendance({bool force = false}) => _load(
    current: () => attendance,
    set: (Loadable<StudentAttendance> v) => attendance = v,
    fetch: _api.attendance,
    force: force,
  );

  Future<void> loadExams({bool force = false}) => _load(
    current: () => exams,
    set: (Loadable<StudentExams> v) => exams = v,
    fetch: _api.exams,
    force: force,
  );

  Future<void> loadTimetable({bool force = false}) => _load(
    current: () => timetable,
    set: (Loadable<List<TimetableSlot>> v) => timetable = v,
    fetch: _api.timetable,
    force: force,
  );

  Future<void> loadHomework({bool force = false}) => _load(
    current: () => homework,
    set: (Loadable<List<StudentHomework>> v) => homework = v,
    fetch: _api.homework,
    force: force,
  );

  Future<void> loadFees({bool force = false}) => _load(
    current: () => fees,
    set: (Loadable<List<StudentFee>> v) => fees = v,
    fetch: _api.fees,
    force: force,
  );

  Future<void> loadNotices({bool force = false}) => _load(
    current: () => notices,
    set: (Loadable<List<StudentNotice>> v) => notices = v,
    fetch: _api.notices,
    force: force,
  );

  Future<void> _load<T>({
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

/// Rebuilds [builder] whenever the store changes.
class StudentStoreBuilder extends StatelessWidget {
  const StudentStoreBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, StudentStore store) builder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: StudentStore.instance,
    builder: (BuildContext context, _) => builder(context, StudentStore.instance),
  );
}
