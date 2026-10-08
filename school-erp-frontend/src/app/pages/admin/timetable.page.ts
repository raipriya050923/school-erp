import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { IconComponent } from '../../shared/icon.component';
import {
  AdminApiService, adminApiError, DayTimetable, DayRow, TimetableCell, TimetablePeriod,
  TimetableSubjectOption, TeacherListItem, TeacherWeek, TeacherWeekCell, TeacherAssignmentOption,
} from '../../core/admin-api.service';

/**
 * The school's week, laid out one day at a time: a row per section, a column per period — the
 * whole timetable on one screen rather than a visit per class.
 *
 * A period can only hold a subject the class studies, taught by whoever is assigned to it under
 * Subjects & Teachers. The teacher is never picked here, so the timetable can never contradict
 * who actually teaches the subject; the server rejects teacher and room clashes.
 */
@Component({
  selector: 'app-ad-timetable',
  standalone: true,
  imports: [FormsModule, RouterLink, IconComponent],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Timetable</h1>
        <div class="page-sub">
          @if (view === 'teacher') {
            @if (week) { {{ week.teacherName }} · {{ teacherFilled }} of {{ teacherSlots }} periods scheduled }
            @else { Pick a teacher to see their week }
          } @else {
            {{ dayLabel(day) }} · {{ filledToday }} of {{ slotsToday }} periods across {{ grid?.rows?.length || 0 }} sections
          }
        </div>
      </div>
      <button class="btn btn-ghost" (click)="openWorkingDays()" title="Choose which days the school runs">
        Working days
      </button>
      <a class="btn btn-primary" routerLink="/admin/timetable/periods"
         title="Add periods and set how long each one runs">
        <app-icon name="clock" [size]="16" /> Periods
      </a>
    </div>

    <div class="card">
      <div class="card-head filters">
        <div class="pill-group" style="margin-right:6px;">
          <button [class.on-p]="view === 'day'" (click)="setView('day')">Whole school</button>
          <button [class.on-p]="view === 'teacher'" (click)="setView('teacher')">One teacher</button>
        </div>

        @if (view === 'day') {
          <div class="pill-group">
            @for (d of workingDayList; track d.value) {
              <button [class.on-p]="day === d.value" (click)="selectDay(d.value)">{{ d.short }}</button>
            }
          </div>
          <button class="btn btn-ghost btn-sm" (click)="autoFill()" [disabled]="autoFilling"
                  title="Suggest subjects for the empty periods, without double-booking a teacher">
            {{ autoFilling ? 'Suggesting…' : 'Suggest for ' + dayLabel(day) }}
          </button>
          <button class="btn btn-ghost btn-sm danger" (click)="openReset()"
                  title="Clear what is scheduled, so the grid can be built again">
            Reset
          </button>
          <div class="grow"></div>
          <div class="field" style="margin:0;min-width:210px;">
            <label style="font-size:11px;">Highlight teacher</label>
            <select class="select" [(ngModel)]="highlightId">
              <option [ngValue]="0">— None —</option>
              @for (t of teachers; track t.id) { <option [ngValue]="t.id">{{ t.name }}</option> }
            </select>
          </div>
        } @else {
          <div class="field" style="margin:0;min-width:220px;">
            <label style="font-size:11px;">Teacher</label>
            <select class="select" [(ngModel)]="staffId" (ngModelChange)="loadTeacher()">
              <option [ngValue]="0">Select a teacher…</option>
              @for (t of teachers; track t.id) { <option [ngValue]="t.id">{{ t.name }}</option> }
            </select>
          </div>
          <div class="grow"></div>
        }
      </div>

      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }

      @else if (view === 'day') {
        @if (!grid || !grid.rows.length) {
          <div class="empty">No sections yet — add a class and section first.</div>
        } @else {
          <div class="table-wrap">
            <table class="data-table tt-grid">
              <thead>
                <tr>
                  <th>Class</th>
                  @for (p of grid.periods; track p.periodNo) {
                    <th [class.tt-break]="p.isBreak">
                      {{ p.name }}<div class="td-sub" style="font-weight:500;">{{ p.timeLabel }}</div>
                    </th>
                  }
                </tr>
              </thead>
              <tbody>
                @for (row of grid.rows; track row.sectionId) {
                  <tr>
                    <td class="td-main">{{ row.className }} — {{ row.sectionName }}</td>
                    @for (p of grid.periods; track p.periodNo) {
                      <td [class.tt-break]="p.isBreak">
                        @if (p.isBreak) { <span class="td-sub">Break</span> }
                        @else {
                          <button type="button" class="tt-cell"
                                  [class.filled]="!!cell(row, p.periodNo)"
                                  [class.highlight]="isHighlighted(row, p.periodNo)"
                                  (click)="openCell(row, p)">
                            @if (cell(row, p.periodNo); as c) {
                              <span class="tt-subject">{{ c.subject }}</span>
                              <span class="tt-meta">{{ c.teacherName || 'No teacher' }}</span>
                              @if (c.room) { <span class="tt-meta">Room {{ c.room }}</span> }
                            } @else { <span class="tt-add">+</span> }
                          </button>
                        }
                      </td>
                    }
                  </tr>
                }
              </tbody>
            </table>
          </div>
          @if (autoFillNotes.length) {
            <div class="field-hint" style="margin-top:10px;color:var(--warn-text);">
              @for (n of autoFillNotes; track n) { <div>{{ n }}</div> }
            </div>
          }
          <div class="field-hint" style="margin-top:10px;">
            Click any period to change it.
            @if (highlightId) { {{ highlightName }} has {{ highlightCount }} period(s) on {{ dayLabel(day) }}. }
            @else { Pick a teacher above to highlight their periods. }
          </div>
        }
      }

      @else if (!week) { <div class="empty">Choose a teacher above.</div> }
      @else if (!week.options.length && !week.cells.length) {
        <div class="empty">
          {{ week.teacherName }} has no periods yet and is not assigned to any subject. Book them
          from a class timetable, or assign a subject under Classes &amp; Sections →
          “Subjects &amp; Teachers”.
        </div>
      } @else {
        <div class="table-wrap">
          <table class="data-table tt-grid">
            <thead>
              <tr>
                <th>Day</th>
                @for (p of week.periods; track p.periodNo) {
                  <th [class.tt-break]="p.isBreak">
                    {{ p.name }}<div class="td-sub" style="font-weight:500;">{{ p.timeLabel }}</div>
                  </th>
                }
              </tr>
            </thead>
            <tbody>
              @for (d of workingDayList; track d.value) {
                <tr>
                  <td class="td-main">{{ d.label }}</td>
                  @for (p of week.periods; track p.periodNo) {
                    <td [class.tt-break]="p.isBreak">
                      @if (p.isBreak) { <span class="td-sub">Break</span> }
                      @else {
                        <button type="button" class="tt-cell" [class.filled]="!!teacherCell(d.value, p.periodNo)"
                                (click)="openTeacherCell(d.value, p)">
                          @if (teacherCell(d.value, p.periodNo); as c) {
                            <span class="tt-subject">{{ c.className }}-{{ c.sectionName }}</span>
                            <span class="tt-meta">{{ c.subject }}</span>
                            @if (c.room) { <span class="tt-meta">Room {{ c.room }}</span> }
                          } @else { <span class="tt-add">+</span> }
                        </button>
                      }
                    </td>
                  }
                </tr>
              }
            </tbody>
          </table>
        </div>
        <div class="field-hint" style="margin-top:10px;">
          Click any period to change it. Options are this teacher’s subject assignments plus the
          classes they are already booked for.
        </div>
      }
    </div>

    <!--
      Emptying the grid. The scope is chosen in the dialog rather than split across two buttons,
      because the difference between "this day" and "the whole week" is exactly what needs to be
      read carefully before confirming.
    -->
    @if (showReset) {
      <div class="modal-backdrop" (click)="showReset = false">
        <div class="modal" (click)="$event.stopPropagation()" style="max-width: 480px;">
          <div class="modal-head">
            <div class="grow">
              <h2>Reset timetable</h2>
              <div class="td-sub" style="margin-top:2px;">This cannot be undone.</div>
            </div>
            <button class="modal-close" (click)="showReset = false">✕</button>
          </div>
          <div class="modal-body">
            <div class="field">
              <label>What to clear</label>
              <div class="chip-picker">
                <label class="pick-chip" [class.on]="resetScope === 'day'">
                  <input type="radio" name="resetScope" [checked]="resetScope === 'day'"
                         (change)="resetScope = 'day'" />
                  {{ dayLabel(day) }} only — {{ filledToday }} period(s)
                </label>
                <label class="pick-chip" [class.on]="resetScope === 'week'">
                  <input type="radio" name="resetScope" [checked]="resetScope === 'week'"
                         (change)="resetScope = 'week'" />
                  The whole week — every day
                </label>
              </div>
            </div>
            <div class="field-hint">
              Only what is scheduled is removed. Your periods and working days stay as they are,
              so you can fill the grid again straight away.
            </div>
            @if (formError) { <div class="field-error" style="margin-top:10px;">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showReset = false">Cancel</button>
            <button class="btn btn-danger" (click)="confirmReset()" [disabled]="resetting">
              {{ resetting ? 'Clearing…' : (resetScope === 'day' ? 'Clear ' + dayLabel(day) : 'Clear the whole week') }}
            </button>
          </div>
        </div>
      </div>
    }

    <!-- Which days the school runs -->
    @if (showWorkingDays) {
      <div class="modal-backdrop" (click)="showWorkingDays = false">
        <div class="modal" (click)="$event.stopPropagation()" style="max-width: 420px;">
          <div class="modal-head">
            <h2>Working days</h2>
            <button class="modal-close" (click)="showWorkingDays = false">✕</button>
          </div>
          <div class="modal-body">
            <div class="field">
              <label>Days the school runs</label>
              <div class="chip-picker">
                @for (d of allDays; track d.value) {
                  <label class="pick-chip" [class.on]="draftDays.includes(d.value)">
                    <input type="checkbox" [checked]="draftDays.includes(d.value)" (change)="toggleDay(d.value)" />
                    {{ d.label }}
                  </label>
                }
              </div>
              <div class="field-hint">
                A day with periods already on it cannot be turned off — clear them first.
              </div>
            </div>
            @if (formError) { <div class="field-error">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showWorkingDays = false">Cancel</button>
            <button class="btn btn-primary" (click)="saveWorkingDays()" [disabled]="saving">
              {{ saving ? 'Saving…' : 'Save' }}
            </button>
          </div>
        </div>
      </div>
    }

    <!-- Set one period of one section (day grid) -->
    @if (editing; as e) {
      <div class="modal-backdrop" (click)="editing = null">
        <div class="modal" (click)="$event.stopPropagation()" style="max-width: 480px;">
          <div class="modal-head">
            <div class="grow">
              <h2>{{ e.row.className }} — {{ e.row.sectionName }}</h2>
              <div class="td-sub" style="margin-top:2px;">{{ dayLabel(day) }} · {{ e.period.name }} · {{ e.period.timeLabel }}</div>
            </div>
            <button class="modal-close" (click)="editing = null">✕</button>
          </div>
          <div class="modal-body">
            <div class="field">
              <label>Subject</label>
              <select class="select" [(ngModel)]="form.subject" (ngModelChange)="onSubjectChange()">
                <option value="">— Free period —</option>
                @for (s of e.row.subjects; track s.subject) {
                  <option [value]="s.subject">
                    {{ s.subject }}{{ s.teacherName ? ' — ' + s.teacherName : ' — no teacher assigned' }}{{ teacherBusyNote(e.period.periodNo, s) }}
                  </option>
                }
              </select>
              @if (!e.row.subjects.length) {
                <div class="field-hint">
                  {{ e.row.className }} has no subjects yet — set them under Classes &amp; Sections →
                  “Subjects &amp; Teachers”.
                </div>
              }
            </div>
            <div class="field-hint" style="margin: -6px 0 12px;">
              A teacher already taking another section in this period is marked BUSY — picking them
              is refused, so this is how you tell what is still free.
            </div>

            <!--
              Defaults to whoever is assigned to the subject, but stays editable so
              a stand-in can take one period without changing the assignment.
            -->
            @if (form.subject) {
              <div class="field">
                <label>Teacher</label>
                <select class="select" [(ngModel)]="form.teacherStaffId" (ngModelChange)="formError = ''">
                  <option [ngValue]="null">— No teacher —</option>
                  @for (t of teachers; track t.id) {
                    <option [ngValue]="t.id">
                      {{ t.name }}{{ t.subject ? ' — ' + t.subject : '' }}{{ teacherBusyElsewhere(t.id) }}
                    </option>
                  }
                </select>
                @if (!teachers.length) {
                  <div class="field-hint">No teachers on staff yet — add them under Teachers.</div>
                }
              </div>
            }

            <div class="field">
              <label>Room</label>
              <input class="input" [(ngModel)]="form.room" (ngModelChange)="formError = ''" placeholder="e.g. Hall A" />
            </div>
            @if (formError) { <div class="field-error">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="editing = null">Cancel</button>
            <button class="btn btn-primary" (click)="saveCell()" [disabled]="saving">
              {{ saving ? 'Saving…' : 'Save Period' }}
            </button>
          </div>
        </div>
      </div>
    }

    <!-- Schedule a teacher into one of their sections (teacher view) -->
    @if (teacherEditing; as e) {
      <div class="modal-backdrop" (click)="teacherEditing = null">
        <div class="modal" (click)="$event.stopPropagation()" style="max-width: 520px;">
          <div class="modal-head">
            <div class="grow">
              <h2>{{ dayLabel(e.day) }} · {{ e.period.name }}</h2>
              <div class="td-sub" style="margin-top:2px;">{{ week?.teacherName }} · {{ e.period.timeLabel }}</div>
            </div>
            <button class="modal-close" (click)="teacherEditing = null">✕</button>
          </div>
          <div class="modal-body">
            <div class="field">
              <label>Class, section and subject</label>
              <select class="select" [(ngModel)]="teacherForm.optionKey" (ngModelChange)="formError = ''">
                <option value="">— Free period —</option>
                @for (o of week?.options || []; track optionKey(o)) {
                  <option [value]="optionKey(o)">
                    {{ o.className }}-{{ o.sectionName }} · {{ o.subject }}{{ busyNote(e.day, e.period.periodNo, o) }}
                  </option>
                }
              </select>
              <div class="field-hint">A section already busy in this period is marked — picking it replaces what is there.</div>
            </div>
            <div class="field">
              <label>Room</label>
              <input class="input" [(ngModel)]="teacherForm.room" (ngModelChange)="formError = ''" placeholder="e.g. Hall A" />
            </div>
            @if (formError) { <div class="field-error">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="teacherEditing = null">Cancel</button>
            <button class="btn btn-primary" (click)="saveTeacherCell()" [disabled]="saving">
              {{ saving ? 'Saving…' : 'Save Period' }}
            </button>
          </div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
  styles: [`
    .tt-grid th, .tt-grid td { vertical-align: top; }
    .tt-grid .tt-break { background: var(--surface-2); text-align: center; }
    .tt-cell {
      display: block; width: 100%; min-width: 128px; min-height: 58px;
      text-align: left; padding: 8px 10px;
      border: 1px dashed var(--border); border-radius: 9px;
      background: transparent; cursor: pointer; font-family: inherit;
      transition: border-color 0.15s ease, background 0.15s ease;
    }
    .tt-cell:hover { border-color: var(--brand); background: var(--brand-tint); }
    .tt-cell.filled { border-style: solid; background: var(--tile-1); border-color: var(--tile-1-line); }
    /* The highlighted teacher's periods, so a day's load is visible at a glance. */
    .tt-cell.highlight { background: var(--tile-4); border-color: #f0c36b; box-shadow: 0 0 0 2px rgba(217,119,6,0.25); }
    .tt-subject { display: block; font-size: 13px; font-weight: 600; color: var(--ink); }
    .tt-meta { display: block; font-size: 11.5px; color: var(--ink-2); margin-top: 1px; }
    .tt-add { display: block; text-align: center; color: var(--muted); font-size: 18px; line-height: 40px; }
  `],
})
export class AdTimetableComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  /** 1 = Sunday … 7 = Saturday, matching what the API stores. */
  readonly allDays = [
    { value: 1, label: 'Sunday', short: 'Sun' }, { value: 2, label: 'Monday', short: 'Mon' },
    { value: 3, label: 'Tuesday', short: 'Tue' }, { value: 4, label: 'Wednesday', short: 'Wed' },
    { value: 5, label: 'Thursday', short: 'Thu' }, { value: 6, label: 'Friday', short: 'Fri' },
    { value: 7, label: 'Saturday', short: 'Sat' },
  ];

  /** Days this school actually runs; everything else is a holiday and is not offered. */
  workingDays: number[] = [1, 2, 3, 4, 5, 6];
  showWorkingDays = false;
  draftDays: number[] = [];

  autoFilling = false;
  showReset = false;
  resetScope: 'day' | 'week' = 'day';
  resetting = false;
  /** Anything the suggestion could not place, shown under the grid. */
  autoFillNotes: string[] = [];

  view: 'day' | 'teacher' = 'day';
  day = 1;
  grid: DayTimetable | null = null;
  teachers: TeacherListItem[] = [];
  highlightId = 0;

  staffId = 0;
  week: TeacherWeek | null = null;

  loading = false;
  error = '';
  saving = false;
  formError = '';
  editing: { row: DayRow; period: TimetablePeriod } | null = null;
  form = { subject: '', room: '', teacherStaffId: null as number | null };
  teacherEditing: { day: number; period: TimetablePeriod } | null = null;
  teacherForm = { optionKey: '', room: '' };
  toast = '';
  private timer?: ReturnType<typeof setTimeout>;

  /** The day tabs: the school's working days, in order. */
  get workingDayList() { return this.allDays.filter(d => this.workingDays.includes(d.value)); }

  ngOnInit(): void {
    // Open on today when the school runs today; otherwise the first working day.
    this.day = new Date().getDay() + 1;
    this.api.getTeachers().subscribe({ next: t => this.teachers = t, error: () => this.teachers = [] });
    this.loadDay();
  }

  setView(view: 'day' | 'teacher'): void {
    this.view = view;
    this.error = '';
    if (view === 'day' && !this.grid) this.loadDay();
  }

  selectDay(day: number): void { this.day = day; this.loadDay(); }

  dayLabel(day: number): string { return this.allDays.find(d => d.value === day)?.label ?? ''; }

  /**
   * Fills this day's empty periods with a clash-free suggestion. Existing periods are left as
   * they are, and every suggested cell can be clicked and changed afterwards.
   */
  autoFill(): void {
    if (!confirm(`Suggest subjects for the empty periods on ${this.dayLabel(this.day)}? Periods you have already set are kept.`)) return;
    this.autoFilling = true;
    this.autoFillNotes = [];
    this.api.autoFillDay(this.day).subscribe({
      next: r => {
        this.autoFilling = false;
        this.autoFillNotes = r.notes ?? [];
        this.showToast(r.filled
          ? `${r.filled} period(s) suggested${r.leftEmpty ? `, ${r.leftEmpty} left empty` : ''}`
          : 'Nothing to fill — every period is already set or has no subject available');
        this.loadDay();
      },
      error: e => { this.autoFilling = false; this.error = adminApiError(e); },
    });
  }

  openReset(): void {
    this.resetScope = 'day';
    this.formError = '';
    this.showReset = true;
  }

  /**
   * Wipes what is scheduled so the grid can be built again. Deliberately does not touch the
   * period columns or the working days — those are the shape of the week, and clearing them
   * would leave nothing to rebuild onto.
   */
  confirmReset(): void {
    this.resetting = true;
    this.formError = '';
    this.api.resetTimetable(this.resetScope === 'week' ? null : this.day).subscribe({
      next: r => {
        this.resetting = false;
        this.showReset = false;
        this.autoFillNotes = [];
        this.showToast(r.cleared
          ? `${r.cleared} period(s) cleared from ${r.scope}`
          : `Nothing to clear — ${r.scope} was already empty`);
        this.loadDay();
        if (this.staffId) this.loadTeacher();
      },
      error: e => { this.resetting = false; this.formError = adminApiError(e); },
    });
  }

  openWorkingDays(): void {
    this.draftDays = [...this.workingDays];
    this.formError = '';
    this.showWorkingDays = true;
  }

  toggleDay(value: number): void {
    this.draftDays = this.draftDays.includes(value)
      ? this.draftDays.filter(d => d !== value)
      : [...this.draftDays, value].sort((a, b) => a - b);
    this.formError = '';
  }

  saveWorkingDays(): void {
    if (!this.draftDays.length) { this.formError = 'Pick at least one working day.'; return; }
    this.saving = true;
    this.api.setWorkingDays(this.draftDays).subscribe({
      next: () => {
        this.saving = false;
        this.showWorkingDays = false;
        this.workingDays = [...this.draftDays];
        // The open day may no longer be a working one.
        if (!this.workingDays.includes(this.day)) this.day = this.workingDays[0];
        this.showToast('Working days updated');
        this.loadDay();
      },
      error: e => { this.saving = false; this.formError = adminApiError(e); },
    });
  }

  loadDay(): void {
    this.loading = true;
    this.api.getDayTimetable(this.day).subscribe({
      next: g => {
        this.grid = g;
        this.workingDays = g.workingDays?.length ? g.workingDays : this.workingDays;
        // Landing on a holiday (or today being one) falls back to the first working day.
        if (!this.workingDays.includes(this.day)) { this.day = this.workingDays[0]; this.loadDay(); return; }
        this.loading = false; this.error = '';
      },
      error: e => { this.error = adminApiError(e); this.loading = false; this.grid = null; },
    });
  }

  cell(row: DayRow, periodNo: number): TimetableCell | undefined {
    return row.cells.find(c => c.periodNo === periodNo);
  }

  isHighlighted(row: DayRow, periodNo: number): boolean {
    return !!this.highlightId && this.cell(row, periodNo)?.teacherStaffId === Number(this.highlightId);
  }

  get highlightName(): string { return this.teachers.find(t => t.id === Number(this.highlightId))?.name ?? ''; }

  get highlightCount(): number {
    if (!this.highlightId || !this.grid) return 0;
    return this.grid.rows.reduce((n, r) =>
      n + r.cells.filter(c => c.teacherStaffId === Number(this.highlightId)).length, 0);
  }

  get slotsToday(): number {
    const teaching = (this.grid?.periods ?? []).filter(p => !p.isBreak).length;
    return teaching * (this.grid?.rows.length ?? 0);
  }

  get teacherWeekDays() { return this.workingDayList; }
  get filledToday(): number {
    return (this.grid?.rows ?? []).reduce((n, r) => n + r.cells.length, 0);
  }

  /**
   * Flags a subject whose teacher is already taking another section in this period. Computed from
   * the day grid already loaded, so it costs nothing — and it turns "which subject goes in P1?"
   * into a question with a visible answer.
   */
  teacherBusyNote(periodNo: number, option: TimetableSubjectOption): string {
    if (!option.teacherStaffId || !this.editing) return '';
    const clash = (this.grid?.rows ?? [])
      .filter(r => r.sectionId !== this.editing!.row.sectionId)
      .flatMap(r => r.cells
        .filter(c => c.periodNo === periodNo && c.teacherStaffId === option.teacherStaffId)
        .map(() => `${r.className}-${r.sectionName}`))[0];
    return clash ? `  — BUSY with ${clash}` : '';
  }

  openCell(row: DayRow, period: TimetablePeriod): void {
    const existing = this.cell(row, period.periodNo);
    this.form = {
      subject: existing?.subject ?? '',
      room: existing?.room ?? '',
      teacherStaffId: existing?.teacherStaffId ?? null,
    };
    this.formError = '';
    this.editing = { row, period };
  }

  /**
   * Changing the subject pre-selects whoever is assigned to teach it, so the
   * common case needs no second choice. The picker stays editable for a
   * stand-in.
   */
  onSubjectChange(): void {
    this.formError = '';

    const option = this.editing?.row.subjects.find(s => s.subject === this.form.subject);
    this.form.teacherStaffId = option?.teacherStaffId ?? null;
  }

  /** Teachers already booked elsewhere in this period, so the list can say so. */
  teacherBusyElsewhere(staffId: number): string {
    if (!this.editing) return '';

    const { row, period } = this.editing;

    const clash = this.grid?.rows.find(r =>
      !(r.className === row.className && r.sectionName === row.sectionName) &&
      r.cells.some(c => c.periodNo === period.periodNo && c.teacherStaffId === staffId));

    return clash ? ` — busy with ${clash.className}-${clash.sectionName}` : '';
  }

  saveCell(): void {
    if (!this.editing) return;
    const { row, period } = this.editing;
    this.saving = true;
    this.api.saveTimetableSlot({
      className: row.className,
      sectionName: row.sectionName,
      dayOfWeek: this.day,
      periodNo: period.periodNo,
      subject: this.form.subject || null,
      room: this.form.room.trim() || null,
      teacherStaffId: this.form.subject ? this.form.teacherStaffId : null,
    }).subscribe({
      next: () => {
        this.saving = false;
        this.editing = null;
        this.showToast(this.form.subject
          ? `${row.className}-${row.sectionName} · ${this.form.subject} set for ${period.name}`
          : `${row.className}-${row.sectionName} ${period.name} cleared`);
        this.loadDay();
      },
      error: e => { this.saving = false; this.formError = adminApiError(e); },
    });
  }

  /* ---------- one teacher, whole week ---------- */

  optionKey(o: TeacherAssignmentOption): string { return `${o.classId}|${o.sectionId}|${o.subject}`; }

  get teacherFilled(): number { return this.week?.cells.length ?? 0; }
  get teacherSlots(): number {
    const teaching = (this.week?.periods ?? []).filter(p => !p.isBreak).length;
    return teaching * this.workingDayList.length;
  }

  teacherCell(day: number, periodNo: number): TeacherWeekCell | undefined {
    return this.week?.cells.find(c => c.dayOfWeek === day && c.periodNo === periodNo);
  }

  /** Notes when the chosen section already has something in that period, and what. */
  busyNote(day: number, periodNo: number, o: TeacherAssignmentOption): string {
    const hit = this.week?.sectionBusy.find(b =>
      b.dayOfWeek === day && b.periodNo === periodNo &&
      b.className === o.className && b.sectionName === o.sectionName);
    if (!hit) return '';
    return hit.subject === o.subject ? '  — already scheduled' : `  — busy: ${hit.subject}`;
  }

  loadTeacher(): void {
    if (!this.staffId) { this.week = null; return; }
    this.loading = true;
    this.api.getTeacherWeek(Number(this.staffId)).subscribe({
      next: w => {
        this.week = w;
        if (w.workingDays?.length) this.workingDays = w.workingDays;
        this.loading = false; this.error = '';
      },
      error: e => { this.error = adminApiError(e); this.loading = false; this.week = null; },
    });
  }

  openTeacherCell(day: number, period: TimetablePeriod): void {
    const existing = this.teacherCell(day, period.periodNo);
    const match = this.week?.options.find(o =>
      o.className === existing?.className && o.sectionName === existing?.sectionName && o.subject === existing?.subject);
    this.teacherForm = { optionKey: match ? this.optionKey(match) : '', room: existing?.room ?? '' };
    this.formError = '';
    this.teacherEditing = { day, period };
  }

  saveTeacherCell(): void {
    if (!this.teacherEditing || !this.week) return;
    const { day, period } = this.teacherEditing;
    const existing = this.teacherCell(day, period.periodNo);
    const chosen = this.week.options.find(o => this.optionKey(o) === this.teacherForm.optionKey);

    // Clearing empties the period in the section this teacher was in, not a blank save.
    const target = chosen
      ? { className: chosen.className, sectionName: chosen.sectionName, subject: chosen.subject as string | null }
      : existing
        ? { className: existing.className ?? '', sectionName: existing.sectionName ?? '', subject: null }
        : null;
    if (!target) { this.teacherEditing = null; return; }

    this.saving = true;
    this.api.saveTimetableSlot({
      className: target.className,
      sectionName: target.sectionName,
      dayOfWeek: day,
      periodNo: period.periodNo,
      subject: target.subject,
      room: this.teacherForm.room.trim() || null,
      // This view schedules one named teacher, so book them explicitly rather
      // than relying on the subject assignment.
      teacherStaffId: target.subject ? this.staffId : null,
    }).subscribe({
      next: () => {
        this.saving = false;
        this.teacherEditing = null;
        this.showToast(target.subject
          ? `${target.className}-${target.sectionName} · ${target.subject} set for ${this.dayLabel(day)} ${period.name}`
          : `${this.dayLabel(day)} ${period.name} cleared`);
        this.loadTeacher();
      },
      error: e => { this.saving = false; this.formError = adminApiError(e); },
    });
  }

  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }
}
