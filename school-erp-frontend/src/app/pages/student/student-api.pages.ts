import { Component, OnInit, inject } from '@angular/core';
import { DecimalPipe, DatePipe } from '@angular/common';
import {
  StudentApiService, studentApiError, feeBadge, attBadge,
  StudentDashboard, StudentAttendance, StudentTimetableSlot, StudentHomework,
  StudentExams, StudentResult, StudentFee, StudentNotice,
} from '../../core/student-api.service';

/* =====================  DASHBOARD  ===================== */

@Component({
  selector: 'app-st-dashboard',
  standalone: true,
  imports: [DecimalPipe, DatePipe],
  template: `
    @if (loading) { <div class="card"><div class="empty">Loading…</div></div> }
    @else if (error) { <div class="card"><div class="empty">{{ error }}</div></div> }
    @else if (d) {
      <div class="page-head"><div class="grow"><h1>Hi {{ firstName }} 👋</h1><div class="page-sub">{{ d.className }}-{{ d.sectionName }} · Roll {{ d.rollNo }} · live data from the API</div></div></div>

      <div class="stat-grid">
        <div class="stat-tile"><div class="stat-label">Attendance</div><div class="stat-value">{{ d.attendancePercent }}%</div><div class="stat-sub">{{ d.presentDays }} of {{ d.totalDays }} days</div></div>
        <div class="stat-tile"><div class="stat-label">Pending Homework</div><div class="stat-value">{{ d.pendingHomework }}</div><div class="stat-sub">to submit</div></div>
        <div class="stat-tile"><div class="stat-label">Next Exam</div><div class="stat-value">{{ d.nextExamDate ? (d.nextExamDate | date:'MMM d') : '—' }}</div><div class="stat-sub">{{ d.nextExamName || 'nothing scheduled' }}</div></div>
        <div class="stat-tile"><div class="stat-label">Fee Due</div><div class="stat-value">Rs {{ d.feeDue | number }}</div><div class="stat-sub" [class.down]="d.feeDue > 0">outstanding</div></div>
      </div>

      <div class="card">
        <div class="card-head"><h2 class="grow">Pending Homework</h2></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Assignment</th><th>Subject</th><th>Due</th></tr></thead>
            <tbody>
              @for (h of d.upcomingHomework; track h.title) {
                <tr><td class="td-main">{{ h.title }}</td><td>{{ h.subject }}</td><td class="td-sub">{{ h.dueDate | date:'mediumDate' }}</td></tr>
              } @empty { <tr><td colspan="3"><div class="empty">All caught up! 🎉</div></td></tr> }
            </tbody>
          </table>
        </div>
      </div>
    }
  `,
})
export class StDashboardComponent implements OnInit {
  private readonly api = inject(StudentApiService);
  d: StudentDashboard | null = null;
  loading = true;
  error = '';
  get firstName(): string { return (this.d?.name ?? '').split(' ')[0]; }
  ngOnInit(): void {
    this.api.getDashboard().subscribe({ next: d => { this.d = d; this.loading = false; }, error: e => { this.error = studentApiError(e); this.loading = false; } });
  }
}

/* =====================  ATTENDANCE  ===================== */

@Component({
  selector: 'app-st-attendance',
  standalone: true,
  template: `
    <div class="page-head"><div class="grow"><h1>My Attendance</h1>@if (a) { <div class="page-sub">{{ a.overallPercent }}% overall · {{ a.presentDays }} of {{ a.totalDays }} days</div> }</div></div>
    @if (loading) { <div class="card"><div class="empty">Loading…</div></div> }
    @else if (error) { <div class="card"><div class="empty">{{ error }}</div></div> }
    @else if (a) {
      <div class="stat-grid">
        @for (m of a.months; track m.month) {
          <div class="stat-tile">
            <div class="stat-label">{{ m.month }}</div>
            <div class="stat-value">{{ m.percent }}%</div>
            <div class="stat-sub">{{ m.present }} present · {{ m.absent }} absent · {{ m.late }} late</div>
            <div class="meter" [class.good]="m.percent >= 90" style="margin-top:10px;"><span [style.width.%]="m.percent"></span></div>
          </div>
        }
      </div>
      <div class="card">
        <div class="card-head"><h2 class="grow">Recent Days</h2></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Date</th><th>Day</th><th>Status</th></tr></thead>
            <tbody>
              @for (r of a.recent; track r.date) {
                <tr><td class="td-sub">{{ r.date }}</td><td>{{ r.day }}</td><td><span class="badge" [class]="'badge ' + badge(r.status)">{{ r.status }}</span></td></tr>
              }
            </tbody>
          </table>
        </div>
      </div>
    }
  `,
})
export class StAttendanceComponent implements OnInit {
  private readonly api = inject(StudentApiService);
  a: StudentAttendance | null = null;
  loading = true;
  error = '';
  badge = attBadge;
  ngOnInit(): void {
    this.api.getAttendance().subscribe({ next: a => { this.a = a; this.loading = false; }, error: e => { this.error = studentApiError(e); this.loading = false; } });
  }
}

/* =====================  TIMETABLE  ===================== */

@Component({
  selector: 'app-st-timetable',
  standalone: true,
  template: `
    <div class="page-head"><div class="grow"><h1>Class Timetable</h1><div class="page-sub">Weekly schedule</div></div></div>
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
                    <td>@if (slot(d.num, p); as s) { <span class="tt-subject">{{ s.subject }}</span><div class="tt-meta">{{ s.time }} · {{ s.room }}</div> } @else { <span class="tt-meta">—</span> }</td>
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
export class StTimetableComponent implements OnInit {
  private readonly api = inject(StudentApiService);
  slots: StudentTimetableSlot[] = [];
  loading = true;
  error = '';
  readonly days = [
    { num: 1, label: 'Sunday' }, { num: 2, label: 'Monday' }, { num: 3, label: 'Tuesday' },
    { num: 4, label: 'Wednesday' }, { num: 5, label: 'Thursday' }, { num: 6, label: 'Friday' },
  ];
  readonly periods = [1, 2, 3, 4, 5, 6];
  ngOnInit(): void {
    this.api.getTimetable().subscribe({ next: s => { this.slots = s; this.loading = false; }, error: e => { this.error = studentApiError(e); this.loading = false; } });
  }
  slot(day: number, period: number): StudentTimetableSlot | null {
    return this.slots.find(s => s.dayOfWeek === day && s.periodNo === period) ?? null;
  }
}

/* =====================  HOMEWORK  ===================== */

@Component({
  selector: 'app-st-homework',
  standalone: true,
  imports: [DatePipe],
  template: `
    <div class="page-head"><div class="grow"><h1>My Homework</h1><div class="page-sub">{{ list.length }} assignments</div></div></div>
    <div class="card">
      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Assignment</th><th>Subject</th><th>Due</th><th>Status</th></tr></thead>
            <tbody>
              @for (h of list; track h.title) {
                <tr>
                  <td class="td-main">{{ h.title }}</td>
                  <td>{{ h.subject }}</td>
                  <td class="td-sub">{{ h.dueDate | date:'mediumDate' }}</td>
                  <td><span class="badge" [class]="h.status === 'Pending' ? 'badge info' : 'badge neutral'">{{ h.status }}</span></td>
                </tr>
              } @empty { <tr><td colspan="4"><div class="empty">No homework assigned.</div></td></tr> }
            </tbody>
          </table>
        </div>
      }
    </div>
  `,
})
export class StHomeworkComponent implements OnInit {
  private readonly api = inject(StudentApiService);
  list: StudentHomework[] = [];
  loading = true;
  error = '';
  ngOnInit(): void {
    this.api.getHomework().subscribe({ next: h => { this.list = h; this.loading = false; }, error: e => { this.error = studentApiError(e); this.loading = false; } });
  }
}

/* =====================  EXAMS & RESULTS  ===================== */

@Component({
  selector: 'app-st-exams',
  standalone: true,
  imports: [DatePipe],
  template: `
    <div class="page-head"><div class="grow"><h1>Exams &amp; Results</h1><div class="page-sub">{{ e?.examName || 'Latest published result' }}</div></div></div>
    @if (loading) { <div class="card"><div class="empty">Loading…</div></div> }
    @else if (error) { <div class="card"><div class="empty">{{ error }}</div></div> }
    @else if (e) {
      <div class="stat-grid">
        <div class="stat-tile"><div class="stat-label">Total</div><div class="stat-value">{{ e.total }}/{{ e.fullTotal }}</div><div class="stat-sub">{{ e.percent }}% aggregate</div></div>
        <div class="stat-tile"><div class="stat-label">Overall Grade</div><div class="stat-value">{{ e.grade }}</div></div>
        <div class="stat-tile"><div class="stat-label">Subjects</div><div class="stat-value">{{ e.results.length }}</div></div>
      </div>

      <div class="card">
        <div class="card-head"><h2 class="grow">Subject-wise Result</h2></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Subject</th><th class="num">Full Marks</th><th class="num">Obtained</th><th>Grade</th><th>Score</th></tr></thead>
            <tbody>
              @for (r of e.results; track r.subject) {
                <tr>
                  <td class="td-main">{{ r.subject }}</td>
                  <td class="num">{{ r.fullMarks }}</td>
                  <td class="num">{{ r.marks }}</td>
                  <td><span class="badge" [class]="'badge ' + gradeBadge(r.marks, r.fullMarks)">{{ r.grade }}</span></td>
                  <td><div class="meter" [class.good]="ratio(r) >= 0.8" style="max-width:160px;"><span [style.width.%]="ratio(r) * 100"></span></div></td>
                </tr>
              } @empty { <tr><td colspan="5"><div class="empty">No results published yet.</div></td></tr> }
            </tbody>
          </table>
        </div>
      </div>

      <div class="card">
        <div class="card-head"><h2 class="grow">Upcoming Exam Schedule</h2></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Date</th><th>Subject</th><th>Time</th><th>Room</th></tr></thead>
            <tbody>
              @for (u of e.upcoming; track $index) {
                <tr><td class="td-sub">{{ u.date | date:'mediumDate' }}</td><td class="td-main">{{ u.subject }}</td><td>{{ u.time }}</td><td class="td-sub">{{ u.room }}</td></tr>
              } @empty { <tr><td colspan="4"><div class="empty">No upcoming exams scheduled.</div></td></tr> }
            </tbody>
          </table>
        </div>
      </div>
    }
  `,
})
export class StExamsComponent implements OnInit {
  private readonly api = inject(StudentApiService);
  e: StudentExams | null = null;
  loading = true;
  error = '';
  ngOnInit(): void {
    this.api.getExams().subscribe({ next: e => { this.e = e; this.loading = false; }, error: err => { this.error = studentApiError(err); this.loading = false; } });
  }
  ratio(r: StudentResult): number { return r.fullMarks ? (Number(r.marks) || 0) / r.fullMarks : 0; }
  gradeBadge(marks: number | null, full: number): string {
    if (marks == null) return 'neutral';
    const r = full ? marks / full : 0;
    if (r >= 0.8) return 'success';
    if (r >= 0.6) return 'info';
    if (r >= 0.4) return 'warning';
    return 'danger';
  }
}

/* =====================  FEES  ===================== */

@Component({
  selector: 'app-st-fees',
  standalone: true,
  imports: [DecimalPipe, DatePipe],
  template: `
    <div class="page-head"><div class="grow"><h1>My Fees</h1><div class="page-sub">Fee account</div></div></div>
    @if (loading) { <div class="card"><div class="empty">Loading…</div></div> }
    @else if (error) { <div class="card"><div class="empty">{{ error }}</div></div> }
    @else {
      <div class="stat-grid">
        <div class="stat-tile"><div class="stat-label">Outstanding</div><div class="stat-value">Rs {{ outstanding | number }}</div><div class="stat-sub down">across {{ unpaidCount }} invoice(s)</div></div>
        <div class="stat-tile"><div class="stat-label">Paid</div><div class="stat-value">Rs {{ paidTotal | number }}</div></div>
        <div class="stat-tile"><div class="stat-label">Invoices</div><div class="stat-value">{{ list.length }}</div></div>
      </div>
      <div class="card">
        <div class="card-head"><h2 class="grow">Invoices</h2></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Invoice #</th><th>Month</th><th class="num">Amount</th><th class="num">Paid</th><th class="num">Balance</th><th>Due</th><th>Status</th></tr></thead>
            <tbody>
              @for (f of list; track f.invoiceNo) {
                <tr>
                  <td class="td-sub">{{ f.invoiceNo }}</td>
                  <td class="td-main">{{ f.month }}</td>
                  <td class="num">Rs {{ f.amount | number }}</td>
                  <td class="num">Rs {{ f.paid | number }}</td>
                  <td class="num">@if (f.balance > 0) { <span style="color:var(--crit-text);font-weight:600;">Rs {{ f.balance | number }}</span> } @else { <span class="td-sub">—</span> }</td>
                  <td class="td-sub">{{ f.dueDate | date:'mediumDate' }}</td>
                  <td><span class="badge" [class]="'badge ' + badge(f.status)">{{ label(f.status) }}</span></td>
                </tr>
              } @empty { <tr><td colspan="7"><div class="empty">No invoices.</div></td></tr> }
            </tbody>
          </table>
        </div>
      </div>
    }
  `,
})
export class StFeesComponent implements OnInit {
  private readonly api = inject(StudentApiService);
  list: StudentFee[] = [];
  loading = true;
  error = '';
  badge = feeBadge;
  get outstanding(): number { return this.list.reduce((n, f) => n + f.balance, 0); }
  get paidTotal(): number { return this.list.reduce((n, f) => n + f.paid, 0); }
  get unpaidCount(): number { return this.list.filter(f => f.balance > 0).length; }
  ngOnInit(): void {
    this.api.getFees().subscribe({ next: f => { this.list = f; this.loading = false; }, error: e => { this.error = studentApiError(e); this.loading = false; } });
  }
  label(s: string): string { return s ? s.charAt(0).toUpperCase() + s.slice(1) : ''; }
}

/* =====================  NOTICES  ===================== */

@Component({
  selector: 'app-st-notices',
  standalone: true,
  imports: [DatePipe],
  template: `
    <div class="page-head"><div class="grow"><h1>Notice Board</h1><div class="page-sub">School announcements</div></div></div>
    <div class="card">
      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else {
        @for (n of notices; track n.id) {
          <div class="notice-item">
            <div class="notice-title">{{ n.title }}</div>
            <div class="notice-meta">{{ n.publishDate | date:'mediumDate' }} · {{ n.audience }}</div>
            <div class="notice-body">{{ n.body }}</div>
          </div>
        } @empty { <div class="empty">No notices yet.</div> }
      }
    </div>
  `,
})
export class StNoticesComponent implements OnInit {
  private readonly api = inject(StudentApiService);
  notices: StudentNotice[] = [];
  loading = true;
  error = '';
  ngOnInit(): void {
    this.api.getNotices().subscribe({ next: n => { this.notices = n; this.loading = false; }, error: e => { this.error = studentApiError(e); this.loading = false; } });
  }
}
