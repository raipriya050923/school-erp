import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import {
  TeacherApiService, teacherApiError,
  MyClass, AttendanceRow, Exam, MarksProgress, MarksGridStudent, TeachingSection, TimetableSlot, TimetablePeriod,
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

/**
 * The whole exam as one grid: the subjects this teacher is assigned across the top, every student
 * down the side. A row is one student, a column is one subject, and tabbing moves along the row —
 * so either direction is a single pass with no reloading between entries.
 *
 * Sections come from the teacher's subject assignments, not from the section they are class
 * teacher of. Those are different responsibilities: attendance follows the class teacher, marks
 * follow whoever teaches the subject. Listing class-teacher sections here both hid sections a
 * teacher taught elsewhere and offered them their colleagues' subjects in their own.
 *
 * The subject was once a free-text box defaulted to "Mathematics", which meant marks could be
 * filed under a name no paper matched. Columns now come from the exam's papers, and the server
 * rejects anything else and takes full marks from the paper rather than a fixed 100.
 */
@Component({
  selector: 'app-t-marks',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Marks Entry</h1>
        <div class="page-sub">
          @if (examName && sections.length) { {{ examName }} · {{ sectionLabel }} · {{ papers.length }} of your subjects · {{ grid.length }} students }
          @else { Enter marks for the subjects you teach }
        </div>
      </div>
    </div>

    <div class="card">
      <div class="card-head filters">
        <select class="select" [(ngModel)]="examId" (ngModelChange)="loadAll()">
          @for (e of exams; track e.id) { <option [value]="e.id">{{ e.name }}</option> }
        </select>
        <select class="select" [(ngModel)]="section" (ngModelChange)="loadAll()" [disabled]="!sections.length">
          @for (c of sections; track c.className + c.sectionName) {
            <option [value]="c.className + '|' + c.sectionName">{{ c.className }} — {{ c.sectionName }}</option>
          }
          @if (!sections.length) { <option value="">No sections assigned</option> }
        </select>
        <div class="grow"></div>
        @if (dirty) { <span class="unsaved">Unsaved changes</span> }
        <span class="td-sub">Class avg: {{ gridAverage }}%</span>
        <button class="btn btn-primary" (click)="save()" [disabled]="saving || !papers.length">{{ saving ? 'Saving…' : 'Submit Marks' }}</button>
      </div>

      @if (papers.length) {
        <!-- A standing count of how much of the exam is in, for classes too long to see at once. -->
        <div class="paper-strip">
          <span class="td-sub">{{ doneCount }} of {{ papers.length }} subjects complete:</span>
          @for (p of papers; track p.subject) {
            <span class="paper-chip" [class.done]="p.total > 0 && p.entered >= p.total">
              {{ p.subject }}
              <span class="paper-count">{{ p.entered }}/{{ p.total }}</span>
            </span>
          }
        </div>
      } @else if (!loading) {
        @if (!sections.length) {
          <div class="empty">
            You are not assigned to teach any subject yet. Marks entry follows subject assignments —
            ask your admin to assign you under Classes &amp; Sections → Subjects &amp; Teachers.
          </div>
        } @else {
          <div class="empty">
            {{ examName }} has no paper for the subject{{ mySubjects.length === 1 ? '' : 's' }} you
            teach in {{ sectionLabel }} ({{ mySubjects.join(', ') }}). Ask your admin to add them
            under Examinations.
          </div>
        }
      }

      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else if (papers.length) {
        <div class="table-wrap">
          <table class="data-table grid-table">
            <thead>
              <tr>
                <th class="num stick stick-1">Roll</th>
                <th class="stick stick-2">Student</th>
                @for (p of papers; track p.subject) {
                  <th class="num">{{ p.subject }}<div class="td-sub">/ {{ p.fullMarks }}</div></th>
                }
                <th class="num">Total</th>
                <th class="num">%</th>
                <th>Grade</th>
              </tr>
            </thead>
            <tbody>
              @for (s of grid; track s.studentId) {
                <tr>
                  <td class="num stick stick-1">{{ s.rollNo }}</td>
                  <td class="td-main stick stick-2">{{ s.name }}</td>
                  @for (p of papers; track p.subject) {
                    <td class="num">
                      <input class="input mark" type="number" min="0" [max]="p.fullMarks"
                             [ngModel]="s.marks[p.subject]" (ngModelChange)="setCell(s, p.subject, $event)" />
                    </td>
                  }
                  <td class="num">{{ rowTotal(s) }} / {{ gridFullMarks }}</td>
                  <td class="num"><strong>{{ rowPercent(s) }}%</strong></td>
                  <td><span class="badge" [class]="'badge ' + gradeBadge(rowTotal(s), gridFullMarks)">{{ grade(rowTotal(s), gridFullMarks) }}</span></td>
                </tr>
              } @empty { <tr><td [attr.colspan]="papers.length + 5"><div class="empty">No students in this section.</div></td></tr> }
            </tbody>
            @if (grid.length) {
              <tfoot>
                <tr>
                  <td class="stick stick-1"></td>
                  <td class="td-sub stick stick-2">Subject average</td>
                  @for (p of papers; track p.subject) { <td class="num td-sub">{{ columnAverage(p.subject) }}</td> }
                  <td class="num td-sub" colspan="3">Class average {{ gridAverage }}%</td>
                </tr>
              </tfoot>
            }
          </table>
        </div>
        <div class="td-sub" style="padding:10px 14px;">
          Fill a row to mark one student across every subject, or a column to mark one subject for
          the class. Leave a box empty to leave that mark unrecorded. Submit saves everything at once.
        </div>
      }
    </div>
    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
  styles: [`
    .paper-strip { display:flex; flex-wrap:wrap; align-items:center; gap:8px; padding:10px 14px; border-bottom:1px solid var(--border,#e5e7eb); }
    .paper-chip { display:inline-flex; align-items:center; gap:6px; padding:4px 10px; border-radius:999px;
                  border:1px solid var(--border,#e5e7eb); font-size:12px; }
    .paper-chip.done { border-color:#16a34a; }
    .paper-chip.done .paper-count { color:#16a34a; font-weight:600; }
    .paper-count { font-variant-numeric: tabular-nums; opacity:.75; }

    .unsaved { font-size:12px; color:var(--crit-text,#b91c1c); font-weight:600; }
    .input.mark { width:88px; text-align:right; padding:6px 8px; }

    /* Roll and Student stay put while the subject columns scroll sideways. */
    .grid-table th, .grid-table td { white-space:nowrap; }
    .grid-table .stick { position:sticky; background:var(--surface,#fff); z-index:1; }
    .grid-table .stick-1 { left:0; }
    .grid-table .stick-2 { left:56px; }
    .grid-table tfoot td { border-top:1px solid var(--border,#e5e7eb); }
  `],
})
export class TMarksComponent implements OnInit {
  private readonly api = inject(TeacherApiService);
  exams: Exam[] = [];
  /** Sections this teacher is assigned to teach in — the section dropdown. */
  sections: TeachingSection[] = [];
  /** The exam's papers for the subjects they teach here — the grid's columns. */
  papers: MarksProgress[] = [];
  /** One row per student, marks keyed by subject. */
  grid: MarksGridStudent[] = [];

  examId = 0;
  section = '';
  loading = true;
  error = '';
  saving = false;
  dirty = false;
  toast = '';
  private ready = 0;
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void {
    this.api.getExams().subscribe({
      next: e => { this.exams = e; if (e.length) this.examId = e[0].id; this.maybeLoad(); },
      error: e => { this.error = teacherApiError(e); this.loading = false; },
    });
    this.api.teachingSections().subscribe({
      next: s => {
        this.sections = s;
        if (s.length) this.section = s[0].className + '|' + s[0].sectionName;
        this.maybeLoad();
      },
      // Still count as ready, or a teacher with no assignments would sit on "Loading…" forever.
      error: () => this.maybeLoad(),
    });
  }
  private maybeLoad(): void { if (++this.ready >= 2) this.loadAll(); }

  /* ---- context ---- */

  get examName(): string { return this.exams.find(e => String(e.id) === String(this.examId))?.name ?? ''; }
  get sectionLabel(): string { return this.section.replace('|', ' — '); }
  /** The subjects this teacher holds in the selected section. */
  get mySubjects(): string[] {
    const [cls, sec] = this.section.split('|');
    return this.sections.find(s => s.className === cls && s.sectionName === sec)?.subjects ?? [];
  }
  get doneCount(): number { return this.papers.filter(p => p.total > 0 && p.entered >= p.total).length; }
  /** What a student is marked out of across the whole exam. */
  get gridFullMarks(): number { return this.papers.reduce((sum, p) => sum + p.fullMarks, 0); }
  get gridAverage(): number {
    const pcts = this.grid.map(s => this.rowPercent(s)).filter(p => p > 0);
    return pcts.length ? Math.round(pcts.reduce((a, b) => a + b, 0) / pcts.length) : 0;
  }

  /* ---- loading ---- */

  loadAll(): void {
    if (!this.examId || !this.section) { this.loading = false; this.papers = []; this.grid = []; return; }
    const [cls, sec] = this.section.split('|');
    this.loading = true;
    this.dirty = false;
    // Papers first: they are the columns, and an exam with none has no grid to draw.
    this.api.marksProgress(Number(this.examId), cls, sec).subscribe({
      next: p => {
        this.papers = p;
        if (!p.length) { this.grid = []; this.loading = false; this.error = ''; return; }
        this.loadGrid();
      },
      error: e => { this.error = teacherApiError(e); this.loading = false; },
    });
  }

  loadGrid(): void {
    const [cls, sec] = this.section.split('|');
    this.loading = true;
    this.api.marksGrid(Number(this.examId), cls, sec).subscribe({
      next: g => { this.grid = g.students; this.dirty = false; this.loading = false; this.error = ''; },
      error: e => { this.error = teacherApiError(e); this.loading = false; },
    });
  }

  /* ---- cells ---- */

  setCell(student: MarksGridStudent, subject: string, value: unknown): void {
    // An empty box means "not marked", which is different from a zero, so it is stored as null.
    const n = Number(value);
    student.marks[subject] = value === '' || value === null || value === undefined || isNaN(n) ? null : n;
    this.dirty = true;
  }

  rowTotal(s: MarksGridStudent): number {
    return this.papers.reduce((sum, p) => sum + (Number(s.marks[p.subject]) || 0), 0);
  }
  rowPercent(s: MarksGridStudent): number {
    return this.gridFullMarks ? Math.round((this.rowTotal(s) / this.gridFullMarks) * 100) : 0;
  }
  columnAverage(subject: string): string {
    const vals = this.grid
      .map(s => s.marks[subject])
      .filter((v): v is number => v !== null && v !== undefined && !isNaN(Number(v)))
      .map(Number);
    return vals.length ? String(Math.round(vals.reduce((a, b) => a + b, 0) / vals.length)) : '—';
  }

  /* ---- saving ---- */

  save(): void {
    const [cls, sec] = this.section.split('|');
    const entries = this.grid.flatMap(s => this.papers.map(p => ({
      studentId: s.studentId, subject: p.subject, marks: s.marks[p.subject] ?? null,
    })));
    this.saving = true;
    this.api.saveMarksGrid(Number(this.examId), cls, sec, entries).subscribe({
      next: r => {
        this.saving = false;
        this.dirty = false;
        this.showToast(`${r.saved} mark(s) saved across ${this.papers.length} subjects`);
        this.refreshProgress();
      },
      error: e => { this.saving = false; alert(teacherApiError(e)); },
    });
  }

  private refreshProgress(): void {
    const [cls, sec] = this.section.split('|');
    this.api.marksProgress(Number(this.examId), cls, sec).subscribe({ next: p => this.papers = p, error: () => {} });
  }

  /* ---- grading ---- */

  grade(m: number | null, outOf: number): string {
    if (m == null || !outOf) return '—';
    const pct = (Number(m) / outOf) * 100;
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B+';
    if (pct >= 60) return 'B';
    if (pct >= 50) return 'C+';
    if (pct >= 40) return 'C';
    return 'NG';
  }
  gradeBadge(m: number | null, outOf: number): string {
    if (m == null || !outOf) return 'neutral';
    const pct = (Number(m) / outOf) * 100;
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
            <thead>
              <tr>
                <th>Day</th>
                @for (p of periods; track p.periodNo) {
                  <th [class.tt-break]="p.isBreak">
                    {{ p.name }}<div class="tt-meta">{{ p.timeLabel }}</div>
                  </th>
                }
              </tr>
            </thead>
            <tbody>
              @for (d of days; track d.num) {
                <tr>
                  <th>{{ d.label }}</th>
                  @for (p of periods; track p.periodNo) {
                    <td [class.tt-break]="p.isBreak">
                      @if (p.isBreak) {
                        <span class="tt-meta">Break</span>
                      } @else {
                        @if (slot(d.num, p.periodNo); as s) {
                          <div class="tt-subject">{{ s.label }}</div>
                          <div class="tt-meta">{{ s.time }}@if (s.room) { · Room {{ s.room }} }</div>
                        } @else { <span class="tt-meta">—</span> }
                      }
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
  /** Columns come from the school's own periods — never assumed to be 1..6. */
  periods: TimetablePeriod[] = [];
  loading = true;
  error = '';
  readonly days = [
    { num: 1, label: 'Sunday' }, { num: 2, label: 'Monday' }, { num: 3, label: 'Tuesday' },
    { num: 4, label: 'Wednesday' }, { num: 5, label: 'Thursday' }, { num: 6, label: 'Friday' },
  ];

  ngOnInit(): void {
    this.api.getTimetable().subscribe({
      next: t => { this.periods = t.periods; this.slots = t.slots; this.loading = false; },
      error: e => { this.error = teacherApiError(e); this.loading = false; },
    });
  }
  slot(day: number, period: number): TimetableSlot | null {
    return this.slots.find(s => s.dayOfWeek === day && s.periodNo === period) ?? null;
  }
}
