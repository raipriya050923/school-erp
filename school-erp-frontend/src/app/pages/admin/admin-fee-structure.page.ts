import { Component, OnInit, inject } from '@angular/core';
import { DecimalPipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {
  AdminApiService, adminApiError, AcademicYearDto,
  FeeHeadDto, SaveFeeHead, FeeStructureGrid, FeeStructureCell,
} from '../../core/admin-api.service';
import { FieldErrors } from '../../shared/field-errors';

/**
 * Where invoice amounts come from. A school defines its fee heads, then prices each class for
 * each head in the current academic year; Generate Invoices adds up the monthly heads for the
 * student's class. Amounts used to be a rate table compiled into the API, identical for every
 * school, so anything outside "Grade 6".."Grade 10" was billed a flat fallback.
 *
 * Prices are a snapshot, not a link: changing one changes what the *next* run bills. Invoices
 * already raised keep their own line breakdown.
 */
@Component({
  selector: 'app-ad-fee-structure',
  standalone: true,
  imports: [FormsModule, DecimalPipe],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Fee Structure</h1>
        <div class="page-sub">
          @if (grid?.academicYearName) { Pricing for {{ grid?.academicYearName }} } @else { No academic year set }
          @if (dirtyCount) { · <span style="color:var(--crit-text);font-weight:600;">{{ dirtyCount }} unsaved</span> }
        </div>
      </div>
      @if (years.length > 1) {
        <button class="btn btn-ghost" (click)="openCopy()">Copy from another year</button>
      }
      <button class="btn btn-ghost" (click)="openHead()">+ Add Fee Head</button>
      <button class="btn btn-primary" (click)="saveGrid()" [disabled]="!dirtyCount || saving">
        {{ saving ? 'Saving…' : 'Save Prices' }}
      </button>
    </div>

    <div class="card">
      <div class="card-head"><h2 class="grow">Class prices</h2>
        <select class="select" [ngModel]="selectedYearId" (ngModelChange)="switchYear($event)">
          @for (y of years; track y.id) { <option [value]="y.id">{{ y.name }}{{ y.isCurrent ? ' (current)' : '' }}</option> }
        </select>
      </div>

      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else if (!grid?.academicYearId) {
        <div class="empty">Create an academic year first — prices are set per year.</div>
      }
      @else if (!classes.length) {
        <div class="empty">No classes yet — add them under Classes &amp; Sections, then price them here.</div>
      }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr>
                <th>Class</th>
                @for (h of activeHeads; track h.id) {
                  <th class="num">{{ h.name }}<div class="td-sub">{{ freqLabel(h.frequency) }}</div></th>
                }
                <th class="num">Monthly invoice</th>
              </tr>
            </thead>
            <tbody>
              @for (c of classes; track c.classId) {
                <tr>
                  <td class="td-main">{{ c.className }}</td>
                  @for (h of activeHeads; track h.id) {
                    <td class="num">
                      <input class="input sm num" type="number" min="0" step="100"
                             [ngModel]="amount(c.classId, h.id)"
                             (ngModelChange)="setAmount(c.classId, h.id, $event)"
                             [class.dirty]="isDirty(c.classId, h.id)" placeholder="—" />
                    </td>
                  }
                  <td class="num"><strong>₹{{ monthlyTotal(c.classId) | number }}</strong></td>
                </tr>
              }
            </tbody>
          </table>
        </div>
        <div class="td-sub" style="padding:10px 14px;">
          Blank or 0 means the class is not billed for that head. The Monthly invoice column adds up
          the monthly heads only — yearly and one-time heads are billed when you tick
          “include yearly &amp; one-time charges” on Generate Invoices.
        </div>
      }
    </div>

    <div class="card">
      <div class="card-head"><h2 class="grow">Fee heads</h2></div>
      <div class="table-wrap">
        <table class="data-table">
          <thead><tr><th>Head</th><th>Billed</th><th>Description</th><th class="num">Classes priced</th><th>Status</th><th>Actions</th></tr></thead>
          <tbody>
            @for (h of heads; track h.id) {
              <tr>
                <td class="td-main">{{ h.name }}</td>
                <td>{{ freqLabel(h.frequency) }}</td>
                <td class="td-sub">{{ h.description || '—' }}</td>
                <td class="num">{{ h.inUse }}</td>
                <td><span class="badge" [class]="h.isActive ? 'badge success' : 'badge neutral'">{{ h.isActive ? 'Active' : 'Retired' }}</span></td>
                <td>
                  <div class="row-actions">
                    <button class="btn btn-ghost btn-sm" (click)="openHead(h)">Edit</button>
                    @if (h.isActive) {
                      <button class="btn btn-ghost btn-sm" (click)="setHeadActive(h, false)">Retire</button>
                    } @else {
                      <button class="btn btn-ghost btn-sm" (click)="setHeadActive(h, true)">Restore</button>
                    }
                  </div>
                </td>
              </tr>
            } @empty { <tr><td colspan="6"><div class="empty">No fee heads yet.</div></td></tr> }
          </tbody>
        </table>
      </div>
    </div>

    @if (showHead) {
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>{{ editingHeadId ? 'Edit Fee Head' : 'Add Fee Head' }}</h2><button class="modal-close" (click)="showHead = false">✕</button></div>
          <div class="modal-body">
            <div class="field">
              <label>Name <span class="req">*</span></label>
              <input class="input" [class.invalid]="err.has('name')" [(ngModel)]="headForm.name"
                     (ngModelChange)="err.clear('name')" placeholder="e.g. Hostel Fee" />
              @if (err.has('name')) { <div class="field-error">{{ err.get('name') }}</div> }
            </div>
            <div class="field"><label>Billed</label>
              <select class="select" [(ngModel)]="headForm.frequency">
                <option value="monthly">Monthly</option>
                <option value="quarterly">Quarterly</option>
                <option value="half_yearly">Half-yearly</option>
                <option value="yearly">Yearly</option>
                <option value="one_time">One-time</option>
              </select>
              <div class="field-hint">Only monthly heads go on every monthly invoice.</div>
            </div>
            <div class="field"><label>Description</label><input class="input" [(ngModel)]="headForm.description" placeholder="Shown on the invoice breakdown" /></div>
            <label class="check"><input type="checkbox" [(ngModel)]="headForm.isRefundable" /> Refundable deposit</label>
            @if (headError) { <div style="color:var(--crit-text);font-size:13px;">{{ headError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showHead = false">Cancel</button>
            <button class="btn btn-primary" (click)="saveHead()" [disabled]="saving">{{ editingHeadId ? 'Save Changes' : 'Add Head' }}</button>
          </div>
        </div>
      </div>
    }

    @if (showCopy) {
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>Copy Prices</h2><button class="modal-close" (click)="showCopy = false">✕</button></div>
          <div class="modal-body">
            <div class="form-row">
              <div class="field"><label>From</label>
                <select class="select" [(ngModel)]="copyForm.from">@for (y of years; track y.id) { <option [value]="y.id">{{ y.name }}</option> }</select>
              </div>
              <div class="field"><label>Into</label>
                <select class="select" [(ngModel)]="copyForm.to">@for (y of years; track y.id) { <option [value]="y.id">{{ y.name }}</option> }</select>
              </div>
            </div>
            <div class="td-sub">Prices already set in the target year are left alone.</div>
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
    .input.sm.num { width: 108px; text-align: right; padding: 6px 8px; }
    .input.dirty { border-color: var(--accent, #2563eb); background: color-mix(in srgb, var(--accent, #2563eb) 6%, transparent); }
    .check { display: flex; align-items: center; gap: 8px; font-size: 13px; margin-top: 4px; }
  `],
})
export class AdFeeStructureComponent implements OnInit {
  private readonly api = inject(AdminApiService);

  grid: FeeStructureGrid | null = null;
  years: AcademicYearDto[] = [];
  selectedYearId: number | null = null;
  loading = true;
  error = '';
  saving = false;
  toast = '';

  showHead = false;
  readonly err = new FieldErrors();
  editingHeadId: number | null = null;
  headForm: SaveFeeHead = this.emptyHead();
  headError = '';

  showCopy = false;
  copyForm = { from: 0, to: 0 };
  copyError = '';

  /** classId:headId -> amount, holding edits until Save Prices is pressed. */
  private edits = new Map<string, number>();
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void {
    this.api.getAcademicYears().subscribe({
      next: y => { this.years = y; if (!this.selectedYearId) this.selectedYearId = (y.find(x => x.isCurrent) ?? y[0])?.id ?? null; },
      error: () => {},
    });
    this.reload();
  }

  get heads(): FeeHeadDto[] { return this.grid?.heads ?? []; }
  get activeHeads(): FeeHeadDto[] { return this.heads.filter(h => h.isActive); }
  get classes() { return this.grid?.classes ?? []; }
  get dirtyCount(): number { return this.edits.size; }

  reload(yearId?: number | null): void {
    this.loading = true;
    this.edits.clear();
    this.api.feeStructure(yearId ?? undefined).subscribe({
      next: g => {
        this.grid = g;
        this.selectedYearId = g.academicYearId;
        this.loading = false;
        this.error = '';
      },
      error: e => { this.error = adminApiError(e); this.loading = false; },
    });
  }

  switchYear(id: number | string): void {
    const yearId = Number(id);
    if (this.dirtyCount && !confirm('Discard unsaved price changes?')) { this.selectedYearId = this.grid?.academicYearId ?? null; return; }
    this.reload(yearId);
  }

  /* ---- grid ---- */

  private key(classId: number, headId: number): string { return `${classId}:${headId}`; }

  amount(classId: number, headId: number): number | null {
    const k = this.key(classId, headId);
    if (this.edits.has(k)) return this.edits.get(k)!;
    return this.grid?.cells.find(c => c.classId === classId && c.headId === headId)?.amount ?? null;
  }

  setAmount(classId: number, headId: number, value: unknown): void {
    const n = Number(value);
    const next = Number.isFinite(n) && n > 0 ? n : 0;
    const stored = this.grid?.cells.find(c => c.classId === classId && c.headId === headId)?.amount ?? 0;
    const k = this.key(classId, headId);
    // Typing a value back to what it already was is not a change, so it should not stay flagged.
    if (next === stored) this.edits.delete(k); else this.edits.set(k, next);
  }

  isDirty(classId: number, headId: number): boolean { return this.edits.has(this.key(classId, headId)); }

  /** Live monthly total, counting unsaved edits so the number tracks what is being typed. */
  monthlyTotal(classId: number): number {
    return this.activeHeads
      .filter(h => h.frequency === 'monthly')
      .reduce((sum, h) => sum + (this.amount(classId, h.id) ?? 0), 0);
  }

  saveGrid(): void {
    if (!this.dirtyCount) return;
    const cells: FeeStructureCell[] = [...this.edits.entries()].map(([k, amount]) => {
      const [classId, headId] = k.split(':').map(Number);
      return { classId, headId, amount };
    });
    this.saving = true;
    this.api.saveFeeStructure(this.selectedYearId, cells).subscribe({
      next: () => { this.saving = false; this.showToast(`${cells.length} price(s) saved`); this.reload(this.selectedYearId); },
      error: e => { this.saving = false; alert(adminApiError(e)); },
    });
  }

  /* ---- heads ---- */

  openHead(h?: FeeHeadDto): void {
    this.editingHeadId = h?.id ?? null;
    this.headForm = h
      ? { name: h.name, description: h.description ?? '', frequency: h.frequency, isRefundable: h.isRefundable }
      : this.emptyHead();
    this.headError = '';
    this.err.reset();
    this.showHead = true;
  }

  saveHead(): void {
    this.headError = '';
    this.err.reset();
    if (!this.err.require('name', this.headForm.name, 'Name is required.')) return;
    this.saving = true;
    const dto: SaveFeeHead = {
      ...this.headForm,
      name: this.headForm.name.trim(),
      description: (this.headForm.description ?? '').trim() || null,
    };
    const done = (m: string) => { this.saving = false; this.showHead = false; this.showToast(m); this.reload(this.selectedYearId); };
    const fail = (e: unknown) => { this.saving = false; this.headError = adminApiError(e); };
    if (this.editingHeadId) this.api.updateFeeHead(this.editingHeadId, dto).subscribe({ next: () => done('Fee head updated'), error: fail });
    else this.api.createFeeHead(dto).subscribe({ next: () => done('Fee head added'), error: fail });
  }

  setHeadActive(h: FeeHeadDto, value: boolean): void {
    if (!value && !confirm(`Retire ${h.name}? It stops being billed on new invoices; its prices and past invoice lines are kept.`)) return;
    this.api.setFeeHeadActive(h.id, value).subscribe({
      next: () => { this.showToast(`${h.name} ${value ? 'restored' : 'retired'}`); this.reload(this.selectedYearId); },
      error: e => alert(adminApiError(e)),
    });
  }

  /* ---- copy ---- */

  openCopy(): void {
    const current = this.years.find(y => y.isCurrent) ?? this.years[0];
    this.copyForm = { from: this.years.find(y => y.id !== current?.id)?.id ?? 0, to: current?.id ?? 0 };
    this.copyError = '';
    this.showCopy = true;
  }

  copyYear(): void {
    if (!this.copyForm.from || !this.copyForm.to) { this.copyError = 'Pick both years.'; return; }
    this.saving = true;
    this.api.copyFeeStructure(Number(this.copyForm.from), Number(this.copyForm.to)).subscribe({
      next: r => {
        this.saving = false;
        this.showCopy = false;
        this.showToast(r.copied > 0 ? `${r.copied} price(s) copied` : 'Nothing to copy — the target year is already priced');
        this.reload(this.selectedYearId);
      },
      error: e => { this.saving = false; this.copyError = adminApiError(e); },
    });
  }

  freqLabel(f: string): string {
    switch (f) {
      case 'monthly': return 'Monthly';
      case 'quarterly': return 'Quarterly';
      case 'half_yearly': return 'Half-yearly';
      case 'yearly': return 'Yearly';
      case 'one_time': return 'One-time';
      default: return f;
    }
  }

  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }
  private emptyHead(): SaveFeeHead { return { name: '', description: '', frequency: 'monthly', isRefundable: false }; }
}
