import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface TeacherProfile {
  id: number; employeeCode: string; name: string;
  subject: string | null; classesTaught: string | null;
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
export interface MarkRow { studentId: number; rollNo: string | null; name: string; marks: number | null; }
export interface TimetableSlot { dayOfWeek: number; periodNo: number; time: string | null; label: string | null; room: string | null; }

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
  getMarks(examId: number, className: string, sectionName: string, subject: string): Observable<MarkRow[]> {
    const p = new HttpParams().set('examId', examId).set('className', className).set('sectionName', sectionName).set('subject', subject);
    return this.http.get<MarkRow[]>(`${this.base}/marks`, { params: p });
  }
  saveMarks(examId: number, className: string, sectionName: string, subject: string, fullMarks: number, entries: { studentId: number; marks: number | null }[]): Observable<void> {
    return this.http.post<void>(`${this.base}/marks`, { examId, className, sectionName, subject, fullMarks, entries });
  }

  // Timetable
  getTimetable(): Observable<TimetableSlot[]> { return this.http.get<TimetableSlot[]>(`${this.base}/timetable`); }
}

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
