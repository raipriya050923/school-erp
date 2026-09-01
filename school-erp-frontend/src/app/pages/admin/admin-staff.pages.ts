import { Component, OnInit, inject } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {
  AdminApiService, adminApiError, statusLabel,
  StaffAttendanceRow, StaffAttendanceSummary, LeaveApplicationDto, LeaveTypeDto, TeacherListItem,
} from '../../core/admin-api.service';
import { currentMonthRange, todayIso } from './admin-txn.pages';

/** Attendance statuses a staff member can be marked with, in the order the buttons appear. */
const STAFF_STATUSES = ['present', 'absent', 'late', 'half_day', 'on_leave'] as const;

/* =====================  STAFF ATTENDANCE  ===================== */

@Component({
  selector: 'app-ad-staff-attendance',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Staff Attendance</h1>
        <div class="page-sub">{{ rows.length }} staff · {{ markedCount }} marked present</div>
      </div>
      <button class="btn btn-primary" (click)="save()" [disabled]="saving || !rows.length">
        {{ saving ? 'Saving…' : 'Save Attendance' }}
      </button>
    </div>

    @if (summary) {
      <div class="stat-grid">
        <div class="stat-tile"><div class="stat-label">Present</div><div class="stat-value">{{ summary.present }}</div><div class="stat-sub">this month</div></div>
        <div class="stat-tile"><div class="stat-label">Absent</div><div class="stat-value">{{ summary.absent }}</div><div class="stat-sub" [class.down]="summary.absent > 0">this month</div></div>
        <div class="stat-tile"><div class="stat-label">Late</div><div class="stat-value">{{ summary.late }}</div><div class="stat-sub">this month</div></div>
        <div class="stat-tile"><div class="stat-label">On leave</div><div class="stat-value">{{ summary.onLeave }}</div><div class="stat-sub">this month</div></div>
      </div>
    }

    <div class="card">
      <div class="card-head filters">
        <h2 class="grow">Mark attendance</h2>
        <div class="field" style="margin:0;">
          <label style="font-size:11px;">Date</label>
          <input class="input" type="date" [max]="today" [(ngModel)]="date" (ngModelChange)="reload()" />
        </div>
        <button class="btn btn-ghost" (click)="setAll('present')">All present</button>
      </div>

      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Code</th><th>Staff</th><th>Status</th><th>Remarks</th></tr></thead>
            <tbody>
              @for (r of rows; track r.staffId) {
                <tr>
                  <td class="td-sub">{{ r.employeeCode }}</td>
                  <td class="td-main">{{ r.name }}</td>
                  <td>
                    <div class="row-actions">
                      @for (s of statuses; track s) {
                        <button class="btn btn-sm" [class.btn-primary]="r.status === s" [class.btn-ghost]="r.status !== s"
                                (click)="r.status = s">{{ label(s) }}</button>
                      }
                    </div>
                  </td>
                  <td><input class="input" style="max-width:220px;" placeholder="optional" [(ngModel)]="r.remarks" /></td>
                </tr>
              } @empty { <tr><td colspan="4"><div class="empty">No active staff.</div></td></tr> }
            </tbody>
          </table>
        </div>
      }
    </div>

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class AdStaffAttendanceComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  rows: StaffAttendanceRow[] = [];
  summary: StaffAttendanceSummary | null = null;
  readonly statuses = STAFF_STATUSES;
  readonly today = todayIso();
  date = todayIso();
  loading = true;
  saving = false;
  error = '';
  toast = '';
  label = statusLabel;
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void { this.reload(); this.loadSummary(); }

  get markedCount(): number { return this.rows.filter(r => r.status === 'present').length; }

  reload(): void {
    if (!this.date) return;
    this.loading = true;
    this.api.getStaffAttendance(this.date).subscribe({
      next: r => { this.rows = r; this.loading = false; this.error = ''; },
      error: e => { this.error = adminApiError(e); this.loading = false; },
    });
  }

  private loadSummary(): void {
    const { from, to } = currentMonthRange();
    this.api.getStaffAttendanceSummary(from, to).subscribe({ next: s => this.summary = s, error: () => {} });
  }

  setAll(status: string): void { this.rows.forEach(r => r.status = status); }

  save(): void {
    this.saving = true;
    const entries = this.rows.map(r => ({ staffId: r.staffId, status: r.status, remarks: r.remarks || null }));
    this.api.saveStaffAttendance(this.date, entries).subscribe({
      next: () => { this.saving = false; this.showToast('Attendance saved'); this.loadSummary(); },
      error: e => { this.saving = false; alert(adminApiError(e)); },
    });
  }

  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }
}

/* =====================  LEAVE REQUESTS  ===================== */

@Component({
  selector: 'app-ad-leave',
  standalone: true,
  imports: [FormsModule, DatePipe],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Leave Requests</h1>
        <div class="page-sub">{{ pendingCount }} awaiting review · {{ types.length }} leave types</div>
      </div>
      <button class="btn btn-ghost" (click)="openTypeForm()">+ Leave Type</button>
      <button class="btn btn-primary" (click)="openApply()">+ Apply for Staff</button>
    </div>

    <div class="card">
      <div class="card-head filters">
        <h2 class="grow">Requests</h2>
        <select class="select" [(ngModel)]="status" (ngModelChange)="reload()">
          <option value="">All</option>
          <option value="pending">Pending</option>
          <option value="approved">Approved</option>
          <option value="rejected">Rejected</option>
        </select>
      </div>

      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Staff</th><th>Type</th><th>Dates</th><th class="num">Days</th><th>Reason</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              @for (a of applications; track a.id) {
                <tr>
                  <td class="td-main">{{ a.applicantName }}</td>
                  <td>{{ a.leaveTypeName }}</td>
                  <td class="td-sub">{{ a.fromDate | date:'mediumDate' }} → {{ a.toDate | date:'mediumDate' }}</td>
                  <td class="num">{{ a.days }}</td>
                  <td class="td-sub" style="white-space:normal;max-width:260px;">{{ a.reason }}</td>
                  <td>
                    <span class="badge" [class]="'badge ' + badge(a.status)">{{ label(a.status) }}</span>
                    @if (a.reviewedByName) { <div class="td-sub">by {{ a.reviewedByName }}</div> }
                    @if (a.reviewRemarks) { <div class="td-sub">“{{ a.reviewRemarks }}”</div> }
                  </td>
                  <td>
                    @if (a.status === 'pending') {
                      <div class="row-actions">
                        <button class="btn btn-primary btn-sm" (click)="review(a, 'approved')">Approve</button>
                        <button class="btn btn-ghost btn-sm" (click)="review(a, 'rejected')">Reject</button>
                      </div>
                    } @else { <span class="td-sub">—</span> }
                  </td>
                </tr>
              } @empty { <tr><td colspan="7"><div class="empty">No leave requests.</div></td></tr> }
            </tbody>
          </table>
        </div>
      }
    </div>

    <div class="card">
      <div class="card-head"><h2 class="grow">Leave Types</h2><span class="td-sub">what staff can apply under</span></div>
      <div class="table-wrap">
        <table class="data-table">
          <thead><tr><th>Type</th><th>Paid</th><th class="num">Max days / year</th></tr></thead>
          <tbody>
            @for (t of types; track t.id) {
              <tr>
                <td class="td-main">{{ t.name }}</td>
                <td>@if (t.isPaid) { <span class="badge success">Paid</span> } @else { <span class="badge neutral">Unpaid</span> }</td>
                <td class="num">{{ t.maxDaysPerYear === null ? 'Unlimited' : t.maxDaysPerYear }}</td>
              </tr>
            } @empty { <tr><td colspan="3"><div class="empty">No leave types yet.</div></td></tr> }
          </tbody>
        </table>
      </div>
    </div>

    <!-- Record leave for someone who reported it to the office -->
    @if (showApply) {
      <div class="modal-backdrop">
        <div class="modal" style="max-width: 540px;">
          <div class="modal-head"><h2>Apply for Staff</h2><button class="modal-close" (click)="showApply = false">✕</button></div>
          <div class="modal-body">
            <div class="field">
              <label>Staff member <span class="req">*</span></label>
              <select class="select" [class.invalid]="!!errors.staffId" [(ngModel)]="applyForm.staffId"
                      (ngModelChange)="errors.staffId = ''">
                <option [ngValue]="0">Select a staff member…</option>
                @for (t of staff; track t.id) { <option [ngValue]="t.id">{{ t.name }}</option> }
              </select>
              @if (errors.staffId) { <div class="field-error">{{ errors.staffId }}</div> }
            </div>
            <div class="field">
              <label>Leave type <span class="req">*</span></label>
              <select class="select" [class.invalid]="!!errors.leaveTypeId" [(ngModel)]="applyForm.leaveTypeId"
                      (ngModelChange)="errors.leaveTypeId = ''">
                <option [ngValue]="0">Select a type…</option>
                @for (t of types; track t.id) { <option [ngValue]="t.id">{{ t.name }}{{ t.isPaid ? '' : ' (unpaid)' }}</option> }
              </select>
              @if (errors.leaveTypeId) { <div class="field-error">{{ errors.leaveTypeId }}</div> }
            </div>
            <div class="form-row">
              <div class="field">
                <label>From <span class="req">*</span></label>
                <input class="input" type="date" [class.invalid]="!!errors.fromDate"
                       [(ngModel)]="applyForm.fromDate" (ngModelChange)="onFromChange()" />
                @if (errors.fromDate) { <div class="field-error">{{ errors.fromDate }}</div> }
              </div>
              <div class="field">
                <label>To <span class="req">*</span></label>
                <input class="input" type="date" [class.invalid]="!!errors.toDate"
                       [(ngModel)]="applyForm.toDate" (ngModelChange)="errors.toDate = ''" />
                @if (errors.toDate) { <div class="field-error">{{ errors.toDate }}</div> }
              </div>
            </div>
            <div class="field">
              <label>Reason <span class="req">*</span></label>
              <textarea class="input" rows="3" [class.invalid]="!!errors.reason" [(ngModel)]="applyForm.reason"
                        (ngModelChange)="errors.reason = ''" placeholder="e.g. Phoned in sick this morning"></textarea>
              @if (errors.reason) { <div class="field-error">{{ errors.reason }}</div> }
            </div>
            <div class="field">
              <label style="display:flex;align-items:center;gap:8px;font-weight:500;">
                <input type="checkbox" [(ngModel)]="applyForm.autoApprove" /> Approve straight away
              </label>
              <div class="field-hint">
                Approved leave shows the person as “on leave” on Staff Attendance for those dates.
                Untick to leave it pending review.
              </div>
            </div>
            @if (formError) { <div class="field-error">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showApply = false">Cancel</button>
            <button class="btn btn-primary" (click)="saveApply()" [disabled]="saving">{{ saving ? 'Saving…' : 'Record Leave' }}</button>
          </div>
        </div>
      </div>
    }

    @if (showType) {
      <div class="modal-backdrop">
        <div class="modal" style="max-width: 460px;">
          <div class="modal-head"><h2>Add Leave Type</h2><button class="modal-close" (click)="showType = false">✕</button></div>
          <div class="modal-body">
            <div class="field">
              <label>Name <span class="req">*</span></label>
              <input class="input" [class.invalid]="!!typeErrors.name" [(ngModel)]="typeForm.name"
                     (ngModelChange)="typeErrors.name = ''" placeholder="e.g. Maternity Leave" />
              @if (typeErrors.name) { <div class="field-error">{{ typeErrors.name }}</div> }
            </div>
            <div class="form-row">
              <div class="field">
                <label>Max days per year</label>
                <input class="input" type="number" min="1" [class.invalid]="!!typeErrors.maxDays"
                       [(ngModel)]="typeForm.maxDaysPerYear" (ngModelChange)="typeErrors.maxDays = ''"
                       placeholder="Blank = unlimited" />
                @if (typeErrors.maxDays) { <div class="field-error">{{ typeErrors.maxDays }}</div> }
              </div>
              <div class="field">
                <label>Paid?</label>
                <select class="select" [(ngModel)]="typeForm.isPaid">
                  <option [ngValue]="true">Paid</option>
                  <option [ngValue]="false">Unpaid</option>
                </select>
              </div>
            </div>
            @if (typeError) { <div class="field-error">{{ typeError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showType = false">Cancel</button>
            <button class="btn btn-primary" (click)="saveType()" [disabled]="saving">{{ saving ? 'Saving…' : 'Add Type' }}</button>
          </div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class AdLeaveComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  applications: LeaveApplicationDto[] = [];
  types: LeaveTypeDto[] = [];
  staff: TeacherListItem[] = [];
  status = 'pending';
  loading = true;
  error = '';
  toast = '';
  saving = false;
  showApply = false;
  showType = false;
  formError = '';
  typeError = '';
  errors: { staffId?: string; leaveTypeId?: string; fromDate?: string; toDate?: string; reason?: string } = {};
  typeErrors: { name?: string; maxDays?: string } = {};
  applyForm = { staffId: 0, leaveTypeId: 0, fromDate: '', toDate: '', reason: '', autoApprove: true };
  typeForm: { name: string; isPaid: boolean; maxDaysPerYear: number | null } = { name: '', isPaid: true, maxDaysPerYear: null };
  label = statusLabel;
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void {
    this.reload();
    this.loadTypes();
    this.api.getTeachers().subscribe({ next: t => this.staff = t, error: () => this.staff = [] });
  }

  private loadTypes(): void {
    this.api.getLeaveTypes().subscribe({ next: t => this.types = t, error: () => this.types = [] });
  }

  openApply(): void {
    this.applyForm = { staffId: 0, leaveTypeId: 0, fromDate: '', toDate: '', reason: '', autoApprove: true };
    this.errors = {};
    this.formError = '';
    this.showApply = true;
  }

  /** Most recorded absences are a single day, so the end follows the start until changed. */
  onFromChange(): void {
    this.errors.fromDate = '';
    if (this.applyForm.fromDate && !this.applyForm.toDate) this.applyForm.toDate = this.applyForm.fromDate;
  }

  saveApply(): void {
    const e: typeof this.errors = {};
    if (!this.applyForm.staffId) e.staffId = 'Choose a staff member.';
    if (!this.applyForm.leaveTypeId) e.leaveTypeId = 'Choose a leave type.';
    if (!this.applyForm.fromDate) e.fromDate = 'From date is required.';
    if (!this.applyForm.toDate) e.toDate = 'To date is required.';
    else if (this.applyForm.fromDate && this.applyForm.toDate < this.applyForm.fromDate)
      e.toDate = 'The to date must be on or after the from date.';
    if (!this.applyForm.reason.trim()) e.reason = 'A reason is required.';
    this.errors = e;
    this.formError = '';
    if (Object.keys(e).length) return;

    this.saving = true;
    this.api.applyLeaveForStaff({
      staffId: Number(this.applyForm.staffId),
      leaveTypeId: Number(this.applyForm.leaveTypeId),
      fromDate: this.applyForm.fromDate,
      toDate: this.applyForm.toDate,
      reason: this.applyForm.reason.trim(),
      autoApprove: this.applyForm.autoApprove,
    }).subscribe({
      next: () => {
        this.saving = false; this.showApply = false;
        this.showToast(this.applyForm.autoApprove ? 'Leave recorded and approved' : 'Leave recorded for review');
        this.reload();
      },
      error: err => { this.saving = false; this.formError = adminApiError(err); },
    });
  }

  openTypeForm(): void {
    this.typeForm = { name: '', isPaid: true, maxDaysPerYear: null };
    this.typeErrors = {};
    this.typeError = '';
    this.showType = true;
  }

  saveType(): void {
    const e: typeof this.typeErrors = {};
    if (!this.typeForm.name.trim()) e.name = 'Name is required.';
    const max = this.typeForm.maxDaysPerYear;
    if (max !== null && (max as unknown as string) !== '' && Number(max) < 1)
      e.maxDays = 'Leave blank for unlimited, or enter 1 or more.';
    this.typeErrors = e;
    this.typeError = '';
    if (Object.keys(e).length) return;

    this.saving = true;
    this.api.createLeaveType({
      name: this.typeForm.name.trim(),
      isPaid: this.typeForm.isPaid,
      maxDaysPerYear: max === null || (max as unknown as string) === '' ? null : Number(max),
    }).subscribe({
      next: () => { this.saving = false; this.showType = false; this.showToast('Leave type added'); this.loadTypes(); },
      error: err => { this.saving = false; this.typeError = adminApiError(err); },
    });
  }

  get pendingCount(): number { return this.applications.filter(a => a.status === 'pending').length; }

  badge(s: string): string {
    switch (s) { case 'approved': return 'success'; case 'rejected': return 'danger'; case 'cancelled': return 'neutral'; default: return 'warning'; }
  }

  reload(): void {
    this.loading = true;
    this.api.getLeaveApplications(this.status || undefined).subscribe({
      next: a => { this.applications = a; this.loading = false; this.error = ''; },
      error: e => { this.error = adminApiError(e); this.loading = false; },
    });
  }

  review(a: LeaveApplicationDto, decision: string): void {
    const remarks = prompt(`${decision === 'approved' ? 'Approve' : 'Reject'} ${a.applicantName}'s leave — remarks (optional):`, '');
    if (remarks === null) return;   // cancelled the prompt
    this.api.reviewLeave(a.id, decision, remarks || null).subscribe({
      next: () => { this.showToast(`Leave ${decision}`); this.reload(); },
      error: e => alert(adminApiError(e)),
    });
  }

  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }
}
