import { FeeReceipt } from '../shared/fee-receipt.component';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

/* ===================== Models (mirror the .NET admin DTOs) ===================== */

export interface AttendancePoint { date: string; percent: number; present: number; total: number; }

export interface AdminDashboard {
  schoolName: string;
  academicYear: string | null;
  totalStudents: number;
  totalTeachers: number;
  teachersOnLeave: number;
  totalClasses: number;
  totalSections: number;
  feesDue: number;
  feesBilled: number;
  feesCollected: number;
  feesOverdue: number;
  unpaidInvoices: number;
  /** null when nobody has marked attendance today. */
  attendanceToday: number | null;
  attendanceTrend: AttendancePoint[];
  recentAdmissions: { name: string; className: string | null; sectionName: string | null; admissionDate: string | null }[];
  latestNotices: NoticeDto[];
  /** Null for a school onboarded before plans existed. */
  subscription: SubscriptionStatus | null;
}

/**
 * The school's plan entitlement, computed server-side from the subscription's
 * end date and the plan's seat count — not from the stored status word, which
 * only changes when somebody edits the subscription.
 */
export interface SubscriptionStatus {
  planId: number | null;
  planName: string | null;
  status: string;
  isTrial: boolean;
  endDate: string | null;
  /** Negative once the end date has passed. */
  daysRemaining: number | null;
  studentCount: number;
  /** Null means the plan is unlimited. */
  maxStudents: number | null;
  atStudentCap: boolean;
  isLapsed: boolean;
  lapseReason: string | null;
  seatsRemaining: number | null;
  isExpiringSoon: boolean;
}

/** The guardian on a student, and whether they have a login yet. */
export interface ParentAccount {
  guardianId: number;
  name: string;
  relation: string;
  phone: string;
  email: string | null;
  username: string | null;
  hasLogin: boolean;
}

export interface CreateParentLogin {
  firstName?: string;
  lastName?: string;
  relation: string;
  phone?: string;
  email?: string;
}

/** One page of a list, with what a pager needs to know about the rest of the result. */
export interface Paged<T> {
  items: T[];
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}

/** Everything the roster endpoint filters and pages by. */
export interface StudentQuery {
  search?: string;
  className?: string;
  /** ISO dates (yyyy-mm-dd); both ends are inclusive. */
  admittedFrom?: string;
  admittedTo?: string;
  page?: number;
  pageSize?: number;
}

export interface StudentListItem {
  id: number;
  admissionNo: string;
  name: string;
  className: string | null;
  sectionName: string | null;
  rollNo: string | null;
  guardianName: string | null;
  guardianPhone: string | null;
  feeDue: number;
  status: string;
  admissionDate: string | null;
}
export interface StudentDetail extends StudentListItem {
  firstName: string; lastName: string;
  gender: string | null; dob: string | null; bloodGroup: string | null;
  email: string | null; phone: string | null;
  address: string | null; city: string | null; state: string | null; pincode: string | null;
  previousSchool: string | null;
  /** Transfer certificate number from the school the student left. */
  tcNo: string | null;
  admissionDate: string | null;
  stateId: number | null; cityId: number | null;
}
export interface SaveStudent {
  firstName: string; lastName: string;
  className?: string | null; sectionName?: string | null; rollNo?: string | null;
  gender?: string | null; dob?: string | null; bloodGroup?: string | null;
  email?: string | null; guardianName?: string | null; guardianPhone?: string | null;
  address?: string | null; city?: string | null; state?: string | null; pincode?: string | null;
  previousSchool?: string | null;
  /** Transfer certificate number from the school the student left. Optional. */
  tcNo?: string | null;
  /** Geography master ids; null when the typed name matched nothing. */
  stateId?: number | null; cityId?: number | null;
}

export interface TeacherListItem {
  id: number; employeeCode: string; name: string;
  /** The subjects joined for display; `subjects` carries them separately. */
  subject: string | null;
  /** Every subject this teacher can take — a teacher commonly takes more than one. */
  subjects: string[];
  phone: string | null; email: string | null; status: string;
  joiningDate: string | null;
  /** Section this teacher is class teacher of, e.g. "Grade 6 — A"; null when none. */
  classTeacherOf: string | null;
}
/** One qualification a teacher holds; institution and year are optional. */
export interface QualificationDto { name: string; institution: string | null; completionYear: number | null; }
export interface SaveQualification { name: string; institution: string | null; completionYear: number | null; }

export interface TeacherDetail extends TeacherListItem {
  firstName: string; lastName: string;
  /** Joined summary of `qualifications`, as stored on the staff row. */
  qualification: string | null;
  /** Each qualification separately, with its awarding body and year. */
  qualifications: QualificationDto[];
  /** Every subject this teacher can take. */
  subjects: string[];
  gender: string | null; dob: string | null;
  address: string | null; city: string | null; state: string | null; pincode: string | null;
  joiningDate: string | null;
  stateId: number | null; cityId: number | null;
}
export interface SaveTeacher {
  firstName: string; lastName: string;
  /** Legacy single value; ignored when `subjects` is supplied. */
  subject?: string | null;
  /** Every subject this teacher can take, by name. */
  subjects?: string[];
  phone?: string | null; email?: string | null;
  /** Legacy single value; ignored when `qualifications` is supplied. */
  qualification?: string | null;
  qualifications?: SaveQualification[];
  gender?: string | null; dob?: string | null;
  address?: string | null; city?: string | null; state?: string | null; pincode?: string | null;
  /** Geography master ids; null when the typed name matched nothing. */
  stateId?: number | null; cityId?: number | null;
}

/**
 * Login created alongside a new teacher or student, returned once. `temporaryPassword` is
 * plaintext and never retrievable again — only its bcrypt hash is stored — so it must be shown
 * immediately and never logged or persisted. `email` is null when the address was already in
 * use by another account, in which case the person signs in by username only.
 */
export interface GeneratedCredentials {
  userId: number;
  fullName: string;
  username: string;
  email: string | null;
  temporaryPassword: string;
}
/** Whether someone has a portal login, so a screen knows whether to offer a reset. */
export interface LoginSummary {
  hasLogin: boolean;
  username: string | null;
  /** A plain-English line about the account, or null when there is nothing worth saying. */
  lastPasswordChangeNote: string | null;
}

export interface CreateTeacherResult { id: number; employeeCode: string; credentials: GeneratedCredentials; }
export interface CreateStudentResult { id: number; admissionNo: string; rollNo: string | null; credentials: GeneratedCredentials; }

/** What became of one row of an uploaded admission sheet. */
export interface StudentImportRow {
  row: number; name: string;
  /** created | skipped | failed */
  status: string;
  message: string | null;
  admissionNo: string | null; rollNo: string | null;
  /** The login minted for the student — the password exists only in this response. */
  username: string | null; temporaryPassword: string | null;
}
export interface StudentImportResult {
  totalRows: number; created: number; skipped: number; failed: number;
  rows: StudentImportRow[];
}

export interface SectionDto { id: number; classId: number; name: string; teacher: string | null; studentCount: number; }
export interface ClassDto { id: number; name: string; sections: SectionDto[]; }

export interface NoticeDto {
  id: number; title: string; body: string; audience: string; publishDate: string;
  /** Author, so the board can show who posted it and offer a "Mine" filter. */
  createdBy: number; createdByName: string | null;
}

export interface StaffAttendanceRow { staffId: number; employeeCode: string | null; name: string; status: string; remarks: string | null; }
export interface StaffAttendanceSummary { present: number; absent: number; late: number; halfDay: number; onLeave: number; }
export interface LeaveTypeDto { id: number; name: string; isPaid: boolean; maxDaysPerYear: number | null; }
export interface LeaveApplicationDto {
  id: number; leaveTypeId: number; leaveTypeName: string | null; applicantName: string | null;
  fromDate: string; toDate: string; days: number; reason: string;
  status: string; reviewedByName: string | null; reviewedAt: string | null; reviewRemarks: string | null;
  createdAt: string;
}

export interface ClassSubjectOption { subjectId: number; name: string; selected: boolean; hasTeacher: boolean; }
export interface AssignmentCell { sectionId: number; sectionName: string; staffId: number | null; teacherName: string | null; }
export interface AssignmentRow { subjectId: number; subjectName: string; sections: AssignmentCell[]; }
/** Subject picks + the subject-teacher grid for one class, in the current academic year. */
export interface ClassCurriculum {
  classId: number; className: string; academicYear: string | null;
  subjects: ClassSubjectOption[];
  grid: AssignmentRow[];
}

export interface TimetablePeriod { periodNo: number; name: string; timeLabel: string; isBreak: boolean; }
/**
 * A period as the admin manages it. `periodNo` is its running position in the day (breaks
 * included) — the same number the grid cells are keyed on — and `scheduledCount` is how many
 * cells school-wide sit in it, so the screen can say what deleting it would strand.
 */
export interface Period {
  id: number; periodNo: number; name: string;
  startTime: string; endTime: string; durationMinutes: number;
  isBreak: boolean; scheduledCount: number;
}
/** A period is entered as a start time plus a duration; the end time is derived server-side. */
export interface SavePeriod {
  name: string; startTime: string; durationMinutes: number; isBreak: boolean;
}

export interface TimetableCell {
  dayOfWeek: number; periodNo: number;
  subject: string | null; teacherStaffId: number | null; teacherName: string | null; room: string | null;
}
/** A subject the class studies, with whoever is assigned to teach it to this section. */
export interface TimetableSubjectOption { subject: string; teacherStaffId: number | null; teacherName: string | null; }
export interface SectionTimetable {
  className: string; sectionName: string;
  periods: TimetablePeriod[];
  cells: TimetableCell[];
  subjects: TimetableSubjectOption[];
}
export interface DayRow {
  classId: number; className: string; sectionId: number; sectionName: string;
  cells: TimetableCell[];
  subjects: TimetableSubjectOption[];
}
/** Every section's periods for one day — the whole school on one grid. */
export interface DayTimetable { dayOfWeek: number; periods: TimetablePeriod[]; rows: DayRow[]; workingDays: number[]; }

export interface TeacherWeekCell {
  dayOfWeek: number; periodNo: number;
  className: string | null; sectionName: string | null; subject: string | null; room: string | null;
}
export interface TeacherAssignmentOption {
  classId: number; className: string; sectionId: number; sectionName: string; subject: string;
}
/** A period already taken in one of the teacher's sections — by them or a colleague. */
export interface SectionBusy {
  dayOfWeek: number; periodNo: number; className: string; sectionName: string;
  subject: string | null; teacherName: string | null;
}
export interface TeacherWeek {
  staffId: number; teacherName: string;
  periods: TimetablePeriod[];
  cells: TeacherWeekCell[];
  options: TeacherAssignmentOption[];
  sectionBusy: SectionBusy[];
  workingDays: number[];
}

export interface SaveTimetableSlot {
  className: string; sectionName: string; dayOfWeek: number; periodNo: number;
  subject: string | null; room: string | null;
  /** Overrides the subject's assigned teacher for this one period. */
  teacherStaffId: number | null;
}

export interface AcademicYearDto {
  id: number; name: string; startDate: string; endDate: string;
  isCurrent: boolean;
  /** Class-subject and teacher-assignment rows filed against this year. */
  usageCount: number;
}
export interface SaveAcademicYear { name: string; startDate: string; endDate: string; }

/** One class and the subjects it studies this year — what it may be examined in. */
export interface ClassSubjects { classId: number; className: string; subjects: string[]; }

export interface SubjectDto { id: number; name: string; code: string | null; subjectType: string; isActive: boolean; }
export interface SaveSubject { name: string; code?: string | null; subjectType: string; }

export interface AttendanceRow { studentId: number; rollNo: string | null; name: string; status: string; }
export interface AttendanceDay { date: string; day: string; status: string; }
export interface AttendanceReport { studentName: string; present: number; absent: number; late: number; schoolDays: number; percent: number; days: AttendanceDay[]; }
export interface ExamPaperDto { id: number; classLabel: string | null; subject: string; examDate: string | null; time: string | null; room: string | null; fullMarks: number; }
export interface ExamDto {
  id: number; name: string; type: string | null;
  startDate: string | null; endDate: string | null; classes: string | null;
  /** What to act on: the pinned status if an admin set one, else derived from the dates. */
  status: string;
  /** True when an admin pinned it, so the UI can show that the dates are being overridden. */
  isManualStatus: boolean;
  /** What the dates alone would say — shown against the "Auto" option. */
  derivedStatus: string;
  paperCount: number; papers: ExamPaperDto[];
}
/** What an Add Subject run did, per class. */
export interface AddPapersResult {
  created: number;
  scheduled: string[];
  alreadyScheduled: string[];
  /** Classes skipped because the subject is not on their curriculum. */
  notTaught: string[];
}

/** One section's sign-off state for an exam — the admin's publish checklist. */
export interface ExamApprovalDto {
  className: string; sectionName: string; status: string;
  approvedByName: string | null; approvedAt: string | null; remarks: string | null;
  studentCount: number; completeCount: number;
}
export interface FeeInvoiceDto { id: number; invoiceNo: string | null; studentName: string | null; classLabel: string | null; month: string | null; amount: number; paid: number; balance: number; dueDate: string | null; status: string; }
/** One fee head's share of an invoice total. */
/** One payment on an invoice, before its receipt is opened. */
export interface FeePaymentDto {
  id: number; receiptNo: string; amount: number;
  method: string | null; reference: string | null;
  paidDate: string | null; balanceAfter: number;
}

export interface FeeInvoiceLineDto { description: string; amount: number; }
export interface GenerateInvoicesResult {
  created: number;
  alreadyBilled: number;
  /** Classes skipped because the fee structure prices nothing for them. */
  unpricedClasses: string[];
  /** Riders billed without their bus — no distance recorded, or past the last band. */
  transportSkipped: string[];
  /** One-time or yearly charges left off because the student already had them. */
  repeatChargesSkipped: number;
  /** Existing invoices for the month that gained the charges they were missing. */
  toppedUp: number;
}

/** A charge the school levies. `inUse` counts the classes priced for it this year. */
export interface FeeHeadDto {
  id: number; name: string; description: string | null;
  frequency: string;
  /** 'class' takes the amount from the price grid; 'distance' takes it from the student. */
  pricingMode: string;
  isRefundable: boolean; isActive: boolean; inUse: number;
}
export interface SaveFeeHead {
  name: string; description?: string | null; frequency: string;
  pricingMode: string; isRefundable: boolean;
}

/* ---------------- transport, priced by distance ---------------- */

/** One distance band. `fromKm` is the band below's ceiling, so the table reads "3 – 6 km". */
export interface TransportSlabDto {
  id: number; fromKm: number; upToKm: number; amount: number; riders: number;
}
export interface SaveTransportSlab { upToKm: number; amount: number; }

/** A student on the assignment list, with what their distance currently earns. */
export interface TransportStudentDto {
  studentId: number;
  name: string;
  admissionNo: string;
  className: string | null;
  sectionName: string | null;
  usesTransport: boolean;
  distanceKm: number | null;
  pickupPoint: string | null;
  amountOverride: number | null;
  note: string | null;
  amount: number;
  /** priced | not_riding | no_distance | beyond_slabs | no_slabs */
  status: string;
  matchedSlabKm: number | null;
}
export interface SaveTransportStudent {
  studentId: number;
  usesTransport: boolean;
  distanceKm: number | null;
  pickupPoint: string | null;
  amountOverride: number | null;
  note: string | null;
}
export interface TransportSummary {
  riders: number; notRiding: number; needsDistance: number; beyondSlabs: number; monthlyTotal: number;
}
export interface TransportGrid {
  academicYearId: number | null;
  academicYearName: string | null;
  feeHeadId: number | null;
  feeHeadName: string | null;
  feeHeadFrequency: string | null;
  slabs: TransportSlabDto[];
  students: TransportStudentDto[];
  summary: TransportSummary;
}
export interface FeeStructureClass { classId: number; className: string; }
export interface FeeStructureCell { classId: number; headId: number; amount: number; }
/** Everything the Fee Structure grid draws for one academic year. */
export interface FeeStructureGrid {
  academicYearId: number | null;
  academicYearName: string | null;
  classes: FeeStructureClass[];
  heads: FeeHeadDto[];
  cells: FeeStructureCell[];
  /** Class name to what one monthly invoice comes to. */
  monthlyTotals: Record<string, number>;
}
export interface FeeSummaryDto { totalBilled: number; collected: number; outstanding: number; unpaid: number; overdue: number; }

/**
 * A payment a family says they have made, awaiting the office's confirmation. `invoiceBalance`
 * travels with it so a reviewer can see what is still owed without opening the invoice.
 */
export interface FeeSubmissionDto {
  id: number; invoiceId: number; invoiceNo: string | null;
  studentName: string | null; classLabel: string | null; month: string | null;
  amount: number; method: string; reference: string | null; paidDate: string;
  note: string | null; status: string; submittedAt: string;
  invoiceAmount: number; invoiceBalance: number;
  reviewedAt: string | null; reviewNote: string | null;
}

/* ===================== Service ===================== */

@Injectable({ providedIn: 'root' })
export class AdminApiService {
  private readonly http = inject(HttpClient);
  private readonly base = environment.adminApi;

  /** The guardian on a student; null when the school has never recorded one. */
  getParentAccount(studentId: number): Observable<ParentAccount | null> {
    return this.http.get<ParentAccount | null>(`${this.base}/students/${studentId}/parent-login`);
  }
  /** Issues the login. The password comes back once and is never stored in plaintext. */
  createParentLogin(studentId: number, dto: CreateParentLogin): Observable<GeneratedCredentials> {
    return this.http.post<GeneratedCredentials>(`${this.base}/students/${studentId}/parent-login`, dto);
  }

  getDashboard(): Observable<AdminDashboard> {
    return this.http.get<AdminDashboard>(`${this.base}/dashboard/stats`);
  }

  // Students
  /** The sample workbook, as a blob so the browser can save it. */
  studentImportTemplate(): Observable<Blob> {
    return this.http.get(`${this.base}/students/import/template`, { responseType: 'blob' });
  }
  /** `dryRun` checks the sheet and writes nothing, so an admin can look before leaping. */
  importStudents(file: File, dryRun: boolean): Observable<StudentImportResult> {
    const body = new FormData();
    body.append('file', file, file.name);
    return this.http.post<StudentImportResult>(`${this.base}/students/import`, body,
      { params: new HttpParams().set('dryRun', dryRun) });
  }

  /**
   * One page of the roster. Every filter is a query parameter rather than something applied to
   * the rows afterwards — a page that was filtered again on arrival would show fewer students
   * than the count beside the pager promises.
   */
  getStudents(opts: StudentQuery = {}): Observable<Paged<StudentListItem>> {
    let p = new HttpParams()
      .set('page', String(opts.page ?? 1))
      .set('pageSize', String(opts.pageSize ?? 25));
    if (opts.search) p = p.set('search', opts.search);
    if (opts.className) p = p.set('className', opts.className);
    if (opts.admittedFrom) p = p.set('admittedFrom', opts.admittedFrom);
    if (opts.admittedTo) p = p.set('admittedTo', opts.admittedTo);
    return this.http.get<Paged<StudentListItem>>(`${this.base}/students`, { params: p });
  }
  /** Next free roll number in a class/section — a preview; the server assigns the final one. */
  getNextRollNo(className: string, sectionName: string): Observable<{ rollNo: string }> {
    const p = new HttpParams().set('className', className).set('sectionName', sectionName);
    return this.http.get<{ rollNo: string }>(`${this.base}/students/next-roll`, { params: p });
  }
  getStudent(id: number): Observable<StudentDetail> {
    return this.http.get<StudentDetail>(`${this.base}/students/${id}`);
  }
  createStudent(dto: SaveStudent): Observable<CreateStudentResult> {
    return this.http.post<CreateStudentResult>(`${this.base}/students`, dto);
  }
  updateStudent(id: number, dto: SaveStudent): Observable<void> {
    return this.http.put<void>(`${this.base}/students/${id}`, dto);
  }
  setStudentStatus(id: number, status: string): Observable<void> {
    return this.http.patch<void>(`${this.base}/students/${id}/status`, { status });
  }

  // Teachers
  getTeachers(search?: string): Observable<TeacherListItem[]> {
    let p = new HttpParams();
    if (search) p = p.set('search', search);
    return this.http.get<TeacherListItem[]>(`${this.base}/teachers`, { params: p });
  }
  getTeacher(id: number): Observable<TeacherDetail> {
    return this.http.get<TeacherDetail>(`${this.base}/teachers/${id}`);
  }
  /* ---- password resets ordered by the school admin ---- */

  teacherLogin(id: number): Observable<LoginSummary> {
    return this.http.get<LoginSummary>(`${this.base}/teachers/${id}/login`);
  }
  studentLogin(id: number): Observable<LoginSummary> {
    return this.http.get<LoginSummary>(`${this.base}/students/${id}/login`);
  }
  /**
   * Issues a new password. `newPassword` null lets the server generate one, which is the normal
   * case. The password comes back in the response and exists nowhere else, so the caller must
   * show it before discarding it.
   */
  resetTeacherPassword(id: number, newPassword: string | null): Observable<GeneratedCredentials> {
    return this.http.post<GeneratedCredentials>(`${this.base}/teachers/${id}/reset-password`, { newPassword });
  }
  resetStudentPassword(id: number, newPassword: string | null): Observable<GeneratedCredentials> {
    return this.http.post<GeneratedCredentials>(`${this.base}/students/${id}/reset-password`, { newPassword });
  }
  resetParentPassword(studentId: number, newPassword: string | null): Observable<GeneratedCredentials> {
    return this.http.post<GeneratedCredentials>(`${this.base}/students/${studentId}/parent-login/reset-password`, { newPassword });
  }

  createTeacher(dto: SaveTeacher): Observable<CreateTeacherResult> {
    return this.http.post<CreateTeacherResult>(`${this.base}/teachers`, dto);
  }
  updateTeacher(id: number, dto: SaveTeacher): Observable<void> {
    return this.http.put<void>(`${this.base}/teachers/${id}`, dto);
  }
  setTeacherStatus(id: number, status: string): Observable<void> {
    return this.http.patch<void>(`${this.base}/teachers/${id}/status`, { status });
  }

  // Classes & sections
  getClasses(): Observable<ClassDto[]> {
    return this.http.get<ClassDto[]>(`${this.base}/classes`);
  }
  createClass(name: string, sectionName?: string, teacher?: string): Observable<{ id: number }> {
    return this.http.post<{ id: number }>(`${this.base}/classes`, { name, sectionName, teacher });
  }
  renameClass(id: number, name: string): Observable<void> {
    return this.http.put<void>(`${this.base}/classes/${id}`, { name });
  }
  deleteClass(id: number): Observable<void> {
    return this.http.delete<void>(`${this.base}/classes/${id}`);
  }
  addSection(classId: number, name: string, teacher?: string): Observable<{ id: number }> {
    return this.http.post<{ id: number }>(`${this.base}/classes/sections`, { classId, name, teacher });
  }
  updateSection(id: number, classId: number, name: string, teacher?: string): Observable<void> {
    return this.http.put<void>(`${this.base}/classes/sections/${id}`, { classId, name, teacher });
  }
  deleteSection(id: number): Observable<void> {
    return this.http.delete<void>(`${this.base}/classes/sections/${id}`);
  }

  // Notices
  getNotices(): Observable<NoticeDto[]> {
    return this.http.get<NoticeDto[]>(`${this.base}/notices`);
  }
  createNotice(title: string, body: string, audience: string): Observable<{ id: number }> {
    return this.http.post<{ id: number }>(`${this.base}/notices`, { title, body, audience });
  }
  updateNotice(id: number, title: string, body: string, audience: string): Observable<void> {
    return this.http.put<void>(`${this.base}/notices/${id}`, { title, body, audience });
  }
  deleteNotice(id: number): Observable<void> {
    return this.http.delete<void>(`${this.base}/notices/${id}`);
  }

  // Attendance
  getAttendance(className: string, sectionName: string, date: string): Observable<AttendanceRow[]> {
    const p = new HttpParams().set('className', className).set('sectionName', sectionName).set('date', date);
    return this.http.get<AttendanceRow[]>(`${this.base}/attendance`, { params: p });
  }
  saveAttendance(className: string, sectionName: string, date: string, entries: { studentId: number; status: string }[]): Observable<void> {
    return this.http.post<void>(`${this.base}/attendance`, { className, sectionName, date, entries });
  }
  attendanceReport(studentId: number, from: string, to: string): Observable<AttendanceReport> {
    const p = new HttpParams().set('studentId', studentId).set('from', from).set('to', to);
    return this.http.get<AttendanceReport>(`${this.base}/attendance/report`, { params: p });
  }

  // Exams
  getExams(): Observable<ExamDto[]> { return this.http.get<ExamDto[]>(`${this.base}/exams`); }
  /** Active subject names — backs the exam Add Subject dropdown. */
  getSubjects(): Observable<string[]> { return this.http.get<string[]>(`${this.base}/subjects/names`); }
  /** Cancel an exam, or reinstate a cancelled one ('scheduled'). */
  examApprovals(examId: number): Observable<ExamApprovalDto[]> {
    return this.http.get<ExamApprovalDto[]>(`${this.base}/exams/${examId}/approvals`);
  }
  setExamStatus(id: number, status: string): Observable<void> {
    return this.http.patch<void>(`${this.base}/exams/${id}/status`, { status });
  }

  updateExam(id: number, dto: { name: string; type?: string; startDate?: string | null; endDate?: string | null; classes?: string }): Observable<void> {
    return this.http.put<void>(`${this.base}/exams/${id}`, dto);
  }
  deleteExam(id: number): Observable<void> { return this.http.delete<void>(`${this.base}/exams/${id}`); }

  // Staff attendance
  getStaffAttendance(date: string): Observable<StaffAttendanceRow[]> {
    return this.http.get<StaffAttendanceRow[]>(`${this.base}/staff-attendance`, { params: new HttpParams().set('date', date) });
  }
  saveStaffAttendance(date: string, entries: { staffId: number; status: string; remarks?: string | null }[]): Observable<void> {
    return this.http.post<void>(`${this.base}/staff-attendance`, { date, entries });
  }
  getStaffAttendanceSummary(from: string, to: string): Observable<StaffAttendanceSummary> {
    return this.http.get<StaffAttendanceSummary>(`${this.base}/staff-attendance/summary`,
      { params: new HttpParams().set('from', from).set('to', to) });
  }

  // Leave (admin side)
  getLeaveTypes(): Observable<LeaveTypeDto[]> { return this.http.get<LeaveTypeDto[]>(`${this.base}/leave/types`); }
  /** Records leave for a staff member who reported it to the office. */
  applyLeaveForStaff(dto: { staffId: number; leaveTypeId: number; fromDate: string; toDate: string; reason: string; autoApprove: boolean }): Observable<{ id: number }> {
    return this.http.post<{ id: number }>(`${this.base}/leave`, dto);
  }
  createLeaveType(dto: { name: string; isPaid: boolean; maxDaysPerYear: number | null }): Observable<{ id: number }> {
    return this.http.post<{ id: number }>(`${this.base}/leave/types`, dto);
  }
  getLeaveApplications(status?: string): Observable<LeaveApplicationDto[]> {
    let p = new HttpParams();
    if (status) p = p.set('status', status);
    return this.http.get<LeaveApplicationDto[]>(`${this.base}/leave`, { params: p });
  }
  reviewLeave(id: number, status: string, remarks?: string | null): Observable<void> {
    return this.http.patch<void>(`${this.base}/leave/${id}/review`, { status, remarks });
  }

  // Subjects
  // Academic years
  getAcademicYears(): Observable<AcademicYearDto[]> {
    return this.http.get<AcademicYearDto[]>(`${this.base}/academic-years`);
  }
  createAcademicYear(dto: SaveAcademicYear): Observable<{ id: number }> {
    return this.http.post<{ id: number }>(`${this.base}/academic-years`, dto);
  }
  updateAcademicYear(id: number, dto: SaveAcademicYear): Observable<void> {
    return this.http.put<void>(`${this.base}/academic-years/${id}`, dto);
  }
  setCurrentAcademicYear(id: number): Observable<void> {
    return this.http.patch<void>(`${this.base}/academic-years/${id}/current`, {});
  }
  deleteAcademicYear(id: number): Observable<void> {
    return this.http.delete<void>(`${this.base}/academic-years/${id}`);
  }

  // Timetable
  getSectionTimetable(className: string, sectionName: string): Observable<SectionTimetable> {
    const p = new HttpParams().set('className', className).set('sectionName', sectionName);
    return this.http.get<SectionTimetable>(`${this.base}/timetable`, { params: p });
  }
  getDayTimetable(dayOfWeek: number): Observable<DayTimetable> {
    return this.http.get<DayTimetable>(`${this.base}/timetable/day/${dayOfWeek}`);
  }
  /** Suggests subjects for the day's empty periods without double-booking a teacher. */
  autoFillDay(dayOfWeek: number): Observable<{ filled: number; leftEmpty: number; notes: string[] }> {
    return this.http.post<{ filled: number; leftEmpty: number; notes: string[] }>(
      `${this.base}/timetable/day/${dayOfWeek}/autofill`, {});
  }
  setWorkingDays(days: number[]): Observable<void> {
    return this.http.put<void>(`${this.base}/timetable/working-days`, { days });
  }
  getTeacherWeek(staffId: number): Observable<TeacherWeek> {
    return this.http.get<TeacherWeek>(`${this.base}/timetable/teacher/${staffId}`);
  }
  /**
   * Clears the grid — one day, or the whole week when `dayOfWeek` is null. The period columns
   * and the school's working days are settings rather than content, so they survive a reset.
   */
  resetTimetable(dayOfWeek: number | null): Observable<{ cleared: number; scope: string }> {
    return this.http.post<{ cleared: number; scope: string }>(
      `${this.base}/timetable/reset`, { dayOfWeek });
  }
  /** The school's periods, each with the duration it runs for. */
  getPeriods(): Observable<Period[]> {
    return this.http.get<Period[]>(`${this.base}/timetable/periods`);
  }
  createPeriod(dto: SavePeriod): Observable<{ id: number }> {
    return this.http.post<{ id: number }>(`${this.base}/timetable/periods`, dto);
  }
  updatePeriod(id: number, dto: SavePeriod): Observable<void> {
    return this.http.put<void>(`${this.base}/timetable/periods/${id}`, dto);
  }
  deletePeriod(id: number): Observable<void> {
    return this.http.delete<void>(`${this.base}/timetable/periods/${id}`);
  }
  saveTimetableSlot(dto: SaveTimetableSlot): Observable<void> {
    return this.http.put<void>(`${this.base}/timetable/slot`, dto);
  }

  // Curriculum: class subjects + subject-teacher assignments
  /** Every class with the subjects it studies — one call, used to gate exam scheduling. */
  getSubjectsByClass(): Observable<ClassSubjects[]> {
    return this.http.get<ClassSubjects[]>(`${this.base}/curriculum/subjects-by-class`);
  }
  getClassCurriculum(classId: number): Observable<ClassCurriculum> {
    return this.http.get<ClassCurriculum>(`${this.base}/curriculum/classes/${classId}`);
  }
  setClassSubjects(classId: number, subjectIds: number[]): Observable<void> {
    return this.http.put<void>(`${this.base}/curriculum/classes/${classId}/subjects`, { subjectIds });
  }
  /** Unassigns every subject teacher for a class in one call. */
  clearSubjectTeachers(classId: number): Observable<{ cleared: number }> {
    return this.http.delete<{ cleared: number }>(`${this.base}/curriculum/classes/${classId}/assignments`);
  }
  assignSubjectTeacher(dto: { classId: number; sectionId: number; subjectId: number; staffId: number | null }): Observable<void> {
    return this.http.put<void>(`${this.base}/curriculum/assignments`, dto);
  }

  getSubjectList(): Observable<SubjectDto[]> { return this.http.get<SubjectDto[]>(`${this.base}/subjects`); }
  createSubject(dto: SaveSubject): Observable<{ id: number }> {
    return this.http.post<{ id: number }>(`${this.base}/subjects`, dto);
  }
  updateSubject(id: number, dto: SaveSubject): Observable<void> {
    return this.http.put<void>(`${this.base}/subjects/${id}`, dto);
  }
  setSubjectActive(id: number, value: boolean): Observable<void> {
    return this.http.patch<void>(`${this.base}/subjects/${id}/active?value=${value}`, {});
  }
  createExam(dto: { name: string; type?: string; startDate?: string | null; endDate?: string | null; classes?: string }): Observable<{ id: number }> {
    return this.http.post<{ id: number }>(`${this.base}/exams`, dto);
  }
  /** `classLabels` schedules the same paper across several classes in one call. */
  addPaper(dto: { examId: number; classLabels: string[]; subject: string; examDate?: string | null; time?: string; room?: string; fullMarks: number }): Observable<AddPapersResult> {
    return this.http.post<AddPapersResult>(`${this.base}/exams/papers`, dto);
  }
  deletePaper(id: number): Observable<void> { return this.http.delete<void>(`${this.base}/exams/papers/${id}`); }

  // Fees
  getInvoices(status?: string): Observable<FeeInvoiceDto[]> {
    let p = new HttpParams();
    if (status) p = p.set('status', status);
    return this.http.get<FeeInvoiceDto[]>(`${this.base}/fees/invoices`, { params: p });
  }
  feeSummary(): Observable<FeeSummaryDto> { return this.http.get<FeeSummaryDto>(`${this.base}/fees/summary`); }
  recordFeePayment(invoiceId: number, dto: { amount: number; method: string; ref?: string; paymentDate: string }): Observable<void> {
    return this.http.post<void>(`${this.base}/fees/invoices/${invoiceId}/payments`, dto);
  }
  /** Payments families have declared. Pending first, oldest first within that. */
  feeSubmissions(status?: string): Observable<FeeSubmissionDto[]> {
    let p = new HttpParams();
    if (status) p = p.set('status', status);
    return this.http.get<FeeSubmissionDto[]>(`${this.base}/fees/submissions`, { params: p });
  }
  /** Approving records the money against the invoice; rejecting returns the note to the family. */
  reviewFeeSubmission(id: number, approve: boolean, note: string | null): Observable<void> {
    return this.http.post<void>(`${this.base}/fees/submissions/${id}/review`, { approve, note });
  }
  /** Payments taken against one invoice, oldest first — one receipt each. */
  invoicePayments(invoiceId: number): Observable<FeePaymentDto[]> {
    return this.http.get<FeePaymentDto[]>(`${this.base}/fees/invoices/${invoiceId}/payments`);
  }
  /** The printable receipt for one payment. */
  paymentReceipt(paymentId: number): Observable<FeeReceipt> {
    return this.http.get<FeeReceipt>(`${this.base}/fees/payments/${paymentId}/receipt`);
  }
  invoiceLines(invoiceId: number): Observable<FeeInvoiceLineDto[]> {
    return this.http.get<FeeInvoiceLineDto[]>(`${this.base}/fees/invoices/${invoiceId}/lines`);
  }
  generateInvoices(month: string, dueDate: string, className: string, includeOneOff: boolean): Observable<GenerateInvoicesResult> {
    return this.http.post<GenerateInvoicesResult>(`${this.base}/fees/generate`, { month, dueDate, className, includeOneOff });
  }

  // Fee structure — where invoice amounts come from
  feeStructure(academicYearId?: number): Observable<FeeStructureGrid> {
    let p = new HttpParams();
    if (academicYearId) p = p.set('academicYearId', academicYearId);
    return this.http.get<FeeStructureGrid>(`${this.base}/fee-structure`, { params: p });
  }
  saveFeeStructure(academicYearId: number | null, cells: FeeStructureCell[]): Observable<void> {
    return this.http.put<void>(`${this.base}/fee-structure`, { academicYearId, cells });
  }
  copyFeeStructure(fromAcademicYearId: number, toAcademicYearId: number): Observable<{ copied: number }> {
    return this.http.post<{ copied: number }>(`${this.base}/fee-structure/copy`, { fromAcademicYearId, toAcademicYearId });
  }
  getFeeHeads(): Observable<FeeHeadDto[]> { return this.http.get<FeeHeadDto[]>(`${this.base}/fee-structure/heads`); }

  /* ---- transport ---- */

  transport(academicYearId?: number): Observable<TransportGrid> {
    let p = new HttpParams();
    if (academicYearId) p = p.set('academicYearId', academicYearId);
    return this.http.get<TransportGrid>(`${this.base}/transport`, { params: p });
  }
  /** Replaces the whole band set — bands only mean anything as a scale. */
  saveTransportSlabs(academicYearId: number | null, slabs: SaveTransportSlab[]): Observable<void> {
    return this.http.put<void>(`${this.base}/transport/slabs`, { academicYearId, slabs });
  }
  /** Writes only the students listed; everyone else keeps what they had. */
  saveTransportStudents(students: SaveTransportStudent[]): Observable<{ saved: number }> {
    return this.http.put<{ saved: number }>(`${this.base}/transport/students`, { students });
  }
  copyTransportSlabs(fromAcademicYearId: number, toAcademicYearId: number): Observable<{ copied: number }> {
    return this.http.post<{ copied: number }>(`${this.base}/transport/copy`, { fromAcademicYearId, toAcademicYearId });
  }
  createFeeHead(dto: SaveFeeHead): Observable<{ id: number }> { return this.http.post<{ id: number }>(`${this.base}/fee-structure/heads`, dto); }
  updateFeeHead(id: number, dto: SaveFeeHead): Observable<void> { return this.http.put<void>(`${this.base}/fee-structure/heads/${id}`, dto); }
  setFeeHeadActive(id: number, value: boolean): Observable<void> {
    return this.http.patch<void>(`${this.base}/fee-structure/heads/${id}/active`, {}, { params: new HttpParams().set('value', value) });
  }
}

/* ===================== Display helpers ===================== */

export function statusLabel(s: string): string {
  if (!s) return '';
  const t = s.replace(/_/g, ' ');
  return t.charAt(0).toUpperCase() + t.slice(1);
}
export function statusBadge(s: string): string {
  const t = s.replace(/_/g, ' ').toLowerCase();
  if (['active'].includes(t)) return 'success';
  if (['on leave', 'transferred'].includes(t)) return 'warning';
  if (['inactive', 'resigned', 'terminated', 'dropped'].includes(t)) return 'danger';
  return 'neutral';
}

/** Pull a readable message out of the API error envelope. */
export function adminApiError(err: unknown, fallback = 'Something went wrong.'): string {
  const e = err as { status?: number; error?: { message?: string }; message?: string };
  if (e?.status === 0) return 'Cannot reach the API. Is it running on the configured URL?';
  return e?.error?.message ?? e?.message ?? fallback;
}
