import { Component, OnInit, inject } from '@angular/core';
import { DecimalPipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {
  AdminApiService, adminApiError, AcademicYearDto,
  TransportGrid, TransportSlabDto, TransportStudentDto, SaveTransportSlab, SaveTransportStudent,
} from '../../core/admin-api.service';

/**
 * Transport fees, which are the one head a class price cannot express. Two children in the same
 * class can live a street apart and twelve kilometres apart, and a third walks to school and
 * should see no bus charge at all.
 *
 * So the school sets a scale of distance bands once, records how far each rider lives, and the
 * band decides the fare. A negotiated amount overrides the band for the cases every school has —
 * staff children, siblings, a term of half fare — without bending the scale for everyone else.
 *
 * Both halves are edited here and saved separately: changing a band changes what every rider in
 * it pays, which is a different decision from marking one more child onto the bus.
 */
@Component({
  selector: 'app-ad-transport',
  standalone: true,
  imports: [FormsModule, DecimalPipe],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Transport Fee</h1>
        <div class="page-sub">
          @if (grid?.academicYearName) { Distance pricing for {{ grid?.academicYearName }} }
          @else { No academic year set }
          @if (slabsDirty) { · <span class="unsaved">bands not saved</span> }
          @if (studentEdits.size) { · <span class="unsaved">{{ studentEdits.size }} student(s) not saved</span> }
        </div>
      </div>
      @if (years.length > 1) { <button class="btn btn-ghost" (click)="openCopy()">Copy bands from another year</button> }
    </div>

    @if (loading) { <div class="card"><div class="empty">Loading…</div></div> }
    @else if (error) { <div class="card"><div class="empty">{{ error }}</div></div> }
    @else if (!grid?.feeHeadId) {
      <div class="card">
        <div class="empty">
          No fee head is priced by distance. Open <b>Fee Structure</b>, edit the head you bill
          transport under, and set <b>Priced by</b> to “Per student (distance)”.
        </div>
      </div>
    }
    @else {
      <!-- What the current bands and assignments add up to, before anything is billed. -->
      <div class="stat-row">
        <div class="stat"><div class="stat-label">On the bus</div><div class="stat-value">{{ summary.riders | number }}</div></div>
        <div class="stat"><div class="stat-label">Not riding</div><div class="stat-value">{{ summary.notRiding | number }}</div></div>
        <div class="stat" [class.warn]="summary.needsDistance > 0">
          <div class="stat-label">Distance missing</div><div class="stat-value">{{ summary.needsDistance | number }}</div>
        </div>
        <div class="stat" [class.warn]="summary.beyondSlabs > 0">
          <div class="stat-label">Past last band</div><div class="stat-value">{{ summary.beyondSlabs | number }}</div>
        </div>
        <div class="stat"><div class="stat-label">Per month</div><div class="stat-value">₹{{ summary.monthlyTotal | number }}</div></div>
      </div>

      <div class="card">
        <div class="card-head">
          <h2 class="grow">Distance bands</h2>
          <select class="select" [ngModel]="selectedYearId" (ngModelChange)="switchYear($event)">
            @for (y of years; track y.id) { <option [value]="y.id">{{ y.name }}{{ y.isCurrent ? ' (current)' : '' }}</option> }
          </select>
          <button class="btn btn-ghost btn-sm" (click)="addSlab()">+ Add band</button>
          <button class="btn btn-primary btn-sm" (click)="saveSlabs()" [disabled]="!slabsDirty || saving">
            {{ saving ? 'Saving…' : 'Save bands' }}
          </button>
        </div>

        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr>
                <th>Band</th>
                <th class="num">Up to (km)</th>
                <th class="num">{{ freqLabel }} amount</th>
                <th class="num">Riders</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              @for (s of slabRows; track $index; let i = $index) {
                <tr>
                  <td class="td-main">{{ bandLabel(i) }}</td>
                  <td class="num">
                    <input class="input sm num" type="number" min="0.5" step="0.5" [(ngModel)]="s.upToKm"
                           (ngModelChange)="slabsDirty = true" />
                  </td>
                  <td class="num">
                    <input class="input sm num" type="number" min="0" step="50" [(ngModel)]="s.amount"
                           (ngModelChange)="slabsDirty = true" />
                  </td>
                  <td class="num">{{ s.riders ?? 0 }}</td>
                  <td><button class="btn btn-ghost btn-sm" (click)="removeSlab(i)">Remove</button></td>
                </tr>
              } @empty {
                <tr><td colspan="5"><div class="empty">No bands yet — add one to start pricing by distance.</div></td></tr>
              }
            </tbody>
          </table>
        </div>
        <div class="td-sub foot-note">
          A band covers everything above the band below it, up to and including its own distance.
          A rider whose distance is past the last band is <b>not billed</b> and is listed below,
          so an unpriced stretch of road cannot be hidden by quietly charging the top rate.
        </div>
      </div>

      <div class="card">
        <div class="card-head">
          <h2 class="grow">Students</h2>
          <input class="input" style="min-width:210px;" placeholder="Search name, admission no or class…"
                 [(ngModel)]="q" />
          <select class="select" [(ngModel)]="filter">
            <option value="all">Everyone</option>
            <option value="riding">On the bus</option>
            <option value="not_riding">Not riding</option>
            <option value="attention">Needs attention</option>
          </select>
          <button class="btn btn-primary btn-sm" (click)="saveStudents()" [disabled]="!studentEdits.size || saving">
            {{ saving ? 'Saving…' : 'Save ' + studentEdits.size + ' student(s)' }}
          </button>
        </div>

        @if (overrideCount > 0) {
          <div class="override-note">
            <b>{{ overrideCount }}</b> student(s) are on an agreed amount and ignore the bands
            entirely. That is right for a staff child or a negotiated rate; if you meant them to
            follow the scale, clear the box or press <b>use band</b> on the row.
          </div>
        }

        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr>
                <th>Student</th>
                <th>Class</th>
                <th class="mid">Rides</th>
                <th class="num">Distance (km)</th>
                <th class="num">Charge</th>
                <th>Pickup point</th>
                <th class="num">Agreed amount<div class="th-sub">optional</div></th>
              </tr>
            </thead>
            <tbody>
              @for (s of visible; track s.studentId) {
                <tr [class.row-edited]="studentEdits.has(s.studentId)">
                  <td><div class="td-main">{{ s.name }}</div><div class="td-sub">{{ s.admissionNo }}</div></td>
                  <td>{{ s.className }}@if (s.sectionName) {-{{ s.sectionName }}}</td>
                  <td class="mid">
                    <input type="checkbox" [ngModel]="s.usesTransport"
                           (ngModelChange)="setRiding(s, $event)" [attr.aria-label]="'Rides the bus: ' + s.name" />
                  </td>
                  <td class="num">
                    <input class="input sm num" type="number" min="0" step="0.5" placeholder="—"
                           [disabled]="!s.usesTransport" [ngModel]="s.distanceKm"
                           (ngModelChange)="setField(s, 'distanceKm', $event)" />
                  </td>
                  <!--
                    Filled by the band the moment a distance is typed. Deliberately not an input:
                    it is the answer the scale gives, and making it editable here is what led to
                    every student being put on a private amount and the bands pricing nobody.
                  -->
                  <td class="num charge" [class.charge-over]="s.amountOverride !== null">
                    <div class="charge-amt">{{ chargeLabel(s) }}</div>
                    <div class="td-sub">{{ chargeWhy(s) }}</div>
                  </td>
                  <td>
                    <input class="input sm" placeholder="—" [disabled]="!s.usesTransport"
                           [ngModel]="s.pickupPoint" (ngModelChange)="setField(s, 'pickupPoint', $event)" />
                  </td>
                  <td class="num">
                    <div class="override-cell">
                      <input class="input sm num" type="number" min="0" step="50"
                             [placeholder]="bandHint(s)"
                             [disabled]="!s.usesTransport" [ngModel]="s.amountOverride"
                             (ngModelChange)="setField(s, 'amountOverride', $event)" />
                      @if (s.amountOverride !== null) {
                        <button class="link-btn" (click)="clearOverride(s)"
                                title="Charge this student from the distance bands instead">use band</button>
                      }
                    </div>
                  </td>
                </tr>
              } @empty {
                <tr><td colspan="7"><div class="empty">No students match.</div></td></tr>
              }
            </tbody>
          </table>
        </div>
        <div class="td-sub foot-note">
          Type the distance and the <b>Charge</b> fills itself from the bands above — that is the
          normal case, and it means a band you change later moves every student in it at once.
          <b>Agreed amount</b> is for exceptions only: a figure there pins this one student and
          takes them out of the bands, including <b>0</b> for a child who rides free. Nothing is
          billed until you generate invoices.
        </div>
      </div>
    }

    @if (showCopy) {
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>Copy Bands</h2><button class="modal-close" (click)="showCopy = false">✕</button></div>
          <div class="modal-body">
            <div class="form-row">
              <div class="field"><label>From</label>
                <select class="select" [(ngModel)]="copyForm.from">@for (y of years; track y.id) { <option [value]="y.id">{{ y.name }}</option> }</select>
              </div>
              <div class="field"><label>Into</label>
                <select class="select" [(ngModel)]="copyForm.to">@for (y of years; track y.id) { <option [value]="y.id">{{ y.name }}</option> }</select>
              </div>
            </div>
            <div class="td-sub">A band the target year already has keeps its own amount.</div>
            @if (copyError) { <div style="color:var(--crit-text);font-size:13px;margin-top:8px;">{{ copyError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showCopy = false">Cancel</button>
            <button class="btn btn-primary" (click)="copyYear()" [disabled]="saving">Copy</button>
          </div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
  styles: [`
    .unsaved { color: var(--crit-text); font-weight: 600; }
    .input.sm.num { width: 96px; text-align: right; padding: 6px 8px; }
    .input.sm { padding: 6px 8px; font-size: 13px; }
    .data-table .mid { text-align: center; }
    .row-edited td { background: var(--brand-tint); }
    .foot-note { padding: 10px 14px; line-height: 1.55; }

    /* A short summary strip, same pastel family as the dashboard tiles. */
    .stat-row { display: flex; flex-wrap: wrap; gap: 12px; margin-bottom: 14px; }
    .stat {
      flex: 1 1 140px; padding: 12px 14px;
      background: var(--surface); border: 1px solid var(--border); border-radius: 12px;
      box-shadow: var(--shadow-xs);
    }
    .stat.warn { border-color: rgba(250, 178, 25, 0.45); background: var(--warn-tint); }
    .stat-label { font-size: 11.5px; font-weight: 600; color: var(--muted); text-transform: uppercase; letter-spacing: 0.04em; }
    .stat-value { font-size: 20px; font-weight: 800; margin-top: 3px; font-variant-numeric: tabular-nums; }
    .missing { color: var(--crit-text); font-weight: 600; }

    /* The charge is the output of the row, so it is set like a result and not like another box. */
    .charge { white-space: nowrap; }
    .charge-amt { font-weight: 700; font-variant-numeric: tabular-nums; }
    .charge-over .charge-amt { color: var(--warn-text); }
    .th-sub { font-size: 10.5px; font-weight: 500; color: var(--muted); text-transform: none; letter-spacing: 0; }

    .override-cell { display: flex; align-items: center; justify-content: flex-end; gap: 6px; }
    .link-btn {
      font-family: inherit; font-size: 11px; font-weight: 600;
      background: none; border: 0; padding: 2px 4px; cursor: pointer;
      color: var(--brand); text-decoration: underline; white-space: nowrap;
    }
    .link-btn:hover { color: var(--brand-dark); }

    .override-note {
      margin: 0 14px 10px; padding: 9px 12px; border-radius: 9px;
      background: var(--warn-tint); color: var(--warn-text);
      font-size: 12.5px; line-height: 1.5;
    }
  `],
})
export class AdTransportComponent implements OnInit {
  private readonly api = inject(AdminApiService);

  grid: TransportGrid | null = null;
  years: AcademicYearDto[] = [];
  selectedYearId: number | null = null;
  loading = true;
  error = '';
  saving = false;
  toast = '';

  /** Bands are edited as a working copy: the set is replaced wholesale on save. */
  slabRows: { upToKm: number | null; amount: number | null; riders?: number }[] = [];
  slabsDirty = false;

  q = '';
  filter: 'all' | 'riding' | 'not_riding' | 'attention' = 'all';
  /** Students touched since the last save, by id. */
  readonly studentEdits = new Map<number, TransportStudentDto>();

  showCopy = false;
  copyForm = { from: 0, to: 0 };
  copyError = '';

  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void {
    this.api.getAcademicYears().subscribe({
      next: y => { this.years = y; if (!this.selectedYearId) this.selectedYearId = (y.find(x => x.isCurrent) ?? y[0])?.id ?? null; },
      error: () => {},
    });
    this.reload();
  }

  get summary() {
    return this.grid?.summary ?? { riders: 0, notRiding: 0, needsDistance: 0, beyondSlabs: 0, monthlyTotal: 0 };
  }

  get freqLabel(): string {
    switch (this.grid?.feeHeadFrequency) {
      case 'monthly': return 'Monthly';
      case 'quarterly': return 'Quarterly';
      case 'half_yearly': return 'Half-yearly';
      case 'yearly': return 'Yearly';
      case 'one_time': return 'One-time';
      default: return 'Monthly';
    }
  }

  reload(yearId?: number | null): void {
    this.loading = true;
    this.api.transport(yearId ?? undefined).subscribe({
      next: g => {
        this.grid = g;
        this.selectedYearId = g.academicYearId;
        this.slabRows = g.slabs.map((s: TransportSlabDto) => ({ upToKm: s.upToKm, amount: s.amount, riders: s.riders }));
        this.slabsDirty = false;
        this.studentEdits.clear();
        this.loading = false;
        this.error = '';
      },
      error: e => { this.error = adminApiError(e); this.loading = false; },
    });
  }

  switchYear(id: number | string): void {
    if ((this.slabsDirty || this.studentEdits.size) && !confirm('Discard unsaved changes?')) {
      this.selectedYearId = this.grid?.academicYearId ?? null;
      return;
    }
    this.reload(Number(id));
  }

  /* ---------------- bands ---------------- */

  /** "0 – 3 km" for the first band, "3 – 6 km" after it: the floor is the band below's ceiling. */
  bandLabel(i: number): string {
    const from = i === 0 ? 0 : (this.slabRows[i - 1]?.upToKm ?? 0);
    const to = this.slabRows[i]?.upToKm;
    return to == null ? `over ${from} km` : `${from} – ${to} km`;
  }

  addSlab(): void {
    const last = this.slabRows[this.slabRows.length - 1];
    // A new band starts beyond the last one; guessing +2 km saves the common keystroke and is
    // still obviously a guess to anyone reading it.
    this.slabRows.push({ upToKm: last?.upToKm ? Number(last.upToKm) + 2 : 3, amount: last?.amount ?? 0 });
    this.slabsDirty = true;
  }

  removeSlab(i: number): void {
    const band = this.bandLabel(i);
    const riders = this.slabRows[i]?.riders ?? 0;
    if (riders > 0 && !confirm(`${riders} student(s) are priced by ${band}. Removing it moves them into the next band up, or off pricing entirely. Continue?`)) return;
    this.slabRows.splice(i, 1);
    this.slabsDirty = true;
  }

  saveSlabs(): void {
    const slabs: SaveTransportSlab[] = this.slabRows
      .filter(r => Number(r.upToKm) > 0)
      .map(r => ({ upToKm: Number(r.upToKm), amount: Number(r.amount) || 0 }))
      .sort((a, b) => a.upToKm - b.upToKm);

    const ceilings = new Set(slabs.map(s => s.upToKm));
    if (ceilings.size !== slabs.length) { alert('Two bands end at the same distance. Give each band its own ceiling.'); return; }

    this.saving = true;
    this.api.saveTransportSlabs(this.selectedYearId, slabs).subscribe({
      next: () => { this.saving = false; this.showToast(`${slabs.length} band(s) saved`); this.reload(this.selectedYearId); },
      error: e => { this.saving = false; alert(adminApiError(e)); },
    });
  }

  /* ---------------- students ---------------- */

  /**
   * The band scale as it stands in the editor, ordered by ceiling — unsaved edits included, so a
   * charge previews against the scale being typed rather than the one last saved.
   */
  private get bands(): { km: number; amount: number }[] {
    return this.slabRows
      .filter(r => Number(r.upToKm) > 0)
      .map(r => ({ km: Number(r.upToKm), amount: Number(r.amount) || 0 }))
      .sort((a, b) => a.km - b.km);
  }

  get visible(): TransportStudentDto[] {
    const q = this.q.trim().toLowerCase();
    return (this.grid?.students ?? []).filter(s => {
      if (this.filter === 'riding' && !s.usesTransport) return false;
      if (this.filter === 'not_riding' && s.usesTransport) return false;
      // "Needs attention" is the working list: riders the invoice run would skip.
      if (this.filter === 'attention' && s.status !== 'no_distance' && s.status !== 'beyond_slabs' && s.status !== 'no_slabs') return false;
      if (!q) return true;
      return `${s.name} ${s.admissionNo} ${s.className ?? ''} ${s.sectionName ?? ''}`.toLowerCase().includes(q);
    });
  }

  setRiding(s: TransportStudentDto, value: boolean): void {
    s.usesTransport = value;
    // Taking someone off the bus drops the agreed amount with it — that was a deal for a service
    // they are no longer taking. The distance stays: it is a fact about where they live.
    if (!value) s.amountOverride = null;
    this.touch(s);
  }

  setField(s: TransportStudentDto, field: 'distanceKm' | 'pickupPoint' | 'amountOverride', value: unknown): void {
    if (field === 'pickupPoint') {
      s.pickupPoint = (value as string) || null;
    } else {
      // An empty box is "not set", which is not the same as zero: a blank agreed amount hands
      // the student back to the bands, while 0 means they ride free.
      const raw = value as string | number | null;
      const n = raw === '' || raw === null || raw === undefined ? null : Number(raw);
      const parsed = n === null || Number.isNaN(n) ? null : n;
      if (field === 'distanceKm') s.distanceKm = parsed; else s.amountOverride = parsed;
    }
    this.touch(s);
  }

  private touch(s: TransportStudentDto): void {
    this.studentEdits.set(s.studentId, s);
    this.repriceLocally(s);
  }

  /**
   * Re-runs the band rule in the browser so the Charge column tracks what is being typed. The
   * server decides the real number on reload; this only has to agree with it, which it does
   * because both walk the same ordered ceilings.
   */
  private repriceLocally(s: TransportStudentDto): void {
    if (!s.usesTransport) { s.amount = 0; s.status = 'not_riding'; s.matchedSlabKm = null; return; }
    if (s.amountOverride !== null) { s.amount = s.amountOverride; s.status = 'priced'; s.matchedSlabKm = null; return; }
    if (s.distanceKm === null) { s.amount = 0; s.status = 'no_distance'; s.matchedSlabKm = null; return; }

    if (!this.bands.length) { s.amount = 0; s.status = 'no_slabs'; s.matchedSlabKm = null; return; }

    const band = this.bands.find(b => b.km >= s.distanceKm!);
    if (!band) { s.amount = 0; s.status = 'beyond_slabs'; s.matchedSlabKm = null; return; }
    s.amount = band.amount;
    s.status = 'priced';
    s.matchedSlabKm = band.km;
  }

  /** How many riders are pinned to an agreed amount rather than priced by a band. */
  get overrideCount(): number {
    return (this.grid?.students ?? []).filter(s => s.usesTransport && s.amountOverride !== null).length;
  }

  /**
   * What the bands would charge this student, shown as the override box's placeholder. Seeing
   * the figure the scale produces is what stops someone typing it in by hand.
   */
  bandHint(s: TransportStudentDto): string {
    if (!s.usesTransport) return '—';
    if (s.distanceKm === null) return 'band';
    const band = this.bands.find(b => b.km >= s.distanceKm!);
    return band ? band.amount.toLocaleString('en-IN') : 'band';
  }

  /** Where the number in the Charge cell came from, in the fewest words that are still true. */
  chargeWhy(s: TransportStudentDto): string {
    if (!s.usesTransport) return 'not riding';
    if (s.amountOverride !== null) return 'agreed amount';
    switch (s.status) {
      case 'priced': return `${s.matchedSlabKm} km band`;
      case 'no_distance': return 'enter a distance';
      case 'no_slabs': return 'add bands above';
      case 'beyond_slabs': return 'add a wider band';
      default: return '';
    }
  }

  /** Hands a student back to the scale. The distance and pickup point are left as they are. */
  clearOverride(s: TransportStudentDto): void {
    s.amountOverride = null;
    this.studentEdits.set(s.studentId, s);
    this.repriceLocally(s);
  }

  /** The Charge cell says why there is no charge, rather than showing a bare ₹0. */
  chargeLabel(s: TransportStudentDto): string {
    switch (s.status) {
      case 'priced': return `₹${s.amount.toLocaleString('en-IN')}`;
      case 'not_riding': return '—';
      case 'no_distance': return 'distance?';
      case 'no_slabs': return 'no bands';
      case 'beyond_slabs': return 'past last band';
      default: return '—';
    }
  }

  saveStudents(): void {
    if (!this.studentEdits.size) return;
    const students: SaveTransportStudent[] = [...this.studentEdits.values()].map(s => ({
      studentId: s.studentId,
      usesTransport: s.usesTransport,
      distanceKm: s.distanceKm,
      pickupPoint: s.pickupPoint,
      amountOverride: s.amountOverride,
      note: s.note,
    }));
    this.saving = true;
    this.api.saveTransportStudents(students).subscribe({
      next: r => { this.saving = false; this.showToast(`${r.saved} student(s) saved`); this.reload(this.selectedYearId); },
      error: e => { this.saving = false; alert(adminApiError(e)); },
    });
  }

  /* ---------------- copy ---------------- */

  openCopy(): void {
    const current = this.years.find(y => y.isCurrent) ?? this.years[0];
    this.copyForm = { from: this.years.find(y => y.id !== current?.id)?.id ?? 0, to: current?.id ?? 0 };
    this.copyError = '';
    this.showCopy = true;
  }

  copyYear(): void {
    if (!this.copyForm.from || !this.copyForm.to) { this.copyError = 'Pick both years.'; return; }
    this.saving = true;
    this.api.copyTransportSlabs(Number(this.copyForm.from), Number(this.copyForm.to)).subscribe({
      next: r => {
        this.saving = false;
        this.showCopy = false;
        this.showToast(r.copied > 0 ? `${r.copied} band(s) copied` : 'Nothing to copy — the target year already has those bands');
        this.reload(this.selectedYearId);
      },
      error: e => { this.saving = false; this.copyError = adminApiError(e); },
    });
  }

  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }
}
