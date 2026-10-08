import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { AdminApiService, adminApiError, Period } from '../../core/admin-api.service';

/**
 * The shape of the school day: which periods there are and how long each one runs.
 *
 * A period is entered as "starts at X, runs for N minutes" — how a school day is actually
 * decided — and the end time follows, so the two can never disagree. Where a period sits in the
 * day follows from its start time as well, which is why there is no reordering to do here: the
 * clock already orders the day, and periods are not allowed to overlap.
 *
 * These are the timetable's columns, shared by every class, so the screen sits under
 * /admin/timetable rather than standing on its own in the sidebar.
 */
@Component({
  selector: 'app-ad-periods',
  standalone: true,
  imports: [FormsModule, RouterLink],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Periods</h1>
        <div class="page-sub">{{ dayLength }}</div>
      </div>
      <a class="btn btn-ghost" routerLink="/admin/timetable">← Back to timetable</a>
      <button class="btn btn-primary" (click)="add()">+ Add period</button>
    </div>

    <div class="card">
      <div class="card-head">
        <div class="grow">
          <strong>The school day</strong>
          <div class="td-sub" style="margin-top:2px;">
            The same columns for every class, breaks included.
          </div>
        </div>
      </div>

      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr><th>#</th><th>Name</th><th>Time</th><th>Duration</th><th>Scheduled</th><th>Actions</th></tr>
            </thead>
            <tbody>
              @for (p of periods; track p.id) {
                <tr>
                  <td class="td-sub">{{ p.periodNo }}</td>
                  <td class="td-main">
                    {{ p.name }}
                    @if (p.isBreak) { <span class="badge neutral" style="margin-left:6px;">Break</span> }
                  </td>
                  <td class="td-sub">{{ p.startTime }}–{{ p.endTime }}</td>
                  <td>{{ p.durationMinutes }} min</td>
                  <!-- What a delete would strand, visible before it is attempted. -->
                  <td class="td-sub">
                    {{ p.isBreak ? '—' : (p.scheduledCount ? p.scheduledCount + ' class(es)' : 'empty') }}
                  </td>
                  <td>
                    <div class="row-actions">
                      <button class="icon-action primary" (click)="edit(p)" title="Edit" aria-label="Edit">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/></svg>
                      </button>
                      <button class="icon-action danger" (click)="remove(p)" title="Delete" aria-label="Delete">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M8 6V4h8v2M6 6l1 14h10l1-14"/></svg>
                      </button>
                    </div>
                  </td>
                </tr>
              } @empty {
                <tr><td colspan="6"><div class="empty">No periods yet — add the first one.</div></td></tr>
              }
            </tbody>
          </table>
        </div>

        <div class="card-body" style="padding-top:0;">
          @if (listError) { <div class="field-error" style="margin-bottom:10px;">{{ listError }}</div> }
          <div class="field-hint">
            A period that still holds scheduled classes cannot be deleted or turned into a break —
            clear those cells on the timetable first.
          </div>
        </div>
      }
    </div>

    <!-- Entering one period. A popup, so the list it belongs to stays in view behind it. -->
    @if (editing; as e) {
      <div class="modal-backdrop" (click)="editing = null">
        <div class="modal" (click)="$event.stopPropagation()" style="max-width: 560px;">
          <div class="modal-head">
            <div class="grow">
              <h2>{{ e.id ? 'Edit period' : 'Add period' }}</h2>
              <div class="td-sub" style="margin-top:2px;">
                Starts at a time and runs for a length — the end follows from those.
              </div>
            </div>
            <button class="modal-close" (click)="editing = null">✕</button>
          </div>
          <div class="modal-body">
            <div class="field">
              <label>Name <span class="req">*</span></label>
              <input class="input" [(ngModel)]="form.name" (ngModelChange)="formError = ''"
                     maxlength="40" placeholder="e.g. P7 or Lunch" />
            </div>
            <div class="form-row">
              <div class="field">
                <label>Starts at <span class="req">*</span></label>
                <input class="input" type="time" [(ngModel)]="form.startTime" (ngModelChange)="formError = ''" />
              </div>
              <div class="field">
                <label>Duration (minutes) <span class="req">*</span></label>
                <input class="input" type="number" min="5" max="480" step="5"
                       [(ngModel)]="form.durationMinutes" (ngModelChange)="formError = ''" />
              </div>
            </div>
            <div class="field-hint" style="margin-top:-4px;">
              @if (endPreview) { Runs {{ form.startTime }}–{{ endPreview }}. }
              Where it sits in the day follows from its start time — no reordering needed.
            </div>
            <label class="pick-chip" [class.on]="form.isBreak" style="margin-top:12px;">
              <input type="checkbox" [checked]="form.isBreak" (change)="toggleBreak()" />
              It’s a break — no class is taught in it
            </label>
            @if (formError) { <div class="field-error" style="margin-top:12px;">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="editing = null">Cancel</button>
            <button class="btn btn-primary" (click)="save()" [disabled]="saving">
              {{ saving ? 'Saving…' : (e.id ? 'Save changes' : 'Add period') }}
            </button>
          </div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class AdPeriodsComponent implements OnInit {
  private readonly api = inject(AdminApiService);

  periods: Period[] = [];
  loading = true;
  error = '';
  /** Errors from acting on the list (a refused delete), kept apart from the form's own. */
  listError = '';

  /** Null when no form is open; `{ id: 0 }` while adding. */
  editing: { id: number } | null = null;
  form = { name: '', startTime: '10:00', durationMinutes: 45, isBreak: false };
  saving = false;
  formError = '';
  toast = '';
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void { this.load(); }

  private load(): void {
    this.loading = true;
    this.api.getPeriods().subscribe({
      next: p => { this.periods = p; this.loading = false; this.error = ''; },
      error: e => { this.error = adminApiError(e); this.loading = false; },
    });
  }

  /** How long the school day runs end to end, teaching and breaks together. */
  get dayLength(): string {
    if (!this.periods.length) return 'Nothing set up yet.';
    const teaching = this.periods.filter(p => !p.isBreak);
    const minutes = teaching.reduce((n, p) => n + p.durationMinutes, 0);
    return `${this.periods[0].startTime}–${this.periods[this.periods.length - 1].endTime} · ` +
      `${teaching.length} teaching period(s), ${Math.floor(minutes / 60)}h ${minutes % 60}m of class`;
  }

  /** The end time the entered duration works out to, so it can be checked before saving. */
  get endPreview(): string {
    const start = parseClock(this.form.startTime);
    const mins = Number(this.form.durationMinutes);
    if (start === null || !mins || mins <= 0) return '';
    const end = start + mins;
    if (end >= 24 * 60) return '';
    return `${String(Math.floor(end / 60)).padStart(2, '0')}:${String(end % 60).padStart(2, '0')}`;
  }

  /**
   * A new period starts where the day currently ends and keeps the last one's length, since that
   * is almost always what is wanted — appending one more period to the day.
   */
  add(): void {
    const last = this.periods[this.periods.length - 1];
    this.form = {
      name: '',
      startTime: last?.endTime ?? '10:00',
      durationMinutes: last?.durationMinutes ?? 45,
      isBreak: false,
    };
    this.formError = '';
    this.listError = '';
    this.editing = { id: 0 };
  }

  edit(p: Period): void {
    this.form = {
      name: p.name,
      startTime: p.startTime,
      durationMinutes: p.durationMinutes,
      isBreak: p.isBreak,
    };
    this.formError = '';
    this.listError = '';
    this.editing = { id: p.id };
  }

  toggleBreak(): void {
    this.form.isBreak = !this.form.isBreak;
    this.formError = '';
  }

  save(): void {
    const name = this.form.name.trim();
    if (!name) { this.formError = 'Give the period a name, e.g. P1 or Lunch.'; return; }
    if (parseClock(this.form.startTime) === null) {
      this.formError = 'Enter a start time as HH:mm, e.g. 10:00.';
      return;
    }
    const duration = Number(this.form.durationMinutes);
    if (!Number.isFinite(duration) || duration < 5 || duration > 480) {
      this.formError = 'Duration must be between 5 and 480 minutes.';
      return;
    }

    const dto = { name, startTime: this.form.startTime, durationMinutes: duration, isBreak: this.form.isBreak };
    const id = this.editing?.id ?? 0;
    this.saving = true;
    const done = (message: string) => {
      this.saving = false;
      this.editing = null;
      this.showToast(message);
      this.load();
    };
    const fail = (e: unknown) => { this.saving = false; this.formError = adminApiError(e); };

    if (id) this.api.updatePeriod(id, dto).subscribe({ next: () => done(`${name} updated`), error: fail });
    else this.api.createPeriod(dto).subscribe({ next: () => done(`${name} added`), error: fail });
  }

  remove(p: Period): void {
    if (!confirm(`Delete ${p.name}? Every class loses this column from their week.`)) return;
    this.listError = '';
    this.api.deletePeriod(p.id).subscribe({
      next: () => { this.showToast(`${p.name} deleted`); this.load(); },
      error: e => this.listError = adminApiError(e),
    });
  }

  private showToast(m: string): void {
    this.toast = m;
    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.toast = '', 3000);
  }
}

/** Minutes since midnight for an "HH:mm" value, or null if it is not one. */
function parseClock(value: string): number | null {
  const m = /^(\d{1,2}):(\d{2})/.exec((value || '').trim());
  if (!m) return null;
  const h = Number(m[1]), min = Number(m[2]);
  return h < 24 && min < 60 ? h * 60 + min : null;
}
