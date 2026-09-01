import { Component, OnInit, inject } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {
  TeacherApiService, teacherApiError, LeaveApplication, LeaveType,
} from '../../core/teacher-api.service';

/** A teacher's own leave: what they have asked for, and the form to ask for more. */
@Component({
  selector: 'app-tc-my-leave',
  standalone: true,
  imports: [FormsModule, DatePipe],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>My Leave</h1>
        <div class="page-sub">{{ pendingCount }} awaiting approval · {{ requests.length }} total</div>
      </div>
      <button class="btn btn-primary" (click)="openForm()">+ Apply for Leave</button>
    </div>

    <div class="card">
      <div class="card-head"><h2 class="grow">My Requests</h2></div>
      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Type</th><th>Dates</th><th class="num">Days</th><th>Reason</th><th>Status</th><th>Reviewed</th></tr></thead>
            <tbody>
              @for (r of requests; track r.id) {
                <tr>
                  <td class="td-main">{{ r.leaveTypeName }}</td>
                  <td class="td-sub">{{ r.fromDate | date:'mediumDate' }} → {{ r.toDate | date:'mediumDate' }}</td>
                  <td class="num">{{ r.days }}</td>
                  <td style="white-space:normal;max-width:280px;">{{ r.reason }}</td>
                  <td><span class="badge" [class]="'badge ' + badge(r.status)">{{ label(r.status) }}</span></td>
                  <td>
                    @if (r.reviewedByName) {
                      <div class="td-sub">{{ r.reviewedByName }} · {{ r.reviewedAt | date:'mediumDate' }}</div>
                      @if (r.reviewRemarks) { <div class="td-sub" style="white-space:normal;max-width:240px;">“{{ r.reviewRemarks }}”</div> }
                    } @else { <span class="td-sub">—</span> }
                  </td>
                </tr>
              } @empty {
                <tr><td colspan="6"><div class="empty">You have not applied for any leave yet.</div></td></tr>
              }
            </tbody>
          </table>
        </div>
      }
    </div>

    @if (showForm) {
      <div class="modal-backdrop">
        <div class="modal" style="max-width: 520px;">
          <div class="modal-head">
            <h2>Apply for Leave</h2>
            <button class="modal-close" (click)="showForm = false">✕</button>
          </div>
          <div class="modal-body">
            <div class="field">
              <label>Leave type <span class="req">*</span></label>
              <select class="select" [class.invalid]="!!errors.leaveTypeId" [(ngModel)]="form.leaveTypeId"
                      (ngModelChange)="errors.leaveTypeId = ''">
                <option [ngValue]="0">Select a type…</option>
                @for (t of types; track t.id) {
                  <option [ngValue]="t.id">{{ t.name }}{{ t.isPaid ? '' : ' (unpaid)' }}</option>
                }
              </select>
              @if (errors.leaveTypeId) { <div class="field-error">{{ errors.leaveTypeId }}</div> }
            </div>
            <div class="form-row">
              <div class="field">
                <label>From <span class="req">*</span></label>
                <input class="input" type="date" [class.invalid]="!!errors.fromDate"
                       [(ngModel)]="form.fromDate" (ngModelChange)="onFromChange()" />
                @if (errors.fromDate) { <div class="field-error">{{ errors.fromDate }}</div> }
              </div>
              <div class="field">
                <label>To <span class="req">*</span></label>
                <input class="input" type="date" [class.invalid]="!!errors.toDate"
                       [(ngModel)]="form.toDate" (ngModelChange)="errors.toDate = ''" />
                @if (errors.toDate) { <div class="field-error">{{ errors.toDate }}</div> }
              </div>
            </div>
            @if (dayCount > 0) { <div class="field-hint">That is {{ dayCount }} day{{ dayCount === 1 ? '' : 's' }}, both ends included.</div> }
            <div class="field">
              <label>Reason <span class="req">*</span></label>
              <textarea class="input" rows="3" [class.invalid]="!!errors.reason" [(ngModel)]="form.reason"
                        (ngModelChange)="errors.reason = ''" placeholder="Briefly, why you need the time off"></textarea>
              @if (errors.reason) { <div class="field-error">{{ errors.reason }}</div> }
            </div>
            @if (formError) { <div class="field-error">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showForm = false">Cancel</button>
            <button class="btn btn-primary" (click)="submit()" [disabled]="saving">
              {{ saving ? 'Submitting…' : 'Submit Request' }}
            </button>
          </div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class TcMyLeaveComponent implements OnInit {
  private readonly api = inject(TeacherApiService);
  requests: LeaveApplication[] = [];
  types: LeaveType[] = [];
  loading = true;
  error = '';
  showForm = false;
  saving = false;
  formError = '';
  errors: { leaveTypeId?: string; fromDate?: string; toDate?: string; reason?: string } = {};
  form = { leaveTypeId: 0, fromDate: '', toDate: '', reason: '' };
  toast = '';
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void {
    this.reload();
    this.api.getLeaveTypes().subscribe({ next: t => this.types = t, error: () => this.types = [] });
  }

  get pendingCount(): number { return this.requests.filter(r => r.status === 'pending').length; }

  /** Inclusive of both ends, matching how the server counts the days. */
  get dayCount(): number {
    if (!this.form.fromDate || !this.form.toDate) return 0;
    const from = new Date(this.form.fromDate);
    const to = new Date(this.form.toDate);
    if (to < from) return 0;
    return Math.round((to.getTime() - from.getTime()) / 86400000) + 1;
  }

  reload(): void {
    this.api.getMyLeave().subscribe({
      next: r => { this.requests = r; this.loading = false; this.error = ''; },
      error: e => { this.error = teacherApiError(e); this.loading = false; },
    });
  }

  openForm(): void {
    this.form = { leaveTypeId: 0, fromDate: '', toDate: '', reason: '' };
    this.errors = {};
    this.formError = '';
    this.showForm = true;
  }

  /** Most leave is a single day, so the end date follows the start until it is changed. */
  onFromChange(): void {
    this.errors.fromDate = '';
    if (this.form.fromDate && !this.form.toDate) this.form.toDate = this.form.fromDate;
  }

  submit(): void {
    const e: typeof this.errors = {};
    if (!this.form.leaveTypeId) e.leaveTypeId = 'Choose a leave type.';
    if (!this.form.fromDate) e.fromDate = 'From date is required.';
    if (!this.form.toDate) e.toDate = 'To date is required.';
    else if (this.form.fromDate && this.form.toDate < this.form.fromDate)
      e.toDate = 'The to date must be on or after the from date.';
    if (!this.form.reason.trim()) e.reason = 'A reason is required.';
    this.errors = e;
    this.formError = '';
    if (Object.keys(e).length) return;

    this.saving = true;
    this.api.applyLeave({
      leaveTypeId: Number(this.form.leaveTypeId),
      fromDate: this.form.fromDate,
      toDate: this.form.toDate,
      reason: this.form.reason.trim(),
    }).subscribe({
      next: () => {
        this.saving = false; this.showForm = false;
        this.showToast('Leave request submitted for approval');
        this.reload();
      },
      error: err => { this.saving = false; this.formError = teacherApiError(err); },
    });
  }

  badge(status: string): string {
    switch (status) {
      case 'approved': return 'success';
      case 'rejected': return 'danger';
      case 'cancelled': return 'neutral';
      default: return 'warning';
    }
  }
  label(status: string): string { return status ? status.charAt(0).toUpperCase() + status.slice(1) : ''; }

  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }
}
