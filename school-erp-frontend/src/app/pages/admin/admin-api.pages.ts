import { Component, OnInit, inject } from '@angular/core';
import { DecimalPipe, DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Subscription } from 'rxjs';
import {
  AdminApiService, adminApiError, statusLabel, statusBadge,
  AdminDashboard, StudentListItem, StudentDetail, SaveStudent,
  TeacherListItem, TeacherDetail, SaveTeacher, ClassDto, SectionDto, NoticeDto,
  ClassCurriculum, ClassSubjectOption, AssignmentRow, AssignmentCell,
  CreateStudentResult, CreateTeacherResult,
} from '../../core/admin-api.service';
import { AutocompleteComponent } from '../../shared/autocomplete.component';
import { DigitsOnlyDirective } from '../../shared/digits-only.directive';
import { FieldErrors, isValidPhone, isValidPincode, isValidEmail } from '../../shared/field-errors';
import { GeoPickerComponent, GeoValue } from '../../shared/geo-picker.component';
import { CredentialsDialogComponent } from '../../shared/credentials-dialog.component';
import { AuthService } from '../../core/auth.service';
import { currentMonthRange } from './admin-txn.pages';
import { IconComponent } from '../../shared/icon.component';
import { TrendChartComponent, DonutChartComponent, TrendPoint, DonutSlice } from '../../shared/charts.component';

/* =====================  DASHBOARD  ===================== */

@Component({
  selector: 'app-ad-dashboard',
  standalone: true,
  imports: [DecimalPipe, DatePipe, IconComponent, TrendChartComponent, DonutChartComponent],
  template: `
    <div class="dash-hero">
      <h1>{{ d?.schoolName || 'Dashboard' }}</h1>
      <p>@if (d?.academicYear) { Academic Year {{ d?.academicYear }} · }Here's what's happening in your school today.</p>
      <div class="hero-badge"><span class="live-dot"></span> {{ today | date:'MMM d, y' }}</div>
    </div>

    @if (loading) { <div class="card"><div class="empty">Loading…</div></div> }
    @else if (error) { <div class="card"><div class="empty">{{ error }}</div></div> }
    @else if (d) {
      <!-- Headline figures -->
      <div class="metric-grid">
        <div class="metric-card">
          <div class="metric-top"><div class="icon-badge blue"><app-icon name="users" [size]="24" /></div></div>
          <div class="metric-value">{{ d.totalStudents | number }}</div>
          <div class="metric-label">Total Students</div>
          <div class="metric-sub">active enrolment</div>
        </div>
        <div class="metric-card">
          <div class="metric-top">
            <div class="icon-badge green"><app-icon name="teacher" [size]="24" /></div>
            @if (d.teachersOnLeave > 0) { <span class="metric-pill warn">{{ d.teachersOnLeave }} on leave</span> }
          </div>
          <div class="metric-value">{{ d.totalTeachers | number }}</div>
          <div class="metric-label">Total Teachers</div>
          <div class="metric-sub">teaching staff</div>
        </div>
        <div class="metric-card">
          <div class="metric-top"><div class="icon-badge violet"><app-icon name="layers" [size]="24" /></div></div>
          <div class="metric-value">{{ d.totalClasses | number }}</div>
          <div class="metric-label">Total Classes</div>
          <div class="metric-sub">{{ d.totalSections | number }} sections</div>
        </div>
        <div class="metric-card">
          <div class="metric-top">
            <div class="icon-badge amber"><app-icon name="money" [size]="24" /></div>
            @if (d.feesBilled > 0) { <span class="metric-pill good">{{ collectionRate }}% collected</span> }
          </div>
          <div class="metric-value">₹{{ d.feesCollected | number:'1.0-0' }}</div>
          <div class="metric-label">Fees Collected</div>
          <div class="metric-sub">of ₹{{ d.feesBilled | number:'1.0-0' }} billed</div>
        </div>
      </div>

      <!-- Secondary figures -->
      <div class="stat-grid">
        <div class="stat-tile">
          <div class="stat-label">Attendance Today</div>
          <div class="stat-value">{{ d.attendanceToday === null ? '—' : (d.attendanceToday | number:'1.0-1') + '%' }}</div>
          <div class="stat-sub" [class.up]="(d.attendanceToday ?? 0) >= 90" [class.down]="d.attendanceToday !== null && d.attendanceToday < 75">
            {{ d.attendanceToday === null ? 'not marked yet' : 'present across the school' }}
          </div>
        </div>
        <div class="stat-tile">
          <div class="stat-label">Fees Outstanding</div>
          <div class="stat-value">₹{{ outstanding | number:'1.0-0' }}</div>
          <div class="stat-sub" [class.down]="outstanding > 0">{{ d.unpaidInvoices }} open invoices</div>
        </div>
        <div class="stat-tile">
          <div class="stat-label">Overdue</div>
          <div class="stat-value">₹{{ d.feesOverdue | number:'1.0-0' }}</div>
          <div class="stat-sub" [class.down]="d.feesOverdue > 0">past the due date</div>
        </div>
        <div class="stat-tile">
          <div class="stat-label">Avg Attendance</div>
          <div class="stat-value">{{ avgAttendance === null ? '—' : (avgAttendance | number:'1.0-1') + '%' }}</div>
          <div class="stat-sub">last {{ d.attendanceTrend.length }} marked days</div>
        </div>
      </div>

      <!-- Charts -->
      <div class="grid-2">
        <div class="card">
          <div class="card-head">
            <h2 class="grow">Attendance Overview</h2>
            <span class="td-sub">last {{ d.attendanceTrend.length }} marked days</span>
          </div>
          <div class="card-body">
            <app-trend-chart [points]="trendPoints" ariaLabel="School-wide attendance percentage over the last 30 days" />
          </div>
        </div>

        <div class="card">
          <div class="card-head">
            <h2 class="grow">Fees Collection</h2>
            <span class="td-sub">₹{{ d.feesBilled | number:'1.0-0' }} billed</span>
          </div>
          <div class="card-body">
            @if (d.feesBilled > 0) {
              <app-donut-chart [slices]="feeSlices" prefix="₹"
                               [centerValue]="'₹' + (d.feesCollected | number:'1.0-0')" centerLabel="Collected"
                               ariaLabel="Fee collection split between collected, pending and overdue" />
            } @else {
              <div class="empty">No invoices raised yet.</div>
            }
          </div>
        </div>
      </div>

      <div class="grid-2">
        <div class="card">
          <div class="card-head"><h2 class="grow">Recent Admissions</h2></div>
          <div class="table-wrap">
            <table class="data-table">
              <thead><tr><th>Student</th><th>Class</th><th>Date</th></tr></thead>
              <tbody>
                @for (a of d.recentAdmissions; track $index) {
                  <tr><td class="td-main">{{ a.name }}</td><td>{{ a.className }}-{{ a.sectionName }}</td><td class="td-sub">{{ a.admissionDate | date:'mediumDate' }}</td></tr>
                } @empty { <tr><td colspan="3"><div class="empty">No recent admissions.</div></td></tr> }
              </tbody>
            </table>
          </div>
        </div>

        <div class="card">
          <div class="card-head"><h2 class="grow">Latest Notices</h2></div>
          @for (n of d.latestNotices; track n.id) {
            <div class="notice-item">
              <div class="notice-title">{{ n.title }}</div>
              <div class="notice-meta">{{ n.publishDate | date:'mediumDate' }} · {{ n.audience }}</div>
              <div class="notice-body">{{ n.body }}</div>
            </div>
          } @empty { <div class="empty">No notices yet.</div> }
        </div>
      </div>
    }
  `,
})
export class AdDashboardComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  d: AdminDashboard | null = null;
  loading = true;
  error = '';
  readonly today = new Date();

  ngOnInit(): void {
    this.api.getDashboard().subscribe({
      next: d => { this.d = d; this.loading = false; },
      error: e => { this.error = adminApiError(e); this.loading = false; },
    });
  }

  get collectionRate(): number {
    if (!this.d?.feesBilled) return 0;
    return Math.round((this.d.feesCollected / this.d.feesBilled) * 100);
  }

  get outstanding(): number {
    return Math.max(0, (this.d?.feesBilled ?? 0) - (this.d?.feesCollected ?? 0));
  }

  /** Mean of the days that were actually marked; null when none were. */
  get avgAttendance(): number | null {
    const days = this.d?.attendanceTrend ?? [];
    if (!days.length) return null;
    return days.reduce((sum, p) => sum + p.percent, 0) / days.length;
  }

  get trendPoints(): TrendPoint[] {
    return (this.d?.attendanceTrend ?? []).map(p => ({
      label: new Date(p.date).toLocaleDateString(undefined, { day: 'numeric', month: 'short' }),
      value: p.percent,
      sub: `${p.present}/${p.total} present`,
    }));
  }

  /**
   * Collected / pending / overdue. Status hues (good, warning, critical) rather than
   * categorical ones, since the colours mean a state — every slice is labelled with its
   * value in the legend, so colour never carries the meaning alone.
   */
  get feeSlices(): DonutSlice[] {
    const d = this.d;
    if (!d) return [];
    const pending = Math.max(0, d.feesBilled - d.feesCollected - d.feesOverdue);
    return [
      { label: 'Collected', value: d.feesCollected, color: '#0ca30c' },
      { label: 'Pending', value: pending, color: '#fab219' },
      { label: 'Overdue', value: d.feesOverdue, color: '#d03b3b' },
    ];
  }
}

/* =====================  STUDENTS  ===================== */

@Component({
  selector: 'app-ad-students',
  standalone: true,
  imports: [FormsModule, DecimalPipe, DatePipe, AutocompleteComponent, CredentialsDialogComponent, GeoPickerComponent, DigitsOnlyDirective],
  template: `
    <div class="page-head">
      <div class="grow"><h1>Student Management</h1><div class="page-sub">{{ displayed.length }} of {{ students.length }} students</div></div>
      <button class="btn btn-primary" (click)="openForm()">+ New Admission</button>
    </div>

    <div class="card">
      <div class="card-head filters">
        <div class="grow"></div>
        <input class="input" style="min-width:220px;" placeholder="Search name, admission no or guardian…" [(ngModel)]="q" (keyup.enter)="search()" />
        <input class="input" style="max-width:140px;" placeholder="Class" [(ngModel)]="cls" (keyup.enter)="search()" />
        <div class="field" style="margin:0;"><label style="font-size:11px;">Admitted from</label><input class="input" type="date" [(ngModel)]="fromDate" /></div>
        <div class="field" style="margin:0;"><label style="font-size:11px;">Admitted to</label><input class="input" type="date" [(ngModel)]="toDate" /></div>
        <button class="btn btn-primary" (click)="search()">Search</button>
        @if (q || cls || appliedFrom || appliedTo) { <button class="btn btn-ghost" (click)="clear()">Clear</button> }
      </div>
      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Student</th><th>Class</th><th>Roll</th><th>Guardian</th><th class="num">Fee Due</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              @for (s of displayed; track s.id) {
                <tr>
                  <td><div class="td-main">{{ s.name }}</div><div class="td-sub">{{ s.admissionNo }}</div></td>
                  <td>{{ s.className }}@if (s.sectionName) {-{{ s.sectionName }}}</td>
                  <td>{{ s.rollNo }}</td>
                  <td>{{ s.guardianName }}<div class="td-sub">{{ s.guardianPhone }}</div></td>
                  <td class="num">@if (s.feeDue > 0) { <span style="color:var(--crit-text);font-weight:600;">₹{{ s.feeDue | number }}</span> } @else { <span class="td-sub">—</span> }</td>
                  <td><span class="badge" [class]="'badge ' + badge(s.status)">{{ label(s.status) }}</span></td>
                  <td>
                    <div class="row-actions">
                      <button class="icon-action primary" (click)="view(s.id)" title="View"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7-11-7-11-7z"/><circle cx="12" cy="12" r="3"/></svg></button>
                      <button class="icon-action primary" (click)="edit(s.id)" title="Edit"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/></svg></button>
                      @if (s.status === 'inactive') {
                        <button class="icon-action success" (click)="setStatus(s, 'active')" title="Reactivate"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.5 2.5L16 9"/></svg></button>
                      } @else {
                        <button class="icon-action danger" (click)="deactivate(s)" title="Deactivate"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><line x1="5.6" y1="5.6" x2="18.4" y2="18.4"/></svg></button>
                      }
                    </div>
                  </td>
                </tr>
              } @empty { <tr><td colspan="7"><div class="empty">No students match.</div></td></tr> }
            </tbody>
          </table>
        </div>
      }
    </div>

    @if (viewing; as s) {
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>{{ s.name }}</h2><button class="modal-close" (click)="viewing = null">✕</button></div>
          <div class="modal-body">
            <div class="kv-row"><span class="kv-label">Admission #</span><span class="kv-value">{{ s.admissionNo }}</span></div>
            <div class="kv-row"><span class="kv-label">Class / Section</span><span class="kv-value">{{ s.className }} — {{ s.sectionName }}</span></div>
            <div class="kv-row"><span class="kv-label">Roll no</span><span class="kv-value">{{ s.rollNo || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Gender</span><span class="kv-value">{{ s.gender || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Date of birth</span><span class="kv-value">{{ s.dob ? (s.dob | date:'mediumDate') : '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Blood group</span><span class="kv-value">{{ s.bloodGroup || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Guardian</span><span class="kv-value">{{ s.guardianName }} ({{ s.guardianPhone }})</span></div>
            <div class="kv-row"><span class="kv-label">Address</span><span class="kv-value">{{ s.address || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">City / State</span><span class="kv-value">{{ s.city || '—' }} {{ s.state ? ', ' + s.state : '' }}</span></div>
            <div class="kv-row"><span class="kv-label">Pincode</span><span class="kv-value">{{ s.pincode || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Fee due</span><span class="kv-value">{{ s.feeDue > 0 ? '₹' + (s.feeDue | number) : 'Cleared' }}</span></div>
            <div class="kv-row"><span class="kv-label">Status</span><span class="kv-value"><span class="badge" [class]="'badge ' + badge(s.status)">{{ label(s.status) }}</span></span></div>
          </div>
          <div class="modal-foot"><button class="btn btn-ghost" (click)="viewing = null">Close</button></div>
        </div>
      </div>
    }

    @if (showForm) {
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>{{ editingId ? 'Edit Student' : 'New Admission' }}</h2><button class="modal-close" (click)="showForm = false">✕</button></div>
          <div class="modal-body">
            <div class="form-row">
              <div class="field">
                <label>First name <span class="req">*</span></label>
                <input class="input" [class.invalid]="err.has('firstName')" [(ngModel)]="form.firstName"
                       (ngModelChange)="err.clear('firstName')" />
                @if (err.has('firstName')) { <div class="field-error">{{ err.get('firstName') }}</div> }
              </div>
              <div class="field">
                <label>Last name <span class="req">*</span></label>
                <input class="input" [class.invalid]="err.has('lastName')" [(ngModel)]="form.lastName"
                       (ngModelChange)="err.clear('lastName')" />
                @if (err.has('lastName')) { <div class="field-error">{{ err.get('lastName') }}</div> }
              </div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Class <span class="req">*</span></label>
                <app-autocomplete [options]="classNames" [value]="form.className ?? ''" placeholder="Search class…"
                                  [invalid]="err.has('className')"
                                  (valueChange)="onClassChange($event)" />
                @if (err.has('className')) { <div class="field-error">{{ err.get('className') }}</div> }
              </div>
              <div class="field">
                <label>Section <span class="req">*</span></label>
                <select class="select" [class.invalid]="err.has('sectionName')" [(ngModel)]="form.sectionName"
                        [disabled]="!sectionOptions.length"
                        (ngModelChange)="err.clear('sectionName'); refreshRollNo()">
                  <option value="">{{ sectionPlaceholder }}</option>
                  @for (s of sectionOptions; track s) { <option [value]="s">{{ s }}</option> }
                </select>
                @if (err.has('sectionName')) { <div class="field-error">{{ err.get('sectionName') }}</div> }
              </div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Roll no <span class="td-sub" style="font-weight:500;">(auto)</span></label>
                <input class="input" [value]="rollNoDisplay" readonly disabled />
              </div>
              <div class="field">
                <label>Gender <span class="req">*</span></label>
                <select class="select" [class.invalid]="err.has('gender')" [(ngModel)]="form.gender"
                        (ngModelChange)="err.clear('gender')">
                  <option value="">Select gender…</option>
                  <option value="male">Male</option><option value="female">Female</option><option value="other">Other</option>
                </select>
                @if (err.has('gender')) { <div class="field-error">{{ err.get('gender') }}</div> }
              </div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Date of birth</label>
                <input class="input" type="date" [class.invalid]="err.has('dob')" [max]="today"
                       [(ngModel)]="form.dob" (ngModelChange)="err.clear('dob')" />
                @if (err.has('dob')) { <div class="field-error">{{ err.get('dob') }}</div> }
              </div>
              <div class="field"><label>Blood group</label><select class="select" [(ngModel)]="form.bloodGroup"><option value="">Unknown</option><option>A+</option><option>A-</option><option>B+</option><option>B-</option><option>O+</option><option>O-</option><option>AB+</option><option>AB-</option></select></div>
            </div>
            <div class="field"><label>Address</label><input class="input" [(ngModel)]="form.address" /></div>
            <app-geo-picker [showCountry]="false"
                            [stateId]="form.stateId ?? null" [cityId]="form.cityId ?? null"
                            [state]="form.state ?? ''" [city]="form.city ?? ''"
                            (changed)="applyPlace($event)" />
            <div class="form-row">
              <div class="field">
                <label>Pincode</label>
                <input class="input" appDigitsOnly="6" [class.invalid]="err.has('pincode')"
                       [(ngModel)]="form.pincode" (ngModelChange)="err.clear('pincode')" placeholder="6 digits" />
                @if (err.has('pincode')) { <div class="field-error">{{ err.get('pincode') }}</div> }
              </div>
              <div class="field"></div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Guardian name <span class="req">*</span></label>
                <input class="input" [class.invalid]="err.has('guardianName')" [(ngModel)]="form.guardianName"
                       (ngModelChange)="err.clear('guardianName')" />
                @if (err.has('guardianName')) { <div class="field-error">{{ err.get('guardianName') }}</div> }
              </div>
              <div class="field">
                <label>Guardian phone <span class="req">*</span></label>
                <input class="input" appDigitsOnly="10" [class.invalid]="err.has('guardianPhone')"
                       [(ngModel)]="form.guardianPhone" (ngModelChange)="err.clear('guardianPhone')"
                       placeholder="10 digits" />
                @if (err.has('guardianPhone')) { <div class="field-error">{{ err.get('guardianPhone') }}</div> }
              </div>
            </div>
            @if (formError) { <div style="color:var(--crit-text);font-size:13px;">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showForm = false">Cancel</button>
            <button class="btn btn-primary" (click)="save()" [disabled]="saving">{{ saving ? 'Saving…' : (editingId ? 'Save Changes' : 'Admit Student') }}</button>
          </div>
        </div>
      </div>
    }

    @if (admitted; as r) {
      <app-credentials-dialog
        title="Student admitted"
        [fullName]="r.credentials.fullName"
        [username]="r.credentials.username"
        [password]="r.credentials.temporaryPassword"
        [email]="r.credentials.email"
        [details]="[{ label: 'Admission no', value: r.admissionNo }, { label: 'Roll no', value: r.rollNo }]"
        (copied)="showToast($event)"
        (closed)="admitted = null" />
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class AdStudentsComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  students: StudentListItem[] = [];
  /** Backs the class / section autocompletes in the admission form. */
  classes: ClassDto[] = [];
  rollLoading = false;
  private rollSub?: Subscription;
  loading = true;
  error = '';
  q = '';
  cls = '';
  // The date boxes open on the current month. They are not applied until Search is pressed, so
  // the list still shows every student on load rather than appearing empty.
  fromDate = currentMonthRange().from;
  toDate = currentMonthRange().to;
  appliedFrom = '';
  appliedTo = '';
  showForm = false;
  saving = false;
  formError = '';
  /** Per-field messages, so a rejection lands under the box it concerns. */
  readonly err = new FieldErrors();
  /** Caps the date-of-birth picker; a student born tomorrow is a typo. */
  readonly today = new Date().toISOString().slice(0, 10);
  editingId: number | null = null;
  viewing: StudentDetail | null = null;
  /** Held only until the admin dismisses the dialog — never persisted anywhere. */
  admitted: CreateStudentResult | null = null;
  toast = '';
  form = this.empty();
  label = statusLabel;
  badge = statusBadge;
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void {
    this.reload();
    // Suggestion source for the form; a failure here just leaves the boxes as plain text inputs.
    this.api.getClasses().subscribe({ next: c => this.classes = c, error: () => this.classes = [] });
  }

  get classNames(): string[] { return this.classes.map(c => c.name); }

  /** The class record the typed name resolves to, if any. */
  get matchedClass(): ClassDto | undefined {
    const n = (this.form.className ?? '').trim().toLowerCase();
    return n ? this.classes.find(c => c.name.toLowerCase() === n) : undefined;
  }

  /**
   * Sections belonging to the chosen class. A value already on the student that the
   * class no longer lists is kept, so editing an old record never silently drops it.
   */
  get sectionOptions(): string[] {
    const names = this.matchedClass?.sections.map(s => s.name) ?? [];
    const current = (this.form.sectionName ?? '').trim();
    return current && !names.some(n => n.toLowerCase() === current.toLowerCase()) ? [...names, current] : names;
  }

  get sectionPlaceholder(): string {
    if (!this.matchedClass) return 'Select a class first';
    return this.matchedClass.sections.length ? 'Select section…' : 'No sections in this class';
  }

  /** Re-points the section list at the new class, dropping a section it does not contain. */
  onClassChange(name: string): void {
    this.form.className = name;
    const section = (this.form.sectionName ?? '').trim().toLowerCase();
    const valid = this.matchedClass?.sections.some(s => s.name.toLowerCase() === section) ?? false;
    if (section && !valid) this.form.sectionName = '';
    this.refreshRollNo();
  }

  /** What the read-only roll-no box shows while the class/section are being chosen. */
  get rollNoDisplay(): string {
    if (this.form.rollNo) return this.form.rollNo;
    return this.rollLoading ? 'Generating…' : 'Select class and section';
  }

  /**
   * Previews the next roll number for the chosen class/section. Only for new admissions —
   * an existing student keeps the roll number they were given.
   */
  refreshRollNo(): void {
    if (this.editingId) return;
    const cls = (this.form.className ?? '').trim();
    const sec = (this.form.sectionName ?? '').trim();
    this.rollSub?.unsubscribe();
    this.form.rollNo = '';
    if (!cls || !sec) { this.rollLoading = false; return; }
    this.rollLoading = true;
    this.rollSub = this.api.getNextRollNo(cls, sec).subscribe({
      next: r => { this.form.rollNo = r.rollNo; this.rollLoading = false; },
      error: () => { this.rollLoading = false; },
    });
  }

  /** Client-side admission-date filter on top of the server search. */
  get displayed(): StudentListItem[] {
    return this.students.filter(s => {
      const d = (s.admissionDate ?? '').slice(0, 10);
      if (this.appliedFrom && (!d || d < this.appliedFrom)) return false;
      if (this.appliedTo && (!d || d > this.appliedTo)) return false;
      return true;
    });
  }
  search(): void { this.appliedFrom = this.fromDate; this.appliedTo = this.toDate; this.reload(); }
  reload(): void {
    this.loading = this.students.length === 0;
    this.api.getStudents(this.q.trim() || undefined, this.cls.trim() || undefined).subscribe({
      next: r => { this.students = r; this.loading = false; this.error = ''; },
      error: e => { this.error = adminApiError(e); this.loading = false; },
    });
  }
  clear(): void {
    this.q = ''; this.cls = '';
    // Back to the defaults the page opens with, not blank.
    this.fromDate = currentMonthRange().from;
    this.toDate = currentMonthRange().to;
    this.appliedFrom = ''; this.appliedTo = '';
    this.reload();
  }
  openForm(): void {
    this.editingId = null;
    this.form = this.empty();
    this.rollSub?.unsubscribe();
    this.rollLoading = false;
    this.formError = '';
    this.err.reset();
    this.showForm = true;
  }
  view(id: number): void { this.api.getStudent(id).subscribe({ next: s => this.viewing = s, error: e => alert(adminApiError(e)) }); }
  edit(id: number): void {
    this.api.getStudent(id).subscribe({
      next: s => {
        this.editingId = id;
        this.form = { firstName: s.firstName, lastName: s.lastName, className: s.className ?? '', sectionName: s.sectionName ?? '', rollNo: s.rollNo ?? '', gender: s.gender ?? 'male', dob: s.dob?.slice(0,10) ?? '', bloodGroup: s.bloodGroup ?? '', email: s.email ?? '', address: s.address ?? '', city: s.city ?? '', state: s.state ?? '', pincode: s.pincode ?? '', guardianName: s.guardianName ?? '', guardianPhone: s.guardianPhone ?? '', stateId: s.stateId, cityId: s.cityId };
        this.formError = ''; this.err.reset(); this.showForm = true;
      },
      error: e => alert(adminApiError(e)),
    });
  }
  save(): void {
    if (!this.validate()) return;
    this.saving = true;
    // New admissions send no roll number: the preview can go stale, so the server has the last word.
    const dto: SaveStudent = { ...this.form, dob: this.form.dob || null, rollNo: this.editingId ? this.form.rollNo : '' };
    const done = (m: string) => { this.saving = false; this.showForm = false; this.showToast(m); this.reload(); };
    const fail = (e: unknown) => { this.saving = false; this.formError = adminApiError(e); };
    if (this.editingId) this.api.updateStudent(this.editingId, dto).subscribe({ next: () => done('Student updated'), error: fail });
    else this.api.createStudent(dto).subscribe({
      // The generated password only exists in this response, so raise the dialog before anything else.
      next: r => { this.admitted = r; done('Student admitted'); },
      error: fail,
    });
  }
  /** Checks every field at once, so an admin sees all the gaps rather than one per attempt. */
  private validate(): boolean {
    this.formError = '';
    this.err.reset();
    this.err.require('firstName', this.form.firstName, 'First name is required.');
    this.err.require('lastName', this.form.lastName, 'Last name is required.');
    this.err.require('className', this.form.className, 'Class is required.');
    this.err.require('sectionName', this.form.sectionName, 'Section is required.');
    this.err.require('gender', this.form.gender, 'Gender is required.');
    if (this.err.require('guardianName', this.form.guardianName, 'Guardian name is required.')) {
      // Nothing else to check — the name is free text.
    }
    if (this.err.require('guardianPhone', this.form.guardianPhone, 'Guardian phone is required.'))
      this.err.check('guardianPhone', isValidPhone(this.form.guardianPhone), 'Enter a 10-digit phone number.');
    this.err.check('pincode', isValidPincode(this.form.pincode), 'Pincode must be 6 digits.');
    if (this.form.dob)
      this.err.check('dob', this.form.dob <= this.today, 'Date of birth cannot be in the future.');
    return !this.err.any;
  }

  deactivate(s: StudentListItem): void {
    if (!confirm(`Deactivate ${s.name}? They will lose portal access.`)) return;
    this.setStatus(s, 'inactive');
  }
  setStatus(s: StudentListItem, status: string): void {
    this.api.setStudentStatus(s.id, status).subscribe({ next: () => { this.showToast(`${s.name} → ${statusLabel(status)}`); this.reload(); }, error: e => alert(adminApiError(e)) });
  }
  showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }

  /**
   * The picker sends ids when the typed name matched the master and nulls when it did
   * not; the text is always sent so an unmatched place is still recorded.
   */
  applyPlace(v: GeoValue): void {
    this.form.stateId = v.stateId;
    this.form.cityId = v.cityId;
    this.form.state = v.state;
    this.form.city = v.city;
  }
  private empty(): SaveStudent { return { firstName: '', lastName: '', className: '', sectionName: '', rollNo: '', gender: 'male', dob: '', bloodGroup: '', email: '', address: '', city: '', state: '', pincode: '', guardianName: '', guardianPhone: '', stateId: null, cityId: null }; }
}

/* =====================  TEACHERS  ===================== */

/**
 * A qualification row as the form holds it. Year is a string while it is being typed — an empty
 * box is "not stated", which a number would turn into 0.
 */
interface QualificationRow { name: string; institution: string; completionYear: string; }

@Component({
  selector: 'app-ad-teachers',
  standalone: true,
  imports: [FormsModule, DatePipe, CredentialsDialogComponent, GeoPickerComponent, AutocompleteComponent, DigitsOnlyDirective],
  template: `
    <div class="page-head">
      <div class="grow"><h1>Teacher Management</h1><div class="page-sub">{{ displayed.length }} of {{ teachers.length }} teaching staff</div></div>
      <button class="btn btn-primary" (click)="openForm()">+ Add Teacher</button>
    </div>

    <div class="card">
      <div class="card-head filters">
        <div class="grow"></div>
        <input class="input" style="min-width:220px;" placeholder="Search by name or subject…" [(ngModel)]="q" (keyup.enter)="search()" />
        <div class="field" style="margin:0;"><label style="font-size:11px;">Joined from</label><input class="input" type="date" [(ngModel)]="fromDate" /></div>
        <div class="field" style="margin:0;"><label style="font-size:11px;">Joined to</label><input class="input" type="date" [(ngModel)]="toDate" /></div>
        <button class="btn btn-primary" (click)="search()">Search</button>
        @if (q || appliedFrom || appliedTo) { <button class="btn btn-ghost" (click)="clear()">Clear</button> }
      </div>
      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Teacher</th><th>Subject</th><th>Class Teacher Of</th><th>Phone</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              @for (t of displayed; track t.id) {
                <tr>
                  <td><div class="td-main">{{ t.name }}</div><div class="td-sub">{{ t.employeeCode }}</div></td>
                  <td>{{ t.subject }}</td>
                  <td>
                    @if (t.classTeacherOf) { <span class="badge info">{{ t.classTeacherOf }}</span> }
                    @else { <span class="td-sub">—</span> }
                  </td>
                  <td class="td-sub">{{ t.phone }}</td>
                  <td><span class="badge" [class]="'badge ' + badge(t.status)">{{ label(t.status) }}</span></td>
                  <td>
                    <div class="row-actions">
                      <button class="icon-action primary" (click)="view(t.id)" title="View"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7-11-7-11-7z"/><circle cx="12" cy="12" r="3"/></svg></button>
                      <button class="icon-action primary" (click)="edit(t.id)" title="Edit"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/></svg></button>
                      @if (t.status === 'inactive') {
                        <button class="icon-action success" (click)="setStatus(t, 'active')" title="Reactivate"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.5 2.5L16 9"/></svg></button>
                      } @else {
                        <button class="icon-action danger" (click)="deactivate(t)" title="Deactivate"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><line x1="5.6" y1="5.6" x2="18.4" y2="18.4"/></svg></button>
                      }
                    </div>
                  </td>
                </tr>
              } @empty { <tr><td colspan="6"><div class="empty">No teachers match.</div></td></tr> }
            </tbody>
          </table>
        </div>
      }
    </div>

    @if (viewing; as t) {
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>{{ t.name }}</h2><button class="modal-close" (click)="viewing = null">✕</button></div>
          <div class="modal-body">
            <div class="kv-row"><span class="kv-label">Employee code</span><span class="kv-value">{{ t.employeeCode }}</span></div>
            <div class="kv-row"><span class="kv-label">Subject</span><span class="kv-value">{{ t.subject }}</span></div>
            <div class="kv-row"><span class="kv-label">Phone</span><span class="kv-value">{{ t.phone }}</span></div>
            <div class="kv-row"><span class="kv-label">Email</span><span class="kv-value">{{ t.email || '—' }}</span></div>
            <div class="kv-row">
              <span class="kv-label">Qualifications</span>
              <span class="kv-value">
                @if (t.qualifications.length) {
                  @for (q of t.qualifications; track $index) {
                    <span class="badge neutral" style="margin:0 4px 4px 0;">
                      {{ q.name }}@if (q.institution || q.completionYear) { <span class="td-sub"> — {{ qualDetail(q) }}</span> }
                    </span>
                  }
                } @else { — }
              </span>
            </div>
            <div class="kv-row"><span class="kv-label">Gender</span><span class="kv-value">{{ t.gender || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Address</span><span class="kv-value">{{ t.address || '—' }}{{ t.city ? ', ' + t.city : '' }}</span></div>
            <div class="kv-row"><span class="kv-label">Joined</span><span class="kv-value">{{ t.joiningDate ? (t.joiningDate | date:'mediumDate') : '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Status</span><span class="kv-value"><span class="badge" [class]="'badge ' + badge(t.status)">{{ label(t.status) }}</span></span></div>
          </div>
          <div class="modal-foot"><button class="btn btn-ghost" (click)="viewing = null">Close</button></div>
        </div>
      </div>
    }

    @if (showForm) {
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>{{ editingId ? 'Edit Teacher' : 'Add Teacher' }}</h2><button class="modal-close" (click)="showForm = false">✕</button></div>
          <div class="modal-body">
            <div class="form-row">
              <div class="field">
                <label>First name <span class="req">*</span></label>
                <input class="input" [class.invalid]="err.has('firstName')" [(ngModel)]="form.firstName"
                       (ngModelChange)="err.clear('firstName')" />
                @if (err.has('firstName')) { <div class="field-error">{{ err.get('firstName') }}</div> }
              </div>
              <div class="field">
                <label>Last name <span class="req">*</span></label>
                <input class="input" [class.invalid]="err.has('lastName')" [(ngModel)]="form.lastName"
                       (ngModelChange)="err.clear('lastName')" />
                @if (err.has('lastName')) { <div class="field-error">{{ err.get('lastName') }}</div> }
              </div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Subject <span class="req">*</span></label>
                <app-autocomplete [options]="subjects" [value]="form.subject ?? ''"
                                  [invalid]="err.has('subject')"
                                  [placeholder]="subjects.length ? 'Search subject…' : 'No subjects yet'"
                                  emptyHint="No subjects yet — add them under Subjects."
                                  noMatchHint="Create this subject under Subjects first."
                                  (valueChange)="onSubjectChange($event)" />
                @if (err.has('subject')) { <div class="field-error">{{ err.get('subject') }}</div> }
              </div>
              <div class="field"><label>Email</label>
                <input class="input" type="email" [class.invalid]="err.has('email')" [(ngModel)]="form.email"
                       (ngModelChange)="err.clear('email')" />
                @if (err.has('email')) { <div class="field-error">{{ err.get('email') }}</div> }
              </div>
            </div>

            <!-- A degree on its own says little; who awarded it and when is what an admin verifies. -->
            <div class="field">
              <label>Qualifications</label>
              @for (q of quals; track $index) {
                <div class="qual-row">
                  <div class="field">
                    @if ($first) { <label class="qual-head">Qualification <span class="req">*</span></label> }
                    <input class="input" [class.invalid]="err.has('qual' + $index)" [(ngModel)]="q.name"
                           (ngModelChange)="err.clear('qual' + $index)" placeholder="e.g. M.A. English" />
                    @if (err.has('qual' + $index)) { <div class="field-error">{{ err.get('qual' + $index) }}</div> }
                  </div>
                  <div class="field">
                    @if ($first) { <label class="qual-head">University / board</label> }
                    <input class="input" [(ngModel)]="q.institution" placeholder="e.g. Delhi University" />
                  </div>
                  <div class="field qual-year">
                    @if ($first) { <label class="qual-head">Year</label> }
                    <input class="input" appDigitsOnly="4" [class.invalid]="err.has('qualYear' + $index)"
                           [(ngModel)]="q.completionYear" (ngModelChange)="err.clear('qualYear' + $index)"
                           placeholder="2015" />
                    @if (err.has('qualYear' + $index)) { <div class="field-error">{{ err.get('qualYear' + $index) }}</div> }
                  </div>
                  <button type="button" class="icon-action danger qual-remove" (click)="removeQual($index)"
                          [attr.aria-label]="'Remove qualification ' + ($index + 1)" title="Remove">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="6" y1="6" x2="18" y2="18"/><line x1="18" y1="6" x2="6" y2="18"/></svg>
                  </button>
                </div>
              } @empty {
                <div class="field-hint">None recorded yet.</div>
              }
              <button type="button" class="btn btn-ghost btn-sm" style="margin-top:8px;" (click)="addQual()">+ Add qualification</button>
              <div class="field-hint">Add as many as apply — B.Ed, M.A., NET and so on. Only the name is required.</div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Phone <span class="req">*</span></label>
                <input class="input" appDigitsOnly="10" [class.invalid]="err.has('phone')" [(ngModel)]="form.phone"
                       (ngModelChange)="err.clear('phone')" placeholder="10 digits" />
                @if (err.has('phone')) { <div class="field-error">{{ err.get('phone') }}</div> }
              </div>
              <div class="field">
                <label>Date of birth</label>
                <input class="input" type="date" [max]="today" [class.invalid]="err.has('dob')"
                       [(ngModel)]="form.dob" (ngModelChange)="err.clear('dob')" />
                @if (err.has('dob')) { <div class="field-error">{{ err.get('dob') }}</div> }
              </div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Gender <span class="req">*</span></label>
                <select class="select" [class.invalid]="err.has('gender')" [(ngModel)]="form.gender"
                        (ngModelChange)="err.clear('gender')">
                  <option value="">Select gender…</option>
                  <option value="male">Male</option><option value="female">Female</option><option value="other">Other</option>
                </select>
                @if (err.has('gender')) { <div class="field-error">{{ err.get('gender') }}</div> }
              </div>
              <div class="field"></div>
            </div>
            <div class="field"><label>Address</label><input class="input" [(ngModel)]="form.address" /></div>
            <app-geo-picker [showCountry]="false"
                            [stateId]="form.stateId ?? null" [cityId]="form.cityId ?? null"
                            [state]="form.state ?? ''" [city]="form.city ?? ''"
                            (changed)="applyPlace($event)" />
            @if (formError) { <div style="color:var(--crit-text);font-size:13px;">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showForm = false">Cancel</button>
            <button class="btn btn-primary" (click)="save()" [disabled]="saving">{{ saving ? 'Saving…' : (editingId ? 'Save Changes' : 'Add Teacher') }}</button>
          </div>
        </div>
      </div>
    }

    @if (registered; as r) {
      <app-credentials-dialog
        title="Teacher registered"
        [fullName]="r.credentials.fullName"
        [username]="r.credentials.username"
        [password]="r.credentials.temporaryPassword"
        [email]="r.credentials.email"
        [details]="[{ label: 'Employee code', value: r.employeeCode }]"
        (copied)="showToast($event)"
        (closed)="registered = null" />
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class AdTeachersComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  teachers: TeacherListItem[] = [];
  loading = true;
  error = '';
  q = '';
  // Same as the students page: prefilled with this month, applied only on Search.
  fromDate = currentMonthRange().from;
  toDate = currentMonthRange().to;
  appliedFrom = '';
  appliedTo = '';
  showForm = false;
  saving = false;
  formError = '';
  editingId: number | null = null;
  viewing: TeacherDetail | null = null;
  /** Held only until the admin dismisses the dialog — never persisted anywhere. */
  registered: CreateTeacherResult | null = null;
  toast = '';
  form = this.empty();
  /** The school's subject list, backing the subject autocomplete. */
  subjects: string[] = [];
  /** Per-field messages, so a rejection lands under the box it concerns. */
  readonly err = new FieldErrors();
  readonly today = new Date().toISOString().slice(0, 10);
  /** Qualification rows, edited locally and posted as a whole list. */
  quals: QualificationRow[] = [];
  label = statusLabel;
  badge = statusBadge;
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void {
    this.reload();
    this.api.getSubjects().subscribe({ next: s => this.subjects = s, error: () => this.subjects = [] });
  }

  /** Client-side joining-date filter on top of the server search. */
  get displayed(): TeacherListItem[] {
    return this.teachers.filter(t => {
      const d = (t.joiningDate ?? '').slice(0, 10);
      if (this.appliedFrom && (!d || d < this.appliedFrom)) return false;
      if (this.appliedTo && (!d || d > this.appliedTo)) return false;
      return true;
    });
  }
  search(): void { this.appliedFrom = this.fromDate; this.appliedTo = this.toDate; this.reload(); }
  clear(): void {
    this.q = '';
    this.fromDate = currentMonthRange().from;
    this.toDate = currentMonthRange().to;
    this.appliedFrom = ''; this.appliedTo = '';
    this.reload();
  }
  reload(): void {
    this.loading = this.teachers.length === 0;
    this.api.getTeachers(this.q.trim() || undefined).subscribe({
      next: r => { this.teachers = r; this.loading = false; this.error = ''; },
      error: e => { this.error = adminApiError(e); this.loading = false; },
    });
  }
  openForm(): void {
    this.editingId = null;
    this.form = this.empty();
    // One blank row so the repeater reads as something to fill in rather than an empty space.
    this.quals = [this.emptyQual()];
    this.formError = '';
    this.err.reset();
    this.showForm = true;
  }
  view(id: number): void { this.api.getTeacher(id).subscribe({ next: t => this.viewing = t, error: e => alert(adminApiError(e)) }); }

  addQual(): void {
    if (this.quals.length >= 20) { this.err.set('quals', 'That is as many qualifications as we store.'); return; }
    this.quals.push(this.emptyQual());
    this.err.clear('quals');
  }

  removeQual(index: number): void {
    this.quals.splice(index, 1);
    // Messages are keyed by row index, so any left over would point at the wrong row.
    this.clearQualErrors();
  }

  /** "Delhi University, 2015" — the detail line under a qualification in the view dialog. */
  qualDetail(q: { institution: string | null; completionYear: number | null }): string {
    return [q.institution, q.completionYear].filter(Boolean).join(', ');
  }

  onSubjectChange(value: string): void {
    this.form.subject = value;
    this.err.clear('subject');
  }

  private emptyQual(): QualificationRow { return { name: '', institution: '', completionYear: '' }; }
  private clearQualErrors(): void {
    for (let i = 0; i < 20; i++) { this.err.clear('qual' + i); this.err.clear('qualYear' + i); }
    this.err.clear('quals');
  }

  /** True once the typed subject matches one on the school's subject list. */
  private subjectExists(): boolean {
    const typed = (this.form.subject ?? '').trim().toLowerCase();
    return this.subjects.some(x => x.toLowerCase() === typed);
  }
  edit(id: number): void {
    this.api.getTeacher(id).subscribe({
      next: t => {
        this.editingId = id;
        this.form = { firstName: t.firstName, lastName: t.lastName, subject: t.subject ?? '', phone: t.phone ?? '', email: t.email ?? '', qualification: t.qualification ?? '', gender: t.gender ?? '', dob: t.dob?.slice(0,10) ?? '', address: t.address ?? '', city: t.city ?? '', state: t.state ?? '', pincode: '', stateId: t.stateId, cityId: t.cityId };
        this.quals = (t.qualifications ?? []).map(q => ({
          name: q.name, institution: q.institution ?? '', completionYear: q.completionYear?.toString() ?? '',
        }));
        if (!this.quals.length) this.quals = [this.emptyQual()];
        this.formError = '';
        this.err.reset();
        this.showForm = true;
      },
      error: e => alert(adminApiError(e)),
    });
  }
  /** Checks every field at once, so an admin sees all the gaps rather than one per attempt. */
  private validate(): boolean {
    this.formError = '';
    this.err.reset();
    this.err.require('firstName', this.form.firstName, 'First name is required.');
    this.err.require('lastName', this.form.lastName, 'Last name is required.');
    if (this.err.require('subject', this.form.subject, 'Subject is required.'))
      // The subject must come from the school's list; a free-typed one would never match a class
      // subject or an exam paper.
      this.err.check('subject', this.subjectExists(),
        `“${(this.form.subject ?? '').trim()}” is not on your subject list — create it under Subjects first.`);
    if (this.err.require('phone', this.form.phone, 'Phone is required.'))
      this.err.check('phone', isValidPhone(this.form.phone), 'Enter a 10-digit phone number.');
    this.err.require('gender', this.form.gender, 'Gender is required.');
    this.err.check('email', isValidEmail(this.form.email), 'Enter a valid email address.');
    if (this.form.dob)
      this.err.check('dob', this.form.dob <= this.today, 'Date of birth cannot be in the future.');

    // A row with a university or year but no name is half-filled, not empty, so it is flagged
    // rather than quietly dropped on the way to the server.
    const thisYear = new Date().getFullYear();
    this.quals.forEach((q, i) => {
      const named = q.name.trim().length > 0;
      const hasDetail = q.institution.trim().length > 0 || q.completionYear.trim().length > 0;
      if (!named && hasDetail) this.err.set('qual' + i, 'Enter the qualification, or clear this row.');
      if (q.completionYear.trim()) {
        const year = Number(q.completionYear);
        this.err.check('qualYear' + i, year >= 1950 && year <= thisYear, `Year must be between 1950 and ${thisYear}.`);
      }
    });
    const named = this.quals.filter(q => q.name.trim());
    named.forEach((q, i) => {
      const key = (q.name.trim() + '|' + q.institution.trim()).toLowerCase();
      const firstAt = named.findIndex(o => (o.name.trim() + '|' + o.institution.trim()).toLowerCase() === key);
      if (firstAt !== i) this.err.set('qual' + this.quals.indexOf(q), 'This qualification is already listed.');
    });
    return !this.err.any;
  }

  save(): void {
    if (!this.validate()) return;
    this.saving = true;
    const dto: SaveTeacher = {
      ...this.form, dob: this.form.dob || null,
      // Blank rows are the repeater's own scaffolding, not data.
      qualifications: this.quals.filter(q => q.name.trim()).map(q => ({
        name: q.name.trim(),
        institution: q.institution.trim() || null,
        completionYear: q.completionYear.trim() ? Number(q.completionYear) : null,
      })),
    };
    const done = (m: string) => { this.saving = false; this.showForm = false; this.showToast(m); this.reload(); };
    const fail = (e: unknown) => { this.saving = false; this.formError = adminApiError(e); };
    if (this.editingId) this.api.updateTeacher(this.editingId, dto).subscribe({ next: () => done('Teacher updated'), error: fail });
    else this.api.createTeacher(dto).subscribe({
      // The generated password only exists in this response, so raise the dialog before anything else.
      next: r => { this.registered = r; done('Teacher added'); },
      error: fail,
    });
  }
  deactivate(t: TeacherListItem): void {
    if (!confirm(`Deactivate ${t.name}?`)) return;
    this.setStatus(t, 'inactive');
  }
  setStatus(t: TeacherListItem, status: string): void {
    this.api.setTeacherStatus(t.id, status).subscribe({ next: () => { this.showToast(`${t.name} → ${statusLabel(status)}`); this.reload(); }, error: e => alert(adminApiError(e)) });
  }
  showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }

  /**
   * The picker sends ids when the typed name matched the master and nulls when it did
   * not; the text is always sent so an unmatched place is still recorded.
   */
  applyPlace(v: GeoValue): void {
    this.form.stateId = v.stateId;
    this.form.cityId = v.cityId;
    this.form.state = v.state;
    this.form.city = v.city;
  }
  private empty(): SaveTeacher { return { firstName: '', lastName: '', subject: '', phone: '', email: '', qualification: '', gender: '', dob: '', address: '', city: '', state: '', pincode: '', stateId: null, cityId: null }; }
}

/* =====================  CLASSES & SECTIONS  ===================== */

@Component({
  selector: 'app-ad-classes',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page-head">
      <div class="grow"><h1>Classes &amp; Sections</h1><div class="page-sub">{{ classes.length }} classes · {{ totalSections }} sections · {{ totalStudents }} students</div></div>
      <!-- A section belongs to a class, so there is nothing to attach one to until a class exists.
           Disabled rather than hidden, so the action stays discoverable and can explain itself. -->
      <span [title]="classes.length ? '' : 'Add a class first — a section has to belong to one.'">
        <button class="btn btn-ghost" (click)="openSection()" [disabled]="!classes.length">+ Add Section</button>
      </span>
      <button class="btn btn-primary" (click)="openClass()">+ Add Class</button>
    </div>

    @if (loading) { <div class="card"><div class="empty">Loading…</div></div> }
    @else if (error) { <div class="card"><div class="empty">{{ error }}</div></div> }
    @else {
      @for (c of classes; track c.id) {
        <div class="card">
          <div class="card-head">
            <h2 class="grow">{{ c.name }}</h2>
            <span class="td-sub">{{ c.sections.length }} sections</span>
            <button class="icon-action primary" (click)="editClass(c)" title="Rename"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/></svg></button>
            <button class="icon-action danger" (click)="deleteClass(c)" title="Delete"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2m2 0v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/></svg></button>
            <button class="btn btn-ghost btn-sm" (click)="openCurriculum(c)">Subjects &amp; Teachers</button>
            <button class="btn btn-ghost btn-sm" (click)="openSection(c)">+ Section</button>
          </div>
          <div class="table-wrap">
            <table class="data-table">
              <thead><tr><th>Section</th><th class="num">Students</th><th>Class Teacher</th><th>Actions</th></tr></thead>
              <tbody>
                @for (s of c.sections; track s.id) {
                  <tr>
                    <td class="td-main">{{ c.name }} — {{ s.name }}</td>
                    <td class="num">{{ s.studentCount }}</td>
                    <td>{{ s.teacher || 'Unassigned' }}</td>
                    <td>
                      <div class="row-actions">
                        <button class="icon-action primary" (click)="editSection(c, s)" title="Edit"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/></svg></button>
                        <button class="icon-action danger" (click)="deleteSection(c, s)" title="Remove"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2m2 0v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/></svg></button>
                      </div>
                    </td>
                  </tr>
                } @empty { <tr><td colspan="4"><div class="empty">No sections yet.</div></td></tr> }
              </tbody>
            </table>
          </div>
        </div>
      } @empty { <div class="card"><div class="empty">No classes yet — add one with “+ Add Class”.</div></div> }
    }

    <!-- Subjects a class studies, and the teacher for each subject in each section -->
    @if (curriculum; as cur) {
      <div class="modal-backdrop">
        <div class="modal" style="max-width: 900px;">
          <div class="modal-head">
            <div class="grow">
              <h2>{{ cur.className }} — Subjects &amp; Teachers</h2>
              <div class="td-sub" style="margin-top:2px;">Academic year {{ cur.academicYear || '—' }}</div>
            </div>
            <button class="modal-close" (click)="closeCurriculum()">✕</button>
          </div>
          <div class="modal-body">
            <div class="field">
              <label>Subjects this class studies</label>
              <div class="chip-picker">
                @for (o of cur.subjects; track o.subjectId) {
                  <label class="pick-chip" [class.on]="o.selected" [class.locked]="o.hasTeacher && o.selected"
                         [title]="o.hasTeacher && o.selected ? 'A teacher is assigned — clear the teacher before removing this subject.' : ''">
                    <input type="checkbox" [checked]="o.selected" (change)="toggleSubject(o)" />
                    {{ o.name }}
                  </label>
                } @empty {
                  <div class="empty">No subjects yet — add them under Subjects.</div>
                }
              </div>
              @if (subjectsError) { <div class="field-error">{{ subjectsError }}</div> }
              @if (subjectsDirty) {
                <div style="margin-top:10px;">
                  <button class="btn btn-primary btn-sm" (click)="saveSubjects()" [disabled]="savingSubjects">
                    {{ savingSubjects ? 'Saving…' : 'Save subject list' }}
                  </button>
                  <button class="btn btn-ghost btn-sm" style="margin-left:8px;" (click)="reloadCurriculum()">Cancel</button>
                </div>
              }
            </div>

            <div class="card-head" style="padding:14px 0 10px;border-bottom:1px solid var(--border);">
              <h2 class="grow">Subject teachers</h2>
              @if (subjectTeachersDisabled) {
                <span class="td-sub">disabled for now</span>
              } @else {
                <span class="td-sub">one teacher per subject, per section</span>
              }
              @if (assignedCount > 0) {
                <button class="btn btn-ghost btn-sm danger" (click)="clearAssignments()"
                        [disabled]="clearing || subjectTeachersDisabled">
                  {{ clearing ? 'Clearing…' : 'Unassign all (' + assignedCount + ')' }}
                </button>
              }
            </div>

            @if (!cur.grid.length) {
              <div class="empty">Pick the subjects above first, then assign a teacher to each.</div>
            } @else {
              <!-- Only the opacity is applied here: pointer-events:none would
                   also kill the horizontal scroll needed to reach later
                   sections. The selects carry the actual disabled state. -->
              <div class="table-wrap" [style.opacity]="subjectTeachersDisabled ? 0.6 : 1">
                <table class="data-table sticky-first">
                  <thead>
                    <tr>
                      <th>Subject</th>
                      @for (sec of gridSections; track sec.sectionId) { <th>Section {{ sec.sectionName }}</th> }
                    </tr>
                  </thead>
                  <tbody>
                    @for (row of cur.grid; track row.subjectId) {
                      <tr>
                        <td class="td-main">{{ row.subjectName }}</td>
                        @for (cell of row.sections; track cell.sectionId) {
                          <td>
                            <select class="select sm" [ngModel]="cell.staffId"
                                    [disabled]="subjectTeachersDisabled"
                                    (ngModelChange)="assign(row, cell, $event)">
                              <option [ngValue]="null">— Unassigned —</option>
                              @if (teachersFor(row.subjectName).length) {
                                <optgroup [label]="row.subjectName + ' teachers'">
                                  @for (t of teachersFor(row.subjectName); track t.id) {
                                    <option [ngValue]="t.id">{{ t.name }}</option>
                                  }
                                </optgroup>
                              }
                              <!-- Specialisation is free text on the teacher form, so a
                                   spelling difference must not make a teacher unpickable. -->
                              @if (otherTeachers(row.subjectName).length) {
                                <optgroup label="Other teachers">
                                  @for (t of otherTeachers(row.subjectName); track t.id) {
                                    <option [ngValue]="t.id">{{ t.name }}@if (t.subject) { — {{ t.subject }} }</option>
                                  }
                                </optgroup>
                              }
                            </select>
                          </td>
                        }
                      </tr>
                    }
                  </tbody>
                </table>
              </div>
              <div class="field-hint" style="margin-top:10px;">
                @if (subjectTeachersDisabled) {
                  Subject-teacher assignment is switched off for now. The grid is shown read-only.
                } @else {
                  Changes save as you pick. The class teacher stays on the section itself — this grid is who teaches what.
                }
              </div>
            }
            @if (assignError) { <div class="field-error">{{ assignError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="closeCurriculum()">Close</button>
          </div>
        </div>
      </div>
    }

    @if (showClass) {
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>{{ editingClass ? 'Rename Class' : 'Add New Class' }}</h2><button class="modal-close" (click)="showClass = false">✕</button></div>
          <div class="modal-body">
            <div class="field">
              <label>Class name <span class="req">*</span></label>
              <input class="input" [class.invalid]="err.has('className')" [(ngModel)]="clsForm.name"
                     (ngModelChange)="err.clear('className')" placeholder="e.g. Grade 11" />
              @if (err.has('className')) { <div class="field-error">{{ err.get('className') }}</div> }
            </div>
            @if (!editingClass) {
              <div class="form-row">
                <div class="field">
                  <label>First section <span class="req">*</span></label>
                  <input class="input" [class.invalid]="err.has('firstSection')" [(ngModel)]="clsForm.section"
                         (ngModelChange)="err.clear('firstSection')" placeholder="A" />
                  @if (err.has('firstSection')) { <div class="field-error">{{ err.get('firstSection') }}</div> }
                </div>
                <div class="field">
                  <label>Class teacher</label>
                  <select class="select" [(ngModel)]="clsForm.teacher">
                    <option value="">Unassigned</option>
                    @for (t of activeTeachers; track t.id) {
                      <option [value]="t.name" [disabled]="!!heldSection(t.name)">
                        {{ t.name }}@if (heldSection(t.name)) { — class teacher of {{ heldSection(t.name) }} }
                      </option>
                    }
                  </select>
                  <div class="field-hint">A teacher can be class teacher of one section only.</div>
                </div>
              </div>
            }
            @if (formError) { <div class="field-error">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showClass = false">Cancel</button>
            <button class="btn btn-primary" (click)="saveClass()" [disabled]="saving">{{ editingClass ? 'Save' : 'Add Class' }}</button>
          </div>
        </div>
      </div>
    }

    @if (showSection) {
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>{{ editingSection ? 'Edit Section' : 'Add Section' }}</h2><button class="modal-close" (click)="showSection = false">✕</button></div>
          <div class="modal-body">
            <div class="form-row">
              <div class="field">
                <label>Class <span class="req">*</span></label>
                <select class="select" [class.invalid]="err.has('secClass')" [(ngModel)]="secForm.classId"
                        [disabled]="!!editingSection" (ngModelChange)="err.clear('secClass')">
                  <option [value]="0">Select class…</option>
                  @for (c of classes; track c.id) { <option [value]="c.id">{{ c.name }}</option> }
                </select>
                @if (err.has('secClass')) { <div class="field-error">{{ err.get('secClass') }}</div> }
              </div>
              <div class="field">
                <label>Section name <span class="req">*</span></label>
                <input class="input" [class.invalid]="err.has('secName')" [(ngModel)]="secForm.name"
                       (ngModelChange)="err.clear('secName')" placeholder="C" />
                @if (err.has('secName')) { <div class="field-error">{{ err.get('secName') }}</div> }
              </div>
            </div>
            <div class="field">
              <label>Class teacher</label>
              <select class="select" [(ngModel)]="secForm.teacher">
                <option value="">Unassigned</option>
                @for (t of activeTeachers; track t.id) {
                  <option [value]="t.name" [disabled]="!!heldSection(t.name, editingSection?.id)">
                    {{ t.name }}@if (heldSection(t.name, editingSection?.id)) { — class teacher of {{ heldSection(t.name, editingSection?.id) }} }
                  </option>
                }
              </select>
              <div class="field-hint">
                A teacher can be class teacher of one section only. To have them teach several
                classes, use Subjects &amp; Teachers instead.
              </div>
            </div>
            @if (formError) { <div class="field-error">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showSection = false">Cancel</button>
            <button class="btn btn-primary" (click)="saveSection()" [disabled]="saving">{{ editingSection ? 'Save' : 'Add Section' }}</button>
          </div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class AdClassesComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  classes: ClassDto[] = [];
  activeTeachers: TeacherListItem[] = [];
  loading = true;
  error = '';
  showClass = false;
  showSection = false;
  saving = false;
  formError = '';
  toast = '';
  editingClass: ClassDto | null = null;
  editingSection: SectionDto | null = null;
  clsForm = { name: '', section: 'A', teacher: '' };
  secForm = { classId: 0, name: '', teacher: '' };
  /**
   * Greys out the subject-teacher grid and stops it accepting input. The grid
   * still renders, so existing assignments stay visible — set this back to
   * false to make it editable again.
   */
  readonly subjectTeachersDisabled = true;

  /** Open "Subjects & Teachers" dialog, or null when closed. */
  curriculum: ClassCurriculum | null = null;
  subjectsDirty = false;
  savingSubjects = false;
  subjectsError = '';
  assignError = '';
  clearing = false;
  private timer?: ReturnType<typeof setTimeout>;

  /** Section columns for the grid — taken from the first row, since every row spans them all. */
  get gridSections(): AssignmentCell[] { return this.curriculum?.grid[0]?.sections ?? []; }

  /**
   * Teachers whose specialisation is this subject — the ones actually worth offering.
   * Matched on name because the teacher form stores the subject as free text rather than
   * a reference to the subjects master.
   */
  teachersFor(subject: string): TeacherListItem[] {
    const s = subject.trim().toLowerCase();
    return this.activeTeachers.filter(t => (t.subject ?? '').trim().toLowerCase() === s);
  }

  /**
   * Everyone else, offered under a second group. Without this a subject nobody is
   * recorded as teaching would have an empty dropdown and could never be assigned.
   */
  otherTeachers(subject: string): TeacherListItem[] {
    const s = subject.trim().toLowerCase();
    return this.activeTeachers.filter(t => (t.subject ?? '').trim().toLowerCase() !== s);
  }

  /**
   * The section a teacher already owns as class teacher, or '' when free. Drives the disabled
   * options so the clash is visible before saving; the API enforces the same rule.
   */
  heldSection(teacherName: string, exceptSectionId?: number): string {
    if (!teacherName) return '';
    for (const c of this.classes) {
      for (const sec of c.sections) {
        if (sec.teacher === teacherName && sec.id !== exceptSectionId) return `${c.name} — ${sec.name}`;
      }
    }
    return '';
  }

  openCurriculum(c: ClassDto): void {
    this.subjectsError = '';
    this.assignError = '';
    this.subjectsDirty = false;
    this.api.getClassCurriculum(c.id).subscribe({
      next: cur => this.curriculum = cur,
      error: e => alert(adminApiError(e)),
    });
  }

  closeCurriculum(): void { this.curriculum = null; this.subjectsDirty = false; }

  reloadCurriculum(): void {
    if (!this.curriculum) return;
    this.subjectsError = '';
    this.subjectsDirty = false;
    this.api.getClassCurriculum(this.curriculum.classId).subscribe({
      next: cur => this.curriculum = cur,
      error: e => this.subjectsError = adminApiError(e),
    });
  }

  /** How many cells of the grid currently name a teacher. */
  get assignedCount(): number {
    return (this.curriculum?.grid ?? []).reduce(
      (n, row) => n + row.sections.filter(c => !!c.staffId).length, 0);
  }

  /**
   * Empties the whole grid. Faster than setting a dozen dropdowns to unassigned, and it is what
   * has to happen before a subject can be removed from the class.
   */
  clearAssignments(): void {
    if (!this.curriculum) return;
    const count = this.assignedCount;
    if (!confirm(`Unassign all ${count} subject teacher(s) for ${this.curriculum.className}? The subject list is kept.`)) return;
    this.clearing = true;
    this.api.clearSubjectTeachers(this.curriculum.classId).subscribe({
      next: r => {
        this.clearing = false;
        this.showToast(`${r.cleared} assignment(s) cleared`);
        this.reloadCurriculum();
      },
      error: e => { this.clearing = false; this.assignError = adminApiError(e); },
    });
  }

  /** Ticking is local until saved, so the whole set goes in one request. */
  toggleSubject(o: ClassSubjectOption): void {
    if (o.selected && o.hasTeacher) {
      this.subjectsError = `Clear the teachers for ${o.name} before removing it from this class.`;
      return;
    }
    o.selected = !o.selected;
    this.subjectsDirty = true;
    this.subjectsError = '';
  }

  saveSubjects(): void {
    if (!this.curriculum) return;
    const ids = this.curriculum.subjects.filter(o => o.selected).map(o => o.subjectId);
    this.savingSubjects = true;
    this.api.setClassSubjects(this.curriculum.classId, ids).subscribe({
      next: () => {
        this.savingSubjects = false;
        this.showToast('Subject list updated');
        this.reloadCurriculum();   // the grid rows follow the subject set
      },
      error: e => { this.savingSubjects = false; this.subjectsError = adminApiError(e); },
    });
  }

  /** Each pick saves on its own; the cell is updated optimistically and rolled back on failure. */
  assign(row: AssignmentRow, cell: AssignmentCell, staffId: number | null): void {
    if (!this.curriculum) return;
    const previous = cell.staffId;
    cell.staffId = staffId;
    this.assignError = '';
    this.api.assignSubjectTeacher({
      classId: this.curriculum.classId, sectionId: cell.sectionId, subjectId: row.subjectId, staffId,
    }).subscribe({
      next: () => {
        const teacher = this.activeTeachers.find(t => t.id === staffId);
        cell.teacherName = teacher?.name ?? null;
        this.showToast(staffId
          ? `${teacher?.name} teaches ${row.subjectName} to section ${cell.sectionName}`
          : `${row.subjectName} unassigned for section ${cell.sectionName}`);
      },
      error: e => { cell.staffId = previous; this.assignError = adminApiError(e); },
    });
  }

  get totalSections(): number { return this.classes.reduce((n, c) => n + c.sections.length, 0); }
  get totalStudents(): number { return this.classes.reduce((n, c) => n + c.sections.reduce((m, s) => m + s.studentCount, 0), 0); }

  ngOnInit(): void {
    this.reload();
    this.api.getTeachers().subscribe({ next: t => this.activeTeachers = t.filter(x => x.status === 'active'), error: () => {} });
  }
  reload(): void {
    this.api.getClasses().subscribe({
      next: c => { this.classes = c; this.loading = false; this.error = ''; },
      error: e => { this.error = adminApiError(e); this.loading = false; },
    });
  }
  /** Per-field messages for the class and section dialogs. */
  readonly err = new FieldErrors();

  openClass(): void { this.editingClass = null; this.clsForm = { name: '', section: 'A', teacher: '' }; this.formError = ''; this.err.reset(); this.showClass = true; }
  editClass(c: ClassDto): void { this.editingClass = c; this.clsForm = { name: c.name, section: '', teacher: '' }; this.formError = ''; this.err.reset(); this.showClass = true; }
  saveClass(): void {
    this.formError = '';
    this.err.reset();
    this.err.require('className', this.clsForm.name, 'Class name is required.');
    // A class with no section has nowhere to admit a student, so the first one is required.
    if (!this.editingClass) this.err.require('firstSection', this.clsForm.section, 'A first section is required.');
    if (this.err.any) return;
    this.saving = true;
    const done = (m: string) => { this.saving = false; this.showClass = false; this.showToast(m); this.reload(); };
    const fail = (e: unknown) => { this.saving = false; this.formError = adminApiError(e); };
    if (this.editingClass) this.api.renameClass(this.editingClass.id, this.clsForm.name.trim()).subscribe({ next: () => done('Class renamed'), error: fail });
    else this.api.createClass(this.clsForm.name.trim(), this.clsForm.section.trim() || undefined, this.clsForm.teacher || undefined).subscribe({ next: () => done('Class added'), error: fail });
  }
  deleteClass(c: ClassDto): void {
    if (!confirm(`Delete ${c.name} and its ${c.sections.length} section(s)?`)) return;
    this.api.deleteClass(c.id).subscribe({ next: () => { this.showToast(`${c.name} deleted`); this.reload(); }, error: e => alert(adminApiError(e)) });
  }
  openSection(c?: ClassDto): void { this.editingSection = null; this.secForm = { classId: c?.id ?? this.classes[0]?.id ?? 0, name: '', teacher: '' }; this.formError = ''; this.err.reset(); this.showSection = true; }
  editSection(c: ClassDto, s: SectionDto): void { this.editingSection = s; this.secForm = { classId: c.id, name: s.name, teacher: s.teacher ?? '' }; this.formError = ''; this.err.reset(); this.showSection = true; }
  saveSection(): void {
    this.formError = '';
    this.err.reset();
    this.err.check('secClass', !!Number(this.secForm.classId), 'Class is required.');
    this.err.require('secName', this.secForm.name, 'Section name is required.');
    if (this.err.any) return;
    this.saving = true;
    const done = (m: string) => { this.saving = false; this.showSection = false; this.showToast(m); this.reload(); };
    const fail = (e: unknown) => { this.saving = false; this.formError = adminApiError(e); };
    if (this.editingSection) this.api.updateSection(this.editingSection.id, Number(this.secForm.classId), this.secForm.name.trim(), this.secForm.teacher || undefined).subscribe({ next: () => done('Section updated'), error: fail });
    else this.api.addSection(Number(this.secForm.classId), this.secForm.name.trim(), this.secForm.teacher || undefined).subscribe({ next: () => done('Section added'), error: fail });
  }
  deleteSection(c: ClassDto, s: SectionDto): void {
    if (!confirm(`Remove section ${c.name} — ${s.name}?`)) return;
    this.api.deleteSection(s.id).subscribe({ next: () => { this.showToast('Section removed'); this.reload(); }, error: e => alert(adminApiError(e)) });
  }
  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }
}

/* =====================  NOTICES  ===================== */

@Component({
  selector: 'app-ad-notices',
  standalone: true,
  imports: [FormsModule, DatePipe],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Notice Board</h1>
        <div class="page-sub">{{ displayed.length }} of {{ notices.length }} notices · {{ mineCount }} posted by you</div>
      </div>
    </div>

    <div class="grid-2">
      <div class="card">
        <div class="card-head filters">
          <h2 class="grow">Published</h2>
          <select class="select" [(ngModel)]="scope">
            <option value="all">All notices</option>
            <option value="mine">Posted by me</option>
          </select>
        </div>
        @if (loading) { <div class="empty">Loading…</div> }
        @else if (error) { <div class="empty">{{ error }}</div> }
        @else {
          @for (n of displayed; track n.id) {
            <div class="notice-item">
              <div class="notice-head">
                <div class="notice-title grow">{{ n.title }}</div>
                <div class="row-actions">
                  <button class="icon-action primary" (click)="edit(n)" title="Edit" aria-label="Edit">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/></svg>
                  </button>
                  <button class="icon-action danger" (click)="remove(n)" title="Delete" aria-label="Delete">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6M14 11v6"/></svg>
                  </button>
                </div>
              </div>
              <div class="notice-meta">
                {{ n.publishDate | date:'mediumDate' }} · Audience: {{ n.audience }} ·
                by {{ isMine(n) ? 'you' : (n.createdByName || 'unknown') }}
              </div>
              <div class="notice-body">{{ n.body }}</div>
            </div>
          } @empty { <div class="empty">{{ scope === 'mine' ? 'You have not posted any notices yet.' : 'No notices yet.' }}</div> }
        }
      </div>

      <div class="card">
        <div class="card-head"><h2 class="grow">{{ editingId ? 'Edit Notice' : 'Publish New Notice' }}</h2></div>
        <div class="card-body">
          <div class="field">
            <label>Title <span class="req">*</span></label>
            <input class="input" [class.invalid]="err.has('title')" [(ngModel)]="title" (ngModelChange)="err.clear('title')" />
            @if (err.has('title')) { <div class="field-error">{{ err.get('title') }}</div> }
          </div>
          <div class="field"><label>Audience</label>
            <select class="select" [(ngModel)]="audience"><option value="all">All</option><option value="students">Students</option><option value="teachers">Teachers</option><option value="parents">Parents</option><option value="staff">Staff</option></select>
          </div>
          <div class="field">
            <label>Notice <span class="req">*</span></label>
            <textarea class="input" rows="5" [class.invalid]="err.has('body')" [(ngModel)]="body" (ngModelChange)="err.clear('body')"></textarea>
            @if (err.has('body')) { <div class="field-error">{{ err.get('body') }}</div> }
          </div>
          @if (error2) { <div style="color:var(--crit-text);font-size:13px;">{{ error2 }}</div> }
          <div class="row-actions">
            <button class="btn btn-primary" (click)="publish()" [disabled]="saving">
              {{ saving ? 'Saving…' : (editingId ? 'Save Changes' : 'Publish Notice') }}
            </button>
            @if (editingId) { <button class="btn btn-ghost" (click)="cancelEdit()">Cancel</button> }
          </div>
        </div>
      </div>
    </div>

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class AdNoticesComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  notices: NoticeDto[] = [];
  loading = true;
  error = '';
  error2 = '';
  saving = false;
  title = '';
  audience = 'all';
  body = '';
  toast = '';
  scope: 'all' | 'mine' = 'all';
  editingId: number | null = null;
  private readonly auth = inject(AuthService);
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void { this.reload(); }
  reload(): void {
    this.api.getNotices().subscribe({
      next: n => { this.notices = n; this.loading = false; this.error = ''; },
      error: e => { this.error = adminApiError(e); this.loading = false; },
    });
  }

  /** Notices are matched against the signed-in account, so "mine" survives multiple admins. */
  isMine(n: NoticeDto): boolean { return n.createdBy === this.auth.user()?.id; }
  get mineCount(): number { return this.notices.filter(n => this.isMine(n)).length; }
  get displayed(): NoticeDto[] {
    return this.scope === 'mine' ? this.notices.filter(n => this.isMine(n)) : this.notices;
  }

  edit(n: NoticeDto): void {
    this.editingId = n.id;
    this.title = n.title; this.body = n.body; this.audience = n.audience;
    this.error2 = ''; this.err.reset();
  }
  cancelEdit(): void { this.editingId = null; this.title = ''; this.body = ''; this.audience = 'all'; this.error2 = ''; this.err.reset(); }

  remove(n: NoticeDto): void {
    if (!confirm(`Delete “${n.title}”? This removes it from the notice board for everyone.`)) return;
    this.api.deleteNotice(n.id).subscribe({
      next: () => { if (this.editingId === n.id) this.cancelEdit(); this.showToast('Notice deleted'); this.reload(); },
      error: e => alert(adminApiError(e)),
    });
  }

  readonly err = new FieldErrors();

  publish(): void {
    // The button used to sit disabled until both boxes were filled, which said nothing about
    // why it would not press. Let it be pressed, and say what is missing.
    this.err.reset();
    this.err.require('title', this.title, 'Title is required.');
    this.err.require('body', this.body, 'The notice text is required.');
    if (this.err.any) return;
    this.saving = true; this.error2 = '';
    const done = (m: string) => { this.saving = false; this.cancelEdit(); this.showToast(m); this.reload(); };
    const fail = (e: unknown) => { this.saving = false; this.error2 = adminApiError(e); };
    if (this.editingId) {
      this.api.updateNotice(this.editingId, this.title.trim(), this.body.trim(), this.audience)
        .subscribe({ next: () => done('Notice updated'), error: fail });
    } else {
      this.api.createNotice(this.title.trim(), this.body.trim(), this.audience)
        .subscribe({ next: () => done('Notice published'), error: fail });
    }
  }
  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }
}
