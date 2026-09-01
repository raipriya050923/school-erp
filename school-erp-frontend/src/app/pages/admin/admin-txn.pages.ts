import { Component, OnInit, inject } from '@angular/core';
import { DecimalPipe, DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {
  AdminApiService, adminApiError,
  ClassDto, StudentListItem, AttendanceRow, AttendanceReport, ExamDto, ExamPaperDto,
  FeeInvoiceDto, FeeSummaryDto, FeeInvoiceLineDto,
  ExamApprovalDto,
} from '../../core/admin-api.service';
import { FieldErrors } from '../../shared/field-errors';

/**
 * Today as `yyyy-MM-dd` in the browser's own timezone — what an `<input type="date">` expects.
 * Built from the local parts on purpose: `toISOString()` converts to UTC and lands on the
 * wrong day either side of midnight.
 */
export function todayIso(): string {
  return isoDate(new Date());
}

/** First and last day of the month we are currently in, as `yyyy-MM-dd`. */
export function currentMonthRange(): { from: string; to: string } {
  const d = new Date();
  // Day 0 of the next month is the last day of this one, leap years included.
  return {
    from: isoDate(new Date(d.getFullYear(), d.getMonth(), 1)),
    to: isoDate(new Date(d.getFullYear(), d.getMonth() + 1, 0)),
  };
}

function isoDate(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

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
  date = todayIso();
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
  from = currentMonthRange().from;
  to = currentMonthRange().to;
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
        <div class="stat-tile"><div class="stat-label">Total Billed</div><div class="stat-value">₹{{ summary.totalBilled | number }}</div></div>
        <div class="stat-tile"><div class="stat-label">Collected</div><div class="stat-value">₹{{ summary.collected | number }}</div><div class="stat-sub up">{{ pct }}% of billed</div></div>
        <div class="stat-tile"><div class="stat-label">Outstanding</div><div class="stat-value">₹{{ summary.outstanding | number }}</div><div class="stat-sub" [class.down]="summary.outstanding>0">{{ summary.unpaid }} unpaid/partial</div></div>
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
                  <td class="num"><button class="link-amount" (click)="openBreakdown(i)" title="What makes up this amount">₹{{ i.amount | number }}</button></td>
                  <td class="num">@if (i.balance > 0) { <span style="color:var(--crit-text);font-weight:600;">₹{{ i.balance | number }}</span> } @else { <span class="td-sub">—</span> }</td>
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
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>Record Payment — {{ inv.invoiceNo }}</h2><button class="modal-close" (click)="paying = null">✕</button></div>
          <div class="modal-body">
            <div class="kv-row"><span class="kv-label">Student</span><span class="kv-value">{{ inv.studentName }}</span></div>
            <div class="kv-row" style="margin-bottom:12px;"><span class="kv-label">Balance</span><span class="kv-value" style="color:var(--crit-text);">₹{{ inv.balance | number }}</span></div>
            <div class="form-row">
              <div class="field">
                <label>Amount (₹) <span class="req">*</span></label>
                <input class="input" type="number" min="0" [max]="inv.balance" [class.invalid]="err.has('amount')"
                       [(ngModel)]="payForm.amount" (ngModelChange)="err.clear('amount')" />
                @if (err.has('amount')) { <div class="field-error">{{ err.get('amount') }}</div> }
              </div>
              <div class="field">
                <label>Date <span class="req">*</span></label>
                <input class="input" type="date" [max]="today" [class.invalid]="err.has('payDate')"
                       [(ngModel)]="payForm.date" (ngModelChange)="err.clear('payDate')" />
                @if (err.has('payDate')) { <div class="field-error">{{ err.get('payDate') }}</div> }
              </div>
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
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>Generate Monthly Invoices</h2><button class="modal-close" (click)="showGen = false">✕</button></div>
          <div class="modal-body">
            <div class="form-row">
              <div class="field">
                <label>Billing month <span class="req">*</span></label>
                <input class="input" [class.invalid]="err.has('month')" [(ngModel)]="genForm.month"
                       (ngModelChange)="err.clear('month')" placeholder="August 2026" />
                @if (err.has('month')) { <div class="field-error">{{ err.get('month') }}</div> }
              </div>
              <div class="field">
                <label>Due date <span class="req">*</span></label>
                <input class="input" type="date" [class.invalid]="err.has('due')" [(ngModel)]="genForm.due"
                       (ngModelChange)="err.clear('due')" />
                @if (err.has('due')) { <div class="field-error">{{ err.get('due') }}</div> }
              </div>
            </div>
            <div class="field"><label>Class</label>
              <select class="select" [(ngModel)]="genForm.cls"><option value="All">All classes</option>@for (c of classes; track c) { <option [value]="c">{{ c }}</option> }</select>
            </div>
            <label class="check"><input type="checkbox" [(ngModel)]="genForm.includeOneOff" /> Also bill yearly &amp; one-time charges</label>
            <div class="td-sub">
              Creates one invoice per active student who isn't already billed for that month.
              Amounts come from Fee Structure — monthly heads always, yearly and one-time only when ticked.
            </div>
            @if (formError) { <div style="color:var(--crit-text);font-size:13px;margin-top:8px;">{{ formError }}</div> }
          </div>
          <div class="modal-foot"><button class="btn btn-ghost" (click)="showGen = false">Cancel</button><button class="btn btn-primary" (click)="generate()" [disabled]="saving">Generate</button></div>
        </div>
      </div>
    }

    @if (breakdownOf; as inv) {
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>{{ inv.invoiceNo }} — Breakdown</h2><button class="modal-close" (click)="breakdownOf = null">✕</button></div>
          <div class="modal-body">
            <div class="kv-row"><span class="kv-label">Student</span><span class="kv-value">{{ inv.studentName }}</span></div>
            <div class="kv-row" style="margin-bottom:12px;"><span class="kv-label">Billed for</span><span class="kv-value">{{ inv.month }}</span></div>
            @if (breakdown === null) { <div class="empty">Loading…</div> }
            @else {
              <table class="data-table">
                <thead><tr><th>Fee head</th><th class="num">Amount</th></tr></thead>
                <tbody>
                  @for (l of breakdown; track l.description) {
                    <tr><td>{{ l.description }}</td><td class="num">₹{{ l.amount | number }}</td></tr>
                  }
                  <tr><td class="td-main">Total</td><td class="num"><strong>₹{{ inv.amount | number }}</strong></td></tr>
                </tbody>
              </table>
              <div class="td-sub" style="margin-top:10px;">
                These are the prices that were in force when the invoice was raised. Changing Fee
                Structure now affects the next run, not this invoice.
              </div>
            }
          </div>
          <div class="modal-foot"><button class="btn btn-ghost" (click)="breakdownOf = null">Close</button></div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
  styles: [`
    .link-amount { background:none; border:none; padding:0; font:inherit; color:inherit; cursor:pointer; border-bottom:1px dashed var(--muted,#9ca3af); }
    .link-amount:hover { color: var(--accent,#2563eb); }
    .check { display:flex; align-items:center; gap:8px; font-size:13px; margin:8px 0 4px; }
  `],
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
  breakdownOf: FeeInvoiceDto | null = null;
  /** null while the lines are still loading. */
  breakdown: FeeInvoiceLineDto[] | null = null;
  payForm = { amount: 0, date: '2026-07-05', method: 'cash', ref: '' };
  genForm = { month: 'August 2026', due: '2026-08-10', cls: 'All', includeOneOff: false };
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
  /** Per-field messages for the payment and generate dialogs. */
  readonly err = new FieldErrors();
  readonly today = new Date().toISOString().slice(0, 10);

  openPay(i: FeeInvoiceDto): void {
    this.paying = i;
    this.formError = '';
    this.err.reset();
    this.payForm = { amount: i.balance, date: this.today, method: 'cash', ref: '' };
  }
  savePay(): void {
    if (!this.paying) return;
    this.formError = '';
    this.err.reset();
    const amount = Number(this.payForm.amount);
    this.err.check('amount', amount > 0, 'Enter an amount greater than zero.');
    // The server rejects an overpayment anyway; catching it here says which box is wrong.
    this.err.check('amount', amount <= this.paying.balance,
      `That is more than the ₹${this.paying.balance} outstanding.`);
    if (this.err.require('payDate', this.payForm.date, 'Payment date is required.'))
      this.err.check('payDate', this.payForm.date <= this.today, 'Payment date cannot be in the future.');
    if (this.err.any) return;
    this.saving = true;
    this.api.recordFeePayment(this.paying.id, { amount: Number(this.payForm.amount), method: this.payForm.method, ref: this.payForm.ref.trim(), paymentDate: this.payForm.date }).subscribe({
      next: () => { this.saving = false; this.showToast('Payment recorded'); this.paying = null; this.reload(); },
      error: e => { this.saving = false; this.formError = adminApiError(e); },
    });
  }
  openBreakdown(i: FeeInvoiceDto): void {
    this.breakdownOf = i;
    this.breakdown = null;
    this.api.invoiceLines(i.id).subscribe({ next: l => this.breakdown = l, error: () => this.breakdown = [] });
  }

  openGenerate(): void {
    this.showGen = true;
    this.formError = '';
    this.err.reset();
    // Default to this month and a due date at its end, rather than a date fixed in the source.
    const now = new Date();
    const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0);
    this.genForm = {
      month: now.toLocaleString('en-US', { month: 'long', year: 'numeric' }),
      due: monthEnd.toISOString().slice(0, 10),
      cls: 'All', includeOneOff: false,
    };
  }
  generate(): void {
    this.formError = '';
    this.err.reset();
    this.err.require('month', this.genForm.month, 'Billing month is required.');
    this.err.require('due', this.genForm.due, 'Due date is required.');
    if (this.err.any) return;
    this.saving = true;
    this.api.generateInvoices(this.genForm.month.trim(), this.genForm.due, this.genForm.cls, this.genForm.includeOneOff).subscribe({
      next: r => {
        this.saving = false;
        // Unpriced classes are the one outcome worth interrupting for: nothing was billed for
        // those students and the reason is fixable on the Fee Structure screen.
        if (r.unpricedClasses.length) {
          alert(`${r.created} invoice(s) generated.

No invoice for ${r.unpricedClasses.join(', ')} — those classes have no prices set. Add them under Fee Structure and run this again.`);
        } else {
          this.showToast(r.created > 0
            ? `${r.created} invoice(s) generated`
            : `No new invoices — ${r.alreadyBilled} student(s) already billed for ${this.genForm.month.trim()}`);
        }
        this.showGen = false;
        this.reload();
      },
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

/** One class's papers within an exam, summarised for the schedule table. */
interface PaperGroup {
  classLabel: string;
  papers: ExamPaperDto[];
  dateRange: string;
  summary: string;
  totalMarks: number;
}

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
                  <td>
                    <select class="select sm" [ngModel]="e.isManualStatus ? e.status : 'auto'"
                            (ngModelChange)="setExamStatus(e, $event)"
                            [class]="'select sm status-' + examBadge(e.status)">
                      <option value="auto">Auto — {{ label(e.derivedStatus) }}</option>
                      @for (s of statusOptions; track s) {
                        <option [value]="s">{{ label(s) }}</option>
                      }
                    </select>
                    @if (e.isManualStatus) {
                      <div class="td-sub">pinned · dates say {{ label(e.derivedStatus) }}</div>
                    }
                  </td>
                  <td>
                    <div class="row-actions">
                      <button class="btn btn-ghost btn-sm" (click)="selectExam(e)">Papers</button>
                      <button class="btn btn-ghost btn-sm" (click)="editExam(e)">Edit</button>
                      <button class="icon-action danger" (click)="deleteExam(e)" title="Delete" aria-label="Delete">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6M14 11v6"/></svg>
                      </button>
                    </div>
                  </td>
                </tr>
              } @empty { <tr><td colspan="7"><div class="empty">No exams yet.</div></td></tr> }
            </tbody>
          </table>
        </div>
      }
    </div>

    @if (selected; as e) {
      <div class="card">
        <div class="card-head"><div class="grow"><h2>Subject Schedule — {{ e.name }}</h2></div><button class="btn btn-primary btn-sm" (click)="openPaper()" [disabled]="!classes.length">+ Add Subject</button></div>
        <!-- One row per class: an exam covering several classes repeats the same five or six
             subjects, and listing every paper made three timetables read as one long duplicate. -->
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Class</th><th class="num">Papers</th><th>Dates</th><th>Subjects</th><th class="num">Total marks</th><th>Actions</th></tr></thead>
            <tbody>
              @for (g of paperGroups(e); track g.classLabel) {
                <tr>
                  <td class="td-main">{{ g.classLabel }}</td>
                  <td class="num">{{ g.papers.length }}</td>
                  <td class="td-sub">{{ g.dateRange }}</td>
                  <td class="td-sub">{{ g.summary }}</td>
                  <td class="num">{{ g.totalMarks }}</td>
                  <td>
                    <div class="row-actions">
                      <button class="btn btn-ghost btn-sm" (click)="viewingClass = g.classLabel">View</button>
                      <button class="btn btn-ghost btn-sm" (click)="openPaper(g.classLabel)">+ Subject</button>
                    </div>
                  </td>
                </tr>
              } @empty { <tr><td colspan="6"><div class="empty">No papers yet — add subjects.</div></td></tr> }
            </tbody>
          </table>
        </div>
      </div>
    }

    <!-- One class's timetable for the exam -->
    @if (viewingGroup; as g) {
      <div class="modal-backdrop">
        <div class="modal" style="max-width: 780px;">
          <div class="modal-head">
            <div class="grow">
              <h2>{{ g.classLabel }} — {{ selected?.name }}</h2>
              <div class="td-sub" style="margin-top:2px;">
                {{ g.papers.length }} paper{{ g.papers.length === 1 ? '' : 's' }} ·
                {{ g.dateRange }} · {{ g.totalMarks }} marks in total
              </div>
            </div>
            <button class="modal-close" (click)="viewingClass = null">✕</button>
          </div>
          <div class="modal-body">
            <div class="table-wrap">
              <table class="data-table">
                <thead><tr><th>Date</th><th>Subject</th><th>Time</th><th>Room</th><th class="num">Full Marks</th><th>Actions</th></tr></thead>
                <tbody>
                  @for (p of g.papers; track p.id) {
                    <tr>
                      <td class="td-sub">{{ p.examDate | date:'mediumDate' }}<div class="td-sub">{{ dayName(p.examDate) }}</div></td>
                      <td class="td-main">{{ p.subject }}</td>
                      <td>{{ p.time || '—' }}</td>
                      <td>{{ p.room || '—' }}</td>
                      <td class="num">{{ p.fullMarks }}</td>
                      <td>
                        <button class="icon-action danger" (click)="removePaper(p)" title="Remove" aria-label="Remove">
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2m2 0v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/></svg>
                        </button>
                      </td>
                    </tr>
                  }
                </tbody>
              </table>
            </div>
            @if (clashDays(g).length) {
              <div class="field-error" style="margin-top:10px;">
                More than one paper on {{ clashDays(g).join(', ') }} — check whether that is intended.
              </div>
            }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="viewingClass = null">Close</button>
            <button class="btn btn-primary" (click)="openPaper(g.classLabel)">+ Add Subject</button>
          </div>
        </div>
      </div>
    } @else { <div class="card"><div class="empty">Select an exam above to schedule its subjects.</div></div> }

    <!-- Who the admin is waiting on before results can be published -->
    @if (selected; as e) {
      <div class="card">
        <div class="card-head">
          <div class="grow">
            <h2>Result Approvals — {{ e.name }}</h2>
            <div class="td-sub" style="margin-top:2px;">
              Each section is signed off by its class teacher. Publishing waits on all of them.
            </div>
          </div>
          @if (e.status === 'result_published') {
            <span class="badge badge-success">Published</span>
          } @else if (approvals.length && allApproved) {
            <button class="btn btn-primary btn-sm" (click)="setExamStatus(e, 'result_published')">Publish Results</button>
          } @else {
            <span class="badge badge-neutral">{{ approvedCount }} of {{ approvals.length }} approved</span>
          }
        </div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Class</th><th>Section</th><th class="num">Marks complete</th><th>Status</th><th>Approved by</th><th>When</th></tr></thead>
            <tbody>
              @for (a of approvals; track a.className + a.sectionName) {
                <tr>
                  <td class="td-main">{{ a.className }}</td>
                  <td>{{ a.sectionName }}</td>
                  <td class="num">{{ a.completeCount }} / {{ a.studentCount }}</td>
                  <td>
                    <span class="badge" [class]="a.status === 'approved' ? 'badge success' : 'badge neutral'">
                      {{ a.status === 'approved' ? 'Approved' : 'Pending' }}
                    </span>
                  </td>
                  <td class="td-sub">{{ a.approvedByName || '—' }}</td>
                  <td class="td-sub">{{ a.approvedAt ? (a.approvedAt | date:'medium') : '—' }}</td>
                </tr>
              } @empty {
                <tr><td colspan="6"><div class="empty">No section sits this exam yet — add papers for a class first.</div></td></tr>
              }
            </tbody>
          </table>
        </div>
      </div>
    }

    @if (showExam) {
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>{{ editingExamId ? 'Edit Exam' : 'Schedule New Exam' }}</h2><button class="modal-close" (click)="showExam = false">✕</button></div>
          <div class="modal-body">
            <div class="field">
              <label>Name <span class="req">*</span></label>
              <input class="input" [class.invalid]="err.has('examName')" [(ngModel)]="examForm.name"
                     (ngModelChange)="err.clear('examName')" />
              @if (err.has('examName')) { <div class="field-error">{{ err.get('examName') }}</div> }
            </div>
            <div class="form-row">
              <div class="field"><label>Type</label><select class="select" [(ngModel)]="examForm.type"><option>Unit Test</option><option>Term</option><option>Quarterly</option><option>Half Yearly</option><option>Final</option></select></div>
              <div class="field"><label>Classes</label>
                <select class="select" [(ngModel)]="examForm.classes">
                  <option value="All">All classes</option>
                  @for (c of classes; track c) { <option [value]="c">{{ c }}</option> }
                </select>
                @if (!classes.length) { <div class="field-hint">No classes configured yet — add them under Classes &amp; Sections.</div> }
              </div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Start <span class="req">*</span></label>
                <input class="input" type="date" [class.invalid]="err.has('start')" [(ngModel)]="examForm.start"
                       (ngModelChange)="err.clear('start'); err.clear('end')" />
                @if (err.has('start')) { <div class="field-error">{{ err.get('start') }}</div> }
              </div>
              <div class="field">
                <label>End <span class="req">*</span></label>
                <input class="input" type="date" [class.invalid]="err.has('end')" [(ngModel)]="examForm.end"
                       (ngModelChange)="err.clear('end')" />
                @if (err.has('end')) { <div class="field-error">{{ err.get('end') }}</div> }
              </div>
            </div>
            @if (formError) { <div style="color:var(--crit-text);font-size:13px;">{{ formError }}</div> }
          </div>
          <div class="modal-foot"><button class="btn btn-ghost" (click)="showExam = false">Cancel</button><button class="btn btn-primary" (click)="saveExam()">{{ editingExamId ? 'Save Changes' : 'Create Exam' }}</button></div>
        </div>
      </div>
    }

    @if (showPaper) {
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>Add Subject</h2><button class="modal-close" (click)="showPaper = false">✕</button></div>
          <div class="modal-body">
            <div class="form-row">
              <div class="field">
                <label>Class <span class="req">*</span></label>
                <select class="select" [class.invalid]="err.has('classLabel')" [(ngModel)]="paperForm.classLabel"
                        (ngModelChange)="err.clear('classLabel'); err.clear('subject')">
                  <option value="">Select class…</option>
                  @if (paperClasses.length > 1) {
                    <option [value]="ALL_CLASSES">All classes ({{ paperClasses.length }})</option>
                  }
                  @for (c of paperClasses; track c) { <option [value]="c">{{ c }}</option> }
                </select>
                @if (err.has('classLabel')) { <div class="field-error">{{ err.get('classLabel') }}</div> }
                <div class="field-hint">
                  @if (paperForm.classLabel === ALL_CLASSES) {
                    Schedules this paper for {{ paperClasses.join(', ') }} on the same date and time.
                    Every section of a class sits its class's paper.
                  } @else {
                    A paper is scheduled for one class — every section of it sits the same paper.
                  }
                </div>
              </div>
              <div class="field">
                <label>Subject <span class="req">*</span></label>
                <select class="select" [class.invalid]="err.has('subject')" [(ngModel)]="paperForm.subject"
                        (ngModelChange)="err.clear('subject')">
                  <option value="">Select subject…</option>
                  @for (s of subjects; track s) { <option [value]="s">{{ s }}</option> }
                </select>
                @if (err.has('subject')) { <div class="field-error">{{ err.get('subject') }}</div> }
              </div>
              <div class="field">
                <label>Date <span class="req">*</span></label>
                <input class="input" type="date" [class.invalid]="err.has('paperDate')" [(ngModel)]="paperForm.date"
                       (ngModelChange)="err.clear('paperDate')" />
                @if (err.has('paperDate')) { <div class="field-error">{{ err.get('paperDate') }}</div> }
              </div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Start time</label>
                <input class="input" type="time" [(ngModel)]="paperForm.start" (ngModelChange)="err.clear('endTime')" />
              </div>
              <div class="field">
                <label>End time</label>
                <input class="input" type="time" [class.invalid]="err.has('endTime')" [(ngModel)]="paperForm.end"
                       (ngModelChange)="err.clear('endTime')" />
                @if (err.has('endTime')) { <div class="field-error">{{ err.get('endTime') }}</div> }
              </div>
            </div>
            <div class="form-row">
              <div class="field"><label>Room</label><input class="input" [(ngModel)]="paperForm.room" placeholder="Hall A" /></div>
              <div class="field">
                <label>Full marks <span class="req">*</span></label>
                <input class="input" type="number" min="1" [class.invalid]="err.has('full')"
                       [(ngModel)]="paperForm.full" (ngModelChange)="err.clear('full')" />
                @if (err.has('full')) { <div class="field-error">{{ err.get('full') }}</div> }
              </div>
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
  /** Backs the Classes dropdown on the schedule form. */
  classes: string[] = [];
  /** The school's own subjects, backing the Add Subject dropdown. */
  subjects: string[] = [];
  editingExamId: number | null = null;
  examForm = { name: '', type: 'Term', classes: 'All', start: '', end: '' };
  paperForm = { classLabel: '', subject: '', date: '', start: '08:00', end: '10:00', room: 'Hall A', full: 100 };
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void {
    this.reload();
    this.api.getClasses().subscribe({ next: c => this.classes = c.map(x => x.name), error: () => {} });
    this.api.getSubjects().subscribe({
      // Default the form to the first real subject rather than a hardcoded "English".
      next: s => { this.subjects = s; this.paperForm.subject = s[0] ?? ''; },
      error: () => {},
    });
  }
  reload(): void {
    this.api.getExams().subscribe({
      next: e => {
        this.exams = e; this.loading = false; this.error = '';
        this.selected = this.selected ? e.find(x => x.id === this.selected!.id) ?? e[0] ?? null : e[0] ?? null;
        this.loadApprovals();
      },
      error: err => { this.error = adminApiError(err); this.loading = false; },
    });
  }
  /** Only cancellation is stored — scheduled/ongoing/completed follow the exam's own dates. */
  /** Values an admin can pin. "auto" is offered separately, labelled with what the dates say. */
  readonly statusOptions = ['scheduled', 'ongoing', 'completed', 'result_published', 'cancelled'];

  setExamStatus(e: ExamDto, status: string): void {
    if (status === 'cancelled' && !confirm(`Cancel ${e.name}? Its papers are kept, but it will show as cancelled.`)) {
      this.reload();   // put the dropdown back where it was
      return;
    }
    this.api.setExamStatus(e.id, status).subscribe({
      next: () => {
        this.showToast(status === 'auto'
          ? `${e.name} follows its dates again`
          : `${e.name} set to ${this.label(status)}`);
        this.reload();
      },
      error: err => { alert(adminApiError(err)); this.reload(); },
    });
  }
  /** Per-field messages for the exam and paper dialogs. */
  readonly err = new FieldErrors();
  /** Sign-off state per section for the selected exam; publishing waits on all of them. */
  approvals: ExamApprovalDto[] = [];

  get approvedCount(): number { return this.approvals.filter(a => a.status === 'approved').length; }
  get allApproved(): boolean { return this.approvals.length > 0 && this.approvedCount === this.approvals.length; }

  selectExam(e: ExamDto): void { this.selected = e; this.loadApprovals(); }

  private loadApprovals(): void {
    const id = this.selected?.id;
    if (!id) { this.approvals = []; return; }
    this.api.examApprovals(id).subscribe({ next: a => this.approvals = a, error: () => this.approvals = [] });
  }

  openExam(): void {
    this.editingExamId = null;
    this.showExam = true; this.formError = ''; this.err.reset();
    this.examForm = { name: '', type: 'Term', classes: 'All', start: '', end: '' };
  }
  editExam(e: ExamDto): void {
    this.editingExamId = e.id;
    this.showExam = true; this.formError = ''; this.err.reset();
    this.examForm = {
      name: e.name, type: e.type ?? 'Term', classes: e.classes ?? 'All',
      start: e.startDate?.slice(0, 10) ?? '', end: e.endDate?.slice(0, 10) ?? '',
    };
  }
  saveExam(): void {
    this.formError = '';
    this.err.reset();
    this.err.require('examName', this.examForm.name, 'Exam name is required.');
    this.err.require('start', this.examForm.start, 'Start date is required.');
    if (this.err.require('end', this.examForm.end, 'End date is required.') && this.examForm.start)
      this.err.check('end', this.examForm.end >= this.examForm.start, 'End date must be on or after the start date.');
    if (this.err.any) return;
    const dto = {
      name: this.examForm.name.trim(), type: this.examForm.type,
      startDate: this.examForm.start, endDate: this.examForm.end, classes: this.examForm.classes,
    };
    const done = (m: string) => { this.showExam = false; this.editingExamId = null; this.showToast(m); this.reload(); };
    const fail = (e: unknown) => this.formError = adminApiError(e);
    if (this.editingExamId) this.api.updateExam(this.editingExamId, dto).subscribe({ next: () => done('Exam updated'), error: fail });
    else this.api.createExam(dto).subscribe({ next: () => done('Exam scheduled'), error: fail });
  }
  deleteExam(e: ExamDto): void {
    const papers = e.paperCount ? ` and its ${e.paperCount} paper(s)` : '';
    if (!confirm(`Delete ${e.name}${papers}? Any marks recorded against it are removed too.`)) return;
    this.api.deleteExam(e.id).subscribe({
      next: () => { if (this.selected?.id === e.id) this.selected = null; this.showToast('Exam deleted'); this.reload(); },
      error: err => alert(adminApiError(err)),
    });
  }
  /**
   * Classes a paper may be scheduled for. An exam covering "All" can have papers for any class;
   * one named for a single class is limited to it.
   */
  get paperClasses(): string[] {
    const only = this.selected?.classes;
    return only && only !== 'All' ? [only] : this.classes;
  }

  /** Sentinel for the "All classes" option; not a class name, so it cannot collide with one. */
  readonly ALL_CLASSES = '__all__';

  openPaper(classLabel?: string): void {
    // The dialog used to open with no exam chosen and then do nothing on save, because the
    // handler returned early on a null selection.
    if (!this.selected) { alert('Choose an exam first, then add its subjects.'); return; }
    if (!this.classes.length) { alert('Add classes under Classes & Sections before scheduling papers.'); return; }
    this.showPaper = true;
    this.formError = '';
    this.err.reset();
    this.paperForm = {
      // The class used to be taken silently from the exam, which wrote the literal "All" for an
      // all-classes exam — a label no class view could ever match. Adding from a class's own row
      // pre-selects it; the button above the table leaves it to be chosen.
      classLabel: classLabel && classLabel !== 'All classes' ? classLabel
                : this.paperClasses.length === 1 ? this.paperClasses[0] : '',
      subject: '', date: this.selected?.startDate?.slice(0, 10) ?? '',
      start: '08:00', end: '10:00', room: 'Hall A', full: 100,
    };
  }

  /**
   * The class whose timetable is open in the View dialog, or null when closed. Held as a name
   * rather than the group object so it re-derives after a paper is deleted and the exam reloads.
   */
  viewingClass: string | null = null;
  get viewingGroup(): PaperGroup | null {
    if (!this.viewingClass || !this.selected) return null;
    return this.paperGroups(this.selected).find(g => g.classLabel === this.viewingClass) ?? null;
  }

  /**
   * Papers grouped into one row per class, each already sorted into that class's own timetable.
   * An exam covering several classes repeats the same subjects, so a flat list of every paper
   * reads as duplicates on the same day.
   */
  paperGroups(e: ExamDto): PaperGroup[] {
    const byClass = new Map<string, ExamPaperDto[]>();
    for (const p of e.papers) {
      const key = p.classLabel?.trim() || 'All classes';
      (byClass.get(key) ?? byClass.set(key, []).get(key)!).push(p);
    }
    return [...byClass.entries()]
      .map(([classLabel, papers]) => {
        papers.sort((a, b) => (a.examDate ?? '').localeCompare(b.examDate ?? '') || a.subject.localeCompare(b.subject));
        const dates = papers.map(p => p.examDate).filter((d): d is string => !!d).sort();
        const names = papers.map(p => p.subject);
        return {
          classLabel, papers,
          dateRange: this.rangeLabel(dates),
          // Four names then a count: enough to recognise the set without wrapping the row.
          summary: names.length <= 4 ? names.join(', ') : names.slice(0, 4).join(', ') + ` +${names.length - 4}`,
          totalMarks: papers.reduce((n, p) => n + p.fullMarks, 0),
        };
      })
      .sort((a, b) => a.classLabel.localeCompare(b.classLabel, undefined, { numeric: true }));
  }

  private rangeLabel(dates: string[]): string {
    if (!dates.length) return '—';
    const fmt = (d: string) => new Date(d).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
    const first = fmt(dates[0]), last = fmt(dates[dates.length - 1]);
    return first === last ? first : `${first} — ${last}`;
  }

  dayName(date: string | null): string {
    return date ? new Date(date).toLocaleDateString(undefined, { weekday: 'long' }) : '';
  }

  /**
   * Days carrying more than one paper for the same class. Usually a mistake — every paper
   * defaults to the exam's start date, so forgetting to change it stacks them all on day one.
   */
  clashDays(g: PaperGroup): string[] {
    const seen = new Map<string, number>();
    for (const p of g.papers) {
      const d = (p.examDate ?? '').slice(0, 10);
      if (d) seen.set(d, (seen.get(d) ?? 0) + 1);
    }
    return [...seen.entries()]
      .filter(([, n]) => n > 1)
      .map(([d]) => new Date(d).toLocaleDateString(undefined, { month: 'short', day: 'numeric' }));
  }
  savePaper(): void {
    this.formError = '';
    this.err.reset();
    if (!this.selected) return;
    this.err.require('classLabel', this.paperForm.classLabel, 'Class is required.');
    if (this.paperForm.classLabel === this.ALL_CLASSES && this.paperClasses.length === 0)
      this.err.set('classLabel', 'There are no classes to schedule this for.');
    this.err.require('subject', this.paperForm.subject, 'Subject is required.');
    if (this.err.require('paperDate', this.paperForm.date, 'Date is required.')) {
      // A paper outside its exam's own dates is almost always a mis-typed month.
      const from = this.selected.startDate?.slice(0, 10);
      const to = this.selected.endDate?.slice(0, 10);
      if (from && to)
        this.err.check('paperDate', this.paperForm.date >= from && this.paperForm.date <= to,
          `Date must fall within the exam, ${from} to ${to}.`);
    }
    this.err.check('full', Number(this.paperForm.full) > 0, 'Full marks must be greater than zero.');
    if (this.paperForm.start && this.paperForm.end)
      this.err.check('endTime', this.paperForm.end > this.paperForm.start, 'End time must be after the start time.');
    if (this.err.any) return;
    const time = this.paperForm.start && this.paperForm.end ? `${this.paperForm.start} – ${this.paperForm.end}` : this.paperForm.start;
    // Resolved and checked here rather than left to the server: an empty list comes back as
    // "Class is required", which reads as though nothing was selected when in fact "All classes"
    // was — and says nothing about the class list being the thing that is missing.
    const targets = (this.paperForm.classLabel === this.ALL_CLASSES ? this.paperClasses : [this.paperForm.classLabel])
      .map(c => (c ?? '').trim())
      .filter(c => c.length > 0 && c !== this.ALL_CLASSES);
    if (!targets.length) {
      this.err.set('classLabel', this.classes.length
        ? 'Could not resolve which classes to schedule — reload the page and try again.'
        : 'No classes exist yet. Add them under Classes & Sections first.');
      return;
    }
    this.api.addPaper({
      examId: this.selected.id, classLabels: targets, subject: this.paperForm.subject,
      examDate: this.paperForm.date, time, room: this.paperForm.room.trim(),
      fullMarks: Number(this.paperForm.full) || 100,
    }).subscribe({
      next: r => {
        this.showPaper = false;
        // Naming the classes that were skipped matters: the run partly succeeded, and a bare
        // "Subject added" would hide that some classes already had it.
        this.showToast(r.alreadyScheduled.length
          ? `${this.paperForm.subject} scheduled for ${r.scheduled.join(', ')} · already on ${r.alreadyScheduled.join(', ')}`
          : `${this.paperForm.subject} scheduled for ${r.scheduled.join(', ')}`);
        this.reload();
      },
      error: e => this.formError = adminApiError(e),
    });
  }
  removePaper(p: ExamPaperDto): void {
    if (!confirm(`Remove ${p.subject}?`)) return;
    this.api.deletePaper(p.id).subscribe({ next: () => { this.showToast('Subject removed'); this.reload(); }, error: e => alert(adminApiError(e)) });
  }
  examBadge(s: string): string {
    switch (s) {
      case 'completed': case 'result_published': return 'success';
      case 'ongoing': return 'warning';
      case 'cancelled': return 'danger';
      default: return 'info';
    }
  }
  label(s: string): string { return s ? (s.charAt(0).toUpperCase() + s.slice(1)).replace(/_/g, ' ') : ''; }
  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }
}
