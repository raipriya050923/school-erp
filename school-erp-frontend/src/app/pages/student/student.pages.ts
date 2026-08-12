import { Component, inject } from '@angular/core';
import { DecimalPipe } from '@angular/common';
import { DataService } from '../../core/data.service';

/* =====================  DASHBOARD  ===================== */

@Component({
  selector: 'app-st-dashboard',
  standalone: true,
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Hi Aarav 👋</h1>
        <div class="page-sub">Grade 8-A · Roll 12 · Friday, July 4, 2026</div>
      </div>
    </div>

    <div class="stat-grid">
      @for (s of data.studentStats; track s.label) {
        <div class="stat-tile">
          <div class="stat-label">{{ s.label }}</div>
          <div class="stat-value">{{ s.value }}</div>
          <div class="stat-sub" [class.up]="s.trend === 'up'" [class.down]="s.trend === 'down'">{{ s.sub }}</div>
        </div>
      }
    </div>

    <div class="grid-2">
      <div class="card">
        <div class="card-head"><h2 class="grow">Today’s Classes (Friday)</h2></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Period</th><th>Time</th><th>Subject</th></tr></thead>
            <tbody>
              @for (subj of today; track $index) {
                <tr>
                  <td class="td-main">P{{ $index + 1 }}</td>
                  <td class="td-sub">{{ data.periodTimes[$index] }}</td>
                  <td>{{ subj }}</td>
                </tr>
              }
            </tbody>
          </table>
        </div>
      </div>

      <div class="card">
        <div class="card-head"><h2 class="grow">Pending Homework</h2></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Assignment</th><th>Subject</th><th>Due</th></tr></thead>
            <tbody>
              @for (h of pending; track h.title) {
                <tr>
                  <td class="td-main">{{ h.title }}</td>
                  <td>{{ h.subject }}</td>
                  <td class="td-sub">{{ h.due }}</td>
                </tr>
              } @empty {
                <tr><td colspan="3"><div class="empty">All caught up! 🎉</div></td></tr>
              }
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `,
})
export class StDashboardComponent {
  readonly data = inject(DataService);
  readonly today = this.data.studentTimetable['Friday'] ?? [];
  readonly pending = this.data.studentHomework.filter(h => h.status === 'Pending');
}

/* =====================  ATTENDANCE  ===================== */

@Component({
  selector: 'app-st-attendance',
  standalone: true,
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>My Attendance</h1>
        <div class="page-sub">94.2% overall · 113 of 120 school days</div>
      </div>
    </div>

    <div class="stat-grid">
      @for (m of data.studentAttendanceSummary; track m.month) {
        <div class="stat-tile">
          <div class="stat-label">{{ m.month }}</div>
          <div class="stat-value">{{ m.pct }}%</div>
          <div class="stat-sub">{{ m.present }} present · {{ m.absent }} absent · {{ m.late }} late</div>
          <div class="meter" [class.good]="m.pct >= 90" style="margin-top:10px;">
            <span [style.width.%]="m.pct"></span>
          </div>
        </div>
      }
    </div>

    <div class="card">
      <div class="card-head"><h2 class="grow">Recent Days</h2></div>
      <div class="table-wrap">
        <table class="data-table">
          <thead><tr><th>Date</th><th>Day</th><th>Status</th></tr></thead>
          <tbody>
            @for (d of data.studentAttendanceRecent; track d.date) {
              <tr>
                <td class="td-sub">{{ d.date }}</td>
                <td>{{ d.day }}</td>
                <td><span class="badge" [class]="'badge ' + data.badgeClass(d.status)">{{ d.status }}</span></td>
              </tr>
            }
          </tbody>
        </table>
      </div>
    </div>
  `,
})
export class StAttendanceComponent {
  readonly data = inject(DataService);
}

/* =====================  TIMETABLE  ===================== */

@Component({
  selector: 'app-st-timetable',
  standalone: true,
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Class Timetable</h1>
        <div class="page-sub">Grade 8-A · Weekly schedule</div>
      </div>
    </div>

    <div class="card">
      <div class="table-wrap">
        <table class="tt-grid">
          <thead>
            <tr>
              <th>Day</th>
              @for (t of data.periodTimes; track $index) { <th>P{{ $index + 1 }}<br />{{ t }}</th> }
            </tr>
          </thead>
          <tbody>
            @for (day of days; track day) {
              <tr>
                <th>{{ day }}</th>
                @for (subj of data.studentTimetable[day]; track $index) {
                  <td [class.tt-break]="subj === 'Club'">
                    <span class="tt-subject">{{ subj }}</span>
                  </td>
                }
              </tr>
            }
          </tbody>
        </table>
      </div>
    </div>
  `,
})
export class StTimetableComponent {
  readonly data = inject(DataService);
  readonly days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
}

/* =====================  HOMEWORK  ===================== */

@Component({
  selector: 'app-st-homework',
  standalone: true,
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>My Homework</h1>
        <div class="page-sub">{{ pendingCount }} pending · {{ list.length }} total this term</div>
      </div>
    </div>

    <div class="card">
      <div class="table-wrap">
        <table class="data-table">
          <thead><tr><th>Assignment</th><th>Subject</th><th>Teacher</th><th>Due</th><th>Status</th><th></th></tr></thead>
          <tbody>
            @for (h of list; track h.title) {
              <tr>
                <td class="td-main">{{ h.title }}</td>
                <td>{{ h.subject }}</td>
                <td class="td-sub">{{ h.teacher }}</td>
                <td class="td-sub">{{ h.due }}</td>
                <td><span class="badge" [class]="'badge ' + data.badgeClass(h.status)">{{ h.status }}</span></td>
                <td>
                  @if (h.status === 'Pending') {
                    <button class="btn btn-primary btn-sm" (click)="submit(h)">Submit</button>
                  }
                </td>
              </tr>
            }
          </tbody>
        </table>
      </div>
    </div>
  `,
})
export class StHomeworkComponent {
  readonly data = inject(DataService);
  list = this.data.studentHomework.map(h => ({ ...h }));

  get pendingCount(): number {
    return this.list.filter(h => h.status === 'Pending').length;
  }

  submit(h: { status: string }): void {
    h.status = 'Submitted';
  }
}

/* =====================  EXAMS & RESULTS  ===================== */

@Component({
  selector: 'app-st-exams',
  standalone: true,
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Exams &amp; Results</h1>
        <div class="page-sub">Quarterly Assessment 2083 — result published</div>
      </div>
    </div>

    <div class="stat-grid">
      <div class="stat-tile">
        <div class="stat-label">Total</div>
        <div class="stat-value">{{ total }}/{{ fullTotal }}</div>
        <div class="stat-sub">{{ pct }}% aggregate</div>
      </div>
      <div class="stat-tile">
        <div class="stat-label">Overall Grade</div>
        <div class="stat-value">{{ data.grade(pct) }}</div>
        <div class="stat-sub up">Rank 4 of 38 in class</div>
      </div>
      <div class="stat-tile">
        <div class="stat-label">Next Exam</div>
        <div class="stat-value">Jul 14</div>
        <div class="stat-sub">Unit Test — July (3 days)</div>
      </div>
    </div>

    <div class="card">
      <div class="card-head"><h2 class="grow">Subject-wise Result — Quarterly Assessment</h2></div>
      <div class="table-wrap">
        <table class="data-table">
          <thead><tr><th>Subject</th><th class="num">Full Marks</th><th class="num">Obtained</th><th>Grade</th><th>Score</th></tr></thead>
          <tbody>
            @for (r of data.studentResults; track r.subject) {
              <tr>
                <td class="td-main">{{ r.subject }}</td>
                <td class="num">{{ r.fullMarks }}</td>
                <td class="num">{{ r.marks }}</td>
                <td><span class="badge" [class]="'badge ' + gradeBadge(r.marks / r.fullMarks)">{{ r.grade }}</span></td>
                <td>
                  <div class="meter" [class.good]="r.marks / r.fullMarks >= 0.8" style="max-width:160px;">
                    <span [style.width.%]="(r.marks / r.fullMarks) * 100"></span>
                  </div>
                </td>
              </tr>
            }
          </tbody>
        </table>
      </div>
    </div>

    <div class="card">
      <div class="card-head"><h2 class="grow">Upcoming — First Terminal Examination (Aug 17–26)</h2></div>
      <div class="table-wrap">
        <table class="data-table">
          <thead><tr><th>Date</th><th>Subject</th><th>Time</th><th>Room</th></tr></thead>
          <tbody>
            @for (s of firstTerminalSchedule; track s.date) {
              <tr>
                <td class="td-sub">{{ s.date }}</td>
                <td class="td-main">{{ s.subject }}</td>
                <td>{{ s.time }}</td>
                <td class="td-sub">{{ s.room }}</td>
              </tr>
            }
          </tbody>
        </table>
      </div>
    </div>
  `,
})
export class StExamsComponent {
  readonly data = inject(DataService);
  readonly firstTerminalSchedule =
    this.data.exams.find(e => e.name.includes('First Terminal'))?.schedule ?? [];
  readonly total = this.data.studentResults.reduce((n, r) => n + r.marks, 0);
  readonly fullTotal = this.data.studentResults.reduce((n, r) => n + r.fullMarks, 0);
  readonly pct = Math.round((this.total / this.fullTotal) * 100);

  gradeBadge(ratio: number): string {
    if (ratio >= 0.8) return 'success';
    if (ratio >= 0.6) return 'info';
    if (ratio >= 0.4) return 'warning';
    return 'danger';
  }
}

/* =====================  FEES  ===================== */

@Component({
  selector: 'app-st-fees',
  standalone: true,
  imports: [DecimalPipe],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>My Fees</h1>
        <div class="page-sub">Fee account for AY 2083</div>
      </div>
    </div>

    <div class="stat-grid">
      <div class="stat-tile">
        <div class="stat-label">Outstanding</div>
        <div class="stat-value">Rs {{ outstanding | number }}</div>
        <div class="stat-sub down">Due by Jul 10, 2026</div>
      </div>
      <div class="stat-tile">
        <div class="stat-label">Paid This Year</div>
        <div class="stat-value">Rs {{ paidTotal | number }}</div>
        <div class="stat-sub">3 payments</div>
      </div>
      <div class="stat-tile">
        <div class="stat-label">Monthly Fee</div>
        <div class="stat-value">Rs 12,500</div>
        <div class="stat-sub">Tuition + Transport (Route 4)</div>
      </div>
    </div>

    <div class="card">
      <div class="card-head"><h2 class="grow">Invoices</h2></div>
      <div class="table-wrap">
        <table class="data-table">
          <thead><tr><th>Invoice #</th><th>Month</th><th>Items</th><th class="num">Amount</th><th>Due Date</th><th>Status</th><th></th></tr></thead>
          <tbody>
            @for (f of data.studentFees; track f.no) {
              <tr>
                <td class="td-sub">{{ f.no }}</td>
                <td class="td-main">{{ f.month }}</td>
                <td class="td-sub">{{ f.items }}</td>
                <td class="num">Rs {{ f.amount | number }}</td>
                <td class="td-sub">{{ f.due }}</td>
                <td><span class="badge" [class]="'badge ' + data.badgeClass(f.status)">{{ f.status }}</span></td>
                <td>
                  @if (f.status === 'Unpaid') {
                    <button class="btn btn-primary btn-sm" (click)="pay(f.no)">Pay Online</button>
                  }
                </td>
              </tr>
            }
          </tbody>
        </table>
      </div>
    </div>
  `,
})
export class StFeesComponent {
  readonly data = inject(DataService);
  readonly outstanding = this.data.studentFees.filter(f => f.status === 'Unpaid').reduce((n, f) => n + f.amount - f.paid, 0);
  readonly paidTotal = this.data.studentFees.reduce((n, f) => n + f.paid, 0);

  pay(no: string): void {
    alert(`Demo build — invoice ${no} would open the eSewa/Khalti payment flow here.`);
  }
}

/* =====================  NOTICES  ===================== */

@Component({
  selector: 'app-st-notices',
  standalone: true,
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Notice Board</h1>
        <div class="page-sub">School announcements</div>
      </div>
    </div>

    <div class="card">
      @for (n of data.notices; track n.title) {
        <div class="notice-item">
          <div class="notice-title">{{ n.title }}</div>
          <div class="notice-meta">{{ n.date }} · {{ n.audience }}</div>
          <div class="notice-body">{{ n.body }}</div>
        </div>
      }
    </div>
  `,
})
export class StNoticesComponent {
  readonly data = inject(DataService);
}
