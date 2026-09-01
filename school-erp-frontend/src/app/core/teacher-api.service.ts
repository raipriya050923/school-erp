import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface TeacherProfile {
  id: number; employeeCode: string; name: string;
  subject: string | null;
  phone: string | null; email: string | null; qualification: string | null; joiningDate: string | null;
}
export interface MyClass {
  sectionId: number; className: string; sectionName: string;
  subject: string | null; room: string | null; studentCount: number; isClassTeacher: boolean;
}
export interface RosterStudent { id: number; rollNo: string | null; name: string; }
export interface Homework {
  id: number; title: string; subject: string | null; classLabel: string | null;
  assignedDate: string | null; dueDate: string | null; submitted: number; total: number; status: string;
}
export interface TeacherDashboard {
  profile: TeacherProfile;
  myClassesCount: number;
  studentsTaught: number;
  submissionsToGrade: number;
  openHomework: number;
  recentHomework: Homework[];
}
export interface AttendanceRow { studentId: number; rollNo: string | null; name: string; status: string; }
export interface ExamPaper { id: number; classLabel: string | null; subject: string; examDate: string | null; time: string | null; room: string | null; fullMarks: number; }
export interface Exam { id: number; name: string; type: string | null; startDate: string | null; endDate: string | null; classes: string | null; status: string; paperCount: number; papers: ExamPaper[]; }
/**
 * A section this teacher may enter marks for, and which subjects of it. Driven by their subject
 * assignments, so it covers sections they teach without being class teacher of, and leaves out
 * subjects another teacher holds.
 */
export interface TeachingSection { className: string; sectionName: string; studentCount: number; subjects: string[]; }

/** One row of the marks grid: a student and their mark for each subject, keyed by subject name. */
export interface MarksGridStudent {
  studentId: number; rollNo: string | null; name: string;
  marks: Record<string, number | null>;
}
export interface MarksGridSubject { subject: string; fullMarks: number; examDate: string | null; }
export interface MarksGrid { subjects: MarksGridSubject[]; students: MarksGridStudent[]; }

/** One paper of an exam, with how much of the section has been marked. */
export interface MarksProgress {
  subject: string; fullMarks: number; examDate: string | null;
  entered: number; total: number;
}
/* ---- class teacher's result review ---- */

export interface MyClassSection { className: string; sectionName: string; studentCount: number; }
export interface ClassResultSubject {
  subject: string; fullMarks: number; entered: number; total: number; teacherName: string | null;
}
export interface ClassResultStudent {
  studentId: number; rollNo: string | null; name: string;
  marks: Record<string, number | null>;
  /** Stored figures, written when marks were last saved — not recomputed in the browser. */
  total: number; fullTotal: number; percent: number; grade: string; missing: number;
  /** False while a paper is unmarked: the percentage is real but can still rise. */
  isComplete: boolean;
}
export interface ClassResult {
  examId: number; examName: string; examStatus: string; isPublished: boolean;
  className: string; sectionName: string;
  subjects: ClassResultSubject[]; students: ClassResultStudent[]; missingMarks: number;
  /** pending | approved — whether this section's class teacher has signed the sheet off. */
  approvalStatus: string;
  approvedByName: string | null;
  approvedAt: string | null;
  approvalRemarks: string | null;
  /** True once every student has every paper marked. */
  canApprove: boolean;
}

export interface TimetableSlot { dayOfWeek: number; periodNo: number; time: string | null; label: string | null; room: string | null; }
export interface TimetablePeriod { periodNo: number; name: string; timeLabel: string; isBreak: boolean; }
/** Columns travel with the slots: period numbers include breaks, so a fixed 1..6 grid mislabels them. */
export interface TeacherTimetable { periods: TimetablePeriod[]; slots: TimetableSlot[]; }

@Injectable({ providedIn: 'root' })
export class TeacherApiService {
  private readonly http = inject(HttpClient);
  private readonly base = environment.teacherApi;

  getDashboard(): Observable<TeacherDashboard> {
    return this.http.get<TeacherDashboard>(`${this.base}/dashboard/stats`);
  }
  getProfile(): Observable<TeacherProfile> {
    return this.http.get<TeacherProfile>(`${this.base}/profile`);
  }
  getMyClasses(): Observable<MyClass[]> {
    return this.http.get<MyClass[]>(`${this.base}/classes`);
  }
  getRoster(className: string, sectionName: string): Observable<RosterStudent[]> {
    const p = new HttpParams().set('className', className).set('sectionName', sectionName);
    return this.http.get<RosterStudent[]>(`${this.base}/classes/roster`, { params: p });
  }
  getHomework(): Observable<Homework[]> {
    return this.http.get<Homework[]>(`${this.base}/homework`);
  }
  createHomework(title: string, subject: string, classLabel: string, dueDate: string, totalCount: number): Observable<{ id: number }> {
    return this.http.post<{ id: number }>(`${this.base}/homework`, { title, subject, classLabel, dueDate, totalCount });
  }

  // Attendance
  getAttendance(className: string, sectionName: string, date: string): Observable<AttendanceRow[]> {
    const p = new HttpParams().set('className', className).set('sectionName', sectionName).set('date', date);
    return this.http.get<AttendanceRow[]>(`${this.base}/attendance`, { params: p });
  }
  saveAttendance(className: string, sectionName: string, date: string, entries: { studentId: number; status: string }[]): Observable<void> {
    return this.http.post<void>(`${this.base}/attendance`, { className, sectionName, date, entries });
  }

  // Marks
  getExams(): Observable<Exam[]> { return this.http.get<Exam[]>(`${this.base}/exams`); }
  marksProgress(examId: number, className: string, sectionName: string): Observable<MarksProgress[]> {
    const p = new HttpParams().set('examId', examId).set('className', className).set('sectionName', sectionName);
    return this.http.get<MarksProgress[]>(`${this.base}/marks/progress`, { params: p });
  }
  teachingSections(): Observable<TeachingSection[]> {
    return this.http.get<TeachingSection[]>(`${this.base}/marks/sections`);
  }
  marksGrid(examId: number, className: string, sectionName: string): Observable<MarksGrid> {
    const p = new HttpParams().set('examId', examId).set('className', className).set('sectionName', sectionName);
    return this.http.get<MarksGrid>(`${this.base}/marks/grid`, { params: p });
  }
  saveMarksGrid(examId: number, className: string, sectionName: string,
                entries: { studentId: number; subject: string; marks: number | null }[]): Observable<{ saved: number }> {
    return this.http.post<{ saved: number }>(`${this.base}/marks/grid`, { examId, className, sectionName, entries });
  }

  // Results — read-only review of a section this teacher is class teacher of
  myClassSections(): Observable<MyClassSection[]> {
    return this.http.get<MyClassSection[]>(`${this.base}/results/sections`);
  }
  approveResult(examId: number, className: string, sectionName: string, approve: boolean, remarks?: string): Observable<void> {
    return this.http.post<void>(`${this.base}/results/approve`, { examId, className, sectionName, approve, remarks });
  }
  classResult(examId: number, className: string, sectionName: string): Observable<ClassResult> {
    const p = new HttpParams().set('examId', examId).set('className', className).set('sectionName', sectionName);
    return this.http.get<ClassResult>(`${this.base}/results/class`, { params: p });
  }

  // Timetable
  getTimetable(): Observable<TeacherTimetable> { return this.http.get<TeacherTimetable>(`${this.base}/timetable`); }

  // My leave — the service scopes every read and write to the signed-in teacher
  getMyLeave(): Observable<LeaveApplication[]> {
    return this.http.get<LeaveApplication[]>(`${this.base}/leave`);
  }
  getLeaveTypes(): Observable<LeaveType[]> {
    return this.http.get<LeaveType[]>(`${this.base}/leave/types`);
  }
  applyLeave(dto: ApplyLeave): Observable<{ id: number }> {
    return this.http.post<{ id: number }>(`${this.base}/leave`, dto);
  }
}

export interface LeaveType { id: number; name: string; isPaid: boolean; maxDaysPerYear: number | null; }
export interface LeaveApplication {
  id: number; leaveTypeId: number; leaveTypeName: string | null; applicantName: string | null;
  fromDate: string; toDate: string; days: number; reason: string;
  status: string; reviewedByName: string | null; reviewedAt: string | null; reviewRemarks: string | null;
  createdAt: string;
}
export interface ApplyLeave { leaveTypeId: number; fromDate: string; toDate: string; reason: string; }

export function hwStatusBadge(s: string): string {
  switch (s.toLowerCase()) {
    case 'graded': return 'success';
    case 'grading': return 'warning';
    case 'open': return 'info';
    default: return 'neutral';
  }
}
export function hwStatusLabel(s: string): string {
  return s ? s.charAt(0).toUpperCase() + s.slice(1) : '';
}
export function teacherApiError(err: unknown, fallback = 'Something went wrong.'): string {
  const e = err as { status?: number; error?: { message?: string }; message?: string };
  if (e?.status === 0) return 'Cannot reach the API. Is it running on the configured URL?';
  return e?.error?.message ?? e?.message ?? fallback;
}
