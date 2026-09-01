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
  previousSchool: string | null; admissionDate: string | null;
  stateId: number | null; cityId: number | null;
}
export interface SaveStudent {
  firstName: string; lastName: string;
  className?: string | null; sectionName?: string | null; rollNo?: string | null;
  gender?: string | null; dob?: string | null; bloodGroup?: string | null;
  email?: string | null; guardianName?: string | null; guardianPhone?: string | null;
  address?: string | null; city?: string | null; state?: string | null; pincode?: string | null;
  previousSchool?: string | null;
  /** Geography master ids; null when the typed name matched nothing. */
  stateId?: number | null; cityId?: number | null;
}

export interface TeacherListItem {
  id: number; employeeCode: string; name: string;
  subject: string | null;
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
  gender: string | null; dob: string | null;
  address: string | null; city: string | null; state: string | null; pincode: string | null;
  joiningDate: string | null;
  stateId: number | null; cityId: number | null;
}
export interface SaveTeacher {
  firstName: string; lastName: string;
  subject?: string | null;
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
export interface CreateTeacherResult { id: number; employeeCode: string; credentials: GeneratedCredentials; }
export interface CreateStudentResult { id: number; admissionNo: string; rollNo: string | null; credentials: GeneratedCredentials; }

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
export interface AddPapersResult { created: number; scheduled: string[]; alreadyScheduled: string[]; }

/** One section's sign-off state for an exam — the admin's publish checklist. */
export interface ExamApprovalDto {
  className: string; sectionName: string; status: string;
  approvedByName: string | null; approvedAt: string | null; remarks: string | null;
  studentCount: number; completeCount: number;
}
export interface FeeInvoiceDto { id: number; invoiceNo: string | null; studentName: string | null; classLabel: string | null; month: string | null; amount: number; paid: number; balance: number; dueDate: string | null; status: string; }
/** One fee head's share of an invoice total. */
export interface FeeInvoiceLineDto { description: string; amount: number; }
export interface GenerateInvoicesResult {
  created: number;
  alreadyBilled: number;
  /** Classes skipped because the fee structure prices nothing for them. */
  unpricedClasses: string[];
}

/** A charge the school levies. `inUse` counts the classes priced for it this year. */
export interface FeeHeadDto {
  id: number; name: string; description: string | null;
  frequency: string; isRefundable: boolean; isActive: boolean; inUse: number;
}
export interface SaveFeeHead { name: string; description?: string | null; frequency: string; isRefundable: boolean; }
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

/* ===================== Service ===================== */

@Injectable({ providedIn: 'root' })
export class AdminApiService {
  private readonly http = inject(HttpClient);
  private readonly base = environment.adminApi;

  getDashboard(): Observable<AdminDashboard> {
    return this.http.get<AdminDashboard>(`${this.base}/dashboard/stats`);
  }

  // Students
  getStudents(search?: string, className?: string): Observable<StudentListItem[]> {
    let p = new HttpParams();
    if (search) p = p.set('search', search);
    if (className) p = p.set('className', className);
    return this.http.get<StudentListItem[]>(`${this.base}/students`, { params: p });
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
  saveTimetableSlot(dto: SaveTimetableSlot): Observable<void> {
    return this.http.put<void>(`${this.base}/timetable/slot`, dto);
  }

  // Curriculum: class subjects + subject-teacher assignments
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
