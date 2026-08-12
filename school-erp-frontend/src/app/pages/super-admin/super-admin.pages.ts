import { Component, OnInit, inject } from '@angular/core';
import { CurrencyPipe, DatePipe, DecimalPipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpErrorResponse } from '@angular/common/http';
import {
  SuperAdminApiService, statusBadge, statusLabel, priorityBadge,
  SchoolListItem, SchoolDetail, Plan, Subscription, Invoice, BillingSummary,
  TicketListItem, TicketDetail,
} from '../../core/super-admin-api.service';
import { AuthService } from '../../core/auth.service';
import { IconComponent } from '../../shared/icon.component';

/** Pulls a readable message out of the API's { error, message } envelope. */
function apiError(err: unknown, fallback = 'Something went wrong.'): string {
  const e = err as HttpErrorResponse;
  if (e?.status === 0) return 'Cannot reach the API. Is it running on the configured URL?';
  return e?.error?.message ?? e?.message ?? fallback;
}

/* =====================  DASHBOARD  ===================== */

@Component({
  selector: 'app-sa-dashboard',
  standalone: true,
  imports: [DecimalPipe, CurrencyPipe, DatePipe, IconComponent],
  template: `
    @if (loading) { <div class="card"><div class="empty">Loading dashboard…</div></div> }
    @else if (error) { <div class="card"><div class="empty">{{ error }}</div></div> }
    @else if (stats) {
      <!-- Hero -->
      <div class="dash-hero">
        <div class="hero-badge"><span class="live-dot"></span> Live · {{ today | date:'MMM d, y' }}</div>
        <h1>Welcome back, {{ firstName }} 👋</h1>
        <p>Here's what's happening across your {{ stats.totalSchools }} schools today.</p>
      </div>

      <!-- Metric cards -->
      <div class="metric-grid">
        <div class="metric-card">
          <div class="metric-top">
            <div class="icon-badge blue"><app-icon name="school" [size]="24" /></div>
          </div>
          <div class="metric-value">{{ stats.totalSchools | number }}</div>
          <div class="metric-label">Total Schools</div>
          <div class="metric-sub">tenants on the platform</div>
        </div>

        <div class="metric-card">
          <div class="metric-top">
            <div class="icon-badge green"><app-icon name="package" [size]="24" /></div>
            <span class="metric-pill good">{{ activePct }}% active</span>
          </div>
          <div class="metric-value">{{ stats.activeSubscriptions | number }}</div>
          <div class="metric-label">Active Subscriptions</div>
          <div class="metric-sub">{{ stats.trialSubscriptions }} currently on trial</div>
        </div>

        <div class="metric-card">
          <div class="metric-top">
            <div class="icon-badge violet"><app-icon name="money" [size]="24" /></div>
          </div>
          <div class="metric-value">{{ stats.monthlyRecurringRevenue | currency:'USD':'symbol':'1.0-0' }}</div>
          <div class="metric-label">Monthly Recurring Revenue</div>
          <div class="metric-sub">normalised from active plans</div>
        </div>

        <div class="metric-card">
          <div class="metric-top">
            <div class="icon-badge" [class]="stats.openTickets > 0 ? 'icon-badge amber' : 'icon-badge green'"><app-icon name="ticket" [size]="24" /></div>
            @if (stats.openTickets > 0) { <span class="metric-pill warn">needs attention</span> }
          </div>
          <div class="metric-value">{{ stats.openTickets | number }}</div>
          <div class="metric-label">Open Support Tickets</div>
          <div class="metric-sub">awaiting response</div>
        </div>
      </div>

      <div class="grid-2">
        <!-- Subscription mix -->
        <div class="card">
          <div class="card-head"><h2 class="grow">Subscription Mix</h2><span class="td-sub">{{ stats.totalSchools }} schools</span></div>
          <div class="card-body">
            <div class="prop-bar">
              @if (stats.activeSubscriptions > 0) { <div class="prop-seg" [style.background]="'#1baf7a'" [style.width.%]="pct(stats.activeSubscriptions)"></div> }
              @if (stats.trialSubscriptions > 0) { <div class="prop-seg" [style.background]="'#eda100'" [style.width.%]="pct(stats.trialSubscriptions)"></div> }
              @if (otherCount > 0) { <div class="prop-seg" [style.background]="'#c3c2b7'" [style.width.%]="pct(otherCount)"></div> }
            </div>
            <div class="prop-legend">
              <span class="legend-item"><span class="legend-dot" style="background:#1baf7a"></span> Active <b>{{ stats.activeSubscriptions }}</b></span>
              <span class="legend-item"><span class="legend-dot" style="background:#eda100"></span> Trial <b>{{ stats.trialSubscriptions }}</b></span>
              @if (otherCount > 0) { <span class="legend-item"><span class="legend-dot" style="background:#c3c2b7"></span> Other <b>{{ otherCount }}</b></span> }
            </div>
          </div>
        </div>

        <!-- Recent signups -->
        <div class="card">
          <div class="card-head"><h2 class="grow">Recent Signups</h2></div>
          <div class="table-wrap">
            <table class="data-table">
              <thead><tr><th>School</th><th>City</th><th>Status</th><th>Joined</th></tr></thead>
              <tbody>
                @for (s of recentSchools; track s.id) {
                  <tr>
                    <td><div class="td-main">{{ s.name }}</div><div class="td-sub">{{ s.schoolCode }}</div></td>
                    <td>{{ s.city }}</td>
                    <td><span class="badge" [class]="'badge ' + badge(s.status)">{{ label(s.status) }}</span></td>
                    <td class="td-sub">{{ s.createdAt | date:'mediumDate' }}</td>
                  </tr>
                }
              </tbody>
            </table>
          </div>
        </div>
      </div>
    }
  `,
})
export class SaDashboardComponent implements OnInit {
  private readonly api = inject(SuperAdminApiService);
  stats: DashboardStats | null = null;
  recentSchools: SchoolListItem[] = [];
  loading = true;
  error = '';
  readonly today = new Date();
  label = statusLabel;
  badge = statusBadge;

  get firstName(): string {
    return (this.auth.user()?.name ?? 'Admin').split(' ')[0];
  }
  get activePct(): number {
    const total = (this.stats?.activeSubscriptions ?? 0) + (this.stats?.trialSubscriptions ?? 0) + this.otherCount;
    return total ? Math.round(((this.stats?.activeSubscriptions ?? 0) / total) * 100) : 0;
  }
  get otherCount(): number {
    if (!this.stats) return 0;
    return Math.max(0, this.stats.totalSchools - this.stats.activeSubscriptions - this.stats.trialSubscriptions);
  }
  pct(n: number): number {
    return this.stats?.totalSchools ? (n / this.stats.totalSchools) * 100 : 0;
  }

  private readonly auth = inject(AuthService);

  ngOnInit(): void {
    this.api.getDashboardStats().subscribe({
      next: s => { this.stats = s; this.loadSchools(); },
      error: e => { this.error = apiError(e); this.loading = false; },
    });
  }
  private loadSchools(): void {
    this.api.getSchools().subscribe({
      next: rows => {
        this.recentSchools = [...rows].sort((a, b) => b.createdAt.localeCompare(a.createdAt)).slice(0, 5);
        this.loading = false;
      },
      error: e => { this.error = apiError(e); this.loading = false; },
    });
  }
}
type DashboardStats = import('../../core/super-admin-api.service').DashboardStats;

/* =====================  SCHOOLS  ===================== */

@Component({
  selector: 'app-sa-schools',
  standalone: true,
  imports: [FormsModule, DecimalPipe, DatePipe],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>School Management</h1>
        <div class="page-sub">{{ displayed.length }} of {{ schools.length }} tenants</div>
      </div>
      <button class="btn btn-primary" (click)="openForm()">+ Onboard School</button>
    </div>

    <div class="card">
      <div class="card-head filters">
        <input class="input grow" placeholder="Search by name, code or city…" [(ngModel)]="q" (keyup.enter)="search()" />
        <div class="field" style="margin:0;">
          <label style="font-size:11px;">Joined from</label>
          <input class="input" type="date" [(ngModel)]="fromDate" />
        </div>
        <div class="field" style="margin:0;">
          <label style="font-size:11px;">Joined to</label>
          <input class="input" type="date" [(ngModel)]="toDate" />
        </div>
        <button class="btn btn-primary" (click)="search()">Search</button>
        @if (appliedQ || appliedFrom || appliedTo) {
          <button class="btn btn-ghost" (click)="clearFilters()">Clear</button>
        }
      </div>
      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr><th>Code</th><th>School</th><th>City</th><th class="num">Students</th><th>Status</th><th>Joined</th><th>Actions</th></tr>
            </thead>
            <tbody>
              @for (s of displayed; track s.id) {
                <tr>
                  <td class="td-sub">{{ s.schoolCode }}</td>
                  <td class="td-main">{{ s.name }}</td>
                  <td>{{ s.city }}</td>
                  <td class="num">{{ s.studentCount | number }}</td>
                  <td><span class="badge" [class]="'badge ' + badge(s.status)">{{ label(s.status) }}</span></td>
                  <td class="td-sub">{{ s.createdAt | date:'mediumDate' }}</td>
                  <td>
                    <div class="row-actions">
                      <button class="icon-action primary" (click)="view(s.id)" title="View details" aria-label="View">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7-11-7-11-7z"/><circle cx="12" cy="12" r="3"/></svg>
                      </button>
                      <button class="icon-action primary" (click)="edit(s.id)" title="Edit" aria-label="Edit">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/></svg>
                      </button>
                      @if (s.status === 'suspended') {
                        <button class="icon-action success" (click)="setStatus(s, 'active')" title="Activate" aria-label="Activate">
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.5 2.5L16 9"/></svg>
                        </button>
                      } @else {
                        <button class="icon-action danger" (click)="deactivate(s)" title="Deactivate" aria-label="Deactivate">
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><line x1="5.6" y1="5.6" x2="18.4" y2="18.4"/></svg>
                        </button>
                      }
                    </div>
                  </td>
                </tr>
              } @empty {
                <tr><td colspan="7"><div class="empty">No schools found.</div></td></tr>
              }
            </tbody>
          </table>
        </div>
      }
    </div>

    <!-- View modal -->
    @if (viewing; as s) {
      <div class="modal-backdrop" (click)="viewing = null">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head"><h2>{{ s.name }}</h2><button class="modal-close" (click)="viewing = null">✕</button></div>
          <div class="modal-body">
            <div class="kv-row"><span class="kv-label">Tenant code</span><span class="kv-value">{{ s.schoolCode }}</span></div>
            <div class="kv-row"><span class="kv-label">Subdomain</span><span class="kv-value">{{ s.subdomain }}.edunexus.io</span></div>
            <div class="kv-row"><span class="kv-label">Email</span><span class="kv-value">{{ s.email }}</span></div>
            <div class="kv-row"><span class="kv-label">Phone</span><span class="kv-value">{{ s.phone }}</span></div>
            <div class="kv-row"><span class="kv-label">City</span><span class="kv-value">{{ s.city || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">State</span><span class="kv-value">{{ s.state || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Board</span><span class="kv-value">{{ s.affiliationBoard || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Status</span><span class="kv-value"><span class="badge" [class]="'badge ' + badge(s.status)">{{ label(s.status) }}</span></span></div>
            <div class="kv-row"><span class="kv-label">Joined</span><span class="kv-value">{{ s.createdAt | date:'mediumDate' }}</span></div>
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="viewing = null">Close</button>
            <button class="btn btn-primary" (click)="edit(s.id); viewing = null">Edit School</button>
          </div>
        </div>
      </div>
    }

    <!-- Create / edit modal -->
    @if (showForm) {
      <div class="modal-backdrop" (click)="closeForm()">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head"><h2>{{ editingId ? 'Edit School' : 'Onboard New School' }}</h2><button class="modal-close" (click)="closeForm()">✕</button></div>
          <div class="modal-body">
            <div class="field"><label>School name *</label><input class="input" [(ngModel)]="form.name" /></div>
            <div class="form-row">
              <div class="field"><label>City</label><input class="input" [(ngModel)]="form.city" /></div>
              <div class="field"><label>State / Province</label><input class="input" [(ngModel)]="form.state" /></div>
            </div>
            <div class="form-row">
              <div class="field"><label>Email</label><input class="input" type="email" [(ngModel)]="form.email" /></div>
              <div class="field"><label>Phone</label><input class="input" [(ngModel)]="form.phone" /></div>
            </div>
            <div class="form-row">
              <div class="field"><label>Affiliation board</label><input class="input" [(ngModel)]="form.affiliationBoard" placeholder="NEB / CBSE" /></div>
              <div class="field"><label>Status</label>
                <select class="select" [(ngModel)]="form.status">
                  <option value="pending">Pending</option>
                  <option value="active">Active</option>
                  @if (editingId) { <option value="suspended">Suspended</option> }
                </select>
              </div>
            </div>
            @if (formError) { <div style="color: var(--crit-text); font-size: 13px;">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="closeForm()">Cancel</button>
            <button class="btn btn-primary" (click)="save()" [disabled]="saving">{{ saving ? 'Saving…' : (editingId ? 'Save Changes' : 'Create School') }}</button>
          </div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class SaSchoolsComponent implements OnInit {
  private readonly api = inject(SuperAdminApiService);
  schools: SchoolListItem[] = [];
  loading = true;
  error = '';
  q = '';
  fromDate = '';
  toDate = '';
  // "applied" values only change when the user clicks Search
  appliedQ = '';
  appliedFrom = '';
  appliedTo = '';
  showForm = false;
  saving = false;
  formError = '';
  editingId: number | null = null;
  viewing: SchoolDetail | null = null;
  toast = '';
  label = statusLabel;
  badge = statusBadge;
  form = this.empty();
  private timer?: ReturnType<typeof setTimeout>;
  private searchTimer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void { this.reload(); }

  /** Client-side date-range filter on top of the applied server search. */
  get displayed(): SchoolListItem[] {
    return this.schools.filter(s => {
      const d = s.createdAt.slice(0, 10);
      if (this.appliedFrom && d < this.appliedFrom) return false;
      if (this.appliedTo && d > this.appliedTo) return false;
      return true;
    });
  }

  /** Apply the current search term + date range (triggered by the Search button). */
  search(): void {
    this.appliedQ = this.q.trim();
    this.appliedFrom = this.fromDate;
    this.appliedTo = this.toDate;
    this.reload();
  }

  clearFilters(): void {
    this.q = ''; this.fromDate = ''; this.toDate = '';
    this.appliedQ = ''; this.appliedFrom = ''; this.appliedTo = '';
    this.reload();
  }

  reload(): void {
    clearTimeout(this.searchTimer);
    this.searchTimer = setTimeout(() => {
      this.loading = this.schools.length === 0;
      this.api.getSchools(this.appliedQ || undefined).subscribe({
        next: rows => { this.schools = rows; this.loading = false; this.error = ''; },
        error: e => { this.error = apiError(e); this.loading = false; },
      });
    }, 100);
  }

  openForm(): void { this.editingId = null; this.form = this.empty(); this.formError = ''; this.showForm = true; }

  view(id: number): void {
    this.api.getSchool(id).subscribe({ next: s => this.viewing = s, error: e => alert(apiError(e)) });
  }

  edit(id: number): void {
    this.api.getSchool(id).subscribe({
      next: s => {
        this.editingId = id;
        this.form = { name: s.name, email: s.email, phone: s.phone, city: s.city ?? '', state: s.state ?? '', affiliationBoard: s.affiliationBoard ?? '', status: s.status };
        this.formError = '';
        this.showForm = true;
      },
      error: e => alert(apiError(e)),
    });
  }

  save(): void {
    if (!this.form.name.trim()) { this.formError = 'School name is required.'; return; }
    this.saving = true;
    const dto = { ...this.form, name: this.form.name.trim() };
    const done = (msg: string) => { this.saving = false; this.showForm = false; this.showToast(msg); this.reload(); };
    const fail = (e: unknown) => { this.saving = false; this.formError = apiError(e); };
    if (this.editingId) {
      this.api.updateSchool(this.editingId, dto).subscribe({ next: () => done(`${dto.name} updated`), error: fail });
    } else {
      this.api.createSchool(dto).subscribe({ next: () => done(`${dto.name} onboarded`), error: fail });
    }
  }

  deactivate(s: SchoolListItem): void {
    if (!confirm(`Deactivate ${s.name}? Its users will lose access.`)) return;
    this.setStatus(s, 'suspended');
  }
  setStatus(s: SchoolListItem, status: string): void {
    this.api.setSchoolStatus(s.id, status).subscribe({
      next: () => { this.showToast(`${s.name} → ${statusLabel(status)}`); this.reload(); },
      error: e => alert(apiError(e)),
    });
  }

  closeForm(): void { this.showForm = false; this.editingId = null; }
  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3500); }
  private empty() { return { name: '', email: '', phone: '', city: '', state: '', affiliationBoard: '', status: 'pending' }; }
}

/* =====================  PLANS  ===================== */

@Component({
  selector: 'app-sa-plans',
  standalone: true,
  imports: [FormsModule, DecimalPipe, CurrencyPipe],
  template: `
    <div class="page-head">
      <div class="grow"><h1>Subscription Plans</h1><div class="page-sub">Pricing catalogue offered to schools</div></div>
      <button class="btn btn-primary" (click)="openForm()">+ Create Plan</button>
    </div>

    <div class="card">
      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Plan</th><th class="num">Monthly</th><th class="num">Yearly</th><th class="num">Max Students</th><th class="num">Schools</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              @for (p of plans; track p.id) {
                <tr>
                  <td>
                    <div class="td-main">{{ p.name }}</div>
                    <div class="td-sub" style="white-space: normal; max-width: 320px;">{{ p.description }}</div>
                  </td>
                  <td class="num">{{ p.priceMonthly | currency:'USD':'symbol':'1.0-0' }}</td>
                  <td class="num">{{ p.priceYearly | currency:'USD':'symbol':'1.0-0' }}</td>
                  <td class="num">{{ p.maxStudents === null ? 'Unlimited' : (p.maxStudents | number) }}</td>
                  <td class="num">{{ p.subscriberCount }}</td>
                  <td><span class="badge" [class]="p.isActive ? 'badge success' : 'badge danger'">{{ p.isActive ? 'Active' : 'Inactive' }}</span></td>
                  <td>
                    <div class="row-actions">
                      <button class="icon-action primary" (click)="view = p" title="View">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7-11-7-11-7z"/><circle cx="12" cy="12" r="3"/></svg>
                      </button>
                      <button class="icon-action primary" (click)="edit(p)" title="Edit">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/></svg>
                      </button>
                      @if (p.isActive) {
                        <button class="icon-action danger" (click)="setActive(p, false)" title="Deactivate">
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><line x1="5.6" y1="5.6" x2="18.4" y2="18.4"/></svg>
                        </button>
                      } @else {
                        <button class="icon-action success" (click)="setActive(p, true)" title="Activate">
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.5 2.5L16 9"/></svg>
                        </button>
                      }
                    </div>
                  </td>
                </tr>
              }
            </tbody>
          </table>
        </div>
      }
    </div>

    @if (view; as p) {
      <div class="modal-backdrop" (click)="view = null">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head"><h2>{{ p.name }} Plan</h2><button class="modal-close" (click)="view = null">✕</button></div>
          <div class="modal-body">
            <div class="kv-row"><span class="kv-label">Description</span><span class="kv-value">{{ p.description || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Monthly</span><span class="kv-value">{{ p.priceMonthly | currency:'USD' }}</span></div>
            <div class="kv-row"><span class="kv-label">Yearly</span><span class="kv-value">{{ p.priceYearly | currency:'USD' }}</span></div>
            <div class="kv-row"><span class="kv-label">Max students</span><span class="kv-value">{{ p.maxStudents === null ? 'Unlimited' : (p.maxStudents | number) }}</span></div>
            <div class="kv-row"><span class="kv-label">Trial</span><span class="kv-value">{{ p.trialDays }} days</span></div>
            <div class="kv-row"><span class="kv-label">Schools subscribed</span><span class="kv-value">{{ p.subscriberCount }}</span></div>
            <div class="kv-row"><span class="kv-label">Status</span><span class="kv-value"><span class="badge" [class]="p.isActive ? 'badge success' : 'badge danger'">{{ p.isActive ? 'Active' : 'Inactive' }}</span></span></div>
          </div>
          <div class="modal-foot"><button class="btn btn-ghost" (click)="view = null">Close</button></div>
        </div>
      </div>
    }

    @if (showForm) {
      <div class="modal-backdrop" (click)="showForm = false">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head"><h2>{{ editingId ? 'Edit Plan' : 'Create Plan' }}</h2><button class="modal-close" (click)="showForm = false">✕</button></div>
          <div class="modal-body">
            <div class="field"><label>Plan name *</label><input class="input" [(ngModel)]="form.name" [disabled]="!!editingId" /></div>
            <div class="field"><label>Description</label><input class="input" [(ngModel)]="form.description" /></div>
            <div class="form-row">
              <div class="field"><label>Monthly price (USD) *</label><input class="input" type="number" [(ngModel)]="form.priceMonthly" /></div>
              <div class="field"><label>Yearly price (USD) *</label><input class="input" type="number" [(ngModel)]="form.priceYearly" /></div>
            </div>
            <div class="form-row">
              <div class="field"><label>Max students (blank = unlimited)</label><input class="input" type="number" [(ngModel)]="form.maxStudents" /></div>
              <div class="field"><label>Trial days</label><input class="input" type="number" [(ngModel)]="form.trialDays" /></div>
            </div>
            @if (formError) { <div style="color: var(--crit-text); font-size: 13px;">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showForm = false">Cancel</button>
            <button class="btn btn-primary" (click)="save()" [disabled]="saving">{{ saving ? 'Saving…' : (editingId ? 'Save Changes' : 'Create Plan') }}</button>
          </div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class SaPlansComponent implements OnInit {
  private readonly api = inject(SuperAdminApiService);
  plans: Plan[] = [];
  loading = true;
  error = '';
  showForm = false;
  saving = false;
  formError = '';
  editingId: number | null = null;
  view: Plan | null = null;
  toast = '';
  form = this.empty();
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void { this.reload(); }
  reload(): void {
    this.api.getPlans().subscribe({
      next: p => { this.plans = p; this.loading = false; this.error = ''; },
      error: e => { this.error = apiError(e); this.loading = false; },
    });
  }
  openForm(): void { this.editingId = null; this.form = this.empty(); this.formError = ''; this.showForm = true; }
  edit(p: Plan): void {
    this.editingId = p.id;
    this.form = { name: p.name, description: p.description ?? '', priceMonthly: p.priceMonthly, priceYearly: p.priceYearly, maxStudents: p.maxStudents, trialDays: p.trialDays };
    this.formError = ''; this.showForm = true;
  }
  save(): void {
    if (!this.form.name.trim()) { this.formError = 'Plan name is required.'; return; }
    this.saving = true;
    const max = this.form.maxStudents === null || (this.form.maxStudents as unknown as string) === '' ? null : Number(this.form.maxStudents);
    const base = { description: this.form.description, priceMonthly: Number(this.form.priceMonthly) || 0, priceYearly: Number(this.form.priceYearly) || 0, maxStudents: max, maxStaff: null, trialDays: Number(this.form.trialDays) || 0 };
    const done = (m: string) => { this.saving = false; this.showForm = false; this.showToast(m); this.reload(); };
    const fail = (e: unknown) => { this.saving = false; this.formError = apiError(e); };
    if (this.editingId) {
      this.api.updatePlan(this.editingId, base).subscribe({ next: () => done(`${this.form.name} updated`), error: fail });
    } else {
      this.api.createPlan({ name: this.form.name.trim(), ...base }).subscribe({ next: () => done(`${this.form.name} created`), error: fail });
    }
  }
  setActive(p: Plan, value: boolean): void {
    if (!value && !confirm(`Deactivate the ${p.name} plan? ${p.subscriberCount} school(s) are on it.`)) return;
    this.api.setPlanActive(p.id, value).subscribe({ next: () => { this.showToast(`${p.name} ${value ? 'activated' : 'deactivated'}`); this.reload(); }, error: e => alert(apiError(e)) });
  }
  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3500); }
  private empty(): { name: string; description: string; priceMonthly: number | null; priceYearly: number | null; maxStudents: number | null; trialDays: number } {
    return { name: '', description: '', priceMonthly: null, priceYearly: null, maxStudents: null, trialDays: 14 };
  }
}

/* =====================  SUBSCRIPTIONS  ===================== */

@Component({
  selector: 'app-sa-subscriptions',
  standalone: true,
  imports: [FormsModule, CurrencyPipe, DatePipe],
  template: `
    <div class="page-head">
      <div class="grow"><h1>School Subscriptions</h1><div class="page-sub">{{ displayed.length }} of {{ subs.length }} subscriptions</div></div>
    </div>

    <div class="card">
      <div class="card-head filters">
        <select class="select" [(ngModel)]="status" (ngModelChange)="reload()">
          <option value="">All statuses</option>
          <option value="active">Active</option>
          <option value="trial">Trial</option>
          <option value="past_due">Past due</option>
        </select>
        <div class="grow"></div>
        <div class="field" style="margin:0;"><label style="font-size:11px;">Start from</label><input class="input" type="date" [(ngModel)]="fromDate" /></div>
        <div class="field" style="margin:0;"><label style="font-size:11px;">Start to</label><input class="input" type="date" [(ngModel)]="toDate" /></div>
        <button class="btn btn-primary" (click)="search()">Search</button>
        @if (appliedFrom || appliedTo) { <button class="btn btn-ghost" (click)="clearDates()">Clear</button> }
      </div>
      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>School</th><th>Plan</th><th>Cycle</th><th>Period</th><th class="num">Price</th><th>Status</th></tr></thead>
            <tbody>
              @for (s of displayed; track s.id) {
                <tr>
                  <td class="td-main">{{ s.schoolName }}</td>
                  <td>{{ s.planName }}</td>
                  <td>{{ label(s.billingCycle) }}</td>
                  <td class="td-sub">{{ s.startDate | date:'mediumDate' }} → {{ s.endDate | date:'mediumDate' }}</td>
                  <td class="num">{{ s.price | currency:'USD':'symbol':'1.0-0' }}</td>
                  <td><span class="badge" [class]="'badge ' + badge(s.status)">{{ label(s.status) }}</span></td>
                </tr>
              } @empty {
                <tr><td colspan="6"><div class="empty">No subscriptions match.</div></td></tr>
              }
            </tbody>
          </table>
        </div>
      }
    </div>
  `,
})
export class SaSubscriptionsComponent implements OnInit {
  private readonly api = inject(SuperAdminApiService);
  subs: Subscription[] = [];
  loading = true;
  error = '';
  status = '';
  fromDate = '';
  toDate = '';
  appliedFrom = '';
  appliedTo = '';
  label = statusLabel;
  badge = statusBadge;

  ngOnInit(): void { this.reload(); }

  get displayed(): Subscription[] {
    return this.subs.filter(s => {
      const d = s.startDate.slice(0, 10);
      if (this.appliedFrom && d < this.appliedFrom) return false;
      if (this.appliedTo && d > this.appliedTo) return false;
      return true;
    });
  }
  search(): void { this.appliedFrom = this.fromDate; this.appliedTo = this.toDate; }
  clearDates(): void { this.fromDate = ''; this.toDate = ''; this.appliedFrom = ''; this.appliedTo = ''; }

  reload(): void {
    this.api.getSubscriptions(this.status || undefined).subscribe({
      next: s => { this.subs = s; this.loading = false; this.error = ''; },
      error: e => { this.error = apiError(e); this.loading = false; },
    });
  }
}

/* =====================  BILLING  ===================== */

@Component({
  selector: 'app-sa-billing',
  standalone: true,
  imports: [FormsModule, CurrencyPipe, DatePipe],
  template: `
    <div class="page-head">
      <div class="grow"><h1>Billing &amp; Payments</h1><div class="page-sub">Platform revenue from subscriptions</div></div>
    </div>

    @if (summary) {
      <div class="stat-grid">
        <div class="stat-tile"><div class="stat-label">Collected</div><div class="stat-value">{{ summary.collected | currency:'USD':'symbol':'1.0-0' }}</div><div class="stat-sub up">{{ summary.paidCount }} paid</div></div>
        <div class="stat-tile"><div class="stat-label">Outstanding</div><div class="stat-value">{{ summary.outstanding | currency:'USD':'symbol':'1.0-0' }}</div><div class="stat-sub">{{ summary.sentCount }} awaiting</div></div>
        <div class="stat-tile"><div class="stat-label">Overdue</div><div class="stat-value">{{ summary.overdue | currency:'USD':'symbol':'1.0-0' }}</div><div class="stat-sub down">{{ summary.overdueCount }} past due</div></div>
      </div>
    }

    <div class="card">
      <div class="card-head filters">
        <h2 class="grow">Invoices</h2>
        <div class="field" style="margin:0;"><label style="font-size:11px;">Issued from</label><input class="input" type="date" [(ngModel)]="fromDate" /></div>
        <div class="field" style="margin:0;"><label style="font-size:11px;">Issued to</label><input class="input" type="date" [(ngModel)]="toDate" /></div>
        <button class="btn btn-primary" (click)="search()">Search</button>
        @if (appliedFrom || appliedTo) { <button class="btn btn-ghost" (click)="clearDates()">Clear</button> }
      </div>
      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Invoice #</th><th>School</th><th class="num">Amount</th><th>Issued</th><th>Due</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              @for (i of displayed; track i.id) {
                <tr>
                  <td class="td-sub">{{ i.invoiceNo }}</td>
                  <td class="td-main">{{ i.schoolName }}</td>
                  <td class="num">{{ i.totalAmount | currency:'USD':'symbol':'1.0-0' }}</td>
                  <td class="td-sub">{{ i.issuedAt | date:'mediumDate' }}</td>
                  <td>
                    <div class="td-sub">{{ i.dueDate | date:'mediumDate' }}</div>
                    @if (i.remindedAt) { <div class="td-sub" style="color: var(--info-text);">✉ reminded</div> }
                  </td>
                  <td><span class="badge" [class]="'badge ' + badge(i.status)">{{ label(i.status) }}</span></td>
                  <td>
                    <div class="row-actions">
                      @if (i.status !== 'paid' && i.status !== 'void') {
                        <button class="icon-action success" (click)="openPay(i)" title="Record payment">
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="5" width="20" height="14" rx="2"/><line x1="2" y1="10" x2="22" y2="10"/></svg>
                        </button>
                        <button class="icon-action primary" (click)="remind(i)" title="Send reminder">
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="M2 7l10 6 10-6"/></svg>
                        </button>
                      } @else { <span class="td-sub">—</span> }
                    </div>
                  </td>
                </tr>
              } @empty {
                <tr><td colspan="7"><div class="empty">No invoices.</div></td></tr>
              }
            </tbody>
          </table>
        </div>
      }
    </div>

    @if (paying; as inv) {
      <div class="modal-backdrop" (click)="paying = null">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head"><h2>Record Payment — {{ inv.invoiceNo }}</h2><button class="modal-close" (click)="paying = null">✕</button></div>
          <div class="modal-body">
            <div class="kv-row"><span class="kv-label">School</span><span class="kv-value">{{ inv.schoolName }}</span></div>
            <div class="kv-row" style="margin-bottom:12px;"><span class="kv-label">Amount</span><span class="kv-value">{{ inv.totalAmount | currency:'USD' }}</span></div>
            <div class="form-row">
              <div class="field"><label>Amount received (USD) *</label><input class="input" type="number" [(ngModel)]="payForm.amount" /></div>
              <div class="field"><label>Payment date</label><input class="input" type="date" [(ngModel)]="payForm.date" /></div>
            </div>
            <div class="form-row">
              <div class="field"><label>Method</label>
                <select class="select" [(ngModel)]="payForm.method">
                  <option value="bank_transfer">Bank transfer</option><option value="card">Card</option>
                  <option value="stripe">Stripe</option><option value="esewa">eSewa</option>
                  <option value="khalti">Khalti</option><option value="cash">Cash</option>
                </select>
              </div>
              <div class="field"><label>Reference</label><input class="input" [(ngModel)]="payForm.ref" /></div>
            </div>
            @if (formError) { <div style="color: var(--crit-text); font-size: 13px;">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="paying = null">Cancel</button>
            <button class="btn btn-primary" (click)="savePay()" [disabled]="saving">{{ saving ? 'Saving…' : 'Mark as Paid' }}</button>
          </div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class SaBillingComponent implements OnInit {
  private readonly api = inject(SuperAdminApiService);
  invoices: Invoice[] = [];
  summary: BillingSummary | null = null;
  loading = true;
  error = '';
  fromDate = '';
  toDate = '';
  appliedFrom = '';
  appliedTo = '';
  paying: Invoice | null = null;
  saving = false;
  formError = '';
  toast = '';
  payForm = { amount: 0, date: '2026-07-05', method: 'bank_transfer', ref: '' };
  label = statusLabel;
  badge = statusBadge;
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void { this.reload(); }

  get displayed(): Invoice[] {
    return this.invoices.filter(i => {
      const d = (i.issuedAt ?? '').slice(0, 10);
      if (this.appliedFrom && (!d || d < this.appliedFrom)) return false;
      if (this.appliedTo && (!d || d > this.appliedTo)) return false;
      return true;
    });
  }
  search(): void { this.appliedFrom = this.fromDate; this.appliedTo = this.toDate; }
  clearDates(): void { this.fromDate = ''; this.toDate = ''; this.appliedFrom = ''; this.appliedTo = ''; }

  reload(): void {
    this.api.getBillingSummary().subscribe({ next: s => this.summary = s, error: () => {} });
    this.api.getInvoices().subscribe({
      next: i => { this.invoices = i; this.loading = false; this.error = ''; },
      error: e => { this.error = apiError(e); this.loading = false; },
    });
  }
  openPay(i: Invoice): void { this.paying = i; this.formError = ''; this.payForm = { amount: i.totalAmount, date: '2026-07-05', method: 'bank_transfer', ref: '' }; }
  savePay(): void {
    if (!this.paying) return;
    if (!this.payForm.amount || this.payForm.amount <= 0) { this.formError = 'Enter a valid amount.'; return; }
    this.saving = true;
    this.api.recordPayment(this.paying.id, {
      amount: Number(this.payForm.amount), method: this.payForm.method,
      transactionRef: this.payForm.ref.trim() || null, paidAt: this.payForm.date,
    }).subscribe({
      next: () => { this.saving = false; this.showToast(`Payment recorded for ${this.paying!.invoiceNo}`); this.paying = null; this.reload(); },
      error: e => { this.saving = false; this.formError = apiError(e); },
    });
  }
  remind(i: Invoice): void {
    this.api.sendReminder(i.id).subscribe({ next: () => { this.showToast(`Reminder sent for ${i.invoiceNo}`); this.reload(); }, error: e => alert(apiError(e)) });
  }
  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3500); }
}

/* =====================  TICKETS  ===================== */

@Component({
  selector: 'app-sa-tickets',
  standalone: true,
  imports: [FormsModule, DatePipe],
  template: `
    <div class="page-head">
      <div class="grow"><h1>Support Tickets</h1><div class="page-sub">{{ displayed.length }} of {{ tickets.length }} tickets</div></div>
      <select class="select" [(ngModel)]="status" (ngModelChange)="reload()">
        <option value="">All statuses</option>
        <option value="open">Open</option><option value="in_progress">In progress</option>
        <option value="waiting">Waiting</option><option value="resolved">Resolved</option>
      </select>
    </div>

    <div class="card">
      <div class="card-head filters">
        <div class="grow"></div>
        <div class="field" style="margin:0;"><label style="font-size:11px;">Created from</label><input class="input" type="date" [(ngModel)]="fromDate" /></div>
        <div class="field" style="margin:0;"><label style="font-size:11px;">Created to</label><input class="input" type="date" [(ngModel)]="toDate" /></div>
        <button class="btn btn-primary" (click)="search()">Search</button>
        @if (appliedFrom || appliedTo) { <button class="btn btn-ghost" (click)="clearDates()">Clear</button> }
      </div>
      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Ticket / School</th><th>Subject</th><th>Priority</th><th>Status</th><th>Created</th><th>Actions</th></tr></thead>
            <tbody>
              @for (t of displayed; track t.id) {
                <tr>
                  <td>
                    <div class="td-main">{{ t.ticketNo }}</div>
                    <div class="td-sub">{{ t.schoolName }}</div>
                  </td>
                  <td class="td-main">{{ t.subject }}</td>
                  <td><span class="badge" [class]="'badge ' + prio(t.priority)">{{ label(t.priority) }}</span></td>
                  <td><span class="badge" [class]="'badge ' + badge(t.status)">{{ label(t.status) }}</span></td>
                  <td class="td-sub">{{ t.createdAt | date:'mediumDate' }}</td>
                  <td>
                    <div class="row-actions">
                      <button class="icon-action primary has-badge" (click)="openThread(t)" title="Comments">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
                        @if (t.commentCount > 0) { <span class="badge-count">{{ t.commentCount }}</span> }
                      </button>
                      <select class="select sm" [ngModel]="t.status" (ngModelChange)="changeStatus(t, $event)" title="Update status">
                        @for (s of statuses; track s) { <option [value]="s">{{ label(s) }}</option> }
                      </select>
                    </div>
                  </td>
                </tr>
              } @empty {
                <tr><td colspan="6"><div class="empty">No tickets.</div></td></tr>
              }
            </tbody>
          </table>
        </div>
      }
    </div>

    <!-- Thread modal -->
    @if (detail; as t) {
      <div class="modal-backdrop" (click)="detail = null">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head">
            <div class="grow">
              <h2>{{ t.ticketNo }} — {{ t.subject }}</h2>
              <div class="td-sub" style="margin-top:2px;">{{ t.schoolName }} · {{ t.raisedByName }} · <span class="badge" [class]="'badge ' + badge(t.status)">{{ label(t.status) }}</span></div>
            </div>
            <button class="modal-close" (click)="detail = null">✕</button>
          </div>
          <div class="modal-body">
            <div style="font-size:11px;text-transform:uppercase;letter-spacing:.6px;color:var(--muted);margin-bottom:10px;">Comment history ({{ t.comments.length }})</div>
            <div class="chat">
              @for (c of t.comments; track c.id) {
                <div class="chat-msg" [class.mine]="c.side === 'platform'">
                  <div class="chat-meta">
                    <span class="chat-author">{{ c.authorName }}</span>
                    <span class="badge" [class]="c.side === 'platform' ? 'badge info' : 'badge neutral'">{{ c.side === 'platform' ? 'Support Team' : 'School' }}</span>
                    <span>{{ c.createdAt | date:'short' }}</span>
                  </div>
                  <div class="chat-body">{{ c.message }}</div>
                </div>
              } @empty { <div class="empty">No comments yet.</div> }
            </div>
            <div class="field" style="margin-top:16px;">
              <label>Add a comment (visible to {{ t.schoolName }})</label>
              <textarea class="input" rows="3" [(ngModel)]="newComment"></textarea>
            </div>
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="detail = null">Close</button>
            <button class="btn btn-primary" (click)="postComment()" [disabled]="!newComment.trim() || posting">{{ posting ? 'Posting…' : 'Post Comment' }}</button>
          </div>
        </div>
      </div>
    }

    <!-- Resolve modal -->
    @if (resolving; as t) {
      <div class="modal-backdrop" (click)="resolving = null">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head"><h2>Resolve {{ t.ticketNo }}</h2><button class="modal-close" (click)="resolving = null">✕</button></div>
          <div class="modal-body">
            <div class="field"><label>Resolution note *</label><textarea class="input" rows="4" [(ngModel)]="note" placeholder="What was done to resolve this?"></textarea></div>
            <div class="field"><label style="display:flex;align-items:center;gap:8px;font-weight:500;"><input type="checkbox" [(ngModel)]="notifySchool" /> Email resolution to the school</label></div>
            @if (formError) { <div style="color: var(--crit-text); font-size: 13px;">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="resolving = null">Cancel</button>
            <button class="btn btn-primary" (click)="doResolve()" [disabled]="saving">{{ saving ? 'Saving…' : 'Mark Resolved' }}</button>
          </div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class SaTicketsComponent implements OnInit {
  private readonly api = inject(SuperAdminApiService);
  tickets: TicketListItem[] = [];
  loading = true;
  error = '';
  status = '';
  fromDate = '';
  toDate = '';
  appliedFrom = '';
  appliedTo = '';
  detail: TicketDetail | null = null;
  resolving: TicketListItem | null = null;
  newComment = '';
  note = '';
  notifySchool = true;
  posting = false;
  saving = false;
  formError = '';
  toast = '';
  readonly statuses = ['open', 'in_progress', 'waiting', 'resolved', 'closed'];
  readonly actingUserId = 1;  // super admin (Pramod Rai) from the seed
  label = statusLabel;
  badge = statusBadge;
  prio = priorityBadge;
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void { this.reload(); }

  get displayed(): TicketListItem[] {
    return this.tickets.filter(t => {
      const d = t.createdAt.slice(0, 10);
      if (this.appliedFrom && d < this.appliedFrom) return false;
      if (this.appliedTo && d > this.appliedTo) return false;
      return true;
    });
  }
  search(): void { this.appliedFrom = this.fromDate; this.appliedTo = this.toDate; }
  clearDates(): void { this.fromDate = ''; this.toDate = ''; this.appliedFrom = ''; this.appliedTo = ''; }

  reload(): void {
    this.api.getTickets(this.status || undefined).subscribe({
      next: t => { this.tickets = t; this.loading = false; this.error = ''; },
      error: e => { this.error = apiError(e); this.loading = false; },
    });
  }
  openThread(t: TicketListItem): void {
    this.newComment = '';
    this.api.getTicket(t.id).subscribe({ next: d => this.detail = d, error: e => alert(apiError(e)) });
  }
  postComment(): void {
    if (!this.detail || !this.newComment.trim()) return;
    this.posting = true;
    this.api.addComment(this.detail.id, this.actingUserId, this.newComment.trim()).subscribe({
      next: c => { this.detail!.comments.push(c); this.newComment = ''; this.posting = false; this.reload(); },
      error: e => { this.posting = false; alert(apiError(e)); },
    });
  }
  changeStatus(t: TicketListItem, next: string): void {
    if (next === t.status) return;
    if (next === 'resolved') { this.resolving = t; this.note = ''; this.notifySchool = true; this.formError = ''; return; }
    this.api.setTicketStatus(t.id, next).subscribe({ next: () => { this.showToast(`${t.ticketNo} → ${statusLabel(next)}`); this.reload(); }, error: e => { alert(apiError(e)); this.reload(); } });
  }
  doResolve(): void {
    if (!this.resolving) return;
    if (!this.note.trim()) { this.formError = 'A resolution note is required.'; return; }
    this.saving = true;
    this.api.resolveTicket(this.resolving.id, this.note.trim(), this.notifySchool).subscribe({
      next: () => { this.saving = false; this.showToast(`${this.resolving!.ticketNo} resolved`); this.resolving = null; this.reload(); },
      error: e => { this.saving = false; this.formError = apiError(e); },
    });
  }
  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3500); }
}
