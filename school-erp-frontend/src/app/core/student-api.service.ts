import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface StudentHomework { title: string; subject: string | null; dueDate: string | null; status: string; }
export interface StudentDashboard {
  name: string; className: string | null; sectionName: string | null; rollNo: string | null;
  attendancePercent: number; presentDays: number; totalDays: number;
  pendingHomework: number; nextExamName: string | null; nextExamDate: string | null; feeDue: number;
  upcomingHomework: StudentHomework[];
}
export interface AttendanceMonth { month: string; present: number; absent: number; late: number; percent: number; }
export interface AttendanceRecent { date: string; day: string; status: string; }
export interface StudentAttendance { overallPercent: number; presentDays: number; totalDays: number; months: AttendanceMonth[]; recent: AttendanceRecent[]; }
export interface StudentTimetableSlot { dayOfWeek: number; periodNo: number; time: string | null; subject: string | null; room: string | null; }
export interface StudentResult { subject: string; fullMarks: number; marks: number | null; grade: string; }
export interface UpcomingPaper { date: string | null; subject: string; time: string | null; room: string | null; }
export interface StudentExams { examName: string | null; total: number; fullTotal: number; percent: number; grade: string; results: StudentResult[]; upcoming: UpcomingPaper[]; }
export interface StudentFee { invoiceNo: string | null; month: string | null; amount: number; paid: number; balance: number; dueDate: string | null; status: string; }
export interface StudentNotice { id: number; title: string; body: string; audience: string; publishDate: string; }

@Injectable({ providedIn: 'root' })
export class StudentApiService {
  private readonly http = inject(HttpClient);
  private readonly base = environment.studentApi;

  getDashboard(): Observable<StudentDashboard> { return this.http.get<StudentDashboard>(`${this.base}/dashboard/stats`); }
  getAttendance(): Observable<StudentAttendance> { return this.http.get<StudentAttendance>(`${this.base}/attendance`); }
  getTimetable(): Observable<StudentTimetableSlot[]> { return this.http.get<StudentTimetableSlot[]>(`${this.base}/timetable`); }
  getHomework(): Observable<StudentHomework[]> { return this.http.get<StudentHomework[]>(`${this.base}/homework`); }
  getExams(): Observable<StudentExams> { return this.http.get<StudentExams>(`${this.base}/exams`); }
  getFees(): Observable<StudentFee[]> { return this.http.get<StudentFee[]>(`${this.base}/fees`); }
  getNotices(): Observable<StudentNotice[]> { return this.http.get<StudentNotice[]>(`${this.base}/notices`); }
}

export function feeBadge(s: string): string {
  switch (s) { case 'paid': return 'success'; case 'partial': return 'warning'; case 'overdue': case 'unpaid': return 'danger'; default: return 'info'; }
}
export function attBadge(s: string): string {
  switch (s) { case 'Present': return 'success'; case 'Late': return 'warning'; case 'Absent': return 'danger'; default: return 'neutral'; }
}
export function cap(s: string): string { return s ? s.charAt(0).toUpperCase() + s.slice(1) : ''; }
export function studentApiError(err: unknown, fallback = 'Something went wrong.'): string {
  const e = err as { status?: number; error?: { message?: string }; message?: string };
  if (e?.status === 0) return 'Cannot reach the API. Is it running on the configured URL?';
  return e?.error?.message ?? e?.message ?? fallback;
}
