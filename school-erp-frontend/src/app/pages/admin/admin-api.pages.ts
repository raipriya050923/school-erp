import { Component, OnInit, inject } from '@angular/core';
import { DecimalPipe, DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {
  AdminApiService, adminApiError, statusLabel, statusBadge,
  AdminDashboard, StudentListItem, StudentDetail, SaveStudent,
  TeacherListItem, TeacherDetail, SaveTeacher, ClassDto, SectionDto, NoticeDto,
} from '../../core/admin-api.service';

/* =====================  DASHBOARD  ===================== */

@Component({
  selector: 'app-ad-dashboard',
  standalone: true,
  imports: [DecimalPipe, DatePipe],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Sunrise Public School</h1>
        <div class="page-sub">Academic Year 2083 · live data from the API</div>
      </div>
    </div>

    @if (loading) { <div class="card"><div class="empty">Loading…</div></div> }
    @else if (error) { <div class="card"><div class="empty">{{ error }}</div></div> }
    @else if (d) {
      <div class="stat-grid">
        <div class="stat-tile"><div class="stat-label">Students</div><div class="stat-value">{{ d.totalStudents | number }}</div><div class="stat-sub">active enrolment</div></div>
        <div class="stat-tile"><div class="stat-label">Teachers</div><div class="stat-value">{{ d.totalTeachers | number }}</div><div class="stat-sub">{{ d.teachersOnLeave }} on leave</div></div>
        <div class="stat-tile"><div class="stat-label">Classes</div><div class="stat-value">{{ d.totalClasses | number }}</div><div class="stat-sub">configured</div></div>
        <div class="stat-tile"><div class="stat-label">Fees Due</div><div class="stat-value">Rs {{ d.feesDue | number }}</div><div class="stat-sub" [class.down]="d.feesDue > 0">outstanding</div></div>
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
  ngOnInit(): void {
    this.api.getDashboard().subscribe({
      next: d => { this.d = d; this.loading = false; },
      error: e => { this.error = adminApiError(e); this.loading = false; },
    });
  }
}

/* =====================  STUDENTS  ===================== */

@Component({
  selector: 'app-ad-students',
  standalone: true,
  imports: [FormsModule, DecimalPipe, DatePipe],
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
                  <td class="num">@if (s.feeDue > 0) { <span style="color:var(--crit-text);font-weight:600;">Rs {{ s.feeDue | number }}</span> } @else { <span class="td-sub">—</span> }</td>
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
      <div class="modal-backdrop" (click)="viewing = null">
        <div class="modal" (click)="$event.stopPropagation()">
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
            <div class="kv-row"><span class="kv-label">Fee due</span><span class="kv-value">{{ s.feeDue > 0 ? 'Rs ' + (s.feeDue | number) : 'Cleared' }}</span></div>
            <div class="kv-row"><span class="kv-label">Status</span><span class="kv-value"><span class="badge" [class]="'badge ' + badge(s.status)">{{ label(s.status) }}</span></span></div>
          </div>
          <div class="modal-foot"><button class="btn btn-ghost" (click)="viewing = null">Close</button></div>
        </div>
      </div>
    }

    @if (showForm) {
      <div class="modal-backdrop" (click)="showForm = false">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head"><h2>{{ editingId ? 'Edit Student' : 'New Admission' }}</h2><button class="modal-close" (click)="showForm = false">✕</button></div>
          <div class="modal-body">
            <div class="form-row">
              <div class="field"><label>First name *</label><input class="input" [(ngModel)]="form.firstName" /></div>
              <div class="field"><label>Last name *</label><input class="input" [(ngModel)]="form.lastName" /></div>
            </div>
            <div class="form-row">
              <div class="field"><label>Class</label><input class="input" [(ngModel)]="form.className" placeholder="Grade 8" /></div>
              <div class="field"><label>Section</label><input class="input" [(ngModel)]="form.sectionName" placeholder="A" /></div>
            </div>
            <div class="form-row">
              <div class="field"><label>Roll no</label><input class="input" [(ngModel)]="form.rollNo" /></div>
              <div class="field"><label>Gender</label><select class="select" [(ngModel)]="form.gender"><option value="male">Male</option><option value="female">Female</option><option value="other">Other</option></select></div>
            </div>
            <div class="form-row">
              <div class="field"><label>Date of birth</label><input class="input" type="date" [(ngModel)]="form.dob" /></div>
              <div class="field"><label>Blood group</label><select class="select" [(ngModel)]="form.bloodGroup"><option value="">Unknown</option><option>A+</option><option>A-</option><option>B+</option><option>B-</option><option>O+</option><option>O-</option><option>AB+</option><option>AB-</option></select></div>
            </div>
            <div class="field"><label>Address</label><input class="input" [(ngModel)]="form.address" /></div>
            <div class="form-row">
              <div class="field"><label>City</label><input class="input" [(ngModel)]="form.city" /></div>
              <div class="field"><label>State</label><input class="input" [(ngModel)]="form.state" /></div>
            </div>
            <div class="form-row">
              <div class="field"><label>Pincode</label><input class="input" [(ngModel)]="form.pincode" /></div>
              <div class="field"></div>
            </div>
            <div class="form-row">
              <div class="field"><label>Guardian name *</label><input class="input" [(ngModel)]="form.guardianName" /></div>
              <div class="field"><label>Guardian phone *</label><input class="input" [(ngModel)]="form.guardianPhone" /></div>
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

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class AdStudentsComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  students: StudentListItem[] = [];
  loading = true;
  error = '';
  q = '';
  cls = '';
  fromDate = '';
  toDate = '';
  appliedFrom = '';
  appliedTo = '';
  showForm = false;
  saving = false;
  formError = '';
  editingId: number | null = null;
  viewing: StudentDetail | null = null;
  toast = '';
  form = this.empty();
  label = statusLabel;
  badge = statusBadge;
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void { this.reload(); }

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
  clear(): void { this.q = ''; this.cls = ''; this.fromDate = ''; this.toDate = ''; this.appliedFrom = ''; this.appliedTo = ''; this.reload(); }
  openForm(): void { this.editingId = null; this.form = this.empty(); this.formError = ''; this.showForm = true; }
  view(id: number): void { this.api.getStudent(id).subscribe({ next: s => this.viewing = s, error: e => alert(adminApiError(e)) }); }
  edit(id: number): void {
    this.api.getStudent(id).subscribe({
      next: s => {
        this.editingId = id;
        this.form = { firstName: s.firstName, lastName: s.lastName, className: s.className ?? '', sectionName: s.sectionName ?? '', rollNo: s.rollNo ?? '', gender: s.gender ?? 'male', dob: s.dob?.slice(0,10) ?? '', bloodGroup: s.bloodGroup ?? '', email: s.email ?? '', address: s.address ?? '', city: s.city ?? '', state: s.state ?? '', pincode: s.pincode ?? '', guardianName: s.guardianName ?? '', guardianPhone: s.guardianPhone ?? '' };
        this.formError = ''; this.showForm = true;
      },
      error: e => alert(adminApiError(e)),
    });
  }
  save(): void {
    if (!this.form.firstName.trim() || !this.form.lastName.trim()) { this.formError = 'First and last name are required.'; return; }
    if (!(this.form.guardianName ?? '').trim() || !(this.form.guardianPhone ?? '').trim()) { this.formError = 'Guardian name and phone are required.'; return; }
    this.saving = true;
    const dto: SaveStudent = { ...this.form, dob: this.form.dob || null };
    const done = (m: string) => { this.saving = false; this.showForm = false; this.showToast(m); this.reload(); };
    const fail = (e: unknown) => { this.saving = false; this.formError = adminApiError(e); };
    if (this.editingId) this.api.updateStudent(this.editingId, dto).subscribe({ next: () => done('Student updated'), error: fail });
    else this.api.createStudent(dto).subscribe({ next: () => done('Student admitted'), error: fail });
  }
  deactivate(s: StudentListItem): void {
    if (!confirm(`Deactivate ${s.name}? They will lose portal access.`)) return;
    this.setStatus(s, 'inactive');
  }
  setStatus(s: StudentListItem, status: string): void {
    this.api.setStudentStatus(s.id, status).subscribe({ next: () => { this.showToast(`${s.name} → ${statusLabel(status)}`); this.reload(); }, error: e => alert(adminApiError(e)) });
  }
  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }
  private empty(): SaveStudent { return { firstName: '', lastName: '', className: '', sectionName: '', rollNo: '', gender: 'male', dob: '', bloodGroup: '', email: '', address: '', city: '', state: '', pincode: '', guardianName: '', guardianPhone: '' }; }
}

/* =====================  TEACHERS  ===================== */

@Component({
  selector: 'app-ad-teachers',
  standalone: true,
  imports: [FormsModule, DatePipe],
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
            <thead><tr><th>Teacher</th><th>Subject</th><th>Classes</th><th>Phone</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              @for (t of displayed; track t.id) {
                <tr>
                  <td><div class="td-main">{{ t.name }}</div><div class="td-sub">{{ t.employeeCode }}</div></td>
                  <td>{{ t.subject }}</td>
                  <td class="td-sub">{{ t.classesTaught }}</td>
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
      <div class="modal-backdrop" (click)="viewing = null">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head"><h2>{{ t.name }}</h2><button class="modal-close" (click)="viewing = null">✕</button></div>
          <div class="modal-body">
            <div class="kv-row"><span class="kv-label">Employee code</span><span class="kv-value">{{ t.employeeCode }}</span></div>
            <div class="kv-row"><span class="kv-label">Subject</span><span class="kv-value">{{ t.subject }}</span></div>
            <div class="kv-row"><span class="kv-label">Classes</span><span class="kv-value">{{ t.classesTaught || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Phone</span><span class="kv-value">{{ t.phone }}</span></div>
            <div class="kv-row"><span class="kv-label">Email</span><span class="kv-value">{{ t.email || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Qualification</span><span class="kv-value">{{ t.qualification || '—' }}</span></div>
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
      <div class="modal-backdrop" (click)="showForm = false">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head"><h2>{{ editingId ? 'Edit Teacher' : 'Add Teacher' }}</h2><button class="modal-close" (click)="showForm = false">✕</button></div>
          <div class="modal-body">
            <div class="form-row">
              <div class="field"><label>First name *</label><input class="input" [(ngModel)]="form.firstName" /></div>
              <div class="field"><label>Last name *</label><input class="input" [(ngModel)]="form.lastName" /></div>
            </div>
            <div class="form-row">
              <div class="field"><label>Subject *</label><input class="input" [(ngModel)]="form.subject" /></div>
              <div class="field"><label>Classes taught</label><input class="input" [(ngModel)]="form.classesTaught" placeholder="G6, G7" /></div>
            </div>
            <div class="form-row">
              <div class="field"><label>Phone *</label><input class="input" [(ngModel)]="form.phone" /></div>
              <div class="field"><label>Email</label><input class="input" type="email" [(ngModel)]="form.email" /></div>
            </div>
            <div class="field"><label>Qualification</label><input class="input" [(ngModel)]="form.qualification" /></div>
            <div class="form-row">
              <div class="field"><label>Gender</label><select class="select" [(ngModel)]="form.gender"><option value="">—</option><option value="male">Male</option><option value="female">Female</option><option value="other">Other</option></select></div>
              <div class="field"><label>Date of birth</label><input class="input" type="date" [(ngModel)]="form.dob" /></div>
            </div>
            <div class="field"><label>Address</label><input class="input" [(ngModel)]="form.address" /></div>
            <div class="form-row">
              <div class="field"><label>City</label><input class="input" [(ngModel)]="form.city" /></div>
              <div class="field"><label>State</label><input class="input" [(ngModel)]="form.state" /></div>
            </div>
            @if (formError) { <div style="color:var(--crit-text);font-size:13px;">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showForm = false">Cancel</button>
            <button class="btn btn-primary" (click)="save()" [disabled]="saving">{{ saving ? 'Saving…' : (editingId ? 'Save Changes' : 'Add Teacher') }}</button>
          </div>
        </div>
      </div>
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
  fromDate = '';
  toDate = '';
  appliedFrom = '';
  appliedTo = '';
  showForm = false;
  saving = false;
  formError = '';
  editingId: number | null = null;
  viewing: TeacherDetail | null = null;
  toast = '';
  form = this.empty();
  label = statusLabel;
  badge = statusBadge;
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void { this.reload(); }

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
  clear(): void { this.q = ''; this.fromDate = ''; this.toDate = ''; this.appliedFrom = ''; this.appliedTo = ''; this.reload(); }
  reload(): void {
    this.loading = this.teachers.length === 0;
    this.api.getTeachers(this.q.trim() || undefined).subscribe({
      next: r => { this.teachers = r; this.loading = false; this.error = ''; },
      error: e => { this.error = adminApiError(e); this.loading = false; },
    });
  }
  openForm(): void { this.editingId = null; this.form = this.empty(); this.formError = ''; this.showForm = true; }
  view(id: number): void { this.api.getTeacher(id).subscribe({ next: t => this.viewing = t, error: e => alert(adminApiError(e)) }); }
  edit(id: number): void {
    this.api.getTeacher(id).subscribe({
      next: t => {
        this.editingId = id;
        this.form = { firstName: t.firstName, lastName: t.lastName, subject: t.subject ?? '', classesTaught: t.classesTaught ?? '', phone: t.phone ?? '', email: t.email ?? '', qualification: t.qualification ?? '', gender: t.gender ?? '', dob: t.dob?.slice(0,10) ?? '', address: t.address ?? '', city: t.city ?? '', state: t.state ?? '', pincode: '' };
        this.formError = ''; this.showForm = true;
      },
      error: e => alert(adminApiError(e)),
    });
  }
  save(): void {
    if (!this.form.firstName.trim() || !this.form.lastName.trim()) { this.formError = 'First and last name are required.'; return; }
    if (!(this.form.subject ?? '').trim() || !(this.form.phone ?? '').trim()) { this.formError = 'Subject and phone are required.'; return; }
    this.saving = true;
    const dto: SaveTeacher = { ...this.form, dob: this.form.dob || null };
    const done = (m: string) => { this.saving = false; this.showForm = false; this.showToast(m); this.reload(); };
    const fail = (e: unknown) => { this.saving = false; this.formError = adminApiError(e); };
    if (this.editingId) this.api.updateTeacher(this.editingId, dto).subscribe({ next: () => done('Teacher updated'), error: fail });
    else this.api.createTeacher(dto).subscribe({ next: () => done('Teacher added'), error: fail });
  }
  deactivate(t: TeacherListItem): void {
    if (!confirm(`Deactivate ${t.name}?`)) return;
    this.setStatus(t, 'inactive');
  }
  setStatus(t: TeacherListItem, status: string): void {
    this.api.setTeacherStatus(t.id, status).subscribe({ next: () => { this.showToast(`${t.name} → ${statusLabel(status)}`); this.reload(); }, error: e => alert(adminApiError(e)) });
  }
  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }
  private empty(): SaveTeacher { return { firstName: '', lastName: '', subject: '', classesTaught: '', phone: '', email: '', qualification: '', gender: '', dob: '', address: '', city: '', state: '', pincode: '' }; }
}

/* =====================  CLASSES & SECTIONS  ===================== */

@Component({
  selector: 'app-ad-classes',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page-head">
      <div class="grow"><h1>Classes &amp; Sections</h1><div class="page-sub">{{ classes.length }} classes · {{ totalSections }} sections · {{ totalStudents }} students</div></div>
      <button class="btn btn-ghost" (click)="openSection()">+ Add Section</button>
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

    @if (showClass) {
      <div class="modal-backdrop" (click)="showClass = false">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head"><h2>{{ editingClass ? 'Rename Class' : 'Add New Class' }}</h2><button class="modal-close" (click)="showClass = false">✕</button></div>
          <div class="modal-body">
            <div class="field"><label>Class name *</label><input class="input" [(ngModel)]="clsForm.name" placeholder="e.g. Grade 11" /></div>
            @if (!editingClass) {
              <div class="form-row">
                <div class="field"><label>First section</label><input class="input" [(ngModel)]="clsForm.section" placeholder="A" /></div>
                <div class="field"><label>Class teacher</label><select class="select" [(ngModel)]="clsForm.teacher"><option value="">Unassigned</option>@for (t of activeTeachers; track t.id) { <option [value]="t.name">{{ t.name }}</option> }</select></div>
              </div>
            }
            @if (formError) { <div style="color:var(--crit-text);font-size:13px;">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showClass = false">Cancel</button>
            <button class="btn btn-primary" (click)="saveClass()" [disabled]="saving">{{ editingClass ? 'Save' : 'Add Class' }}</button>
          </div>
        </div>
      </div>
    }

    @if (showSection) {
      <div class="modal-backdrop" (click)="showSection = false">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head"><h2>{{ editingSection ? 'Edit Section' : 'Add Section' }}</h2><button class="modal-close" (click)="showSection = false">✕</button></div>
          <div class="modal-body">
            <div class="form-row">
              <div class="field"><label>Class *</label><select class="select" [(ngModel)]="secForm.classId" [disabled]="!!editingSection">@for (c of classes; track c.id) { <option [value]="c.id">{{ c.name }}</option> }</select></div>
              <div class="field"><label>Section name *</label><input class="input" [(ngModel)]="secForm.name" placeholder="C" /></div>
            </div>
            <div class="field"><label>Class teacher</label><select class="select" [(ngModel)]="secForm.teacher"><option value="">Unassigned</option>@for (t of activeTeachers; track t.id) { <option [value]="t.name">{{ t.name }}</option> }</select></div>
            @if (formError) { <div style="color:var(--crit-text);font-size:13px;">{{ formError }}</div> }
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
  private timer?: ReturnType<typeof setTimeout>;

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
  openClass(): void { this.editingClass = null; this.clsForm = { name: '', section: 'A', teacher: '' }; this.formError = ''; this.showClass = true; }
  editClass(c: ClassDto): void { this.editingClass = c; this.clsForm = { name: c.name, section: '', teacher: '' }; this.formError = ''; this.showClass = true; }
  saveClass(): void {
    if (!this.clsForm.name.trim()) { this.formError = 'Class name is required.'; return; }
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
  openSection(c?: ClassDto): void { this.editingSection = null; this.secForm = { classId: c?.id ?? this.classes[0]?.id ?? 0, name: '', teacher: '' }; this.formError = ''; this.showSection = true; }
  editSection(c: ClassDto, s: SectionDto): void { this.editingSection = s; this.secForm = { classId: c.id, name: s.name, teacher: s.teacher ?? '' }; this.formError = ''; this.showSection = true; }
  saveSection(): void {
    if (!this.secForm.classId || !this.secForm.name.trim()) { this.formError = 'Class and section name are required.'; return; }
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
      <div class="grow"><h1>Notice Board</h1><div class="page-sub">{{ notices.length }} notices</div></div>
    </div>

    <div class="grid-2">
      <div class="card">
        @if (loading) { <div class="empty">Loading…</div> }
        @else if (error) { <div class="empty">{{ error }}</div> }
        @else {
          @for (n of notices; track n.id) {
            <div class="notice-item">
              <div class="notice-title">{{ n.title }}</div>
              <div class="notice-meta">{{ n.publishDate | date:'mediumDate' }} · Audience: {{ n.audience }}</div>
              <div class="notice-body">{{ n.body }}</div>
            </div>
          } @empty { <div class="empty">No notices yet.</div> }
        }
      </div>

      <div class="card">
        <div class="card-head"><h2 class="grow">Publish New Notice</h2></div>
        <div class="card-body">
          <div class="field"><label>Title</label><input class="input" [(ngModel)]="title" /></div>
          <div class="field"><label>Audience</label>
            <select class="select" [(ngModel)]="audience"><option value="all">All</option><option value="students">Students</option><option value="teachers">Teachers</option><option value="parents">Parents</option><option value="staff">Staff</option></select>
          </div>
          <div class="field"><label>Notice</label><textarea class="input" rows="5" [(ngModel)]="body"></textarea></div>
          @if (error2) { <div style="color:var(--crit-text);font-size:13px;">{{ error2 }}</div> }
          <button class="btn btn-primary" (click)="publish()" [disabled]="saving || !title.trim() || !body.trim()">{{ saving ? 'Publishing…' : 'Publish Notice' }}</button>
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
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void { this.reload(); }
  reload(): void {
    this.api.getNotices().subscribe({
      next: n => { this.notices = n; this.loading = false; this.error = ''; },
      error: e => { this.error = adminApiError(e); this.loading = false; },
    });
  }
  publish(): void {
    if (!this.title.trim() || !this.body.trim()) return;
    this.saving = true; this.error2 = '';
    this.api.createNotice(this.title.trim(), this.body.trim(), this.audience).subscribe({
      next: () => { this.saving = false; this.title = ''; this.body = ''; this.showToast('Notice published'); this.reload(); },
      error: e => { this.saving = false; this.error2 = adminApiError(e); },
    });
  }
  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }
}
