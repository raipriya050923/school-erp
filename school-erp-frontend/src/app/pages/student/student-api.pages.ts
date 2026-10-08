import { Component, OnInit, inject } from '@angular/core';
import { DecimalPipe, DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {
  StudentApiService, studentApiError, feeBadge, attBadge,
  StudentDashboard, StudentAttendance, StudentTimetableSlot, StudentTimetablePeriod, StudentHomework,
  StudentExams, StudentResult, StudentFee, StudentFeeSubmission, StudentNotice,
} from '../../core/student-api.service';
import { FeePaymentDto } from '../../core/admin-api.service';
import { FeeReceiptComponent, FeeReceipt } from '../../shared/fee-receipt.component';

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
        <div class="stat-tile"><div class="stat-label">Fee Due</div><div class="stat-value">₹{{ d.feeDue | number }}</div><div class="stat-sub" [class.down]="d.feeDue > 0">outstanding</div></div>
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
    <div class="page-head">
      <div class="grow">
        <h1>Class Timetable</h1>
        <div class="page-sub">
          @if (label) { {{ label }} }@if (label && slots.length) { · }@if (slots.length) { {{ slots.length }} periods across {{ days.length }} days }
          @if (!label && !slots.length) { Weekly schedule }
        </div>
      </div>
    </div>
    @if (loading) { <div class="card"><div class="empty">Loading…</div></div> }
    @else if (error) { <div class="card"><div class="empty">{{ error }}</div></div> }
    @else if (!periods.length) {
      <div class="card"><div class="empty">No periods are set up for your school yet.</div></div>
    }
    @else if (!slots.length) {
      <div class="card"><div class="empty">
        No timetable has been published for {{ label || 'your class' }} yet.
        Your school will add it under Timetable.
      </div></div>
    }
    @else {
      <div class="card">
        <div class="table-wrap">
          <table class="tt-grid">
            <thead>
              <tr>
                <th>Day</th>
                @for (p of periods; track p.periodNo) {
                  <th [class.tt-break]="p.isBreak">{{ p.name }}<div class="tt-meta">{{ p.timeLabel }}</div></th>
                }
              </tr>
            </thead>
            <tbody>
              @for (d of days; track d.num) {
                <tr>
                  <th>{{ d.label }}</th>
                  @for (p of periods; track p.periodNo) {
                    @if (p.isBreak) {
                      <td class="tt-break"><span class="tt-meta">Break</span></td>
                    } @else {
                      <td>
                        @if (slot(d.num, p.periodNo); as s) {
                          <span class="tt-subject">{{ s.subject }}</span>
                          <div class="tt-meta">{{ s.time }}@if (s.room) { · {{ s.room }} }</div>
                        } @else { <span class="tt-meta">—</span> }
                      </td>
                    }
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
  /** Columns, from the school's own period list — breaks included, so nothing shifts. */
  periods: StudentTimetablePeriod[] = [];
  /** Rows, from the school's working days rather than an assumed Sunday–Friday week. */
  days: { num: number; label: string }[] = [];
  /** "Grade 1 — A": names the class, so an empty grid says whose it is. */
  label = '';
  loading = true;
  error = '';

  private static readonly DAY_NAMES = [
    '', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  ];

  ngOnInit(): void {
    this.api.getTimetable().subscribe({
      next: t => {
        this.label = [t.className, t.sectionName].filter(Boolean).join(' — ');
        this.periods = t.periods;
        this.days = t.workingDays.map(n => ({ num: n, label: StTimetableComponent.DAY_NAMES[n] ?? `Day ${n}` }));
        this.slots = t.slots;
        this.loading = false;
      },
      error: e => { this.error = studentApiError(e); this.loading = false; },
    });
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

/**
 * The family's fee account, and where they declare a payment they have already made.
 *
 * Submitting changes nothing about what is owed — the school matches it against their own
 * statement first. That is the whole reason the invoice keeps saying "unpaid" with an
 * "awaiting confirmation" note beside it rather than settling on the payer's say-so.
 */
@Component({
  selector: 'app-st-fees',
  standalone: true,
  imports: [DecimalPipe, DatePipe, FormsModule, FeeReceiptComponent],
  template: `
    <div class="page-head"><div class="grow"><h1>My Fees</h1><div class="page-sub">Fee account</div></div></div>

    @if (receipt; as r) {
      <app-fee-receipt [r]="r" (closed)="receipt = null" />
    }

    @if (receiptsFor; as inv) {
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head">
            <h2>{{ inv.invoiceNo }} — receipts</h2>
            <button class="modal-close" (click)="receiptsFor = null">✕</button>
          </div>
          <div class="modal-body">
            @if (payments === null) { <div class="empty">Loading…</div> }
            @else if (!payments.length) {
              <div class="empty">
                Nothing has been confirmed against this invoice yet. A payment you have submitted
                appears here once the school confirms it.
              </div>
            } @else {
              <table class="data-table">
                <thead><tr><th>Receipt</th><th>Date</th><th>Method</th><th class="num">Amount</th><th></th></tr></thead>
                <tbody>
                  @for (pay of payments; track pay.id) {
                    <tr>
                      <td class="td-sub">{{ pay.receiptNo }}</td>
                      <td class="td-sub">{{ pay.paidDate | date:'mediumDate' }}</td>
                      <td class="td-sub">{{ pay.method || '—' }}</td>
                      <td class="num">₹{{ pay.amount | number }}</td>
                      <td><button class="btn btn-ghost btn-sm" (click)="openReceipt(pay.id)">View</button></td>
                    </tr>
                  }
                </tbody>
              </table>
            }
          </div>
          <div class="modal-foot"><button class="btn btn-ghost" (click)="receiptsFor = null">Close</button></div>
        </div>
      </div>
    }
    @if (loading) { <div class="card"><div class="empty">Loading…</div></div> }
    @else if (error) { <div class="card"><div class="empty">{{ error }}</div></div> }
    @else {
      <div class="stat-grid">
        <div class="stat-tile"><div class="stat-label">Outstanding</div><div class="stat-value">₹{{ outstanding | number }}</div><div class="stat-sub down">across {{ unpaidCount }} invoice(s)</div></div>
        <div class="stat-tile"><div class="stat-label">Paid</div><div class="stat-value">₹{{ paidTotal | number }}</div></div>
        <div class="stat-tile"><div class="stat-label">Awaiting confirmation</div><div class="stat-value">{{ pendingCount }}</div><div class="stat-sub">₹{{ pendingAmount | number }} submitted</div></div>
      </div>

      <div class="card">
        <div class="card-head"><h2 class="grow">Invoices</h2></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Invoice #</th><th>Month</th><th class="num">Amount</th><th class="num">Paid</th><th class="num">Balance</th><th>Due</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              @for (f of list; track f.id) {
                <tr>
                  <td class="td-sub">{{ f.invoiceNo }}</td>
                  <td class="td-main">{{ f.month }}</td>
                  <td class="num">₹{{ f.amount | number }}</td>
                  <td class="num">₹{{ f.paid | number }}</td>
                  <td class="num">@if (f.balance > 0) { <span style="color:var(--crit-text);font-weight:600;">₹{{ f.balance | number }}</span> } @else { <span class="td-sub">—</span> }</td>
                  <td class="td-sub">{{ f.dueDate | date:'mediumDate' }}</td>
                  <td><span class="badge" [class]="'badge ' + badge(f.status)">{{ label(f.status) }}</span></td>
                  <td>
                    <div class="row-actions">
                      @if (f.hasPendingSubmission) {
                        <span class="badge info">Awaiting confirmation</span>
                      } @else if (f.balance > 0) {
                        <button class="btn btn-primary btn-sm" (click)="openSubmit(f)">Submit payment</button>
                      }
                      <!--
                        Offered the moment anything has been paid, not only once the invoice is
                        settled: a family paying in instalments needs the receipt for the first
                        one straight away, which is the whole reason receipts are per payment.
                      -->
                      @if (f.paid > 0) {
                        <button class="btn btn-ghost btn-sm" (click)="openReceipts(f)">Receipts</button>
                      }
                      @if (!f.hasPendingSubmission && f.balance <= 0 && f.paid <= 0) {
                        <span class="td-sub">—</span>
                      }
                    </div>
                  </td>
                </tr>
              } @empty { <tr><td colspan="8"><div class="empty">No invoices.</div></td></tr> }
            </tbody>
          </table>
        </div>
      </div>

      @if (submissions.length) {
        <div class="card">
          <div class="card-head">
            <div class="grow">
              <h2>Payments you have submitted</h2>
              <div class="td-sub" style="margin-top:2px;">The school confirms each one against their own records.</div>
            </div>
          </div>
          <div class="table-wrap">
            <table class="data-table">
              <thead><tr><th>Submitted</th><th>For</th><th class="num">Amount</th><th>Method</th><th>Reference</th><th>Status</th></tr></thead>
              <tbody>
                @for (sub of submissions; track sub.id) {
                  <tr>
                    <td class="td-sub">{{ sub.submittedAt | date:'mediumDate' }}</td>
                    <td class="td-main">{{ sub.month || sub.invoiceNo }}</td>
                    <td class="num">₹{{ sub.amount | number }}</td>
                    <td class="td-sub">{{ methodLabel(sub.method) }}</td>
                    <td class="td-sub">{{ sub.reference || '—' }}</td>
                    <td>
                      <span class="badge" [class]="'badge ' + submissionBadge(sub.status)">{{ label(sub.status) }}</span>
                      <!-- A rejection with no reason cannot be acted on, so it always travels with one. -->
                      @if (sub.status === 'rejected' && sub.reviewNote) {
                        <div class="td-sub" style="margin-top:3px;max-width:260px;white-space:normal;">{{ sub.reviewNote }}</div>
                      }
                    </td>
                  </tr>
                }
              </tbody>
            </table>
          </div>
        </div>
      }
    }

    @if (paying; as inv) {
      <div class="modal-backdrop" (click)="paying = null">
        <div class="modal" (click)="$event.stopPropagation()" style="max-width: 540px;">
          <div class="modal-head">
            <div class="grow">
              <h2>Submit payment</h2>
              <div class="td-sub" style="margin-top:2px;">
                {{ inv.month || inv.invoiceNo }} · ₹{{ inv.balance | number }} outstanding
              </div>
            </div>
            <button class="modal-close" (click)="paying = null">✕</button>
          </div>
          <div class="modal-body">
            <div class="field-hint" style="margin-bottom:12px;">
              Pay the school first, then record it here. Nothing is deducted until the school
              confirms it against their own records.
            </div>
            <div class="form-row">
              <div class="field">
                <label>Amount paid <span class="req">*</span></label>
                <input class="input" type="number" min="1" [max]="inv.balance" step="1"
                       [(ngModel)]="form.amount" (ngModelChange)="formError = ''" />
              </div>
              <div class="field">
                <label>Paid on <span class="req">*</span></label>
                <input class="input" type="date" [max]="today"
                       [(ngModel)]="form.paidDate" (ngModelChange)="formError = ''" />
              </div>
            </div>
            <div class="field">
              <label>How did you pay? <span class="req">*</span></label>
              <select class="select" [(ngModel)]="form.method" (ngModelChange)="formError = ''">
                @for (m of methods; track m.value) { <option [value]="m.value">{{ m.label }}</option> }
              </select>
            </div>
            <div class="field">
              <label>
                Transaction / reference number
                @if (referenceRequired) { <span class="req">*</span> }
              </label>
              <input class="input" [(ngModel)]="form.reference" (ngModelChange)="formError = ''"
                     placeholder="e.g. UPI ref 418223344556" />
              <div class="field-hint">
                @if (referenceRequired) { This is what the school matches against their bank statement. }
                @else { Optional for cash — quote a receipt number if you were given one. }
              </div>
            </div>
            <div class="field">
              <label>Anything to add?</label>
              <input class="input" [(ngModel)]="form.note" (ngModelChange)="formError = ''"
                     placeholder="Optional note for the office" />
            </div>
            @if (formError) { <div class="field-error">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="paying = null">Cancel</button>
            <button class="btn btn-primary" (click)="submitPayment()" [disabled]="saving">
              {{ saving ? 'Submitting…' : 'Submit for confirmation' }}
            </button>
          </div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class StFeesComponent implements OnInit {
  private readonly api = inject(StudentApiService);
  list: StudentFee[] = [];
  submissions: StudentFeeSubmission[] = [];
  /** The invoice whose receipts are listed, or null when that dialog is closed. */
  receiptsFor: StudentFee | null = null;
  payments: FeePaymentDto[] | null = null;
  /** The receipt on screen. */
  receipt: FeeReceipt | null = null;
  loading = true;
  error = '';
  badge = feeBadge;

  /** Must match the methods the API accepts, or a submission is refused on arrival. */
  readonly methods = [
    { value: 'upi', label: 'UPI' },
    { value: 'bank_transfer', label: 'Bank transfer' },
    { value: 'cash', label: 'Cash' },
    { value: 'cheque', label: 'Cheque' },
    { value: 'card', label: 'Card' },
    { value: 'esewa', label: 'eSewa' },
    { value: 'khalti', label: 'Khalti' },
    { value: 'other', label: 'Other' },
  ];

  paying: StudentFee | null = null;
  form = { amount: 0, method: 'upi', reference: '', paidDate: '', note: '' };
  saving = false;
  formError = '';
  toast = '';
  private timer?: ReturnType<typeof setTimeout>;

  get today(): string { return new Date().toISOString().slice(0, 10); }
  get outstanding(): number { return this.list.reduce((n, f) => n + f.balance, 0); }
  get paidTotal(): number { return this.list.reduce((n, f) => n + f.paid, 0); }
  get unpaidCount(): number { return this.list.filter(f => f.balance > 0).length; }
  get pending(): StudentFeeSubmission[] { return this.submissions.filter(s => s.status === 'pending'); }
  get pendingCount(): number { return this.pending.length; }
  get pendingAmount(): number { return this.pending.reduce((n, s) => n + s.amount, 0); }

  /** Cash needs no reference; anything that moved electronically leaves one to quote. */
  get referenceRequired(): boolean { return this.form.method !== 'cash' && this.form.method !== 'other'; }

  openReceipts(f: StudentFee): void {
    this.receiptsFor = f;
    this.payments = null;
    this.api.invoicePayments(f.id).subscribe({
      next: p => this.payments = p,
      error: () => this.payments = [],
    });
  }

  openReceipt(paymentId: number): void {
    this.api.paymentReceipt(paymentId).subscribe({
      next: r => this.receipt = r,
      error: e => alert(studentApiError(e)),
    });
  }

  ngOnInit(): void { this.load(); }

  private load(): void {
    this.api.getFees().subscribe({
      next: f => { this.list = f; this.loading = false; this.error = ''; },
      error: e => { this.error = studentApiError(e); this.loading = false; },
    });
    this.api.getFeeSubmissions().subscribe({
      next: s => this.submissions = s,
      error: () => this.submissions = [],
    });
  }

  openSubmit(f: StudentFee): void {
    // The balance is the usual case and the maximum the server will take, so it is the default.
    this.form = { amount: f.balance, method: 'upi', reference: '', paidDate: this.today, note: '' };
    this.formError = '';
    this.paying = f;
  }

  submitPayment(): void {
    const inv = this.paying;
    if (!inv) return;
    const amount = Number(this.form.amount);
    if (!Number.isFinite(amount) || amount <= 0) { this.formError = 'Enter the amount you paid.'; return; }
    if (amount > inv.balance) { this.formError = `That is more than the ₹${inv.balance} still owing.`; return; }
    if (!this.form.paidDate) { this.formError = 'When did you pay?'; return; }
    if (this.form.paidDate > this.today) { this.formError = 'The payment date cannot be in the future.'; return; }
    if (this.referenceRequired && !this.form.reference.trim()) {
      this.formError = 'Enter the transaction or reference number.';
      return;
    }

    this.saving = true;
    this.api.submitFeePayment(inv.id, {
      amount,
      method: this.form.method,
      reference: this.form.reference.trim() || null,
      paidDate: this.form.paidDate,
      note: this.form.note.trim() || null,
    }).subscribe({
      next: () => {
        this.saving = false;
        this.paying = null;
        this.showToast('Submitted — the school will confirm it shortly');
        this.load();
      },
      error: e => { this.saving = false; this.formError = studentApiError(e); },
    });
  }

  submissionBadge(status: string): string {
    return status === 'verified' ? 'success' : status === 'rejected' ? 'danger' : 'info';
  }

  methodLabel(value: string): string {
    return this.methods.find(m => m.value === value)?.label ?? value;
  }

  label(s: string): string { return s ? s.charAt(0).toUpperCase() + s.slice(1) : ''; }

  private showToast(m: string): void {
    this.toast = m;
    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.toast = '', 3500);
  }
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
