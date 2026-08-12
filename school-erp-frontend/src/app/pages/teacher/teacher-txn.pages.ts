import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import {
  TeacherApiService, teacherApiError,
  MyClass, AttendanceRow, Exam, MarkRow, TimetableSlot,
} from '../../core/teacher-api.service';

/* =====================  ATTENDANCE  ===================== */

@Component({
  selector: 'app-t-attendance',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page-head"><div class="grow"><h1>Student Attendance</h1><div class="page-sub">Mark attendance for your class</div></div></div>

    <div class="card">
      <div class="card-head filters">
        <input class="input" type="date" [(ngModel)]="date" (ngModelChange)="load()" />
        <select class="select" [(ngModel)]="section" (ngModelChange)="load()">
          @for (c of classes; track c.sectionId) { <option [value]="c.className + '|' + c.sectionName">{{ c.className }} — {{ c.sectionName }}</option> }
        </select>
        <div class="grow"></div>
        <span class="td-sub">{{ presentCount }}/{{ rows.length }} present</span>
        <button class="btn btn-ghost btn-sm" (click)="markAll('present')">All Present</button>
        <button class="btn btn-primary" (click)="save()" [disabled]="saving">{{ saving ? 'Saving…' : 'Save' }}</button>
      </div>
      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th class="num">Roll</th><th>Student</th><th>Status</th></tr></thead>
            <tbody>
              @for (r of rows; track r.studentId) {
                <tr>
                  <td class="num">{{ r.rollNo }}</td>
                  <td class="td-main">{{ r.name }}</td>
                  <td>
                    <div class="pill-group">
                      <button [class.on-p]="r.status === 'present'" (click)="r.status = 'present'">Present</button>
                      <button [class.on-a]="r.status === 'absent'" (click)="r.status = 'absent'">Absent</button>
                      <button [class.on-l]="r.status === 'late'" (click)="r.status = 'late'">Late</button>
                    </div>
                  </td>
                </tr>
              } @empty { <tr><td colspan="3"><div class="empty">No students in this section.</div></td></tr> }
            </tbody>
          </table>
        </div>
      }
    </div>
    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class TAttendanceComponent implements OnInit {
  private readonly api = inject(TeacherApiService);
  classes: MyClass[] = [];
  rows: AttendanceRow[] = [];
  section = '';
  date = '2026-07-05';
  loading = true;
  error = '';
  saving = false;
  toast = '';
  private timer?: ReturnType<typeof setTimeout>;

  get presentCount(): number { return this.rows.filter(r => r.status === 'present').length; }

  ngOnInit(): void {
    this.api.getMyClasses().subscribe({
      next: c => { this.classes = c; if (c.length) { this.section = c[0].className + '|' + c[0].sectionName; this.load(); } else { this.loading = false; } },
      error: e => { this.error = teacherApiError(e); this.loading = false; },
    });
  }
  load(): void {
    if (!this.section) return;
    const [cls, sec] = this.section.split('|');
    this.loading = true;
    this.api.getAttendance(cls, sec, this.date).subscribe({
      next: r => { this.rows = r; this.loading = false; this.error = ''; },
      error: e => { this.error = teacherApiError(e); this.loading = false; },
    });
  }
  markAll(s: string): void { this.rows.forEach(r => r.status = s); }
  save(): void {
    const [cls, sec] = this.section.split('|');
    this.saving = true;
    this.api.saveAttendance(cls, sec, this.date, this.rows.map(r => ({ studentId: r.studentId, status: r.status }))).subscribe({
      next: () => { this.saving = false; this.showToast(`Attendance saved — ${this.presentCount}/${this.rows.length} present`); },
      error: e => { this.saving = false; alert(teacherApiError(e)); },
    });
  }
  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }
}

/* =====================  MARKS ENTRY  ===================== */

@Component({
  selector: 'app-t-marks',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page-head"><div class="grow"><h1>Marks Entry</h1><div class="page-sub">Enter exam marks for your class</div></div></div>

    <div class="card">
      <div class="card-head filters">
        <select class="select" [(ngModel)]="examId" (ngModelChange)="load()">
          @for (e of exams; track e.id) { <option [value]="e.id">{{ e.name }}</option> }
        </select>
        <select class="select" [(ngModel)]="section" (ngModelChange)="load()">
          @for (c of classes; track c.sectionId) { <option [value]="c.className + '|' + c.sectionName">{{ c.className }} — {{ c.sectionName }}</option> }
        </select>
        <input class="input" style="max-width:150px;" [(ngModel)]="subject" placeholder="Subject" (keyup.enter)="load()" />
        <div class="grow"></div>
        <span class="td-sub">Avg: {{ average }}%</span>
        <button class="btn btn-primary" (click)="save()" [disabled]="saving">{{ saving ? 'Saving…' : 'Submit Marks' }}</button>
      </div>
      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th class="num">Roll</th><th>Student</th><th style="width:150px;">Marks / {{ fullMarks }}</th><th>Grade</th></tr></thead>
            <tbody>
              @for (r of rows; track r.studentId) {
                <tr>
                  <td class="num">{{ r.rollNo }}</td>
                  <td class="td-main">{{ r.name }}</td>
                  <td><input class="input" type="number" min="0" [max]="fullMarks" style="width:90px;" [(ngModel)]="r.marks" /></td>
                  <td><span class="badge" [class]="'badge ' + gradeBadge(r.marks)">{{ grade(r.marks) }}</span></td>
                </tr>
              } @empty { <tr><td colspan="4"><div class="empty">Pick an exam, section and subject.</div></td></tr> }
            </tbody>
          </table>
        </div>
      }
    </div>
    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class TMarksComponent implements OnInit {
  private readonly api = inject(TeacherApiService);
  exams: Exam[] = [];
  classes: MyClass[] = [];
  rows: MarkRow[] = [];
  examId = 0;
  section = '';
  subject = 'Mathematics';
  fullMarks = 100;
  loading = true;
  error = '';
  saving = false;
  toast = '';
  private ready = 0;
  private timer?: ReturnType<typeof setTimeout>;

  get average(): number {
    const vals = this.rows.map(r => Number(r.marks)).filter(n => !isNaN(n));
    return vals.length ? Math.round(vals.reduce((a, b) => a + b, 0) / vals.length) : 0;
  }

  ngOnInit(): void {
    this.api.getExams().subscribe({ next: e => { this.exams = e; if (e.length) this.examId = e[0].id; this.maybeLoad(); }, error: e => { this.error = teacherApiError(e); this.loading = false; } });
    this.api.getMyClasses().subscribe({ next: c => { this.classes = c; if (c.length) this.section = c[0].className + '|' + c[0].sectionName; this.maybeLoad(); }, error: () => {} });
  }
  private maybeLoad(): void { if (++this.ready >= 2) this.load(); }
  load(): void {
    if (!this.examId || !this.section || !this.subject.trim()) { this.loading = false; return; }
    const [cls, sec] = this.section.split('|');
    this.loading = true;
    this.api.getMarks(Number(this.examId), cls, sec, this.subject.trim()).subscribe({
      next: r => { this.rows = r; this.loading = false; this.error = ''; },
      error: e => { this.error = teacherApiError(e); this.loading = false; },
    });
  }
  save(): void {
    const [cls, sec] = this.section.split('|');
    this.saving = true;
    this.api.saveMarks(Number(this.examId), cls, sec, this.subject.trim(), this.fullMarks,
      this.rows.map(r => ({ studentId: r.studentId, marks: r.marks == null || (r.marks as unknown as string) === '' ? null : Number(r.marks) }))).subscribe({
      next: () => { this.saving = false; this.showToast(`Marks submitted · class average ${this.average}%`); },
      error: e => { this.saving = false; alert(teacherApiError(e)); },
    });
  }
  grade(m: number | null): string {
    if (m == null) return '—';
    const pct = (Number(m) / this.fullMarks) * 100;
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B+';
    if (pct >= 60) return 'B';
    if (pct >= 50) return 'C+';
    if (pct >= 40) return 'C';
    return 'NG';
  }
  gradeBadge(m: number | null): string {
    if (m == null) return 'neutral';
    const pct = (Number(m) / this.fullMarks) * 100;
    if (pct >= 80) return 'success';
    if (pct >= 60) return 'info';
    if (pct >= 40) return 'warning';
    return 'danger';
  }
  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }
}

/* =====================  TIMETABLE  ===================== */

@Component({
  selector: 'app-t-timetable',
  standalone: true,
  template: `
    <div class="page-head"><div class="grow"><h1>My Timetable</h1><div class="page-sub">Weekly teaching schedule</div></div></div>
    @if (loading) { <div class="card"><div class="empty">Loading…</div></div> }
    @else if (error) { <div class="card"><div class="empty">{{ error }}</div></div> }
    @else {
      <div class="card">
        <div class="table-wrap">
          <table class="tt-grid">
            <thead><tr><th>Day</th>@for (p of periods; track p) { <th>P{{ p }}</th> }</tr></thead>
            <tbody>
              @for (d of days; track d.num) {
                <tr>
                  <th>{{ d.label }}</th>
                  @for (p of periods; track p) {
                    <td>
                      @if (slot(d.num, p); as s) {
                        <div class="tt-subject">{{ s.label }}</div>
                        <div class="tt-meta">{{ s.time }} · {{ s.room }}</div>
                      } @else { <span class="tt-meta">—</span> }
                    </td>
                  }
                </tr>
              }
            </tbody>
          </table>
        </div>
      </div>
    }
  `,
})
export class TTimetableComponent implements OnInit {
  private readonly api = inject(TeacherApiService);
  slots: TimetableSlot[] = [];
  loading = true;
  error = '';
  readonly days = [
    { num: 1, label: 'Sunday' }, { num: 2, label: 'Monday' }, { num: 3, label: 'Tuesday' },
    { num: 4, label: 'Wednesday' }, { num: 5, label: 'Thursday' }, { num: 6, label: 'Friday' },
  ];
  readonly periods = [1, 2, 3, 4, 5, 6];

  ngOnInit(): void {
    this.api.getTimetable().subscribe({
      next: s => { this.slots = s; this.loading = false; },
      error: e => { this.error = teacherApiError(e); this.loading = false; },
    });
  }
  slot(day: number, period: number): TimetableSlot | null {
    return this.slots.find(s => s.dayOfWeek === day && s.periodNo === period) ?? null;
  }
}
