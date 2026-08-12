import { Component, OnInit, inject } from '@angular/core';
import { DecimalPipe, DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {
  AdminApiService, adminApiError,
  ClassDto, StudentListItem, AttendanceRow, AttendanceReport, ExamDto, ExamPaperDto,
  FeeInvoiceDto, FeeSummaryDto,
} from '../../core/admin-api.service';

/* =====================  ATTENDANCE  ===================== */

@Component({
  selector: 'app-ad-attendance',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page-head"><div class="grow"><h1>Attendance</h1><div class="page-sub">Mark or review daily attendance</div></div></div>

    <div class="card">
      <div class="card-head filters">
        <input class="input" type="date" [(ngModel)]="date" (ngModelChange)="load()" />
        <select class="select" [(ngModel)]="section" (ngModelChange)="load()">
          @for (o of sectionOptions; track o) { <option [value]="o">{{ o }}</option> }
        </select>
        <div class="grow"></div>
        <span class="td-sub">{{ presentCount }}/{{ rows.length }} present</span>
        <button class="btn btn-ghost btn-sm" (click)="markAll('present')">All Present</button>
        <button class="btn btn-primary" (click)="save()" [disabled]="saving || !rows.length">{{ saving ? 'Saving…' : 'Save' }}</button>
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
                  <td class="num">{{ r.rollNo }}</td><td class="td-main">{{ r.name }}</td>
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
export class AdAttendanceComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  classes: ClassDto[] = [];
  sectionOptions: string[] = [];
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
    this.api.getClasses().subscribe({
      next: cs => {
        this.classes = cs;
        this.sectionOptions = cs.flatMap(c => c.sections.map(s => `${c.name} — ${s.name}`));
        if (this.sectionOptions.length) { this.section = this.sectionOptions[0]; this.load(); } else { this.loading = false; }
      },
      error: e => { this.error = adminApiError(e); this.loading = false; },
    });
  }
  private parse(): [string, string] { const [c, s] = this.section.split(' — '); return [c, s]; }
  load(): void {
    if (!this.section) return;
    const [cls, sec] = this.parse();
    this.loading = true;
    this.api.getAttendance(cls, sec, this.date).subscribe({
      next: r => { this.rows = r; this.loading = false; this.error = ''; },
      error: e => { this.error = adminApiError(e); this.loading = false; },
    });
  }
  markAll(s: string): void { this.rows.forEach(r => r.status = s); }
  save(): void {
    const [cls, sec] = this.parse();
    this.saving = true;
    this.api.saveAttendance(cls, sec, this.date, this.rows.map(r => ({ studentId: r.studentId, status: r.status }))).subscribe({
      next: () => { this.saving = false; this.showToast(`Attendance saved — ${this.presentCount}/${this.rows.length} present`); },
      error: e => { this.saving = false; alert(adminApiError(e)); },
    });
  }
  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }
}

/* =====================  ATTENDANCE REPORT  ===================== */

@Component({
  selector: 'app-ad-attendance-report',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page-head"><div class="grow"><h1>Student Attendance Report</h1><div class="page-sub">Day-by-day attendance for any date range</div></div></div>

    <div class="card">
      <div class="card-head filters">
        <select class="select grow" [(ngModel)]="studentId">
          <option [ngValue]="0">Select a student…</option>
          @for (s of students; track s.id) { <option [ngValue]="s.id">{{ s.name }} — {{ s.className }}-{{ s.sectionName }}</option> }
        </select>
        <div class="field" style="margin:0;"><label style="font-size:11px;">From</label><input class="input" type="date" [(ngModel)]="from" /></div>
        <div class="field" style="margin:0;"><label style="font-size:11px;">To</label><input class="input" type="date" [(ngModel)]="to" /></div>
        <button class="btn btn-primary" (click)="run()">Generate</button>
      </div>
    </div>

    @if (report) {
      <div class="stat-grid">
        <div class="stat-tile"><div class="stat-label">Attendance</div><div class="stat-value">{{ report.percent }}%</div><div class="stat-sub" [class.up]="report.percent>=90" [class.down]="report.percent<75">{{ report.present + report.late }} of {{ report.schoolDays }} days</div></div>
        <div class="stat-tile"><div class="stat-label">Present</div><div class="stat-value">{{ report.present }}</div></div>
        <div class="stat-tile"><div class="stat-label">Late</div><div class="stat-value">{{ report.late }}</div></div>
        <div class="stat-tile"><div class="stat-label">Absent</div><div class="stat-value">{{ report.absent }}</div><div class="stat-sub" [class.down]="report.absent>0">days missed</div></div>
      </div>
      <div class="card">
        <div class="card-head"><h2 class="grow">{{ report.studentName }} · {{ from }} → {{ to }}</h2></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Date</th><th>Day</th><th>Status</th></tr></thead>
            <tbody>
              @for (d of report.days; track d.date) {
                <tr><td class="td-sub">{{ d.date }}</td><td>{{ d.day }}</td><td><span class="badge" [class]="'badge ' + badge(d.status)">{{ d.status }}</span></td></tr>
              }
            </tbody>
          </table>
        </div>
      </div>
    } @else if (!loading) {
      <div class="card"><div class="empty">Pick a student and date range, then click Generate.</div></div>
    }
  `,
})
export class AdAttendanceReportComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  students: StudentListItem[] = [];
  report: AttendanceReport | null = null;
  studentId = 0;
  from = '2026-06-01';
  to = '2026-06-30';
  loading = true;

  ngOnInit(): void {
    this.api.getStudents().subscribe({ next: s => { this.students = s; this.loading = false; }, error: () => this.loading = false });
  }
  run(): void {
    if (!this.studentId) { alert('Please select a student.'); return; }
    this.api.attendanceReport(this.studentId, this.from, this.to).subscribe({
      next: r => this.report = r, error: e => alert(adminApiError(e)),
    });
  }
  badge(status: string): string {
    switch (status) {
      case 'Present': return 'success';
      case 'Late': return 'warning';
      case 'Absent': return 'danger';
      default: return 'neutral';
    }
  }
}

/* =====================  FEES  ===================== */

@Component({
  selector: 'app-ad-fees',
  standalone: true,
  imports: [FormsModule, DecimalPipe, DatePipe],
  template: `
    <div class="page-head">
      <div class="grow"><h1>Fee Management</h1><div class="page-sub">{{ invoices.length }} invoices</div></div>
      <button class="btn btn-ghost" (click)="openGenerate()">Generate Invoices</button>
    </div>

    @if (summary) {
      <div class="stat-grid">
        <div class="stat-tile"><div class="stat-label">Total Billed</div><div class="stat-value">Rs {{ summary.totalBilled | number }}</div></div>
        <div class="stat-tile"><div class="stat-label">Collected</div><div class="stat-value">Rs {{ summary.collected | number }}</div><div class="stat-sub up">{{ pct }}% of billed</div></div>
        <div class="stat-tile"><div class="stat-label">Outstanding</div><div class="stat-value">Rs {{ summary.outstanding | number }}</div><div class="stat-sub" [class.down]="summary.outstanding>0">{{ summary.unpaid }} unpaid/partial</div></div>
        <div class="stat-tile"><div class="stat-label">Overdue</div><div class="stat-value">{{ summary.overdue }}</div><div class="stat-sub down">invoices past due</div></div>
      </div>
    }

    <div class="card">
      <div class="card-head filters">
        <h2 class="grow">Invoices</h2>
        <select class="select" [(ngModel)]="status" (ngModelChange)="reload()">
          <option value="">All statuses</option><option value="paid">Paid</option><option value="partial">Partial</option><option value="unpaid">Unpaid</option><option value="overdue">Overdue</option>
        </select>
      </div>
      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Invoice #</th><th>Student</th><th>Class</th><th>Month</th><th class="num">Amount</th><th class="num">Balance</th><th>Due</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              @for (i of invoices; track i.id) {
                <tr>
                  <td class="td-sub">{{ i.invoiceNo }}</td>
                  <td class="td-main">{{ i.studentName }}</td>
                  <td>{{ i.classLabel }}</td>
                  <td class="td-sub">{{ i.month }}</td>
                  <td class="num">Rs {{ i.amount | number }}</td>
                  <td class="num">@if (i.balance > 0) { <span style="color:var(--crit-text);font-weight:600;">Rs {{ i.balance | number }}</span> } @else { <span class="td-sub">—</span> }</td>
                  <td class="td-sub">{{ i.dueDate | date:'mediumDate' }}</td>
                  <td><span class="badge" [class]="'badge ' + feeBadge(i.status)">{{ label(i.status) }}</span></td>
                  <td>@if (i.status !== 'paid') { <button class="btn btn-primary btn-sm" (click)="openPay(i)">Record Payment</button> } @else { <span class="td-sub">—</span> }</td>
                </tr>
              } @empty { <tr><td colspan="9"><div class="empty">No invoices.</div></td></tr> }
            </tbody>
          </table>
        </div>
      }
    </div>

    @if (paying; as inv) {
      <div class="modal-backdrop" (click)="paying = null">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head"><h2>Record Payment — {{ inv.invoiceNo }}</h2><button class="modal-close" (click)="paying = null">✕</button></div>
          <div class="modal-body">
            <div class="kv-row"><span class="kv-label">Student</span><span class="kv-value">{{ inv.studentName }}</span></div>
            <div class="kv-row" style="margin-bottom:12px;"><span class="kv-label">Balance</span><span class="kv-value" style="color:var(--crit-text);">Rs {{ inv.balance | number }}</span></div>
            <div class="form-row">
              <div class="field"><label>Amount (Rs) *</label><input class="input" type="number" [(ngModel)]="payForm.amount" /></div>
              <div class="field"><label>Date</label><input class="input" type="date" [(ngModel)]="payForm.date" /></div>
            </div>
            <div class="form-row">
              <div class="field"><label>Method</label><select class="select" [(ngModel)]="payForm.method"><option>cash</option><option>esewa</option><option>khalti</option><option>bank_transfer</option><option>cheque</option><option>card</option></select></div>
              <div class="field"><label>Reference</label><input class="input" [(ngModel)]="payForm.ref" /></div>
            </div>
            @if (formError) { <div style="color:var(--crit-text);font-size:13px;">{{ formError }}</div> }
          </div>
          <div class="modal-foot"><button class="btn btn-ghost" (click)="paying = null">Cancel</button><button class="btn btn-primary" (click)="savePay()" [disabled]="saving">Record</button></div>
        </div>
      </div>
    }

    @if (showGen) {
      <div class="modal-backdrop" (click)="showGen = false">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head"><h2>Generate Monthly Invoices</h2><button class="modal-close" (click)="showGen = false">✕</button></div>
          <div class="modal-body">
            <div class="form-row">
              <div class="field"><label>Billing month *</label><input class="input" [(ngModel)]="genForm.month" placeholder="August 2026" /></div>
              <div class="field"><label>Due date</label><input class="input" type="date" [(ngModel)]="genForm.due" /></div>
            </div>
            <div class="field"><label>Class</label>
              <select class="select" [(ngModel)]="genForm.cls"><option value="All">All classes</option>@for (c of classes; track c) { <option [value]="c">{{ c }}</option> }</select>
            </div>
            <div class="td-sub">Creates one invoice per active student who isn't already billed for that month.</div>
            @if (formError) { <div style="color:var(--crit-text);font-size:13px;margin-top:8px;">{{ formError }}</div> }
          </div>
          <div class="modal-foot"><button class="btn btn-ghost" (click)="showGen = false">Cancel</button><button class="btn btn-primary" (click)="generate()" [disabled]="saving">Generate</button></div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class AdFeesComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  invoices: FeeInvoiceDto[] = [];
  summary: FeeSummaryDto | null = null;
  classes: string[] = [];
  status = '';
  loading = true;
  error = '';
  saving = false;
  formError = '';
  toast = '';
  paying: FeeInvoiceDto | null = null;
  showGen = false;
  payForm = { amount: 0, date: '2026-07-05', method: 'cash', ref: '' };
  genForm = { month: 'August 2026', due: '2026-08-10', cls: 'All' };
  private timer?: ReturnType<typeof setTimeout>;

  get pct(): number { return this.summary && this.summary.totalBilled ? Math.round(this.summary.collected / this.summary.totalBilled * 100) : 0; }

  ngOnInit(): void {
    this.reload();
    this.api.getClasses().subscribe({ next: c => this.classes = c.map(x => x.name), error: () => {} });
  }
  reload(): void {
    this.api.feeSummary().subscribe({ next: s => this.summary = s, error: () => {} });
    this.api.getInvoices(this.status || undefined).subscribe({
      next: i => { this.invoices = i; this.loading = false; this.error = ''; },
      error: e => { this.error = adminApiError(e); this.loading = false; },
    });
  }
  openPay(i: FeeInvoiceDto): void { this.paying = i; this.formError = ''; this.payForm = { amount: i.balance, date: '2026-07-05', method: 'cash', ref: '' }; }
  savePay(): void {
    if (!this.paying) return;
    if (!this.payForm.amount || this.payForm.amount <= 0) { this.formError = 'Enter a valid amount.'; return; }
    this.saving = true;
    this.api.recordFeePayment(this.paying.id, { amount: Number(this.payForm.amount), method: this.payForm.method, ref: this.payForm.ref.trim(), paymentDate: this.payForm.date }).subscribe({
      next: () => { this.saving = false; this.showToast('Payment recorded'); this.paying = null; this.reload(); },
      error: e => { this.saving = false; this.formError = adminApiError(e); },
    });
  }
  openGenerate(): void { this.showGen = true; this.formError = ''; this.genForm = { month: 'August 2026', due: '2026-08-10', cls: 'All' }; }
  generate(): void {
    if (!this.genForm.month.trim()) { this.formError = 'Billing month is required.'; return; }
    this.saving = true;
    this.api.generateInvoices(this.genForm.month.trim(), this.genForm.due, this.genForm.cls).subscribe({
      next: r => { this.saving = false; this.showGen = false; this.showToast(r.created > 0 ? `${r.created} invoice(s) generated` : 'No new invoices — all already billed'); this.reload(); },
      error: e => { this.saving = false; this.formError = adminApiError(e); },
    });
  }
  feeBadge(s: string): string {
    switch (s) { case 'paid': return 'success'; case 'partial': return 'warning'; case 'overdue': return 'danger'; default: return 'info'; }
  }
  label(s: string): string { return s ? s.charAt(0).toUpperCase() + s.slice(1) : ''; }
  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }
}

/* =====================  EXAMS  ===================== */

@Component({
  selector: 'app-ad-exams',
  standalone: true,
  imports: [FormsModule, DatePipe],
  template: `
    <div class="page-head"><div class="grow"><h1>Examination Management</h1><div class="page-sub">Exams for AY 2083</div></div><button class="btn btn-primary" (click)="openExam()">+ Schedule Exam</button></div>

    <div class="card">
      <div class="card-head"><h2 class="grow">Examinations</h2></div>
      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Examination</th><th>Type</th><th>Dates</th><th>Classes</th><th class="num">Papers</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              @for (e of exams; track e.id) {
                <tr [style.background]="e === selected ? 'var(--brand-tint)' : ''">
                  <td class="td-main">{{ e.name }}</td>
                  <td>{{ e.type }}</td>
                  <td class="td-sub">{{ e.startDate | date:'mediumDate' }} → {{ e.endDate | date:'mediumDate' }}</td>
                  <td class="td-sub">{{ e.classes }}</td>
                  <td class="num">{{ e.paperCount }}</td>
                  <td><span class="badge" [class]="'badge ' + examBadge(e.status)">{{ label(e.status) }}</span></td>
                  <td><button class="btn btn-ghost btn-sm" (click)="selected = e">Schedule</button></td>
                </tr>
              } @empty { <tr><td colspan="7"><div class="empty">No exams yet.</div></td></tr> }
            </tbody>
          </table>
        </div>
      }
    </div>

    @if (selected; as e) {
      <div class="card">
        <div class="card-head"><div class="grow"><h2>Subject Schedule — {{ e.name }}</h2></div><button class="btn btn-primary btn-sm" (click)="openPaper()">+ Add Subject</button></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Date</th><th>Subject</th><th>Time</th><th>Room</th><th class="num">Full Marks</th><th>Actions</th></tr></thead>
            <tbody>
              @for (p of e.papers; track p.id) {
                <tr>
                  <td class="td-sub">{{ p.examDate | date:'mediumDate' }}</td>
                  <td class="td-main">{{ p.subject }}</td>
                  <td>{{ p.time }}</td>
                  <td>{{ p.room }}</td>
                  <td class="num">{{ p.fullMarks }}</td>
                  <td><button class="icon-action danger" (click)="removePaper(p)" title="Remove"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2m2 0v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/></svg></button></td>
                </tr>
              } @empty { <tr><td colspan="6"><div class="empty">No papers yet — add subjects.</div></td></tr> }
            </tbody>
          </table>
        </div>
      </div>
    } @else { <div class="card"><div class="empty">Select an exam above to schedule its subjects.</div></div> }

    @if (showExam) {
      <div class="modal-backdrop" (click)="showExam = false">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head"><h2>Schedule New Exam</h2><button class="modal-close" (click)="showExam = false">✕</button></div>
          <div class="modal-body">
            <div class="field"><label>Name *</label><input class="input" [(ngModel)]="examForm.name" /></div>
            <div class="form-row">
              <div class="field"><label>Type</label><select class="select" [(ngModel)]="examForm.type"><option>Unit Test</option><option>Term</option><option>Quarterly</option><option>Half Yearly</option><option>Final</option></select></div>
              <div class="field"><label>Classes</label><input class="input" [(ngModel)]="examForm.classes" placeholder="G6-G10" /></div>
            </div>
            <div class="form-row">
              <div class="field"><label>Start *</label><input class="input" type="date" [(ngModel)]="examForm.start" /></div>
              <div class="field"><label>End *</label><input class="input" type="date" [(ngModel)]="examForm.end" /></div>
            </div>
            @if (formError) { <div style="color:var(--crit-text);font-size:13px;">{{ formError }}</div> }
          </div>
          <div class="modal-foot"><button class="btn btn-ghost" (click)="showExam = false">Cancel</button><button class="btn btn-primary" (click)="saveExam()">Create Exam</button></div>
        </div>
      </div>
    }

    @if (showPaper) {
      <div class="modal-backdrop" (click)="showPaper = false">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head"><h2>Add Subject</h2><button class="modal-close" (click)="showPaper = false">✕</button></div>
          <div class="modal-body">
            <div class="form-row">
              <div class="field"><label>Subject *</label><select class="select" [(ngModel)]="paperForm.subject"><option>English</option><option>Mathematics</option><option>Science</option><option>Nepali</option><option>Social Studies</option><option>Computer Science</option><option>Health &amp; PE</option><option>Optional Mathematics</option></select></div>
              <div class="field"><label>Date *</label><input class="input" type="date" [(ngModel)]="paperForm.date" /></div>
            </div>
            <div class="form-row">
              <div class="field"><label>Start time</label><input class="input" type="time" [(ngModel)]="paperForm.start" /></div>
              <div class="field"><label>End time</label><input class="input" type="time" [(ngModel)]="paperForm.end" /></div>
            </div>
            <div class="form-row">
              <div class="field"><label>Room</label><input class="input" [(ngModel)]="paperForm.room" placeholder="Hall A" /></div>
              <div class="field"><label>Full marks</label><input class="input" type="number" [(ngModel)]="paperForm.full" /></div>
            </div>
            @if (formError) { <div style="color:var(--crit-text);font-size:13px;">{{ formError }}</div> }
          </div>
          <div class="modal-foot"><button class="btn btn-ghost" (click)="showPaper = false">Cancel</button><button class="btn btn-primary" (click)="savePaper()">Add Subject</button></div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class AdExamsComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  exams: ExamDto[] = [];
  selected: ExamDto | null = null;
  loading = true;
  error = '';
  formError = '';
  toast = '';
  showExam = false;
  showPaper = false;
  examForm = { name: '', type: 'Term', classes: 'G6-G10', start: '', end: '' };
  paperForm = { subject: 'English', date: '', start: '08:00', end: '10:00', room: 'Hall A', full: 100 };
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void { this.reload(); }
  reload(): void {
    this.api.getExams().subscribe({
      next: e => {
        this.exams = e; this.loading = false; this.error = '';
        this.selected = this.selected ? e.find(x => x.id === this.selected!.id) ?? e[0] ?? null : e[0] ?? null;
      },
      error: err => { this.error = adminApiError(err); this.loading = false; },
    });
  }
  openExam(): void { this.showExam = true; this.formError = ''; this.examForm = { name: '', type: 'Term', classes: 'G6-G10', start: '', end: '' }; }
  saveExam(): void {
    if (!this.examForm.name.trim() || !this.examForm.start || !this.examForm.end) { this.formError = 'Name, start and end are required.'; return; }
    this.api.createExam({ name: this.examForm.name.trim(), type: this.examForm.type, startDate: this.examForm.start, endDate: this.examForm.end, classes: this.examForm.classes }).subscribe({
      next: () => { this.showExam = false; this.showToast('Exam scheduled'); this.reload(); },
      error: e => this.formError = adminApiError(e),
    });
  }
  openPaper(): void { this.showPaper = true; this.formError = ''; this.paperForm = { subject: 'English', date: this.selected?.startDate?.slice(0,10) ?? '', start: '08:00', end: '10:00', room: 'Hall A', full: 100 }; }
  savePaper(): void {
    if (!this.selected || !this.paperForm.subject || !this.paperForm.date) { this.formError = 'Subject and date are required.'; return; }
    const time = this.paperForm.start && this.paperForm.end ? `${this.paperForm.start} – ${this.paperForm.end}` : this.paperForm.start;
    this.api.addPaper({ examId: this.selected.id, classLabel: this.selected.classes ?? '', subject: this.paperForm.subject, examDate: this.paperForm.date, time, room: this.paperForm.room.trim(), fullMarks: Number(this.paperForm.full) || 100 }).subscribe({
      next: () => { this.showPaper = false; this.showToast('Subject added'); this.reload(); },
      error: e => this.formError = adminApiError(e),
    });
  }
  removePaper(p: ExamPaperDto): void {
    if (!confirm(`Remove ${p.subject}?`)) return;
    this.api.deletePaper(p.id).subscribe({ next: () => { this.showToast('Subject removed'); this.reload(); }, error: e => alert(adminApiError(e)) });
  }
  examBadge(s: string): string {
    switch (s) { case 'completed': case 'result_published': return 'success'; case 'ongoing': return 'warning'; default: return 'info'; }
  }
  label(s: string): string { return s ? (s.charAt(0).toUpperCase() + s.slice(1)).replace(/_/g, ' ') : ''; }
  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }
}
