import { Component, OnInit, inject } from '@angular/core';
import { CurrencyPipe, DatePipe, DecimalPipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpErrorResponse } from '@angular/common/http';
import {
  SuperAdminApiService, statusBadge, statusLabel, priorityBadge,
  SchoolListItem, SchoolDetail, CreateSchoolResult, AdminCredentials, Plan, Subscription, Invoice, BillingSummary,
  TicketListItem, TicketDetail, PAYMENT_METHODS,
} from '../../core/super-admin-api.service';
import { environment } from '../../../environments/environment';
import { AuthService } from '../../core/auth.service';
import { IconComponent } from '../../shared/icon.component';
import { CredentialsDialogComponent } from '../../shared/credentials-dialog.component';
import { GeoPickerComponent, GeoValue } from '../../shared/geo-picker.component';

/** Local-time `yyyy-MM-dd` — `toISOString()` shifts the date either side of midnight. */
function isoDate(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}
function todayIso(): string { return isoDate(new Date()); }
function addDaysIso(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return isoDate(d);
}

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
          <div class="metric-value">{{ stats.monthlyRecurringRevenue | currency:'INR':'symbol':'1.0-0' }}</div>
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

/** Every field on the school onboarding form is mandatory. */
/**
 * The palettes a school may pick, with the two colours that identify each at a glance: the rail
 * itself and its active pill. Kept beside the form rather than fetched — they are design
 * decisions in styles.scss, not data.
 */
const SCHOOL_THEMES = [
  { key: 'classic', name: 'Classic', rail: '#ffffff',                              pill: '#4f46e5', note: 'The white masthead the product ships with' },
  { key: 'brand',   name: 'Brand',   rail: 'linear-gradient(160deg,#2563eb,#1d4ed8)', pill: '#ffffff', note: 'Royal blue masthead' },
  { key: 'forest',  name: 'Forest',  rail: 'linear-gradient(160deg,#154439,#10362f)', pill: '#0f9b76', note: 'Deep green — the traditional school colour' },
  { key: 'mist',    name: 'Mist',    rail: '#eef2f9',                              pill: '#2563eb', note: 'Pale blue-grey masthead' },
];

type SchoolFormField = 'name' | 'email' | 'phone' | 'address' | 'city' | 'state' | 'affiliationBoard' | 'status' | 'theme';

/** local-part@domain.tld — no spaces, no consecutive dots, TLD of 2+ letters. */
const EMAIL_RE = /^[A-Za-z0-9_%+-]+(\.[A-Za-z0-9_%+-]+)*@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$/;
/** Mobile numbers are stored as exactly 10 digits, no separators. */
const PHONE_RE = /^\d{10}$/;

/** Normalises a legacy number (`+977-981 234 5678`) into the 10-digit form the box accepts. */
function toTenDigits(phone: string | null | undefined): string {
  return (phone ?? '').replace(/\D/g, '').slice(-10);
}

const SCHOOL_FIELD_LABELS: Record<SchoolFormField, string> = {
  name: 'School name',
  email: 'Email',
  phone: 'Phone',
  address: 'Address',
  city: 'City',
  state: 'State / Province',
  affiliationBoard: 'Affiliation board',
  theme: 'Portal colour',
  status: 'Status',
};

@Component({
  selector: 'app-sa-schools',
  standalone: true,
  imports: [FormsModule, DecimalPipe, DatePipe, CurrencyPipe, CredentialsDialogComponent, GeoPickerComponent],
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
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>{{ s.name }}</h2><button class="modal-close" (click)="viewing = null">✕</button></div>
          <div class="modal-body">
            <div class="kv-row"><span class="kv-label">Tenant code</span><span class="kv-value">{{ s.schoolCode }}</span></div>
            <div class="kv-row"><span class="kv-label">Subdomain</span><span class="kv-value">{{ s.subdomain }}.edunexus.io</span></div>
            <div class="kv-row"><span class="kv-label">Email</span><span class="kv-value">{{ s.email }}</span></div>
            <div class="kv-row"><span class="kv-label">Phone</span><span class="kv-value">{{ s.phone }}</span></div>
            <div class="kv-row"><span class="kv-label">Address</span><span class="kv-value">{{ s.address || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">City</span><span class="kv-value">{{ s.city || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">State</span><span class="kv-value">{{ s.state || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Board</span><span class="kv-value">{{ s.affiliationBoard || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Status</span><span class="kv-value"><span class="badge" [class]="'badge ' + badge(s.status)">{{ label(s.status) }}</span></span></div>
            <div class="kv-row">
              <span class="kv-label">Subscription</span>
              <span class="kv-value">
                @if (s.planName) {
                  {{ s.planName }} · {{ s.billingCycle }} ·
                  <span class="badge" [class]="'badge ' + badge(s.subscriptionStatus || '')">{{ label(s.subscriptionStatus || '') }}</span>
                  until {{ s.subscriptionEndsOn | date:'mediumDate' }}
                } @else { No plan }
              </span>
            </div>
            <div class="kv-row"><span class="kv-label">Joined</span><span class="kv-value">{{ s.createdAt | date:'mediumDate' }}</span></div>

            <div class="kv-row"><span class="kv-label">Admin login</span><span class="kv-value">
              @if (s.adminUsername) { <code>{{ s.adminUsername }}</code> } @else { <span class="td-sub">No admin account</span> }
            </span></div>
            @if (s.adminUsername) {
              <div class="kv-row"><span class="kv-label">Password</span><span class="kv-value">
                @if (s.adminPassword) {
                  <code>{{ s.adminPassword }}</code>
                  <span class="td-sub"> — shared demo password</span>
                } @else {
                  <span class="td-sub">Stored as a one-way hash and cannot be shown.</span>
                }
              </span></div>
            }
          </div>
          <div class="modal-foot">
            @if (s.adminUsername) {
              <button class="btn btn-ghost" (click)="resetAdminPassword(s)" [disabled]="resetting">
                {{ resetting ? 'Resetting…' : 'Reset password' }}
              </button>
            }
            <button class="btn btn-ghost" (click)="viewing = null">Close</button>
            <button class="btn btn-primary" (click)="edit(s.id); viewing = null">Edit School</button>
          </div>
        </div>
      </div>
    }

    <!-- Create / edit modal -->
    @if (showForm) {
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>{{ editingId ? 'Edit School' : 'Onboard New School' }}</h2><button class="modal-close" (click)="closeForm()">✕</button></div>
          <div class="modal-body">
            <div class="field">
              <label>School name <span class="req">*</span></label>
              <input class="input" [class.invalid]="!!errors.name" [(ngModel)]="form.name" (ngModelChange)="revalidate('name')" />
              @if (errors.name) { <div class="field-error">{{ errors.name }}</div> }
            </div>
            <div class="field">
              <label>Address <span class="req">*</span></label>
              <input class="input" [class.invalid]="!!errors.address" [(ngModel)]="form.address"
                     (ngModelChange)="revalidate('address')" placeholder="Street, ward, landmark" />
              @if (errors.address) { <div class="field-error">{{ errors.address }}</div> }
            </div>
            <app-geo-picker [required]="true"
                            [invalidState]="!!errors.state" [invalidCity]="!!errors.city"
                            [countryId]="geo.countryId" [stateId]="geo.stateId" [cityId]="geo.cityId"
                            [country]="geo.country" [state]="form.state" [city]="form.city"
                            (changed)="applyPlace($event)" />
            @if (errors.city || errors.state) {
              <div class="field-error">{{ errors.city || errors.state }}</div>
            }
            <div class="form-row">
              <div class="field">
                <label>Email <span class="req">*</span></label>
                <input class="input" type="email" [class.invalid]="!!errors.email" [(ngModel)]="form.email" (ngModelChange)="revalidate('email')" />
                @if (errors.email) { <div class="field-error">{{ errors.email }}</div> }
              </div>
              <div class="field">
                <label>Phone <span class="req">*</span></label>
                <input #phoneBox class="input" type="tel" inputmode="numeric" maxlength="10" autocomplete="tel"
                       placeholder="10-digit mobile number" [class.invalid]="!!errors.phone"
                       [value]="form.phone" (input)="onPhoneInput(phoneBox)" (keypress)="blockNonDigit($event)" />
                @if (errors.phone) { <div class="field-error">{{ errors.phone }}</div> }
              </div>
            </div>
            <!--
              The school's own colours. Stored as a palette name rather than a hex value: each is
              a designed set — rail, hover, icon chip, active pill — that has to stay in step.
            -->
            <div class="field">
              <label>Portal colour</label>
              <div class="theme-picker">
                @for (t of themes; track t.key) {
                  <button type="button" class="theme-swatch" [class.on]="form.theme === t.key"
                          (click)="form.theme = t.key" [attr.aria-pressed]="form.theme === t.key"
                          [title]="t.note">
                    <span class="theme-chip" [style.background]="t.rail">
                      <span class="theme-pill" [style.background]="t.pill"></span>
                    </span>
                    <span class="theme-name">{{ t.name }}</span>
                  </button>
                }
              </div>
              <div class="field-hint">
                Applies to every portal at this school — admin, teacher and student alike.
              </div>
            </div>

            <div class="form-row">
              <div class="field">
                <label>Affiliation board <span class="req">*</span></label>
                <input class="input" [class.invalid]="!!errors.affiliationBoard" [(ngModel)]="form.affiliationBoard" (ngModelChange)="revalidate('affiliationBoard')" placeholder="NEB / CBSE" />
                @if (errors.affiliationBoard) { <div class="field-error">{{ errors.affiliationBoard }}</div> }
              </div>
              <div class="field">
                <label>Status <span class="req">*</span></label>
                <select class="select" [class.invalid]="!!errors.status" [(ngModel)]="form.status" (ngModelChange)="revalidate('status')">
                  <option value="active">Active</option>
                  <option value="suspended">Suspended</option>
                  <option value="terminated">Terminated</option>
                  <!-- Only for a legacy record that still carries the retired 'pending' state. -->
                  @if (form.status === 'pending') { <option value="pending">Pending</option> }
                </select>
                <div class="field-hint">Suspended and terminated schools cannot sign in.</div>
                @if (errors.status) { <div class="field-error">{{ errors.status }}</div> }
              </div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Subscription plan <span class="req">*</span></label>
                <select class="select" [class.invalid]="!!planError" [(ngModel)]="planId" (ngModelChange)="planError = ''">
                  <option [ngValue]="null">Select a plan…</option>
                  @for (p of plans; track p.id) {
                    <option [ngValue]="p.id">{{ p.name }} — {{ p.trialDays }}-day trial</option>
                  }
                </select>
                @if (planError) { <div class="field-error">{{ planError }}</div> }
                @if (editingId && !currentSubscription) {
                  <div class="field-hint">No plan yet — choosing one starts this school's subscription.</div>
                }
              </div>
              <div class="field">
                <label>Billing cycle <span class="req">*</span></label>
                <select class="select" [(ngModel)]="billingCycle">
                  <option value="yearly">Yearly</option>
                  <option value="monthly">Monthly</option>
                </select>
                @if (selectedPlan; as p) {
                  <div class="field-hint">
                    {{ (billingCycle === 'monthly' ? p.priceMonthly : p.priceYearly) | currency:'INR':'symbol':'1.0-0' }}
                    per {{ billingCycle === 'monthly' ? 'month' : 'year' }}@if (!currentSubscription) { after the trial }
                  </div>
                }
              </div>
            </div>
            @if (currentSubscription; as cur) {
              <div class="field-hint" style="margin-top:-6px;">
                Currently <strong>{{ cur.planName }}</strong> ·
                <span class="badge" [class]="'badge ' + badge(cur.subscriptionStatus || '')">{{ label(cur.subscriptionStatus || '') }}</span>
                until {{ cur.subscriptionEndsOn | date:'mediumDate' }}.
                Switching plans keeps this period and only re-locks the price.
              </div>
            }
            @if (formError) { <div class="field-error">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="closeForm()">Cancel</button>
            <button class="btn btn-primary" (click)="save()" [disabled]="saving">{{ saving ? 'Saving…' : (editingId ? 'Save Changes' : 'Create School') }}</button>
          </div>
        </div>
      </div>
    }

    <!-- Generated admin credentials — shown once, right after onboarding -->
    @if (credentials; as c) {
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>{{ c.schoolName }} is ready</h2></div>
          <div class="modal-body">
            <p class="cred-intro">
              An administrator login was created for this school. Copy it now —
              <strong>the password cannot be shown again</strong> once you close this dialog.
            </p>

            <div class="cred-box">
              <div class="cred-row">
                <span class="cred-label">Username</span>
                <code class="cred-value">{{ c.username }}</code>
                <button class="btn btn-ghost cred-copy" (click)="copy(c.username, 'Username')">Copy</button>
              </div>
              <div class="cred-row">
                <span class="cred-label">Password</span>
                <code class="cred-value">{{ c.temporaryPassword }}</code>
                <button class="btn btn-ghost cred-copy" (click)="copy(c.temporaryPassword, 'Password')">Copy</button>
              </div>
            </div>

            <div class="kv-row"><span class="kv-label">Admin name</span><span class="kv-value">{{ c.adminFullName }}</span></div>
            <div class="kv-row"><span class="kv-label">Email</span><span class="kv-value">{{ c.email }}</span></div>
            <div class="kv-row"><span class="kv-label">Tenant code</span><span class="kv-value">{{ c.schoolCode }}</span></div>
            <div class="kv-row"><span class="kv-label">Subdomain</span><span class="kv-value">{{ c.subdomain }}.edunexus.io</span></div>
            <div class="kv-row">
              <span class="kv-label">Plan</span>
              <span class="kv-value">
                {{ c.planName }}
                <span class="badge" [class]="'badge ' + badge(c.subscriptionStatus)">{{ label(c.subscriptionStatus) }}</span>
                until {{ c.subscriptionEndsOn | date:'mediumDate' }}
              </span>
            </div>

            <p class="cred-note">
              Send these to the school and ask them to change the password after their first sign-in.
              If they lose it, use <em>Forgot password</em> on the login page — it cannot be recovered from here.
            </p>
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="copyAll(c)">Copy all</button>
            <button class="btn btn-primary" (click)="credentials = null">I've saved these</button>
          </div>
        </div>
      </div>
    }

    @if (resetCredentials; as c) {
      <app-credentials-dialog
        title="New password issued"
        [fullName]="c.fullName"
        [username]="c.username"
        [password]="c.temporaryPassword"
        [email]="c.email"
        (copied)="showToast($event)"
        (closed)="resetCredentials = null" />
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
  styles: [`
    .cred-intro { font-size: 13px; color: var(--ink-2); margin: 0 0 14px; line-height: 1.55; }
    .cred-box { background: var(--neutral-tint); border: 1px solid var(--border); border-radius: 10px; padding: 6px 14px; margin-bottom: 16px; }
    .cred-row { display: flex; align-items: center; gap: 12px; padding: 10px 0; }
    .cred-row + .cred-row { border-top: 1px solid var(--border); }
    .cred-label { font-size: 12px; color: var(--muted); width: 78px; flex: 0 0 78px; }
    .cred-value { flex: 1; font-size: 15px; font-weight: 700; letter-spacing: 0.04em; word-break: break-all; }
    .cred-copy { padding: 4px 12px; font-size: 12px; }
    .cred-note { font-size: 12px; color: var(--muted); line-height: 1.55; margin: 14px 0 0; }
  `],
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
  submitted = false;
  formError = '';
  errors: Partial<Record<SchoolFormField, string>> = {};
  readonly themes = SCHOOL_THEMES;
  editingId: number | null = null;
  viewing: SchoolDetail | null = null;
  /** Held only until the super admin dismisses the dialog — never persisted anywhere. */
  credentials: CreateSchoolResult | null = null;
  toast = '';
  label = statusLabel;
  badge = statusBadge;
  form = this.empty();
  /** Plan + cycle live outside `form`, which is a all-strings record driving the shared validator. */
  plans: Plan[] = [];
  planId: number | null = null;
  billingCycle = 'yearly';
  planError = '';
  /** The subscription the edited school already has, or null when it has none / we are creating. */
  currentSubscription: SchoolDetail | null = null;
  /** A freshly reset admin password — held only until the dialog is dismissed. */
  resetCredentials: AdminCredentials | null = null;
  /** Geography ids chosen in the picker; null where the typed name matched nothing. */
  geo = { countryId: null as number | null, stateId: null as number | null, cityId: null as number | null, country: '' };

  /** Keeps `form.city`/`form.state` (which the shared validator checks) in step with the picker. */
  applyPlace(v: GeoValue): void {
    this.geo = { countryId: v.countryId, stateId: v.stateId, cityId: v.cityId, country: v.country };
    this.form.city = v.city;
    this.form.state = v.state;
    this.revalidate('city');
    this.revalidate('state');
  }

  resetting = false;
  private timer?: ReturnType<typeof setTimeout>;
  private searchTimer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void {
    this.reload();
    // Retired plans stay listed under Plans but must not be assignable to a new school.
    this.api.getPlans().subscribe({ next: p => this.plans = p.filter(x => x.isActive), error: () => {} });
  }

  get selectedPlan(): Plan | undefined {
    return this.plans.find(p => p.id === this.planId);
  }

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

  openForm(): void {
    this.editingId = null;
    this.form = this.empty();
    this.planId = null;
    this.billingCycle = 'yearly';
    this.currentSubscription = null;
    this.geo = { countryId: null, stateId: null, cityId: null, country: '' };
    this.resetValidation();
    this.showForm = true;
  }

  view(id: number): void {
    this.api.getSchool(id).subscribe({ next: s => this.viewing = s, error: e => alert(apiError(e)) });
  }

  /** Issues a new admin password. Irreversible for the school, so it asks first. */
  resetAdminPassword(s: SchoolDetail): void {
    if (!confirm(`Issue a new password for ${s.adminUsername}? Their current password stops working immediately.`)) return;
    this.resetting = true;
    this.api.resetSchoolAdminPassword(s.id).subscribe({
      next: c => { this.resetting = false; this.viewing = null; this.resetCredentials = c; },
      error: e => { this.resetting = false; alert(apiError(e)); },
    });
  }

  edit(id: number): void {
    this.api.getSchool(id).subscribe({
      next: s => {
        this.editingId = id;
        this.form = { name: s.name, email: s.email, phone: toTenDigits(s.phone), address: s.address ?? '', city: s.city ?? '', state: s.state ?? '', affiliationBoard: s.affiliationBoard ?? '', status: s.status, theme: s.theme || 'classic' };
        this.geo = { countryId: s.countryId, stateId: s.stateId, cityId: s.cityId, country: s.country ?? '' };
        this.planId = s.planId;
        this.billingCycle = s.billingCycle ?? 'yearly';
        this.currentSubscription = s.planId === null ? null : s;
        this.resetValidation();
        this.showForm = true;
      },
      error: e => alert(apiError(e)),
    });
  }

  /** Inline message for one field, or '' when it is valid. */
  private fieldError(key: SchoolFormField): string {
    const v = this.form[key].trim();
    if (!v) return `${SCHOOL_FIELD_LABELS[key]} is required.`;
    if (key === 'email' && !EMAIL_RE.test(v)) return 'Enter a valid email address (e.g. admin@school.edu).';
    if (key === 'phone' && !PHONE_RE.test(v)) return 'Phone must be exactly 10 digits.';
    return '';
  }

  /** Rejects non-digit keystrokes outright, so nothing else ever reaches the box. */
  blockNonDigit(e: KeyboardEvent): void {
    if (e.key.length === 1 && !e.ctrlKey && !e.metaKey && !/\d/.test(e.key)) e.preventDefault();
  }

  /**
   * Catches whatever the keypress guard cannot (paste, drag-drop, IME, autofill):
   * strips non-digits, caps at 10, and rewrites the DOM value so the box and the model agree.
   */
  onPhoneInput(el: HTMLInputElement): void {
    const digits = el.value.replace(/\D/g, '').slice(0, 10);
    if (el.value !== digits) {
      const caret = Math.max(0, (el.selectionStart ?? digits.length) - (el.value.length - digits.length));
      el.value = digits;
      el.setSelectionRange(caret, caret);
    }
    this.form.phone = digits;
    this.revalidate('phone');
  }

  /** Clears (or refreshes) a field's message as the user fixes it, once they have submitted. */
  revalidate(key: SchoolFormField): void {
    if (!this.submitted) return;
    const msg = this.fieldError(key);
    if (msg) this.errors[key] = msg; else delete this.errors[key];
  }

  save(): void {
    this.submitted = true;
    const keys = Object.keys(this.form) as SchoolFormField[];
    this.errors = {};
    for (const k of keys) {
      const msg = this.fieldError(k);
      if (msg) this.errors[k] = msg;
    }
    this.planError = this.planId === null ? 'Choose a subscription plan.' : '';
    if (Object.keys(this.errors).length || this.planError) { this.formError = ''; return; }
    this.saving = true;
    this.formError = '';
    const dto = { ...this.form };
    for (const k of keys) dto[k] = dto[k].trim();
    const done = (msg: string) => { this.saving = false; this.showForm = false; this.showToast(msg); this.reload(); };
    const fail = (e: unknown) => { this.saving = false; this.formError = apiError(e); };
    const withPlan = {
      ...dto, planId: this.planId!, billingCycle: this.billingCycle,
      countryId: this.geo.countryId, stateId: this.geo.stateId, cityId: this.geo.cityId,
    };
    if (this.editingId) {
      this.api.updateSchool(this.editingId, withPlan).subscribe({ next: () => done(`${dto.name} updated`), error: fail });
    } else {
      this.api.createSchool(withPlan).subscribe({
        // The generated password only exists in this response, so raise the dialog before anything else.
        next: res => { this.credentials = res; done(`${dto.name} onboarded`); },
        error: fail,
      });
    }
  }

  /** Copies to the clipboard, falling back to a prompt on browsers that block the async API. */
  copy(text: string, label: string): void {
    navigator.clipboard?.writeText(text).then(
      () => this.showToast(`${label} copied`),
      () => prompt(`Copy ${label.toLowerCase()}:`, text),
    ) ?? prompt(`Copy ${label.toLowerCase()}:`, text);
  }

  copyAll(c: CreateSchoolResult): void {
    this.copy(
      [`School: ${c.schoolName} (${c.schoolCode})`,
       `Portal: ${c.subdomain}.edunexus.io`,
       `Username: ${c.username}`,
       `Password: ${c.temporaryPassword}`,
       'Please change this password after your first sign-in.'].join('\n'),
      'Credentials');
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

  closeForm(): void { this.showForm = false; this.editingId = null; this.resetValidation(); }
  private resetValidation(): void { this.submitted = false; this.errors = {}; this.formError = ''; this.planError = ''; }
  showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3500); }
  private empty(): Record<SchoolFormField, string> {
    return { name: '', email: '', phone: '', address: '', city: '', state: '', affiliationBoard: '', status: 'active', theme: 'classic' };
  }
}

/* =====================  PLANS  ===================== */

/** Fields the plan form validates; keys of the inline error map. */
type PlanField = 'name' | 'priceMonthly' | 'priceYearly' | 'maxStudents' | 'trialDays';

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
            <thead><tr><th>Plan</th><th class="num">Monthly</th><th class="num">Yearly</th><th class="num">Trial</th><th class="num">Max Students</th><th class="num">Schools</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              @for (p of plans; track p.id) {
                <tr>
                  <td>
                    <div class="td-main">{{ p.name }}</div>
                    <div class="td-sub" style="white-space: normal; max-width: 320px;">{{ p.description }}</div>
                  </td>
                  <td class="num">{{ p.priceMonthly | currency:'INR':'symbol':'1.0-0' }}</td>
                  <td class="num">{{ p.priceYearly | currency:'INR':'symbol':'1.0-0' }}</td>
                  <td class="num">{{ p.trialDays > 0 ? p.trialDays + ' days' : 'None' }}</td>
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
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>{{ p.name }} Plan</h2><button class="modal-close" (click)="view = null">✕</button></div>
          <div class="modal-body">
            <div class="kv-row"><span class="kv-label">Description</span><span class="kv-value">{{ p.description || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Monthly</span><span class="kv-value">{{ p.priceMonthly | currency:'INR' }}</span></div>
            <div class="kv-row"><span class="kv-label">Yearly</span><span class="kv-value">{{ p.priceYearly | currency:'INR' }}</span></div>
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
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>{{ editingId ? 'Edit Plan' : 'Create Plan' }}</h2><button class="modal-close" (click)="showForm = false">✕</button></div>
          <div class="modal-body">
            <div class="field">
              <label>Plan name <span class="req">*</span></label>
              <input class="input" [class.invalid]="!!errors.name" [(ngModel)]="form.name"
                     (ngModelChange)="clearError('name')" [disabled]="!!editingId" />
              @if (errors.name) { <div class="field-error">{{ errors.name }}</div> }
            </div>
            <div class="field"><label>Description</label><input class="input" [(ngModel)]="form.description" /></div>
            <div class="form-row">
              <div class="field">
                <label>Monthly price (₹) <span class="req">*</span></label>
                <input class="input" type="number" min="0" [class.invalid]="!!errors.priceMonthly"
                       [ngModel]="form.priceMonthly" (ngModelChange)="onMonthlyChange($event)" />
                @if (errors.priceMonthly) { <div class="field-error">{{ errors.priceMonthly }}</div> }
              </div>
              <div class="field">
                <label>Yearly price (₹) <span class="req">*</span></label>
                <input class="input" type="number" min="0" [class.invalid]="!!errors.priceYearly"
                       [ngModel]="form.priceYearly" (ngModelChange)="onYearlyChange($event)" />
                @if (errors.priceYearly) { <div class="field-error">{{ errors.priceYearly }}</div> }
              </div>
            </div>
            <div class="field-hint" style="margin: -6px 0 12px;">
              Yearly is {{ YEARLY_MULTIPLIER }}× monthly ({{ 12 - YEARLY_MULTIPLIER }} months free) — editing either one recalculates the other.
            </div>
            <div class="form-row">
              <div class="field">
                <label>Max students (blank = unlimited)</label>
                <input class="input" type="number" min="1" [class.invalid]="!!errors.maxStudents"
                       [(ngModel)]="form.maxStudents" (ngModelChange)="clearError('maxStudents')" />
                @if (errors.maxStudents) { <div class="field-error">{{ errors.maxStudents }}</div> }
              </div>
              <div class="field">
                <label>Trial days <span class="req">*</span></label>
                <input class="input" type="number" min="0" [class.invalid]="!!errors.trialDays"
                       [(ngModel)]="form.trialDays" (ngModelChange)="clearError('trialDays')" />
                @if (errors.trialDays) { <div class="field-error">{{ errors.trialDays }}</div> }
              </div>
            </div>
            @if (formError) { <div class="field-error">{{ formError }}</div> }
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
  /** Inline per-field messages, keyed by form field. */
  errors: Partial<Record<PlanField, string>> = {};
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
  openForm(): void { this.editingId = null; this.form = this.empty(); this.resetValidation(); this.showForm = true; }
  edit(p: Plan): void {
    this.editingId = p.id;
    this.form = { name: p.name, description: p.description ?? '', priceMonthly: p.priceMonthly, priceYearly: p.priceYearly, maxStudents: p.maxStudents, trialDays: p.trialDays };
    this.resetValidation(); this.showForm = true;
  }

  clearError(field: PlanField): void { delete this.errors[field]; }
  private resetValidation(): void { this.errors = {}; this.formError = ''; }

  /** Every rule for the plan form in one place, so the messages land on their own fields. */
  private validate(): boolean {
    const e: Partial<Record<PlanField, string>> = {};
    if (!this.form.name.trim()) e.name = 'Plan name is required.';
    const monthly = Number(this.form.priceMonthly);
    const yearly = Number(this.form.priceYearly);
    if (this.form.priceMonthly === null || isNaN(monthly)) e.priceMonthly = 'Monthly price is required.';
    else if (monthly <= 0) e.priceMonthly = 'Monthly price must be greater than zero.';
    if (this.form.priceYearly === null || isNaN(yearly)) e.priceYearly = 'Yearly price is required.';
    else if (yearly <= 0) e.priceYearly = 'Yearly price must be greater than zero.';
    const max = this.form.maxStudents;
    if (max !== null && (max as unknown as string) !== '' && Number(max) < 1)
      e.maxStudents = 'Leave blank for unlimited, or enter 1 or more.';
    const trial = Number(this.form.trialDays);
    if (this.form.trialDays === null || isNaN(trial) || trial < 0) e.trialDays = 'Enter 0 or more trial days.';
    this.errors = e;
    return Object.keys(e).length === 0;
  }

  save(): void {
    this.formError = '';
    if (!this.validate()) return;
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
  /**
   * Yearly is priced at ten months, i.e. two months free — the ratio every existing plan uses.
   * Editing one price derives the other; each handler only ever writes the opposite field, so
   * the two bindings cannot bounce off each other.
   */
  readonly YEARLY_MULTIPLIER = 10;

  onMonthlyChange(value: number | null): void {
    this.form.priceMonthly = value;
    if (value === null || value === undefined || value < 0 || isNaN(Number(value))) return;
    this.form.priceYearly = Math.round(Number(value) * this.YEARLY_MULTIPLIER);
  }

  onYearlyChange(value: number | null): void {
    this.form.priceYearly = value;
    if (value === null || value === undefined || value < 0 || isNaN(Number(value))) return;
    this.form.priceMonthly = Math.round(Number(value) / this.YEARLY_MULTIPLIER);
  }

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
                  <td class="num">{{ s.price | currency:'INR':'symbol':'1.0-0' }}</td>
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

/** A school plus its subscription and most recent invoice — one row of the billing table. */
interface BillingRow {
  school: SchoolListItem;
  sub?: Subscription;
  latest?: Invoice;
  open?: Invoice;
  count: number;
}

@Component({
  selector: 'app-sa-billing',
  standalone: true,
  imports: [FormsModule, CurrencyPipe, DatePipe],
  template: `
    <div class="page-head">
      <div class="grow"><h1>Billing &amp; Payments</h1><div class="page-sub">Platform revenue from subscriptions</div></div>
      <button class="btn btn-primary" (click)="openRaise()">+ Raise Invoice</button>
    </div>

    @if (summary) {
      <div class="stat-grid">
        <div class="stat-tile"><div class="stat-label">Collected</div><div class="stat-value">{{ summary.collected | currency:'INR':'symbol':'1.0-0' }}</div><div class="stat-sub up">{{ summary.paidCount }} paid</div></div>
        <div class="stat-tile"><div class="stat-label">Outstanding</div><div class="stat-value">{{ summary.outstanding | currency:'INR':'symbol':'1.0-0' }}</div><div class="stat-sub">{{ summary.sentCount }} awaiting</div></div>
        <div class="stat-tile"><div class="stat-label">Overdue</div><div class="stat-value">{{ summary.overdue | currency:'INR':'symbol':'1.0-0' }}</div><div class="stat-sub down">{{ summary.overdueCount }} past due</div></div>
      </div>
    }

    <!-- One row per school: subscription and its latest invoice merged into a single table -->
    <div class="card">
      <div class="card-head filters">
        <h2 class="grow">Schools &amp; Invoices</h2>
        <span class="td-sub">{{ displayedRows.length }} of {{ schoolRows.length }} schools · {{ awaitingInvoice }} not yet invoiced</span>
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
            <thead>
              <tr>
                <th>School</th><th>Plan</th><th>Subscription</th><th>Invoice #</th>
                <th class="num">Amount</th><th>Issued</th><th>Due</th><th>Status</th><th>Actions</th>
              </tr>
            </thead>
            <tbody>
              @for (r of displayedRows; track r.school.id) {
                <tr>
                  <td><div class="td-main">{{ r.school.name }}</div><div class="td-sub">{{ r.school.schoolCode }}</div></td>
                  <td>{{ r.sub?.planName || '—' }}</td>
                  <td>
                    @if (r.sub) {
                      <span class="badge" [class]="'badge ' + badge(r.sub.status)">{{ label(r.sub.status) }}</span>
                      <div class="td-sub">{{ label(r.sub.billingCycle) }}</div>
                    } @else { <span class="td-sub">no subscription</span> }
                  </td>
                  <td>
                    <div class="td-sub">{{ r.latest?.invoiceNo || '—' }}</div>
                    @if (r.count > 1) { <div class="td-sub">+{{ r.count - 1 }} earlier</div> }
                  </td>
                  <td class="num">{{ r.latest ? (r.latest.totalAmount | currency:'INR':'symbol':'1.0-0') : '—' }}</td>
                  <td class="td-sub">{{ r.latest?.issuedAt ? (r.latest!.issuedAt | date:'mediumDate') : '—' }}</td>
                  <td>
                    <div class="td-sub">{{ r.latest ? (r.latest.dueDate | date:'mediumDate') : '—' }}</div>
                    @if (r.latest?.remindedAt) { <div class="td-sub" style="color: var(--info-text);">✉ reminded</div> }
                  </td>
                  <td>
                    @if (r.latest) { <span class="badge" [class]="'badge ' + badge(r.latest.status)">{{ label(r.latest.status) }}</span> }
                    @else { <span class="badge neutral">No invoice</span> }
                  </td>
                  <td>
                    <div class="row-actions">
                      @if (r.open) {
                        <button class="icon-action success" (click)="openPay(r.open!)" title="Record payment">
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="5" width="20" height="14" rx="2"/><line x1="2" y1="10" x2="22" y2="10"/></svg>
                        </button>
                        <button class="icon-action primary" (click)="remind(r.open!)" title="Send reminder">
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="M2 7l10 6 10-6"/></svg>
                        </button>
                      } @else if (r.sub) {
                        <button class="icon-action primary" (click)="openRaise(r.school.id)" title="Raise invoice">
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="12" y1="12" x2="12" y2="18"/><line x1="9" y1="15" x2="15" y2="15"/></svg>
                        </button>
                      } @else { <span class="td-sub">—</span> }
                    </div>
                  </td>
                </tr>
              } @empty {
                <tr><td colspan="9"><div class="empty">No schools match.</div></td></tr>
              }
            </tbody>
          </table>
        </div>
      }
    </div>

    <!-- Raise invoice -->
    @if (raising) {
      <div class="modal-backdrop">
        <div class="modal" style="max-width: 520px;">
          <div class="modal-head"><h2>Raise Invoice</h2><button class="modal-close" (click)="raising = false">✕</button></div>
          <div class="modal-body">
            <div class="field">
              <label>School <span class="req">*</span></label>
              <select class="select" [class.invalid]="!!raiseErrors.schoolId"
                      [(ngModel)]="raiseForm.schoolId" (ngModelChange)="onRaiseSchoolChange()">
                <option [ngValue]="0">Select a school…</option>
                @for (s of subs; track s.id) {
                  <option [ngValue]="s.schoolId">{{ s.schoolName }} — {{ s.planName }} ({{ label(s.status) }})</option>
                }
              </select>
              @if (raiseErrors.schoolId) { <div class="field-error">{{ raiseErrors.schoolId }}</div> }
              <div class="field-hint">Only schools with a subscription can be invoiced.</div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Amount (₹) <span class="req">*</span></label>
                <input class="input" type="number" min="0" [class.invalid]="!!raiseErrors.amount"
                       [(ngModel)]="raiseForm.amount" (ngModelChange)="raiseErrors.amount = ''" />
                @if (raiseErrors.amount) { <div class="field-error">{{ raiseErrors.amount }}</div> }
              </div>
              <div class="field">
                <label>Due date <span class="req">*</span></label>
                <input class="input" type="date" [class.invalid]="!!raiseErrors.due"
                       [(ngModel)]="raiseForm.due" (ngModelChange)="raiseErrors.due = ''" />
                @if (raiseErrors.due) { <div class="field-error">{{ raiseErrors.due }}</div> }
              </div>
            </div>
            @if (formError) { <div class="field-error">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="raising = false">Cancel</button>
            <button class="btn btn-primary" (click)="saveRaise()" [disabled]="saving">{{ saving ? 'Raising…' : 'Raise Invoice' }}</button>
          </div>
        </div>
      </div>
    }

    @if (paying; as inv) {
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>Record Payment — {{ inv.invoiceNo }}</h2><button class="modal-close" (click)="paying = null">✕</button></div>
          <div class="modal-body">
            <div class="kv-row"><span class="kv-label">School</span><span class="kv-value">{{ inv.schoolName }}</span></div>
            <div class="kv-row" style="margin-bottom:12px;"><span class="kv-label">Amount</span><span class="kv-value">{{ inv.totalAmount | currency:'INR' }}</span></div>
            <div class="form-row">
              <div class="field">
                <label>Amount received (₹) <span class="req">*</span></label>
                <input class="input" type="number" min="0" [class.invalid]="!!payErrors.amount"
                       [(ngModel)]="payForm.amount" (ngModelChange)="payErrors.amount = ''" />
                @if (payErrors.amount) { <div class="field-error">{{ payErrors.amount }}</div> }
              </div>
              <div class="field">
                <label>Payment date <span class="req">*</span></label>
                <input class="input" type="date" [class.invalid]="!!payErrors.date"
                       [(ngModel)]="payForm.date" (ngModelChange)="payErrors.date = ''" />
                @if (payErrors.date) { <div class="field-error">{{ payErrors.date }}</div> }
              </div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Method <span class="req">*</span></label>
                <select class="select" [(ngModel)]="payForm.method" (ngModelChange)="onMethodChange()">
                  @for (m of methods; track m.value) { <option [value]="m.value">{{ m.label }}</option> }
                </select>
              </div>
              <div class="field">
                <label>Reference</label>
                <input class="input" [(ngModel)]="payForm.ref" [placeholder]="refPlaceholder" />
              </div>
            </div>

            <!-- Bank transfers are unreconcilable without the bank, so it is asked for and required. -->
            @if (payForm.method === 'bank_transfer') {
              <div class="field">
                <label>Bank name <span class="req">*</span></label>
                <input class="input" [class.invalid]="!!payErrors.bankName" [(ngModel)]="payForm.bankName"
                       (ngModelChange)="payErrors.bankName = ''" placeholder="e.g. Nabil Bank" />
                @if (payErrors.bankName) { <div class="field-error">{{ payErrors.bankName }}</div> }
              </div>
            }

            <div class="field">
              <label>Payment screenshot</label>
              @if (proof) {
                <div class="proof-chip">
                  <span class="proof-name">{{ proof.fileName }}</span>
                  <a class="proof-view" [href]="proofHref" target="_blank" rel="noopener">View</a>
                  <button type="button" class="proof-remove" (click)="clearProof()" aria-label="Remove">✕</button>
                </div>
              } @else {
                <input class="input" type="file" accept="image/png,image/jpeg,image/webp,application/pdf"
                       (change)="onProofPicked($event)" [disabled]="uploading" />
                <div class="field-hint">{{ uploading ? 'Uploading…' : 'PNG, JPG, WEBP or PDF · up to 5 MB' }}</div>
              }
            </div>

            @if (formError) { <div class="field-error">{{ formError }}</div> }
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
  payForm = { amount: 0, date: todayIso(), method: 'bank_transfer', ref: '', bankName: '' };
  /** Inline messages for the two billing modals. */
  payErrors: { amount?: string; date?: string; bankName?: string } = {};
  raiseErrors: { schoolId?: string; amount?: string; due?: string } = {};
  readonly methods = PAYMENT_METHODS;
  /** Uploaded screenshot, held until the payment itself is saved. */
  proof: { url: string; fileName: string } | null = null;
  uploading = false;
  /** Subscriptions back the school picker — a school without one cannot be invoiced. */
  subs: Subscription[] = [];
  schools: SchoolListItem[] = [];
  raising = false;
  raiseForm = { schoolId: 0, amount: 0, due: '' };
  label = statusLabel;
  badge = statusBadge;
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void { this.reload(); }

  search(): void { this.appliedFrom = this.fromDate; this.appliedTo = this.toDate; }
  clearDates(): void { this.fromDate = ''; this.toDate = ''; this.appliedFrom = ''; this.appliedTo = ''; }

  reload(): void {
    this.api.getBillingSummary().subscribe({ next: s => this.summary = s, error: () => {} });
    this.api.getSubscriptions().subscribe({ next: s => this.subs = s, error: () => this.subs = [] });
    this.api.getSchools().subscribe({ next: s => this.schools = s, error: () => this.schools = [] });
    this.api.getInvoices().subscribe({
      next: i => { this.invoices = i; this.loading = false; this.error = ''; },
      error: e => { this.error = apiError(e); this.loading = false; },
    });
  }

  /**
   * One row per school, including schools that have never been invoiced — which is the point:
   * an invoice-only list hides exactly the tenants that still need billing. Each row carries the
   * school's subscription and its most recent invoice, so both tables fit in one grid.
   */
  get schoolRows(): BillingRow[] {
    return this.schools.map(school => {
      const mine = this.invoices.filter(i => i.schoolId === school.id);
      return {
        school,
        sub: this.subs.find(s => s.schoolId === school.id),
        latest: mine[0],   // the API returns newest first
        open: mine.find(i => i.status === 'sent' || i.status === 'overdue' || i.status === 'draft'),
        count: mine.length,
      };
    });
  }

  /** Date filter applies to the latest invoice; an un-invoiced school drops out once one is set. */
  get displayedRows(): BillingRow[] {
    if (!this.appliedFrom && !this.appliedTo) return this.schoolRows;
    return this.schoolRows.filter(r => {
      const d = (r.latest?.issuedAt ?? '').slice(0, 10);
      if (!d) return false;
      if (this.appliedFrom && d < this.appliedFrom) return false;
      if (this.appliedTo && d > this.appliedTo) return false;
      return true;
    });
  }

  get awaitingInvoice(): number { return this.schoolRows.filter(r => !r.latest).length; }

  openRaise(schoolId = 0): void {
    this.formError = '';
    this.raiseErrors = {};
    this.raiseForm = { schoolId, amount: 0, due: addDaysIso(14) };
    if (schoolId) this.onRaiseSchoolChange();
    this.raising = true;
  }

  /** Prefills the amount with the price locked into that school's subscription. */
  onRaiseSchoolChange(): void {
    const sub = this.subs.find(s => s.schoolId === Number(this.raiseForm.schoolId));
    this.raiseForm.amount = sub?.price ?? 0;
  }

  saveRaise(): void {
    const e: typeof this.raiseErrors = {};
    if (!this.raiseForm.schoolId) e.schoolId = 'Choose a school.';
    if (!this.raiseForm.amount || Number(this.raiseForm.amount) <= 0) e.amount = 'Enter an amount greater than zero.';
    if (!this.raiseForm.due) e.due = 'Due date is required.';
    this.raiseErrors = e;
    this.formError = '';
    if (Object.keys(e).length) return;
    this.saving = true;
    this.api.raiseInvoice({
      schoolId: Number(this.raiseForm.schoolId),
      amount: Number(this.raiseForm.amount),
      dueDate: this.raiseForm.due || null,
    }).subscribe({
      next: inv => { this.saving = false; this.raising = false; this.showToast(`${inv.invoiceNo} raised for ${inv.schoolName}`); this.reload(); },
      error: e => { this.saving = false; this.formError = apiError(e); },
    });
  }

  openPay(i: Invoice): void {
    this.paying = i;
    this.formError = '';
    this.payErrors = {};
    this.proof = null;
    this.uploading = false;
    this.payForm = { amount: i.totalAmount, date: todayIso(), method: 'bank_transfer', ref: '', bankName: '' };
  }

  /** Bank name only applies to a transfer; drop it so a stale value cannot be submitted. */
  onMethodChange(): void {
    this.payErrors.bankName = '';
    if (this.payForm.method !== 'bank_transfer') this.payForm.bankName = '';
  }

  /** Hints at what a reference means for the chosen method. */
  get refPlaceholder(): string {
    switch (this.payForm.method) {
      case 'bank_transfer': return 'Transaction / UTR number';
      case 'upi': return 'UPI transaction ID';
      case 'debit_card':
      case 'credit_card': return 'Auth code or last 4 digits';
      default: return 'Receipt number';
    }
  }

  /** Absolute URL for the stored screenshot — the API returns a path rooted at its own host. */
  get proofHref(): string { return this.proof ? environment.apiBaseUrl.replace(/\/api$/, '') + this.proof.url : ''; }

  onProofPicked(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    if (file.size > 5 * 1024 * 1024) { this.formError = 'The screenshot must be 5 MB or smaller.'; input.value = ''; return; }
    this.uploading = true;
    this.formError = '';
    this.api.uploadPaymentProof(file).subscribe({
      next: r => { this.proof = r; this.uploading = false; },
      error: e => { this.uploading = false; this.formError = apiError(e); input.value = ''; },
    });
  }

  clearProof(): void { this.proof = null; }
  savePay(): void {
    if (!this.paying) return;
    const e: typeof this.payErrors = {};
    if (!this.payForm.amount || Number(this.payForm.amount) <= 0) e.amount = 'Enter an amount greater than zero.';
    if (!this.payForm.date) e.date = 'Payment date is required.';
    if (this.payForm.method === 'bank_transfer' && !this.payForm.bankName.trim())
      e.bankName = 'Bank name is required for a bank transfer.';
    this.payErrors = e;
    this.formError = '';
    if (Object.keys(e).length) return;
    if (this.uploading) { this.formError = 'Wait for the screenshot to finish uploading.'; return; }
    this.saving = true;
    this.api.recordPayment(this.paying.id, {
      amount: Number(this.payForm.amount), method: this.payForm.method,
      bankName: this.payForm.bankName.trim() || null,
      transactionRef: this.payForm.ref.trim() || null,
      proofUrl: this.proof?.url ?? null,
      paidAt: this.payForm.date,
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
      <div class="modal-backdrop">
        <div class="modal">
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
              <label>Add a comment (visible to {{ t.schoolName }}) <span class="req">*</span></label>
              <textarea class="input" rows="3" [class.invalid]="!!commentError" [(ngModel)]="newComment"
                        (ngModelChange)="commentError = ''"></textarea>
              @if (commentError) { <div class="field-error">{{ commentError }}</div> }
            </div>
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="detail = null">Close</button>
            <button class="btn btn-primary" (click)="postComment()" [disabled]="posting">{{ posting ? 'Posting…' : 'Post Comment' }}</button>
          </div>
        </div>
      </div>
    }

    <!-- Resolve modal -->
    @if (resolving; as t) {
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>Resolve {{ t.ticketNo }}</h2><button class="modal-close" (click)="resolving = null">✕</button></div>
          <div class="modal-body">
            <div class="field">
              <label>Resolution note <span class="req">*</span></label>
              <textarea class="input" rows="4" [class.invalid]="!!noteError" [(ngModel)]="note"
                        (ngModelChange)="noteError = ''" placeholder="What was done to resolve this?"></textarea>
              @if (noteError) { <div class="field-error">{{ noteError }}</div> }
            </div>
            <div class="field"><label style="display:flex;align-items:center;gap:8px;font-weight:500;"><input type="checkbox" [(ngModel)]="notifySchool" /> Email resolution to the school</label></div>
            @if (formError) { <div class="field-error">{{ formError }}</div> }
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
  commentError = '';
  note = '';
  noteError = '';
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
    this.commentError = '';
    this.api.getTicket(t.id).subscribe({ next: d => this.detail = d, error: e => alert(apiError(e)) });
  }
  postComment(): void {
    if (!this.detail) return;
    if (!this.newComment.trim()) { this.commentError = 'Write a comment before posting.'; return; }
    this.commentError = '';
    this.posting = true;
    this.api.addComment(this.detail.id, this.actingUserId, this.newComment.trim()).subscribe({
      next: c => { this.detail!.comments.push(c); this.newComment = ''; this.posting = false; this.reload(); },
      error: e => { this.posting = false; alert(apiError(e)); },
    });
  }
  changeStatus(t: TicketListItem, next: string): void {
    if (next === t.status) return;
    if (next === 'resolved') { this.resolving = t; this.note = ''; this.noteError = ''; this.notifySchool = true; this.formError = ''; return; }
    this.api.setTicketStatus(t.id, next).subscribe({ next: () => { this.showToast(`${t.ticketNo} → ${statusLabel(next)}`); this.reload(); }, error: e => { alert(apiError(e)); this.reload(); } });
  }
  doResolve(): void {
    if (!this.resolving) return;
    if (!this.note.trim()) { this.noteError = 'A resolution note is required.'; return; }
    this.noteError = '';
    this.saving = true;
    this.api.resolveTicket(this.resolving.id, this.note.trim(), this.notifySchool).subscribe({
      next: () => { this.saving = false; this.showToast(`${this.resolving!.ticketNo} resolved`); this.resolving = null; this.reload(); },
      error: e => { this.saving = false; this.formError = apiError(e); },
    });
  }
  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3500); }
}
