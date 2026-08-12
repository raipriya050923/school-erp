import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

/* ===================== Models (mirror the .NET admin DTOs) ===================== */

export interface AdminDashboard {
  totalStudents: number;
  totalTeachers: number;
  teachersOnLeave: number;
  totalClasses: number;
  feesDue: number;
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
}
export interface SaveStudent {
  firstName: string; lastName: string;
  className?: string | null; sectionName?: string | null; rollNo?: string | null;
  gender?: string | null; dob?: string | null; bloodGroup?: string | null;
  email?: string | null; guardianName?: string | null; guardianPhone?: string | null;
  address?: string | null; city?: string | null; state?: string | null; pincode?: string | null;
  previousSchool?: string | null;
}

export interface TeacherListItem {
  id: number; employeeCode: string; name: string;
  subject: string | null; classesTaught: string | null;
  phone: string | null; email: string | null; status: string;
  joiningDate: string | null;
}
export interface TeacherDetail extends TeacherListItem {
  firstName: string; lastName: string; qualification: string | null;
  gender: string | null; dob: string | null;
  address: string | null; city: string | null; state: string | null; pincode: string | null;
  joiningDate: string | null;
}
export interface SaveTeacher {
  firstName: string; lastName: string;
  subject?: string | null; classesTaught?: string | null;
  phone?: string | null; email?: string | null; qualification?: string | null;
  gender?: string | null; dob?: string | null;
  address?: string | null; city?: string | null; state?: string | null; pincode?: string | null;
}

export interface SectionDto { id: number; classId: number; name: string; teacher: string | null; studentCount: number; }
export interface ClassDto { id: number; name: string; sections: SectionDto[]; }

export interface NoticeDto { id: number; title: string; body: string; audience: string; publishDate: string; }

export interface AttendanceRow { studentId: number; rollNo: string | null; name: string; status: string; }
export interface AttendanceDay { date: string; day: string; status: string; }
export interface AttendanceReport { studentName: string; present: number; absent: number; late: number; schoolDays: number; percent: number; days: AttendanceDay[]; }
export interface ExamPaperDto { id: number; classLabel: string | null; subject: string; examDate: string | null; time: string | null; room: string | null; fullMarks: number; }
export interface ExamDto { id: number; name: string; type: string | null; startDate: string | null; endDate: string | null; classes: string | null; status: string; paperCount: number; papers: ExamPaperDto[]; }
export interface FeeInvoiceDto { id: number; invoiceNo: string | null; studentName: string | null; classLabel: string | null; month: string | null; amount: number; paid: number; balance: number; dueDate: string | null; status: string; }
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
  getStudent(id: number): Observable<StudentDetail> {
    return this.http.get<StudentDetail>(`${this.base}/students/${id}`);
  }
  createStudent(dto: SaveStudent): Observable<{ id: number }> {
    return this.http.post<{ id: number }>(`${this.base}/students`, dto);
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
  createTeacher(dto: SaveTeacher): Observable<{ id: number }> {
    return this.http.post<{ id: number }>(`${this.base}/teachers`, dto);
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
  createExam(dto: { name: string; type?: string; startDate?: string | null; endDate?: string | null; classes?: string }): Observable<{ id: number }> {
    return this.http.post<{ id: number }>(`${this.base}/exams`, dto);
  }
  addPaper(dto: { examId: number; classLabel?: string; subject: string; examDate?: string | null; time?: string; room?: string; fullMarks: number }): Observable<{ id: number }> {
    return this.http.post<{ id: number }>(`${this.base}/exams/papers`, dto);
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
  generateInvoices(month: string, dueDate: string, className: string): Observable<{ created: number }> {
    return this.http.post<{ created: number }>(`${this.base}/fees/generate`, { month, dueDate, className });
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
