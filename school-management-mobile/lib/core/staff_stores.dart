import '../data/api_models.dart' show StudentTimetable;
import '../data/staff_models.dart';
import 'api/staff_api.dart';
import 'loadable.dart';

/// Caches the teacher portal's sections.
class TeacherStore extends PortalStore {
  TeacherStore._();

  static final TeacherStore instance = TeacherStore._();

  final TeacherApi _api = TeacherApi.instance;

  Loadable<TeacherDashboard> dashboard = const Loadable<TeacherDashboard>.idle();
  Loadable<List<TeacherClass>> classes = const Loadable<List<TeacherClass>>.idle();
  Loadable<StudentTimetable> timetable = const Loadable<StudentTimetable>.idle();
  Loadable<List<LeaveApplication>> leave =
      const Loadable<List<LeaveApplication>>.idle();
  Loadable<List<LeaveType>> leaveTypes = const Loadable<List<LeaveType>>.idle();

  @override
  void reset() {
    dashboard = const Loadable<TeacherDashboard>.idle();
    classes = const Loadable<List<TeacherClass>>.idle();
    timetable = const Loadable<StudentTimetable>.idle();
    leave = const Loadable<List<LeaveApplication>>.idle();
    leaveTypes = const Loadable<List<LeaveType>>.idle();
    notifyListeners();
  }

  Future<void> loadDashboard({bool force = false}) => load(
    current: () => dashboard,
    set: (Loadable<TeacherDashboard> v) => dashboard = v,
    fetch: _api.dashboard,
    force: force,
  );

  Future<void> loadClasses({bool force = false}) => load(
    current: () => classes,
    set: (Loadable<List<TeacherClass>> v) => classes = v,
    fetch: _api.classes,
    force: force,
  );

  Future<void> loadTimetable({bool force = false}) => load(
    current: () => timetable,
    set: (Loadable<StudentTimetable> v) => timetable = v,
    fetch: _api.timetable,
    force: force,
  );

  Future<void> loadLeave({bool force = false}) => load(
    current: () => leave,
    set: (Loadable<List<LeaveApplication>> v) => leave = v,
    fetch: _api.leave,
    force: force,
  );

  Future<void> loadLeaveTypes({bool force = false}) => load(
    current: () => leaveTypes,
    set: (Loadable<List<LeaveType>> v) => leaveTypes = v,
    fetch: _api.leaveTypes,
    force: force,
  );
}

/// Caches the school-admin portal's sections.
class AdminStore extends PortalStore {
  AdminStore._();

  static final AdminStore instance = AdminStore._();

  final AdminApi _api = AdminApi.instance;

  Loadable<AdminDashboard> dashboard = const Loadable<AdminDashboard>.idle();
  Loadable<List<AdminStudent>> students = const Loadable<List<AdminStudent>>.idle();
  Loadable<List<AdminTeacher>> teachers = const Loadable<List<AdminTeacher>>.idle();
  Loadable<FeeSummary> feeSummary = const Loadable<FeeSummary>.idle();
  Loadable<List<AdminInvoice>> invoices = const Loadable<List<AdminInvoice>>.idle();

  @override
  void reset() {
    dashboard = const Loadable<AdminDashboard>.idle();
    students = const Loadable<List<AdminStudent>>.idle();
    teachers = const Loadable<List<AdminTeacher>>.idle();
    feeSummary = const Loadable<FeeSummary>.idle();
    invoices = const Loadable<List<AdminInvoice>>.idle();
    notifyListeners();
  }

  Future<void> loadDashboard({bool force = false}) => load(
    current: () => dashboard,
    set: (Loadable<AdminDashboard> v) => dashboard = v,
    fetch: _api.dashboard,
    force: force,
  );

  Future<void> loadStudents({bool force = false}) => load(
    current: () => students,
    set: (Loadable<List<AdminStudent>> v) => students = v,
    fetch: _api.students,
    force: force,
  );

  Future<void> loadTeachers({bool force = false}) => load(
    current: () => teachers,
    set: (Loadable<List<AdminTeacher>> v) => teachers = v,
    fetch: _api.teachers,
    force: force,
  );

  Future<void> loadFeeSummary({bool force = false}) => load(
    current: () => feeSummary,
    set: (Loadable<FeeSummary> v) => feeSummary = v,
    fetch: _api.feeSummary,
    force: force,
  );

  Future<void> loadInvoices({bool force = false}) => load(
    current: () => invoices,
    set: (Loadable<List<AdminInvoice>> v) => invoices = v,
    fetch: _api.invoices,
    force: force,
  );
}

/// Caches the super-admin portal's sections.
class SuperAdminStore extends PortalStore {
  SuperAdminStore._();

  static final SuperAdminStore instance = SuperAdminStore._();

  final SuperAdminApi _api = SuperAdminApi.instance;

  Loadable<PlatformStats> stats = const Loadable<PlatformStats>.idle();
  Loadable<List<PlatformSchool>> schools = const Loadable<List<PlatformSchool>>.idle();
  Loadable<List<PlatformSubscription>> subscriptions =
      const Loadable<List<PlatformSubscription>>.idle();
  Loadable<List<SupportTicket>> tickets = const Loadable<List<SupportTicket>>.idle();

  @override
  void reset() {
    stats = const Loadable<PlatformStats>.idle();
    schools = const Loadable<List<PlatformSchool>>.idle();
    subscriptions = const Loadable<List<PlatformSubscription>>.idle();
    tickets = const Loadable<List<SupportTicket>>.idle();
    notifyListeners();
  }

  Future<void> loadStats({bool force = false}) => load(
    current: () => stats,
    set: (Loadable<PlatformStats> v) => stats = v,
    fetch: _api.dashboard,
    force: force,
  );

  Future<void> loadSchools({bool force = false}) => load(
    current: () => schools,
    set: (Loadable<List<PlatformSchool>> v) => schools = v,
    fetch: _api.schools,
    force: force,
  );

  Future<void> loadSubscriptions({bool force = false}) => load(
    current: () => subscriptions,
    set: (Loadable<List<PlatformSubscription>> v) => subscriptions = v,
    fetch: _api.subscriptions,
    force: force,
  );

  Future<void> loadTickets({bool force = false}) => load(
    current: () => tickets,
    set: (Loadable<List<SupportTicket>> v) => tickets = v,
    fetch: _api.tickets,
    force: force,
  );
}
