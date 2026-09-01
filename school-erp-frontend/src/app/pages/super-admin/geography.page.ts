import { Component, OnInit, inject } from '@angular/core';
import { HttpClient, HttpErrorResponse, HttpParams } from '@angular/common/http';
import { FormsModule } from '@angular/forms';
import { environment } from '../../../environments/environment';
import { City, Country, GeographyService, StateRegion } from '../../core/geography.service';

function apiError(err: unknown, fallback = 'Something went wrong.'): string {
  const e = err as HttpErrorResponse;
  if (e?.status === 0) return 'Cannot reach the API. Is it running on the configured URL?';
  return e?.error?.message ?? e?.message ?? fallback;
}

type Level = 'countries' | 'states' | 'cities';

/**
 * The platform-level geography master. Countries → states → cities, each level
 * filtered by the row selected above it.
 *
 * Entries are retired rather than deleted: schools, students and staff already
 * point at them, and a school that typed a name the master lacks is exactly why
 * an admin comes here.
 */
@Component({
  selector: 'app-sa-geography',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Geography</h1>
        <div class="page-sub">
          Shared by every school · {{ countries.length }} countries ·
          {{ states.length }} states · {{ cities.length }} cities
        </div>
      </div>
      <button class="btn btn-primary" (click)="openForm()">+ Add {{ singular }}</button>
    </div>

    <div class="card">
      <div class="card-head filters">
        <select class="select" [(ngModel)]="level" (ngModelChange)="onLevelChange()">
          <option value="countries">Countries</option>
          <option value="states">States / Provinces</option>
          <option value="cities">Cities</option>
        </select>

        @if (level !== 'countries') {
          <select class="select" [(ngModel)]="filterCountryId" (ngModelChange)="onCountryFilter()">
            <option [ngValue]="null">All countries</option>
            @for (c of countries; track c.id) { <option [ngValue]="c.id">{{ c.name }}</option> }
          </select>
        }
        @if (level === 'cities') {
          <select class="select" [(ngModel)]="filterStateId" (ngModelChange)="loadCities()">
            <option [ngValue]="null">All states</option>
            @for (s of filteredStates; track s.id) { <option [ngValue]="s.id">{{ s.name }}</option> }
          </select>
        }
        <div class="grow"></div>
        <input class="input" style="max-width:220px;" placeholder="Search…" [(ngModel)]="q" />
      </div>

      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr>
                <th>Name</th>
                @if (level === 'countries') { <th>ISO</th><th>Phone</th><th>Currency</th> }
                @if (level === 'states') { <th>Country</th><th>Code</th> }
                @if (level === 'cities') { <th>State</th><th>Country</th> }
                <th>Status</th><th>Actions</th>
              </tr>
            </thead>
            <tbody>
              @for (r of rows; track r.id) {
                <tr>
                  <td class="td-main">{{ r.name }}</td>
                  @if (level === 'countries') {
                    <td class="td-sub">{{ asCountry(r).iso2 }}</td>
                    <td class="td-sub">{{ asCountry(r).phoneCode || '—' }}</td>
                    <td class="td-sub">{{ asCountry(r).currency || '—' }}</td>
                  }
                  @if (level === 'states') {
                    <td>{{ asState(r).countryName }}</td>
                    <td class="td-sub">{{ asState(r).code || '—' }}</td>
                  }
                  @if (level === 'cities') {
                    <td>{{ asCity(r).stateName }}</td>
                    <td class="td-sub">{{ asCity(r).countryName }}</td>
                  }
                  <td>
                    <span class="badge" [class]="r.isActive ? 'badge success' : 'badge neutral'">
                      {{ r.isActive ? 'Active' : 'Retired' }}
                    </span>
                  </td>
                  <td>
                    <div class="row-actions">
                      <button class="icon-action primary" (click)="edit(r)" title="Edit" aria-label="Edit">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/></svg>
                      </button>
                      @if (r.isActive) {
                        <button class="icon-action danger" (click)="setActive(r, false)" title="Retire" aria-label="Retire">
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><line x1="5.6" y1="5.6" x2="18.4" y2="18.4"/></svg>
                        </button>
                      } @else {
                        <button class="icon-action success" (click)="setActive(r, true)" title="Restore" aria-label="Restore">
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.5 2.5L16 9"/></svg>
                        </button>
                      }
                    </div>
                  </td>
                </tr>
              } @empty {
                <tr><td [attr.colspan]="level === 'countries' ? 6 : 5"><div class="empty">Nothing here.</div></td></tr>
              }
            </tbody>
          </table>
        </div>
      }
    </div>

    @if (showForm) {
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head">
            <h2>{{ editingId ? 'Edit' : 'Add' }} {{ singular }}</h2>
            <button class="modal-close" (click)="showForm = false">✕</button>
          </div>
          <div class="modal-body">
            @if (level === 'states') {
              <div class="field"><label>Country <span class="req">*</span></label>
                <select class="select" [(ngModel)]="form.parentId" [disabled]="!!editingId">
                  <option [ngValue]="null">Select…</option>
                  @for (c of countries; track c.id) { <option [ngValue]="c.id">{{ c.name }}</option> }
                </select>
              </div>
            }
            @if (level === 'cities') {
              <div class="field"><label>State <span class="req">*</span></label>
                <select class="select" [(ngModel)]="form.parentId" [disabled]="!!editingId">
                  <option [ngValue]="null">Select…</option>
                  @for (s of states; track s.id) { <option [ngValue]="s.id">{{ s.name }} — {{ s.countryName }}</option> }
                </select>
              </div>
            }
            <div class="field"><label>Name <span class="req">*</span></label>
              <input class="input" [(ngModel)]="form.name" placeholder="e.g. Kirtipur" /></div>
            @if (level === 'countries') {
              <div class="form-row">
                <div class="field"><label>ISO code <span class="req">*</span></label>
                  <input class="input" maxlength="2" [(ngModel)]="form.iso2" placeholder="NP" /></div>
                <div class="field"><label>Phone code</label>
                  <input class="input" [(ngModel)]="form.phoneCode" placeholder="+977" /></div>
                <div class="field"><label>Currency</label>
                  <input class="input" maxlength="3" [(ngModel)]="form.currency" placeholder="NPR" /></div>
              </div>
            }
            @if (level === 'states') {
              <div class="field"><label>Code</label>
                <input class="input" [(ngModel)]="form.code" placeholder="P3" /></div>
            }
            @if (editingId && level !== 'countries') {
              <div class="field-hint">Renaming does not change records already saved under the old name.</div>
            }
            @if (formError) { <div style="color:var(--crit-text);font-size:13px;">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showForm = false">Cancel</button>
            <button class="btn btn-primary" (click)="save()" [disabled]="saving">
              {{ saving ? 'Saving…' : (editingId ? 'Save Changes' : 'Add') }}
            </button>
          </div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class SaGeographyComponent implements OnInit {
  private readonly http = inject(HttpClient);
  private readonly geo = inject(GeographyService);
  private readonly base = `${environment.superAdminApi}/geography`;

  level: Level = 'countries';
  countries: Country[] = [];
  states: StateRegion[] = [];
  cities: City[] = [];
  filterCountryId: number | null = null;
  filterStateId: number | null = null;
  q = '';

  loading = true;
  error = '';
  formError = '';
  toast = '';
  showForm = false;
  saving = false;
  editingId: number | null = null;
  form = this.emptyForm();
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void { this.loadAll(); }

  get singular(): string {
    return this.level === 'countries' ? 'country' : this.level === 'states' ? 'state' : 'city';
  }

  get filteredStates(): StateRegion[] {
    return this.filterCountryId
      ? this.states.filter(s => s.countryId === this.filterCountryId)
      : this.states;
  }

  /** The rows on screen for the selected level, narrowed by the search box. */
  get rows(): { id: number; name: string; isActive: boolean }[] {
    const all = this.level === 'countries' ? this.countries
      : this.level === 'states' ? this.filteredStates
      : this.cities;
    const q = this.q.trim().toLowerCase();
    return q ? all.filter(r => r.name.toLowerCase().includes(q)) : all;
  }

  asCountry(r: unknown): Country { return r as Country; }
  asState(r: unknown): StateRegion { return r as StateRegion; }
  asCity(r: unknown): City { return r as City; }

  onLevelChange(): void { this.q = ''; this.loadAll(); }
  onCountryFilter(): void { this.filterStateId = null; this.loadCities(); }

  private loadAll(): void {
    this.loading = true;
    this.http.get<Country[]>(`${this.base}/countries`).subscribe({
      next: c => {
        this.countries = c;
        this.http.get<StateRegion[]>(`${this.base}/states`).subscribe({
          next: s => { this.states = s; this.loadCities(); },
          error: e => { this.error = apiError(e); this.loading = false; },
        });
      },
      error: e => { this.error = apiError(e); this.loading = false; },
    });
  }

  loadCities(): void {
    let p = new HttpParams();
    if (this.filterStateId) p = p.set('stateId', this.filterStateId);
    this.http.get<City[]>(`${this.base}/cities`, { params: p }).subscribe({
      next: c => {
        // Without a state filter the API returns every city; narrow by country here.
        this.cities = this.filterCountryId && !this.filterStateId
          ? c.filter(x => this.states.some(s => s.id === x.stateId && s.countryId === this.filterCountryId))
          : c;
        this.loading = false;
        this.error = '';
      },
      error: e => { this.error = apiError(e); this.loading = false; },
    });
  }

  openForm(): void {
    this.editingId = null;
    this.form = this.emptyForm();
    if (this.level === 'states') this.form.parentId = this.filterCountryId;
    if (this.level === 'cities') this.form.parentId = this.filterStateId;
    this.formError = '';
    this.showForm = true;
  }

  edit(r: { id: number; name: string }): void {
    this.editingId = r.id;
    this.formError = '';
    if (this.level === 'countries') {
      const c = this.asCountry(r);
      this.form = { parentId: null, name: c.name, iso2: c.iso2, phoneCode: c.phoneCode ?? '', currency: c.currency ?? '', code: '' };
    } else if (this.level === 'states') {
      const s = this.asState(r);
      this.form = { parentId: s.countryId, name: s.name, iso2: '', phoneCode: '', currency: '', code: s.code ?? '' };
    } else {
      const c = this.asCity(r);
      this.form = { parentId: c.stateId, name: c.name, iso2: '', phoneCode: '', currency: '', code: '' };
    }
    this.showForm = true;
  }

  save(): void {
    if (!this.form.name.trim()) { this.formError = 'Name is required.'; return; }
    if (this.level !== 'countries' && !this.form.parentId) {
      this.formError = this.level === 'states' ? 'Choose a country.' : 'Choose a state.';
      return;
    }
    this.saving = true;
    this.formError = '';

    const body =
      this.level === 'countries'
        ? { name: this.form.name.trim(), iso2: this.form.iso2.trim(), phoneCode: this.form.phoneCode.trim() || null, currency: this.form.currency.trim() || null }
        : this.level === 'states'
          ? { countryId: this.form.parentId, name: this.form.name.trim(), code: this.form.code.trim() || null }
          : { stateId: this.form.parentId, name: this.form.name.trim() };

    const url = `${this.base}/${this.level}`;
    const done = (m: string) => {
      this.saving = false; this.showForm = false;
      // Pickers cache their lists, so drop the cache or the new entry stays invisible.
      this.geo.invalidate();
      this.showToast(m); this.loadAll();
    };
    const fail = (e: unknown) => { this.saving = false; this.formError = apiError(e); };

    if (this.editingId) {
      this.http.put<void>(`${url}/${this.editingId}`, body).subscribe({ next: () => done('Saved'), error: fail });
    } else {
      this.http.post<{ id: number }>(url, body).subscribe({ next: () => done('Added'), error: fail });
    }
  }

  setActive(r: { id: number; name: string }, value: boolean): void {
    if (!value && !confirm(`Retire ${r.name}? It stops being offered on forms; existing records keep it.`)) return;
    this.http.patch<void>(`${this.base}/${this.level}/${r.id}/active?value=${value}`, {}).subscribe({
      next: () => { this.geo.invalidate(); this.showToast(`${r.name} ${value ? 'restored' : 'retired'}`); this.loadAll(); },
      error: e => alert(apiError(e)),
    });
  }

  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }

  private emptyForm() {
    return { parentId: null as number | null, name: '', iso2: '', phoneCode: '', currency: '', code: '' };
  }
}
