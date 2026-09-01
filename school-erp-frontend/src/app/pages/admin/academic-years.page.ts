import { Component, OnInit, inject } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AdminApiService, adminApiError, AcademicYearDto } from '../../core/admin-api.service';
import { NotificationService } from '../../core/notification.service';

/**
 * Manages the school's sessions. Everything year-scoped — class subjects, teacher assignments —
 * resolves through the year flagged current, so this screen is what makes those features usable.
 */
@Component({
  selector: 'app-ad-academic-years',
  standalone: true,
  imports: [FormsModule, DatePipe],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Academic Years</h1>
        <div class="page-sub">{{ years.length }} sessions · current: {{ currentName || 'none set' }}</div>
      </div>
      <button class="btn btn-primary" (click)="openForm()">+ Add Year</button>
    </div>

    @if (!loading && !years.length) {
      <div class="card"><div class="empty">
        No academic years yet. Subjects, exams and teacher assignments are all filed under a year —
        add one to start.
      </div></div>
    }

    <div class="card">
      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else if (years.length) {
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Year</th><th>Starts</th><th>Ends</th><th class="num">In use</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              @for (y of years; track y.id) {
                <tr>
                  <td class="td-main">{{ y.name }}</td>
                  <td class="td-sub">{{ y.startDate | date:'mediumDate' }}</td>
                  <td class="td-sub">{{ y.endDate | date:'mediumDate' }}</td>
                  <td class="num">{{ y.usageCount || '—' }}</td>
                  <td>
                    @if (y.isCurrent) { <span class="badge success">Current</span> }
                    @else { <span class="badge neutral">{{ isPast(y) ? 'Past' : 'Upcoming' }}</span> }
                  </td>
                  <td>
                    <div class="row-actions">
                      @if (!y.isCurrent) {
                        <button class="icon-action success" (click)="makeCurrent(y)" title="Make current">
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.5 2.5L16 9"/></svg>
                        </button>
                      }
                      <button class="icon-action primary" (click)="edit(y)" title="Edit">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/></svg>
                      </button>
                      <span [title]="deleteBlockedReason(y)">
                        <button class="icon-action danger" (click)="remove(y)" [disabled]="!!deleteBlockedReason(y)" title="Delete">
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2m2 0v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/></svg>
                        </button>
                      </span>
                    </div>
                  </td>
                </tr>
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
            <h2>{{ editingId ? 'Edit Academic Year' : 'Add Academic Year' }}</h2>
            <button class="modal-close" (click)="showForm = false">✕</button>
          </div>
          <div class="modal-body">
            <div class="field">
              <label>Year name <span class="req">*</span></label>
              <input class="input" [class.invalid]="!!errors.name" [(ngModel)]="form.name"
                     (ngModelChange)="errors.name = ''" placeholder="e.g. 2026-27" />
              @if (errors.name) { <div class="field-error">{{ errors.name }}</div> }
            </div>
            <div class="form-row">
              <div class="field">
                <label>Starts on <span class="req">*</span></label>
                <input class="input" type="date" [class.invalid]="!!errors.startDate"
                       [(ngModel)]="form.startDate" (ngModelChange)="onStartChange()" />
                @if (errors.startDate) { <div class="field-error">{{ errors.startDate }}</div> }
              </div>
              <div class="field">
                <label>Ends on <span class="req">*</span></label>
                <input class="input" type="date" [class.invalid]="!!errors.endDate"
                       [(ngModel)]="form.endDate" (ngModelChange)="errors.endDate = ''" />
                @if (errors.endDate) { <div class="field-error">{{ errors.endDate }}</div> }
              </div>
            </div>
            <div class="field-hint">
              Sessions cannot overlap. Picking a start date suggests an end date twelve months later —
              adjust it if your session runs differently.
            </div>
            @if (formError) { <div class="field-error">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showForm = false">Cancel</button>
            <button class="btn btn-primary" (click)="save()" [disabled]="saving">
              {{ saving ? 'Saving…' : (editingId ? 'Save Changes' : 'Add Year') }}
            </button>
          </div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class AdAcademicYearsComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  private readonly notify = inject(NotificationService);
  years: AcademicYearDto[] = [];
  loading = true;
  error = '';
  showForm = false;
  saving = false;
  formError = '';
  errors: { name?: string; startDate?: string; endDate?: string } = {};
  editingId: number | null = null;
  form = { name: '', startDate: '', endDate: '' };
  toast = '';
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void { this.reload(); }

  get currentName(): string { return this.years.find(y => y.isCurrent)?.name ?? ''; }

  isPast(y: AcademicYearDto): boolean { return new Date(y.endDate) < new Date(); }

  /** Empty when deletable; otherwise the reason, shown as the button's tooltip. */
  deleteBlockedReason(y: AcademicYearDto): string {
    if (y.isCurrent) return 'This is the current year — make another year current first.';
    if (y.usageCount > 0) return `${y.usageCount} subject/teacher assignment(s) are filed under this year.`;
    return '';
  }

  reload(): void {
    this.api.getAcademicYears().subscribe({
      next: y => { this.years = y; this.loading = false; this.error = ''; },
      error: e => { this.error = adminApiError(e); this.loading = false; },
    });
  }

  openForm(): void {
    this.editingId = null;
    this.form = { name: '', startDate: '', endDate: '' };
    this.resetValidation();
    this.showForm = true;
  }

  edit(y: AcademicYearDto): void {
    this.editingId = y.id;
    this.form = { name: y.name, startDate: y.startDate.slice(0, 10), endDate: y.endDate.slice(0, 10) };
    this.resetValidation();
    this.showForm = true;
  }

  /** Suggests an end date a year on, and a name like 2026-27, only while those are untouched. */
  onStartChange(): void {
    this.errors.startDate = '';
    if (!this.form.startDate) return;
    const start = new Date(this.form.startDate);
    if (!this.form.endDate) {
      const end = new Date(start);
      end.setFullYear(end.getFullYear() + 1);
      end.setDate(end.getDate() - 1);
      this.form.endDate = end.toISOString().slice(0, 10);
    }
    if (!this.form.name) {
      const y = start.getFullYear();
      this.form.name = `${y}-${String((y + 1) % 100).padStart(2, '0')}`;
    }
  }

  save(): void {
    const e: typeof this.errors = {};
    if (!this.form.name.trim()) e.name = 'Year name is required.';
    if (!this.form.startDate) e.startDate = 'Start date is required.';
    if (!this.form.endDate) e.endDate = 'End date is required.';
    else if (this.form.startDate && this.form.endDate <= this.form.startDate)
      e.endDate = 'The end date must fall after the start date.';
    this.errors = e;
    this.formError = '';
    if (Object.keys(e).length) return;

    this.saving = true;
    const dto = { name: this.form.name.trim(), startDate: this.form.startDate, endDate: this.form.endDate };
    const done = (m: string) => {
      this.saving = false; this.showForm = false; this.showToast(m);
      this.reload();
      this.notify.loadYears();   // the top-bar picker reads the same list
    };
    const fail = (err: unknown) => { this.saving = false; this.formError = adminApiError(err); };

    if (this.editingId) this.api.updateAcademicYear(this.editingId, dto).subscribe({ next: () => done(`${dto.name} updated`), error: fail });
    else this.api.createAcademicYear(dto).subscribe({ next: () => done(`${dto.name} added`), error: fail });
  }

  makeCurrent(y: AcademicYearDto): void {
    if (!confirm(`Make ${y.name} the current academic year? New subject and teacher assignments will be filed under it.`)) return;
    this.api.setCurrentAcademicYear(y.id).subscribe({
      next: () => { this.showToast(`${y.name} is now the current year`); this.reload(); this.notify.loadYears(); },
      error: e => alert(adminApiError(e)),
    });
  }

  remove(y: AcademicYearDto): void {
    if (this.deleteBlockedReason(y)) return;
    if (!confirm(`Delete ${y.name}?`)) return;
    this.api.deleteAcademicYear(y.id).subscribe({
      next: () => { this.showToast(`${y.name} deleted`); this.reload(); this.notify.loadYears(); },
      error: e => alert(adminApiError(e)),
    });
  }

  private resetValidation(): void { this.errors = {}; this.formError = ''; }
  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }
}
