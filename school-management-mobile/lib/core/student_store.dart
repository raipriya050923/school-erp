import 'package:flutter/widgets.dart';

import '../data/api_models.dart';
import 'api/api_client.dart';
import 'loadable.dart';

export 'loadable.dart' show Loadable;

/// Fetches and caches the student portal's data.
///
/// Each section is loaded independently so one failing endpoint does not blank
/// the whole app, and each is fetched once until [refresh] is called.
class StudentStore extends PortalStore {
  StudentStore._();

  static final StudentStore instance = StudentStore._();

  final ApiClient _api = ApiClient.instance;

  Loadable<StudentDashboard> dashboard = const Loadable<StudentDashboard>.idle();
  Loadable<StudentProfile> profile = const Loadable<StudentProfile>.idle();
  Loadable<StudentAttendance> attendance = const Loadable<StudentAttendance>.idle();
  Loadable<StudentExams> exams = const Loadable<StudentExams>.idle();
  Loadable<StudentTimetable> timetable = const Loadable<StudentTimetable>.idle();
  Loadable<List<StudentHomework>> homework = const Loadable<List<StudentHomework>>.idle();
  Loadable<List<StudentFee>> fees = const Loadable<List<StudentFee>>.idle();
  Loadable<List<StudentNotice>> notices = const Loadable<List<StudentNotice>>.idle();

  /// Clears everything so a different account cannot see the previous one's data.
  @override
  void reset() {
    dashboard = const Loadable<StudentDashboard>.idle();
    profile = const Loadable<StudentProfile>.idle();
    attendance = const Loadable<StudentAttendance>.idle();
    exams = const Loadable<StudentExams>.idle();
    timetable = const Loadable<StudentTimetable>.idle();
    homework = const Loadable<List<StudentHomework>>.idle();
    fees = const Loadable<List<StudentFee>>.idle();
    notices = const Loadable<List<StudentNotice>>.idle();
    notifyListeners();
  }

  Future<void> loadDashboard({bool force = false}) => load(
    current: () => dashboard,
    set: (Loadable<StudentDashboard> v) => dashboard = v,
    fetch: _api.dashboard,
    force: force,
  );

  Future<void> loadProfile({bool force = false}) => load(
    current: () => profile,
    set: (Loadable<StudentProfile> v) => profile = v,
    fetch: _api.profile,
    force: force,
  );

  Future<void> loadAttendance({bool force = false}) => load(
    current: () => attendance,
    set: (Loadable<StudentAttendance> v) => attendance = v,
    fetch: _api.attendance,
    force: force,
  );

  Future<void> loadExams({bool force = false}) => load(
    current: () => exams,
    set: (Loadable<StudentExams> v) => exams = v,
    fetch: _api.exams,
    force: force,
  );

  Future<void> loadTimetable({bool force = false}) => load(
    current: () => timetable,
    set: (Loadable<StudentTimetable> v) => timetable = v,
    fetch: _api.timetable,
    force: force,
  );

  Future<void> loadHomework({bool force = false}) => load(
    current: () => homework,
    set: (Loadable<List<StudentHomework>> v) => homework = v,
    fetch: _api.homework,
    force: force,
  );

  Future<void> loadFees({bool force = false}) => load(
    current: () => fees,
    set: (Loadable<List<StudentFee>> v) => fees = v,
    fetch: _api.fees,
    force: force,
  );

  Future<void> loadNotices({bool force = false}) => load(
    current: () => notices,
    set: (Loadable<List<StudentNotice>> v) => notices = v,
    fetch: _api.notices,
    force: force,
  );


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
