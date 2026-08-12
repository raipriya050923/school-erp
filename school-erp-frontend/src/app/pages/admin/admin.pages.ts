import { Component, inject } from '@angular/core';
import { DecimalPipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ClassSection, DataService, Exam, ExamPaper, FeeInvoice, SchoolClass, Student, Teacher } from '../../core/data.service';

/* =====================  DASHBOARD  ===================== */

@Component({
  selector: 'app-ad-dashboard',
  standalone: true,
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Sunrise Public School</h1>
        <div class="page-sub">Academic Year 2083 (2026/27) · Friday, July 4, 2026</div>
      </div>
    </div>

    <div class="stat-grid">
      @for (s of data.adminStats; track s.label) {
        <div class="stat-tile">
          <div class="stat-label">{{ s.label }}</div>
          <div class="stat-value">{{ s.value }}</div>
          <div class="stat-sub" [class.up]="s.trend === 'up'" [class.down]="s.trend === 'down'">{{ s.sub }}</div>
        </div>
      }
    </div>

    <div class="grid-2">
      <div class="card">
        <div class="card-head"><h2 class="grow">Recent Admissions</h2></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Student</th><th>Class</th><th>Date</th></tr></thead>
            <tbody>
              @for (a of data.recentAdmissions; track a.name) {
                <tr>
                  <td class="td-main">{{ a.name }}</td>
                  <td>{{ a.cls }}</td>
                  <td class="td-sub">{{ a.date }}</td>
                </tr>
              }
            </tbody>
          </table>
        </div>
      </div>

      <div class="card">
        <div class="card-head"><h2 class="grow">Upcoming Events</h2></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Event</th><th>Type</th><th>Date</th></tr></thead>
            <tbody>
              @for (e of data.upcomingEvents; track e.title) {
                <tr>
                  <td class="td-main">{{ e.title }}</td>
                  <td><span class="badge neutral">{{ e.type }}</span></td>
                  <td class="td-sub">{{ e.date }}</td>
                </tr>
              }
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <div class="card">
      <div class="card-head"><h2 class="grow">Latest Notices</h2></div>
      @for (n of data.notices.slice(0, 3); track n.title) {
        <div class="notice-item">
          <div class="notice-title">{{ n.title }}</div>
          <div class="notice-meta">{{ n.date }} · Audience: {{ n.audience }}</div>
          <div class="notice-body">{{ n.body }}</div>
        </div>
      }
    </div>
  `,
})
export class AdDashboardComponent {
  readonly data = inject(DataService);
}

/* =====================  STUDENTS  ===================== */

@Component({
  selector: 'app-ad-students',
  standalone: true,
  imports: [FormsModule, DecimalPipe],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Student Management</h1>
        <div class="page-sub">{{ filtered.length }} students</div>
      </div>
      <button class="btn btn-primary" (click)="openForm()">+ New Admission</button>
    </div>

    <div class="card">
      <div class="card-head filters">
        <input class="input grow" placeholder="Search name, admission no or guardian…" [(ngModel)]="q" />
        <select class="select" [(ngModel)]="cls">
          <option value="">All classes</option>
          @for (c of data.classes; track c.name) { <option [value]="c.name">{{ c.name }}</option> }
        </select>
      </div>
      <div class="table-wrap">
        <table class="data-table">
          <thead>
            <tr><th>Admission #</th><th>Name</th><th>Class</th><th class="num">Roll</th><th>Guardian</th><th>Phone</th><th class="num">Fee Due</th><th>Status</th><th>Actions</th></tr>
          </thead>
          <tbody>
            @for (s of filtered; track s.adm) {
              <tr>
                <td class="td-sub">{{ s.adm }}</td>
                <td class="td-main">{{ s.name }}</td>
                <td>{{ s.cls }}-{{ s.sec }}</td>
                <td class="num">{{ s.roll }}</td>
                <td>{{ s.guardian }}</td>
                <td class="td-sub">{{ s.phone }}</td>
                <td class="num">
                  @if (s.feeDue > 0) { <span style="color: var(--crit-text); font-weight: 600;">Rs {{ s.feeDue | number }}</span> }
                  @else { <span class="td-sub">—</span> }
                </td>
                <td><span class="badge" [class]="'badge ' + data.badgeClass(s.status)">{{ s.status }}</span></td>
                <td>
                  <div class="row-actions">
                    <button class="icon-action primary" (click)="viewing = s" title="View admission" aria-label="View admission">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7-11-7-11-7z"/><circle cx="12" cy="12" r="3"/>
                      </svg>
                    </button>
                    <button class="icon-action primary" (click)="edit(s)" title="Edit student" aria-label="Edit student">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/>
                      </svg>
                    </button>
                    @if (s.status === 'Inactive') {
                      <button class="icon-action success" (click)="activate(s)" title="Reactivate admission" aria-label="Reactivate admission">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                          <circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.5 2.5L16 9"/>
                        </svg>
                      </button>
                    } @else {
                      <button class="icon-action danger" (click)="deactivate(s)" title="Deactivate admission" aria-label="Deactivate admission">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                          <circle cx="12" cy="12" r="9"/><line x1="5.6" y1="5.6" x2="18.4" y2="18.4"/>
                        </svg>
                      </button>
                    }
                  </div>
                </td>
              </tr>
            } @empty {
              <tr><td colspan="9"><div class="empty">No students match the current filter.</div></td></tr>
            }
          </tbody>
        </table>
      </div>
    </div>

    <!-- View admission modal -->
    @if (viewing; as s) {
      <div class="modal-backdrop" (click)="viewing = null">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head">
            <h2>{{ s.name }}</h2>
            <button class="modal-close" (click)="viewing = null" aria-label="Close">✕</button>
          </div>
          <div class="modal-body">
            <div class="kv-row"><span class="kv-label">Admission #</span><span class="kv-value">{{ s.adm }}</span></div>
            <div class="kv-row"><span class="kv-label">Class / Section</span><span class="kv-value">{{ s.cls }} — {{ s.sec }}</span></div>
            <div class="kv-row"><span class="kv-label">Roll no</span><span class="kv-value">{{ s.roll }}</span></div>
            <div class="kv-row"><span class="kv-label">Gender</span><span class="kv-value">{{ s.gender === 'M' ? 'Male' : 'Female' }}</span></div>
            <div class="kv-row"><span class="kv-label">Date of birth</span><span class="kv-value">{{ s.dob || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Blood group</span><span class="kv-value">{{ s.bloodGroup || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Address</span><span class="kv-value">{{ s.address || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">City</span><span class="kv-value">{{ s.city || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">State / Province</span><span class="kv-value">{{ s.state || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Pincode</span><span class="kv-value">{{ s.pincode || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Guardian</span><span class="kv-value">{{ s.guardian }}</span></div>
            <div class="kv-row"><span class="kv-label">Guardian phone</span><span class="kv-value">{{ s.phone }}</span></div>
            <div class="kv-row"><span class="kv-label">Email</span><span class="kv-value">{{ s.email || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Previous school</span><span class="kv-value">{{ s.previousSchool || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Admission date</span><span class="kv-value">{{ s.admissionDate || '—' }}</span></div>
            <div class="kv-row">
              <span class="kv-label">Fee due</span>
              <span class="kv-value">
                @if (s.feeDue > 0) { <span style="color: var(--crit-text);">Rs {{ s.feeDue | number }}</span> }
                @else { Cleared }
              </span>
            </div>
            <div class="kv-row">
              <span class="kv-label">Status</span>
              <span class="kv-value"><span class="badge" [class]="'badge ' + data.badgeClass(s.status)">{{ s.status }}</span></span>
            </div>
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="viewing = null">Close</button>
          </div>
        </div>
      </div>
    }

    <!-- New admission / edit student modal -->
    @if (showForm) {
      <div class="modal-backdrop" (click)="showForm = false">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head">
            <h2>{{ editing ? 'Edit Student — ' + editing.adm : 'New Admission — AY 2083' }}</h2>
            <button class="modal-close" (click)="showForm = false" aria-label="Close">✕</button>
          </div>
          <div class="modal-body">
            <div class="field">
              <label>Student full name *</label>
              <input class="input" [(ngModel)]="form.name" placeholder="e.g. Nirjala Basnet" />
            </div>
            <div class="form-row">
              <div class="field">
                <label>Class *</label>
                <select class="select" [(ngModel)]="form.cls">
                  @for (c of data.classes; track c.name) { <option [value]="c.name">{{ c.name }}</option> }
                </select>
              </div>
              <div class="field">
                <label>Section *</label>
                <select class="select" [(ngModel)]="form.sec">
                  <option>A</option><option>B</option>
                </select>
              </div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Roll no</label>
                <input class="input" type="number" min="1" [(ngModel)]="form.roll" />
              </div>
              <div class="field">
                <label>Gender</label>
                <select class="select" [(ngModel)]="form.gender">
                  <option value="M">Male</option>
                  <option value="F">Female</option>
                </select>
              </div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Date of birth</label>
                <input class="input" type="date" [(ngModel)]="form.dob" />
              </div>
              <div class="field">
                <label>Blood group</label>
                <select class="select" [(ngModel)]="form.bloodGroup">
                  <option value="">Unknown</option>
                  <option>A+</option><option>A−</option><option>B+</option><option>B−</option>
                  <option>O+</option><option>O−</option><option>AB+</option><option>AB−</option>
                </select>
              </div>
            </div>
            <div class="field">
              <label>Address</label>
              <input class="input" [(ngModel)]="form.address" placeholder="Street / tole / ward, e.g. Baneshwor-10" />
            </div>
            <div class="form-row">
              <div class="field">
                <label>City</label>
                <input class="input" [(ngModel)]="form.city" placeholder="e.g. Kathmandu" />
              </div>
              <div class="field">
                <label>State / Province</label>
                <input class="input" [(ngModel)]="form.state" placeholder="e.g. Bagmati" />
              </div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Pincode</label>
                <input class="input" [(ngModel)]="form.pincode" placeholder="e.g. 44600" />
              </div>
              <div class="field"></div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Guardian name *</label>
                <input class="input" [(ngModel)]="form.guardian" placeholder="Parent / guardian" />
              </div>
              <div class="field">
                <label>Guardian phone *</label>
                <input class="input" [(ngModel)]="form.phone" placeholder="98XXXXXXXX" />
              </div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Email (optional)</label>
                <input class="input" type="email" [(ngModel)]="form.email" placeholder="student@example.com" />
              </div>
              <div class="field">
                <label>Previous school</label>
                <input class="input" [(ngModel)]="form.previousSchool" placeholder="If transferring" />
              </div>
            </div>
            @if (error) {
              <div style="color: var(--crit-text); font-size: 13px;">{{ error }}</div>
            }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showForm = false">Cancel</button>
            <button class="btn btn-primary" (click)="save()">{{ editing ? 'Save Changes' : 'Admit Student' }}</button>
          </div>
        </div>
      </div>
    }

    @if (toast) {
      <div class="toast success">{{ toast }}</div>
    }
  `,
})
export class AdStudentsComponent {
  readonly data = inject(DataService);
  q = '';
  cls = '';
  showForm = false;
  error = '';
  toast = '';
  viewing: Student | null = null;
  editing: Student | null = null;
  form = this.emptyForm();
  private toastTimer: ReturnType<typeof setTimeout> | undefined;

  get filtered() {
    const q = this.q.trim().toLowerCase();
    return this.data.students.filter(s =>
      (!this.cls || s.cls === this.cls) &&
      (!q || [s.name, s.adm, s.guardian].some(v => v.toLowerCase().includes(q))),
    );
  }

  openForm(): void {
    this.editing = null;
    this.form = this.emptyForm();
    this.error = '';
    this.showForm = true;
  }

  edit(s: Student): void {
    this.editing = s;
    this.form = {
      name: s.name, cls: s.cls, sec: s.sec, roll: s.roll,
      gender: s.gender, guardian: s.guardian, phone: s.phone,
      dob: s.dob ?? '', bloodGroup: s.bloodGroup ?? '', address: s.address ?? '',
      city: s.city ?? '', state: s.state ?? '', pincode: s.pincode ?? '',
      email: s.email ?? '', previousSchool: s.previousSchool ?? '',
    };
    this.error = '';
    this.showForm = true;
  }

  save(): void {
    const { name, guardian, phone } = this.form;
    if (!name.trim() || !guardian.trim() || !phone.trim()) {
      this.error = 'Name, guardian and phone are required.';
      return;
    }
    const details = {
      name: name.trim(),
      cls: this.form.cls,
      sec: this.form.sec,
      roll: Number(this.form.roll) || 0,
      gender: this.form.gender,
      guardian: guardian.trim(),
      phone: phone.trim(),
      dob: this.form.dob,
      bloodGroup: this.form.bloodGroup,
      address: this.form.address.trim(),
      city: this.form.city.trim(),
      state: this.form.state.trim(),
      pincode: this.form.pincode.trim(),
      email: this.form.email.trim(),
      previousSchool: this.form.previousSchool.trim(),
    };
    if (this.editing) {
      Object.assign(this.editing, details);
      this.showToast(`${details.name} updated (${this.editing.adm})`);
    } else {
      const adm = this.data.addStudent({ ...details, admissionDate: '2026-07-04' });
      this.q = '';
      this.cls = '';
      this.showToast(`${details.name} admitted to ${this.form.cls}-${this.form.sec} (${adm})`);
    }
    this.showForm = false;
    this.editing = null;
  }

  deactivate(s: Student): void {
    if (confirm(`Deactivate admission for ${s.name} (${s.adm})?\n\nThe student will lose portal access and be excluded from attendance & fee runs.`)) {
      s.status = 'Inactive';
      this.showToast(`${s.name} deactivated`);
    }
  }

  activate(s: Student): void {
    s.status = 'Active';
    this.showToast(`${s.name} reactivated`);
  }

  private showToast(msg: string): void {
    this.toast = msg;
    clearTimeout(this.toastTimer);
    this.toastTimer = setTimeout(() => (this.toast = ''), 3500);
  }

  private emptyForm() {
    return {
      name: '', cls: 'Grade 6', sec: 'A', roll: 1, gender: 'M', guardian: '', phone: '',
      dob: '', bloodGroup: '', address: '', city: '', state: '', pincode: '',
      email: '', previousSchool: '',
    };
  }
}

/* =====================  TEACHERS  ===================== */

@Component({
  selector: 'app-ad-teachers',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Teacher Management</h1>
        <div class="page-sub">{{ filtered.length }} teaching staff</div>
      </div>
      <button class="btn btn-primary" (click)="openForm()">+ Add Teacher</button>
    </div>

    <div class="card">
      <div class="card-head">
        <input class="input grow" placeholder="Search by name or subject…" [(ngModel)]="q" />
      </div>
      <div class="table-wrap">
        <table class="data-table">
          <thead>
            <tr><th>Emp. Code</th><th>Name</th><th>Subject</th><th>Classes</th><th>Phone</th><th>Email</th><th>Status</th><th>Actions</th></tr>
          </thead>
          <tbody>
            @for (t of filtered; track t.code) {
              <tr>
                <td class="td-sub">{{ t.code }}</td>
                <td class="td-main">{{ t.name }}</td>
                <td>{{ t.subject }}</td>
                <td class="td-sub">{{ t.classes }}</td>
                <td class="td-sub">{{ t.phone }}</td>
                <td class="td-sub">{{ t.email }}</td>
                <td><span class="badge" [class]="'badge ' + data.badgeClass(t.status)">{{ t.status }}</span></td>
                <td>
                  <div class="row-actions">
                    <button class="icon-action primary" (click)="viewing = t" title="View teacher" aria-label="View teacher">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7-11-7-11-7z"/><circle cx="12" cy="12" r="3"/>
                      </svg>
                    </button>
                    <button class="icon-action primary" (click)="edit(t)" title="Edit teacher" aria-label="Edit teacher">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/>
                      </svg>
                    </button>
                    @if (t.status === 'Inactive') {
                      <button class="icon-action success" (click)="activate(t)" title="Reactivate teacher" aria-label="Reactivate teacher">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                          <circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.5 2.5L16 9"/>
                        </svg>
                      </button>
                    } @else {
                      <button class="icon-action danger" (click)="deactivate(t)" title="Deactivate teacher" aria-label="Deactivate teacher">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                          <circle cx="12" cy="12" r="9"/><line x1="5.6" y1="5.6" x2="18.4" y2="18.4"/>
                        </svg>
                      </button>
                    }
                  </div>
                </td>
              </tr>
            } @empty {
              <tr><td colspan="8"><div class="empty">No teachers match “{{ q }}”.</div></td></tr>
            }
          </tbody>
        </table>
      </div>
    </div>

    <!-- View teacher modal -->
    @if (viewing; as t) {
      <div class="modal-backdrop" (click)="viewing = null">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head">
            <h2>{{ t.name }}</h2>
            <button class="modal-close" (click)="viewing = null" aria-label="Close">✕</button>
          </div>
          <div class="modal-body">
            <div class="kv-row"><span class="kv-label">Employee code</span><span class="kv-value">{{ t.code }}</span></div>
            <div class="kv-row"><span class="kv-label">Subject</span><span class="kv-value">{{ t.subject }}</span></div>
            <div class="kv-row"><span class="kv-label">Teaches classes</span><span class="kv-value">{{ t.classes }}</span></div>
            <div class="kv-row"><span class="kv-label">Phone</span><span class="kv-value">{{ t.phone }}</span></div>
            <div class="kv-row"><span class="kv-label">Email</span><span class="kv-value">{{ t.email }}</span></div>
            <div class="kv-row"><span class="kv-label">Qualification</span><span class="kv-value">{{ t.qualification || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Gender</span><span class="kv-value">{{ t.gender || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Date of birth</span><span class="kv-value">{{ t.dob || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Address</span><span class="kv-value">{{ t.address || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">City</span><span class="kv-value">{{ t.city || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">State / Province</span><span class="kv-value">{{ t.state || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Pincode</span><span class="kv-value">{{ t.pincode || '—' }}</span></div>
            <div class="kv-row"><span class="kv-label">Joined</span><span class="kv-value">{{ t.joined || '—' }}</span></div>
            <div class="kv-row">
              <span class="kv-label">Status</span>
              <span class="kv-value"><span class="badge" [class]="'badge ' + data.badgeClass(t.status)">{{ t.status }}</span></span>
            </div>
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="viewing = null">Close</button>
          </div>
        </div>
      </div>
    }

    <!-- Add / edit teacher modal -->
    @if (showForm) {
      <div class="modal-backdrop" (click)="showForm = false">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head">
            <h2>{{ editing ? 'Edit Teacher — ' + editing.code : 'Add Teacher' }}</h2>
            <button class="modal-close" (click)="showForm = false" aria-label="Close">✕</button>
          </div>
          <div class="modal-body">
            <div class="field">
              <label>Full name *</label>
              <input class="input" [(ngModel)]="form.name" placeholder="e.g. Manisha Regmi" />
            </div>
            <div class="form-row">
              <div class="field">
                <label>Subject *</label>
                <input class="input" [(ngModel)]="form.subject" placeholder="e.g. Science" />
              </div>
              <div class="field">
                <label>Classes taught</label>
                <input class="input" [(ngModel)]="form.classes" placeholder="e.g. G6, G7" />
              </div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Phone *</label>
                <input class="input" [(ngModel)]="form.phone" placeholder="98XXXXXXXX" />
              </div>
              <div class="field">
                <label>Email</label>
                <input class="input" type="email" [(ngModel)]="form.email" placeholder="name@sunrise.edu.np" />
              </div>
            </div>
            <div class="field">
              <label>Qualification</label>
              <input class="input" [(ngModel)]="form.qualification" placeholder="e.g. M.Sc. Physics, B.Ed." />
            </div>
            <div class="form-row">
              <div class="field">
                <label>Gender</label>
                <select class="select" [(ngModel)]="form.gender">
                  <option value="">Prefer not to say</option>
                  <option>Male</option><option>Female</option><option>Other</option>
                </select>
              </div>
              <div class="field">
                <label>Date of birth</label>
                <input class="input" type="date" [(ngModel)]="form.dob" />
              </div>
            </div>
            <div class="field">
              <label>Address</label>
              <input class="input" [(ngModel)]="form.address" placeholder="Street / tole / ward, e.g. Satdobato" />
            </div>
            <div class="form-row">
              <div class="field">
                <label>City</label>
                <input class="input" [(ngModel)]="form.city" placeholder="e.g. Lalitpur" />
              </div>
              <div class="field">
                <label>State / Province</label>
                <input class="input" [(ngModel)]="form.state" placeholder="e.g. Bagmati" />
              </div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Pincode</label>
                <input class="input" [(ngModel)]="form.pincode" placeholder="e.g. 44700" />
              </div>
              <div class="field"></div>
            </div>
            @if (error) {
              <div style="color: var(--crit-text); font-size: 13px;">{{ error }}</div>
            }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showForm = false">Cancel</button>
            <button class="btn btn-primary" (click)="save()">{{ editing ? 'Save Changes' : 'Add Teacher' }}</button>
          </div>
        </div>
      </div>
    }

    @if (toast) {
      <div class="toast success">{{ toast }}</div>
    }
  `,
})
export class AdTeachersComponent {
  readonly data = inject(DataService);
  q = '';
  showForm = false;
  error = '';
  toast = '';
  viewing: Teacher | null = null;
  editing: Teacher | null = null;
  form = this.emptyForm();
  private toastTimer: ReturnType<typeof setTimeout> | undefined;

  get filtered() {
    const q = this.q.trim().toLowerCase();
    if (!q) return this.data.teachers;
    return this.data.teachers.filter(t =>
      [t.name, t.subject].some(v => v.toLowerCase().includes(q)),
    );
  }

  openForm(): void {
    this.editing = null;
    this.form = this.emptyForm();
    this.error = '';
    this.showForm = true;
  }

  edit(t: Teacher): void {
    this.editing = t;
    this.form = {
      name: t.name, subject: t.subject, classes: t.classes === '—' ? '' : t.classes,
      phone: t.phone, email: t.email, qualification: t.qualification ?? '',
      gender: t.gender ?? '', dob: t.dob ?? '', address: t.address ?? '',
      city: t.city ?? '', state: t.state ?? '', pincode: t.pincode ?? '',
    };
    this.error = '';
    this.showForm = true;
  }

  save(): void {
    const { name, subject, phone } = this.form;
    if (!name.trim() || !subject.trim() || !phone.trim()) {
      this.error = 'Name, subject and phone are required.';
      return;
    }
    const details = {
      name: name.trim(),
      subject: subject.trim(),
      classes: this.form.classes.trim() || '—',
      phone: phone.trim(),
      email: this.form.email.trim(),
      qualification: this.form.qualification.trim(),
      gender: this.form.gender,
      dob: this.form.dob,
      address: this.form.address.trim(),
      city: this.form.city.trim(),
      state: this.form.state.trim(),
      pincode: this.form.pincode.trim(),
    };
    if (this.editing) {
      Object.assign(this.editing, details);
      this.showToast(`${details.name} updated (${this.editing.code})`);
    } else {
      const code = this.data.addTeacher({ ...details, joined: '2026-07-04' });
      this.q = '';
      this.showToast(`${details.name} added as ${details.subject} teacher (${code})`);
    }
    this.showForm = false;
    this.editing = null;
  }

  deactivate(t: Teacher): void {
    if (confirm(`Deactivate ${t.name} (${t.code})?\n\nThey will lose portal access and be removed from timetable assignment lists.`)) {
      t.status = 'Inactive';
      this.showToast(`${t.name} deactivated`);
    }
  }

  activate(t: Teacher): void {
    t.status = 'Active';
    this.showToast(`${t.name} reactivated`);
  }

  private showToast(msg: string): void {
    this.toast = msg;
    clearTimeout(this.toastTimer);
    this.toastTimer = setTimeout(() => (this.toast = ''), 3500);
  }

  private emptyForm() {
    return {
      name: '', subject: '', classes: '', phone: '', email: '', qualification: '',
      gender: '', dob: '', address: '', city: '', state: '', pincode: '',
    };
  }
}

/* =====================  CLASSES & SECTIONS  ===================== */

@Component({
  selector: 'app-ad-classes',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Classes &amp; Sections</h1>
        <div class="page-sub">Academic Year 2083 · {{ data.classes.length }} classes · {{ totalStudents }} students in {{ totalSections }} sections</div>
      </div>
      <button class="btn btn-ghost" (click)="openSection()">+ Add Section</button>
      <button class="btn btn-primary" (click)="openClass()">+ Add Class</button>
    </div>

    @for (c of data.classes; track c.name) {
      <div class="card">
        <div class="card-head">
          <h2 class="grow">{{ c.name }}</h2>
          <span class="td-sub">{{ c.sections.length }} sections · {{ classTotal(c) }} students</span>
          <button class="icon-action primary" (click)="editClass(c)" title="Rename class" aria-label="Rename class">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/>
            </svg>
          </button>
          <button class="icon-action danger" (click)="deleteClass(c)" title="Delete class" aria-label="Delete class">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M3 6h18M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2m2 0v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/>
            </svg>
          </button>
          <button class="btn btn-ghost btn-sm" (click)="openSection(c.name)">+ Section</button>
        </div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Section</th><th class="num">Students</th><th>Class Teacher</th><th>Capacity Utilisation</th><th>Actions</th></tr></thead>
            <tbody>
              @for (s of c.sections; track s.name) {
                <tr>
                  <td class="td-main">{{ c.name }} — {{ s.name }}</td>
                  <td class="num">{{ s.students }}</td>
                  <td>{{ s.teacher }}</td>
                  <td>
                    <div style="display:flex; align-items:center; gap:10px;">
                      <div class="meter" [class.good]="s.students / 45 <= 0.9" [class.low]="s.students / 45 > 0.98" style="flex:1; max-width:180px;">
                        <span [style.width.%]="(s.students / 45) * 100"></span>
                      </div>
                      <span class="td-sub">{{ s.students }}/45</span>
                    </div>
                  </td>
                  <td>
                    <div class="row-actions">
                      <button class="icon-action primary" (click)="editSection(c, s)" title="Edit section" aria-label="Edit section">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                          <path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/>
                        </svg>
                      </button>
                      <button class="icon-action danger" (click)="deleteSection(c, s)" title="Remove section" aria-label="Remove section">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                          <path d="M3 6h18M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2m2 0v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/>
                        </svg>
                      </button>
                    </div>
                  </td>
                </tr>
              } @empty {
                <tr><td colspan="5"><div class="empty">No sections yet — add one with “+ Section”.</div></td></tr>
              }
            </tbody>
          </table>
        </div>
      </div>
    }

    <!-- Add / edit class modal -->
    @if (showClass) {
      <div class="modal-backdrop" (click)="showClass = false">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head">
            <h2>{{ editingClass ? 'Rename Class — ' + editingClass.name : 'Add New Class' }}</h2>
            <button class="modal-close" (click)="showClass = false" aria-label="Close">✕</button>
          </div>
          <div class="modal-body">
            <div class="field">
              <label>Class name *</label>
              <input class="input" [(ngModel)]="clsForm.name" placeholder="e.g. Grade 11 or Nursery" />
            </div>
            @if (!editingClass) {
              <div class="form-row">
                <div class="field">
                  <label>First section</label>
                  <input class="input" [(ngModel)]="clsForm.section" placeholder="e.g. A" />
                </div>
                <div class="field">
                  <label>Class teacher</label>
                  <select class="select" [(ngModel)]="clsForm.teacher">
                    <option value="">Unassigned</option>
                    @for (t of activeTeachers; track t.code) { <option [value]="t.name">{{ t.name }}</option> }
                  </select>
                </div>
              </div>
              <div class="td-sub">A class must have at least one section. You can add more sections later.</div>
            } @else {
              <div class="td-sub">Renaming updates this class across all its sections.</div>
            }
            @if (error) {
              <div style="color: var(--crit-text); font-size: 13px; margin-top: 8px;">{{ error }}</div>
            }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showClass = false">Cancel</button>
            <button class="btn btn-primary" (click)="saveClass()">{{ editingClass ? 'Save Changes' : 'Add Class' }}</button>
          </div>
        </div>
      </div>
    }

    <!-- Add / edit section modal -->
    @if (showSection) {
      <div class="modal-backdrop" (click)="showSection = false">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head">
            <h2>{{ editingSection ? 'Edit Section' : 'Add Section' }}</h2>
            <button class="modal-close" (click)="showSection = false" aria-label="Close">✕</button>
          </div>
          <div class="modal-body">
            <div class="form-row">
              <div class="field">
                <label>Class *</label>
                <select class="select" [(ngModel)]="secForm.cls" [disabled]="!!editingSection">
                  @for (c of data.classes; track c.name) { <option [value]="c.name">{{ c.name }}</option> }
                </select>
              </div>
              <div class="field">
                <label>Section name *</label>
                <input class="input" [(ngModel)]="secForm.name" placeholder="e.g. C" />
              </div>
            </div>
            <div class="field">
              <label>Class teacher</label>
              <select class="select" [(ngModel)]="secForm.teacher">
                <option value="">Unassigned</option>
                @for (t of activeTeachers; track t.code) { <option [value]="t.name">{{ t.name }}</option> }
              </select>
            </div>
            @if (error) {
              <div style="color: var(--crit-text); font-size: 13px;">{{ error }}</div>
            }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showSection = false">Cancel</button>
            <button class="btn btn-primary" (click)="saveSection()">{{ editingSection ? 'Save Changes' : 'Add Section' }}</button>
          </div>
        </div>
      </div>
    }

    @if (toast) {
      <div class="toast success">{{ toast }}</div>
    }
  `,
})
export class AdClassesComponent {
  readonly data = inject(DataService);
  showClass = false;
  showSection = false;
  error = '';
  toast = '';
  editingClass: SchoolClass | null = null;
  editingSection: ClassSection | null = null;
  clsForm = { name: '', section: 'A', teacher: '' };
  secForm = { cls: '', name: '', teacher: '' };
  private toastTimer: ReturnType<typeof setTimeout> | undefined;

  get activeTeachers() {
    return this.data.teachers.filter(t => t.status === 'Active');
  }
  get totalStudents(): number {
    return this.data.classes.reduce((n, c) => n + this.classTotal(c), 0);
  }
  get totalSections(): number {
    return this.data.classes.reduce((n, c) => n + c.sections.length, 0);
  }
  classTotal(c: { sections: { students: number }[] }): number {
    return c.sections.reduce((n, s) => n + s.students, 0);
  }

  /* ---- class ---- */
  openClass(): void {
    this.editingClass = null;
    this.clsForm = { name: '', section: 'A', teacher: '' };
    this.error = '';
    this.showClass = true;
  }

  editClass(c: SchoolClass): void {
    this.editingClass = c;
    this.clsForm = { name: c.name, section: '', teacher: '' };
    this.error = '';
    this.showClass = true;
  }

  saveClass(): void {
    const name = this.clsForm.name.trim();
    if (!name) {
      this.error = 'Class name is required.';
      return;
    }
    const dupe = this.data.classes.some(c => c !== this.editingClass && c.name.toLowerCase() === name.toLowerCase());
    if (dupe) {
      this.error = `“${name}” already exists.`;
      return;
    }
    if (this.editingClass) {
      this.editingClass.name = name;
      this.showToast(`Class renamed to ${name}`);
    } else {
      const sec = this.clsForm.section.trim();
      this.data.addClass(name, sec ? { name: sec.toUpperCase(), teacher: this.clsForm.teacher } : undefined);
      this.showToast(`${name} added${sec ? ' with section ' + sec.toUpperCase() : ''}`);
    }
    this.showClass = false;
    this.editingClass = null;
  }

  deleteClass(c: SchoolClass): void {
    const count = this.classTotal(c);
    const warn = count > 0 ? `\n\n⚠ ${count} students are enrolled in this class.` : '';
    if (confirm(`Delete ${c.name} and its ${c.sections.length} section(s)?${warn}`)) {
      this.data.removeClass(c);
      this.showToast(`${c.name} deleted`);
    }
  }

  /* ---- section ---- */
  openSection(cls?: string): void {
    this.editingSection = null;
    this.secForm = { cls: cls ?? this.data.classes[0]?.name ?? '', name: '', teacher: '' };
    this.error = '';
    this.showSection = true;
  }

  editSection(c: SchoolClass, s: ClassSection): void {
    this.editingSection = s;
    this.secForm = { cls: c.name, name: s.name, teacher: s.teacher === 'Unassigned' ? '' : s.teacher };
    this.error = '';
    this.showSection = true;
  }

  saveSection(): void {
    const name = this.secForm.name.trim().toUpperCase();
    if (!this.secForm.cls || !name) {
      this.error = 'Class and section name are required.';
      return;
    }
    const cls = this.data.classes.find(c => c.name === this.secForm.cls);
    const dupe = cls?.sections.some(s => s !== this.editingSection && s.name.toUpperCase() === name);
    if (dupe) {
      this.error = `Section ${name} already exists in ${this.secForm.cls}.`;
      return;
    }
    if (this.editingSection) {
      this.editingSection.name = name;
      this.editingSection.teacher = this.secForm.teacher || 'Unassigned';
      this.showToast(`Section ${this.secForm.cls} — ${name} updated`);
    } else {
      this.data.addSection(this.secForm.cls, { name, teacher: this.secForm.teacher });
      this.showToast(`Section ${name} added to ${this.secForm.cls}`);
    }
    this.showSection = false;
    this.editingSection = null;
  }

  deleteSection(c: SchoolClass, s: ClassSection): void {
    const warn = s.students > 0 ? `\n\n⚠ ${s.students} students are in this section.` : '';
    if (confirm(`Remove section ${c.name} — ${s.name}?${warn}`)) {
      this.data.removeSection(c, s);
      this.showToast(`Section ${c.name} — ${s.name} removed`);
    }
  }

  private showToast(msg: string): void {
    this.toast = msg;
    clearTimeout(this.toastTimer);
    this.toastTimer = setTimeout(() => (this.toast = ''), 3500);
  }
}

/* =====================  ATTENDANCE  ===================== */

type AttStatus = 'P' | 'A' | 'L';

@Component({
  selector: 'app-ad-attendance',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Attendance</h1>
        <div class="page-sub">Mark or review daily attendance</div>
      </div>
    </div>

    <div class="card">
      <div class="card-head filters">
        <input class="input" type="date" [(ngModel)]="date" />
        <select class="select" [(ngModel)]="section">
          <option>Grade 8 — A</option>
          <option>Grade 8 — B</option>
          <option>Grade 9 — A</option>
        </select>
        <div class="grow"></div>
        <span class="td-sub">{{ presentCount }} present · {{ absentCount }} absent · {{ lateCount }} late</span>
        <button class="btn btn-primary" (click)="save()">Save Attendance</button>
      </div>
      <div class="table-wrap">
        <table class="data-table">
          <thead><tr><th class="num">Roll</th><th>Student</th><th>Status</th></tr></thead>
          <tbody>
            @for (s of roster; track s.roll) {
              <tr>
                <td class="num">{{ s.roll }}</td>
                <td class="td-main">{{ s.name }}</td>
                <td>
                  <div class="pill-group">
                    <button [class.on-p]="marks[s.roll] === 'P'" (click)="marks[s.roll] = 'P'">Present</button>
                    <button [class.on-a]="marks[s.roll] === 'A'" (click)="marks[s.roll] = 'A'">Absent</button>
                    <button [class.on-l]="marks[s.roll] === 'L'" (click)="marks[s.roll] = 'L'">Late</button>
                  </div>
                </td>
              </tr>
            }
          </tbody>
        </table>
      </div>
    </div>
  `,
})
export class AdAttendanceComponent {
  readonly data = inject(DataService);
  date = '2026-07-04';
  section = 'Grade 8 — A';
  readonly roster = this.data.classStudents;
  marks: Record<number, AttStatus> = Object.fromEntries(this.roster.map(s => [s.roll, 'P'])) as Record<number, AttStatus>;

  get presentCount() { return Object.values(this.marks).filter(v => v === 'P').length; }
  get absentCount() { return Object.values(this.marks).filter(v => v === 'A').length; }
  get lateCount() { return Object.values(this.marks).filter(v => v === 'L').length; }

  save(): void {
    alert(`Attendance saved (demo): ${this.presentCount} present, ${this.absentCount} absent, ${this.lateCount} late for ${this.section} on ${this.date}.`);
  }
}

/* =====================  FEES  ===================== */

@Component({
  selector: 'app-ad-fees',
  standalone: true,
  imports: [FormsModule, DecimalPipe],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Fee Management</h1>
        <div class="page-sub">{{ data.feeInvoices.length }} invoices</div>
      </div>
      <button class="btn btn-ghost" (click)="openGenerate()">Generate Invoices</button>
    </div>

    <div class="stat-grid">
      <div class="stat-tile">
        <div class="stat-label">Total Billed</div>
        <div class="stat-value">Rs {{ totalBilled | number }}</div>
        <div class="stat-sub">{{ data.feeInvoices.length }} invoices</div>
      </div>
      <div class="stat-tile">
        <div class="stat-label">Collected</div>
        <div class="stat-value">Rs {{ totalPaid | number }}</div>
        <div class="stat-sub up">{{ collectedPct }}% of billed</div>
      </div>
      <div class="stat-tile">
        <div class="stat-label">Outstanding</div>
        <div class="stat-value">Rs {{ outstanding | number }}</div>
        <div class="stat-sub" [class.down]="outstanding > 0">{{ unpaidCount }} unpaid / partial</div>
      </div>
      <div class="stat-tile">
        <div class="stat-label">Overdue</div>
        <div class="stat-value">{{ overdueCount }}</div>
        <div class="stat-sub down">invoices past due</div>
      </div>
    </div>

    <div class="card">
      <div class="card-head filters">
        <h2 class="grow">Invoices</h2>
        <select class="select" [(ngModel)]="status">
          <option value="">All statuses</option>
          <option>Paid</option><option>Partial</option><option>Unpaid</option><option>Overdue</option>
        </select>
      </div>
      <div class="table-wrap">
        <table class="data-table">
          <thead>
            <tr><th>Invoice #</th><th>Student</th><th>Class</th><th>Month</th><th class="num">Amount</th><th class="num">Paid</th><th class="num">Balance</th><th>Due Date</th><th>Status</th><th>Actions</th></tr>
          </thead>
          <tbody>
            @for (i of filtered; track i.no) {
              <tr>
                <td class="td-sub">{{ i.no }}</td>
                <td class="td-main">{{ i.student }}</td>
                <td>{{ i.cls }}</td>
                <td class="td-sub">{{ i.month }}</td>
                <td class="num">Rs {{ i.amount | number }}</td>
                <td class="num">Rs {{ i.paid | number }}</td>
                <td class="num">
                  @if (i.amount - i.paid > 0) { <span style="color: var(--crit-text); font-weight: 600;">Rs {{ i.amount - i.paid | number }}</span> }
                  @else { <span class="td-sub">—</span> }
                </td>
                <td class="td-sub">{{ i.due }}</td>
                <td><span class="badge" [class]="'badge ' + data.badgeClass(i.status)">{{ i.status }}</span></td>
                <td>
                  <div class="row-actions">
                    <button class="icon-action primary" (click)="viewing = i" title="View invoice" aria-label="View invoice">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7-11-7-11-7z"/><circle cx="12" cy="12" r="3"/>
                      </svg>
                    </button>
                    @if (i.status !== 'Paid') {
                      <button class="icon-action success" (click)="openPayment(i)" title="Record payment" aria-label="Record payment">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                          <rect x="2" y="5" width="20" height="14" rx="2"/><line x1="2" y1="10" x2="22" y2="10"/>
                        </svg>
                      </button>
                    }
                  </div>
                </td>
              </tr>
            } @empty {
              <tr><td colspan="10"><div class="empty">No invoices in this status.</div></td></tr>
            }
          </tbody>
        </table>
      </div>
    </div>

    <!-- Generate invoices modal -->
    @if (showGenerate) {
      <div class="modal-backdrop" (click)="showGenerate = false">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head">
            <h2>Generate Monthly Invoices</h2>
            <button class="modal-close" (click)="showGenerate = false" aria-label="Close">✕</button>
          </div>
          <div class="modal-body">
            <div class="form-row">
              <div class="field">
                <label>Billing month *</label>
                <input class="input" [(ngModel)]="genForm.month" placeholder="e.g. August 2026" />
              </div>
              <div class="field">
                <label>Due date *</label>
                <input class="input" type="date" [(ngModel)]="genForm.due" />
              </div>
            </div>
            <div class="field">
              <label>Class</label>
              <select class="select" [(ngModel)]="genForm.cls">
                <option value="All">All classes</option>
                @for (c of data.classes; track c.name) { <option [value]="c.name">{{ c.name }}</option> }
              </select>
            </div>
            <div class="td-sub">
              Creates one invoice per active student using each class's monthly tuition rate.
              Students who already have an invoice for this month are skipped.
            </div>
            @if (error) {
              <div style="color: var(--crit-text); font-size: 13px; margin-top: 8px;">{{ error }}</div>
            }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showGenerate = false">Cancel</button>
            <button class="btn btn-primary" (click)="generate()">Generate Invoices</button>
          </div>
        </div>
      </div>
    }

    <!-- Record payment modal -->
    @if (paying; as inv) {
      <div class="modal-backdrop" (click)="paying = null">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head">
            <h2>Record Payment — {{ inv.no }}</h2>
            <button class="modal-close" (click)="paying = null" aria-label="Close">✕</button>
          </div>
          <div class="modal-body">
            <div class="kv-row"><span class="kv-label">Student</span><span class="kv-value">{{ inv.student }} · {{ inv.cls }}</span></div>
            <div class="kv-row"><span class="kv-label">Invoice amount</span><span class="kv-value">Rs {{ inv.amount | number }}</span></div>
            <div class="kv-row"><span class="kv-label">Already paid</span><span class="kv-value">Rs {{ inv.paid | number }}</span></div>
            <div class="kv-row" style="margin-bottom: 12px;">
              <span class="kv-label">Balance due</span>
              <span class="kv-value" style="color: var(--crit-text);">Rs {{ inv.amount - inv.paid | number }}</span>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Amount received (Rs) *</label>
                <input class="input" type="number" min="0" [max]="inv.amount - inv.paid" [(ngModel)]="payForm.amount" />
              </div>
              <div class="field">
                <label>Payment date</label>
                <input class="input" type="date" [(ngModel)]="payForm.date" />
              </div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Method</label>
                <select class="select" [(ngModel)]="payForm.method">
                  <option>Cash</option><option>eSewa</option><option>Khalti</option>
                  <option>Bank transfer</option><option>Cheque</option><option>Card</option>
                </select>
              </div>
              <div class="field">
                <label>Reference / receipt</label>
                <input class="input" [(ngModel)]="payForm.ref" placeholder="optional" />
              </div>
            </div>
            @if (error) {
              <div style="color: var(--crit-text); font-size: 13px;">{{ error }}</div>
            }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="paying = null">Cancel</button>
            <button class="btn btn-primary" (click)="savePayment()">Record Payment</button>
          </div>
        </div>
      </div>
    }

    <!-- View invoice modal -->
    @if (viewing; as inv) {
      <div class="modal-backdrop" (click)="viewing = null">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head">
            <h2>Invoice {{ inv.no }}</h2>
            <button class="modal-close" (click)="viewing = null" aria-label="Close">✕</button>
          </div>
          <div class="modal-body">
            <div class="kv-row"><span class="kv-label">Student</span><span class="kv-value">{{ inv.student }}</span></div>
            <div class="kv-row"><span class="kv-label">Class</span><span class="kv-value">{{ inv.cls }}</span></div>
            <div class="kv-row"><span class="kv-label">Billing month</span><span class="kv-value">{{ inv.month }}</span></div>
            <div class="kv-row"><span class="kv-label">Amount</span><span class="kv-value">Rs {{ inv.amount | number }}</span></div>
            <div class="kv-row"><span class="kv-label">Paid</span><span class="kv-value">Rs {{ inv.paid | number }}</span></div>
            <div class="kv-row"><span class="kv-label">Balance</span><span class="kv-value">Rs {{ inv.amount - inv.paid | number }}</span></div>
            <div class="kv-row"><span class="kv-label">Due date</span><span class="kv-value">{{ inv.due }}</span></div>
            <div class="kv-row">
              <span class="kv-label">Status</span>
              <span class="kv-value"><span class="badge" [class]="'badge ' + data.badgeClass(inv.status)">{{ inv.status }}</span></span>
            </div>
            @if (inv.payments && inv.payments.length) {
              <div style="margin-top: 14px;">
                <div style="font-size: 11px; text-transform: uppercase; letter-spacing: 0.6px; color: var(--muted); margin-bottom: 8px;">Payment History</div>
                <table class="data-table">
                  <thead><tr><th>Date</th><th>Method</th><th>Ref</th><th class="num">Amount</th></tr></thead>
                  <tbody>
                    @for (p of inv.payments; track $index) {
                      <tr>
                        <td class="td-sub">{{ p.date }}</td>
                        <td>{{ p.method }}</td>
                        <td class="td-sub">{{ p.ref || '—' }}</td>
                        <td class="num">Rs {{ p.amount | number }}</td>
                      </tr>
                    }
                  </tbody>
                </table>
              </div>
            }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="viewing = null">Close</button>
            @if (inv.status !== 'Paid') {
              <button class="btn btn-primary" (click)="openPayment(inv); viewing = null">Record Payment</button>
            }
          </div>
        </div>
      </div>
    }

    @if (toast) {
      <div class="toast success">{{ toast }}</div>
    }
  `,
})
export class AdFeesComponent {
  readonly data = inject(DataService);
  status = '';
  showGenerate = false;
  error = '';
  toast = '';
  paying: FeeInvoice | null = null;
  viewing: FeeInvoice | null = null;
  genForm = { month: 'August 2026', due: '2026-08-10', cls: 'All' };
  payForm = { amount: 0, date: '2026-07-04', method: 'Cash', ref: '' };
  private toastTimer: ReturnType<typeof setTimeout> | undefined;

  get filtered() {
    return this.status ? this.data.feeInvoices.filter(i => i.status === this.status) : this.data.feeInvoices;
  }
  get totalBilled() { return this.data.feeInvoices.reduce((n, i) => n + i.amount, 0); }
  get totalPaid() { return this.data.feeInvoices.reduce((n, i) => n + i.paid, 0); }
  get outstanding() { return this.totalBilled - this.totalPaid; }
  get collectedPct() { return this.totalBilled ? Math.round((this.totalPaid / this.totalBilled) * 100) : 0; }
  get unpaidCount() { return this.data.feeInvoices.filter(i => i.status === 'Unpaid' || i.status === 'Partial').length; }
  get overdueCount() { return this.data.feeInvoices.filter(i => i.status === 'Overdue').length; }

  openGenerate(): void {
    this.genForm = { month: 'August 2026', due: '2026-08-10', cls: 'All' };
    this.error = '';
    this.showGenerate = true;
  }

  generate(): void {
    if (!this.genForm.month.trim() || !this.genForm.due) {
      this.error = 'Billing month and due date are required.';
      return;
    }
    const count = this.data.generateInvoices(this.genForm.month.trim(), this.genForm.due, this.genForm.cls);
    this.showGenerate = false;
    this.showToast(count > 0
      ? `${count} invoice(s) generated for ${this.genForm.month.trim()}`
      : `No new invoices — all students already billed for ${this.genForm.month.trim()}`);
  }

  openPayment(i: FeeInvoice): void {
    this.paying = i;
    this.error = '';
    this.payForm = { amount: i.amount - i.paid, date: '2026-07-04', method: 'Cash', ref: '' };
  }

  savePayment(): void {
    if (!this.paying) return;
    const bal = this.paying.amount - this.paying.paid;
    const amt = Number(this.payForm.amount);
    if (!amt || amt <= 0) { this.error = 'Enter a valid amount.'; return; }
    if (amt > bal) { this.error = `Amount cannot exceed the balance of Rs ${bal.toLocaleString()}.`; return; }
    this.data.recordFeePayment(this.paying, amt, this.payForm.method, this.payForm.ref.trim(), this.payForm.date);
    const status = this.paying.status;
    this.showToast(`Rs ${amt.toLocaleString()} recorded for ${this.paying.student} — invoice now ${status}`);
    this.paying = null;
  }

  private showToast(msg: string): void {
    this.toast = msg;
    clearTimeout(this.toastTimer);
    this.toastTimer = setTimeout(() => (this.toast = ''), 3500);
  }
}

/* =====================  EXAMS  ===================== */

@Component({
  selector: 'app-ad-exams',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Examination Management</h1>
        <div class="page-sub">Exams for Academic Year 2083</div>
      </div>
      <button class="btn btn-primary" (click)="openExam()">+ Schedule Exam</button>
    </div>

    <div class="card">
      <div class="card-head"><h2 class="grow">Examinations</h2></div>
      <div class="table-wrap">
        <table class="data-table">
          <thead><tr><th>Examination</th><th>Type</th><th>Dates</th><th>Classes</th><th class="num">Papers</th><th>Status</th><th>Actions</th></tr></thead>
          <tbody>
            @for (e of data.exams; track e.name) {
              <tr [class.row-selected]="e === selected">
                <td class="td-main">{{ e.name }}</td>
                <td>{{ e.type }}</td>
                <td class="td-sub">{{ e.start }} → {{ e.end }}</td>
                <td class="td-sub">{{ e.classes }}</td>
                <td class="num">{{ e.schedule.length }}</td>
                <td><span class="badge" [class]="'badge ' + data.badgeClass(e.status)">{{ e.status }}</span></td>
                <td>
                  <div class="row-actions">
                    <button class="icon-action primary" (click)="selected = e" title="View / edit schedule" aria-label="View schedule">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <rect x="3" y="4" width="18" height="18" rx="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="16" y1="2" x2="16" y2="6"/>
                      </svg>
                    </button>
                    <button class="icon-action" (click)="editExam(e)" title="Edit exam" aria-label="Edit exam">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/>
                      </svg>
                    </button>
                  </div>
                </td>
              </tr>
            }
          </tbody>
        </table>
      </div>
    </div>

    @if (selected; as e) {
      <div class="card">
        <div class="card-head">
          <div class="grow">
            <h2>Subject Schedule — {{ e.name }}</h2>
            <div class="page-sub">{{ e.classes }} · {{ e.schedule.length }} papers</div>
          </div>
          <button class="btn btn-primary btn-sm" (click)="openPaper(e)">+ Add Subject</button>
        </div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Date</th><th>Subject</th><th>Time</th><th>Room</th><th class="num">Full Marks</th><th>Actions</th></tr></thead>
            <tbody>
              @for (s of e.schedule; track $index) {
                <tr>
                  <td class="td-sub">{{ s.date }}</td>
                  <td class="td-main">{{ s.subject }}</td>
                  <td>{{ s.time }}</td>
                  <td>{{ s.room }}</td>
                  <td class="num">{{ s.fullMarks }}</td>
                  <td>
                    <button class="icon-action danger" (click)="removePaper(e, s)" title="Remove subject" aria-label="Remove subject">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M3 6h18M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2m2 0v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/>
                      </svg>
                    </button>
                  </td>
                </tr>
              } @empty {
                <tr><td colspan="6"><div class="empty">No papers scheduled yet — add subjects with “+ Add Subject”.</div></td></tr>
              }
            </tbody>
          </table>
        </div>
      </div>
    } @else {
      <div class="card"><div class="empty">Select an exam above (📅) to view and edit its subject schedule.</div></div>
    }

    <!-- Schedule / edit exam modal -->
    @if (showExam) {
      <div class="modal-backdrop" (click)="showExam = false">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head">
            <h2>{{ editingExam ? 'Edit Exam' : 'Schedule New Exam' }}</h2>
            <button class="modal-close" (click)="showExam = false" aria-label="Close">✕</button>
          </div>
          <div class="modal-body">
            <div class="field">
              <label>Examination name *</label>
              <input class="input" [(ngModel)]="examForm.name" placeholder="e.g. Second Terminal Examination 2083" />
            </div>
            <div class="form-row">
              <div class="field">
                <label>Type</label>
                <select class="select" [(ngModel)]="examForm.type">
                  <option>Unit Test</option><option>Term</option><option>Quarterly</option>
                  <option>Half Yearly</option><option>Final</option>
                </select>
              </div>
              <div class="field">
                <label>Classes</label>
                <input class="input" [(ngModel)]="examForm.classes" placeholder="e.g. G6–G10" />
              </div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Start date *</label>
                <input class="input" type="date" [(ngModel)]="examForm.start" />
              </div>
              <div class="field">
                <label>End date *</label>
                <input class="input" type="date" [(ngModel)]="examForm.end" />
              </div>
            </div>
            @if (error) {
              <div style="color: var(--crit-text); font-size: 13px;">{{ error }}</div>
            }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showExam = false">Cancel</button>
            <button class="btn btn-primary" (click)="saveExam()">{{ editingExam ? 'Save Changes' : 'Create Exam' }}</button>
          </div>
        </div>
      </div>
    }

    <!-- Add subject paper modal -->
    @if (showPaper) {
      <div class="modal-backdrop" (click)="showPaper = false">
        <div class="modal" (click)="$event.stopPropagation()">
          <div class="modal-head">
            <h2>Add Subject — {{ paperExam?.name }}</h2>
            <button class="modal-close" (click)="showPaper = false" aria-label="Close">✕</button>
          </div>
          <div class="modal-body">
            <div class="form-row">
              <div class="field">
                <label>Subject *</label>
                <select class="select" [(ngModel)]="paperForm.subject">
                  <option>English</option><option>Mathematics</option><option>Science</option>
                  <option>Nepali</option><option>Social Studies</option><option>Computer Science</option>
                  <option>Health &amp; PE</option><option>Optional Mathematics</option>
                </select>
              </div>
              <div class="field">
                <label>Exam date *</label>
                <input class="input" type="date" [(ngModel)]="paperForm.date" />
              </div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Start time</label>
                <input class="input" type="time" [(ngModel)]="paperForm.startTime" />
              </div>
              <div class="field">
                <label>End time</label>
                <input class="input" type="time" [(ngModel)]="paperForm.endTime" />
              </div>
            </div>
            <div class="form-row">
              <div class="field">
                <label>Room</label>
                <input class="input" [(ngModel)]="paperForm.room" placeholder="e.g. Hall A" />
              </div>
              <div class="field">
                <label>Full marks</label>
                <input class="input" type="number" min="1" [(ngModel)]="paperForm.fullMarks" />
              </div>
            </div>
            @if (error) {
              <div style="color: var(--crit-text); font-size: 13px;">{{ error }}</div>
            }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showPaper = false">Cancel</button>
            <button class="btn btn-primary" (click)="savePaper()">Add Subject</button>
          </div>
        </div>
      </div>
    }

    @if (toast) {
      <div class="toast success">{{ toast }}</div>
    }
  `,
  styles: [`.row-selected { background: var(--brand-tint) !important; }`],
})
export class AdExamsComponent {
  readonly data = inject(DataService);
  selected: Exam | null = this.data.exams[0] ?? null;
  showExam = false;
  showPaper = false;
  editingExam: Exam | null = null;
  paperExam: Exam | null = null;
  error = '';
  toast = '';
  examForm = this.emptyExam();
  paperForm = this.emptyPaper();
  private toastTimer: ReturnType<typeof setTimeout> | undefined;

  /* ---- exam ---- */
  openExam(): void {
    this.editingExam = null;
    this.examForm = this.emptyExam();
    this.error = '';
    this.showExam = true;
  }

  editExam(e: Exam): void {
    this.editingExam = e;
    this.examForm = { name: e.name, type: e.type, classes: e.classes, start: e.start, end: e.end };
    this.error = '';
    this.showExam = true;
  }

  saveExam(): void {
    const { name, start, end } = this.examForm;
    if (!name.trim() || !start || !end) {
      this.error = 'Name, start and end dates are required.';
      return;
    }
    if (start > end) {
      this.error = 'Start date must be on or before the end date.';
      return;
    }
    if (this.editingExam) {
      Object.assign(this.editingExam, {
        name: name.trim(), type: this.examForm.type, classes: this.examForm.classes.trim() || 'G6–G10',
        start, end,
      });
      this.showToast(`${name.trim()} updated`);
    } else {
      const exam = this.data.addExam({
        name: name.trim(), type: this.examForm.type, classes: this.examForm.classes.trim() || 'G6–G10',
        start, end,
      });
      this.selected = exam;
      this.showToast(`${name.trim()} scheduled — now add subjects`);
    }
    this.showExam = false;
    this.editingExam = null;
  }

  /* ---- paper ---- */
  openPaper(e: Exam): void {
    this.paperExam = e;
    this.paperForm = this.emptyPaper();
    this.paperForm.date = e.start;
    this.error = '';
    this.showPaper = true;
  }

  savePaper(): void {
    if (!this.paperExam) return;
    if (!this.paperForm.subject || !this.paperForm.date) {
      this.error = 'Subject and exam date are required.';
      return;
    }
    const dup = this.paperExam.schedule.some(p => p.subject === this.paperForm.subject);
    if (dup) {
      this.error = `${this.paperForm.subject} is already scheduled for this exam.`;
      return;
    }
    const time = this.paperForm.startTime && this.paperForm.endTime
      ? `${this.paperForm.startTime} – ${this.paperForm.endTime}`
      : this.paperForm.startTime || '—';
    this.data.addExamPaper(this.paperExam, {
      date: this.paperForm.date,
      subject: this.paperForm.subject,
      time,
      room: this.paperForm.room.trim() || '—',
      fullMarks: Number(this.paperForm.fullMarks) || 100,
    });
    this.showToast(`${this.paperForm.subject} added to ${this.paperExam.name}`);
    this.showPaper = false;
  }

  removePaper(e: Exam, s: ExamPaper): void {
    if (confirm(`Remove ${s.subject} (${s.date}) from ${e.name}?`)) {
      this.data.removeExamPaper(e, s);
      this.showToast(`${s.subject} removed`);
    }
  }

  private showToast(msg: string): void {
    this.toast = msg;
    clearTimeout(this.toastTimer);
    this.toastTimer = setTimeout(() => (this.toast = ''), 3500);
  }

  private emptyExam() {
    return { name: '', type: 'Term', classes: 'G6–G10', start: '', end: '' };
  }
  private emptyPaper() {
    return { subject: 'English', date: '', startTime: '08:00', endTime: '10:00', room: 'Hall A', fullMarks: 100 };
  }
}

/* =====================  NOTICES  ===================== */

@Component({
  selector: 'app-ad-notices',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Notice Board</h1>
        <div class="page-sub">{{ notices.length }} notices published</div>
      </div>
    </div>

    <div class="grid-2">
      <div class="card">
        @for (n of notices; track n.title) {
          <div class="notice-item">
            <div class="notice-title">{{ n.title }}</div>
            <div class="notice-meta">{{ n.date }} · Audience: {{ n.audience }}</div>
            <div class="notice-body">{{ n.body }}</div>
          </div>
        }
      </div>

      <div class="card">
        <div class="card-head"><h2 class="grow">Publish New Notice</h2></div>
        <div class="card-body">
          <div class="field">
            <label>Title</label>
            <input class="input" [(ngModel)]="title" placeholder="e.g. Library closed on Friday" />
          </div>
          <div class="field">
            <label>Audience</label>
            <select class="select" [(ngModel)]="audience">
              <option>All</option><option>Students</option><option>Teachers</option><option>Parents</option><option>Staff</option>
            </select>
          </div>
          <div class="field">
            <label>Notice</label>
            <textarea class="input" rows="5" [(ngModel)]="body" placeholder="Write the notice content…"></textarea>
          </div>
          <button class="btn btn-primary" (click)="publish()" [disabled]="!title.trim() || !body.trim()">Publish Notice</button>
        </div>
      </div>
    </div>
  `,
})
export class AdNoticesComponent {
  readonly data = inject(DataService);
  notices = [...this.data.notices];
  title = '';
  audience = 'All';
  body = '';

  publish(): void {
    this.notices.unshift({
      title: this.title.trim(),
      audience: this.audience,
      date: '2026-07-04',
      body: this.body.trim(),
    });
    this.title = '';
    this.body = '';
  }
}

/* =====================  STUDENT ATTENDANCE REPORT  ===================== */

interface AttRow { date: string; day: string; status: 'Present' | 'Absent' | 'Late' | 'Holiday'; }

@Component({
  selector: 'app-ad-attendance-report',
  standalone: true,
  imports: [FormsModule, DecimalPipe],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Student Attendance Report</h1>
        <div class="page-sub">View a student's day-by-day attendance for any date range</div>
      </div>
    </div>

    <div class="card">
      <div class="card-head filters">
        <div class="field" style="margin:0; min-width:240px;">
          <label>Student</label>
          <select class="select" [(ngModel)]="adm">
            <option value="">Select a student…</option>
            @for (s of data.students; track s.adm) {
              <option [value]="s.adm">{{ s.name }} — {{ s.cls }}-{{ s.sec }} (Roll {{ s.roll }})</option>
            }
          </select>
        </div>
        <div class="field" style="margin:0;">
          <label>From</label>
          <input class="input" type="date" [(ngModel)]="from" />
        </div>
        <div class="field" style="margin:0;">
          <label>To</label>
          <input class="input" type="date" [(ngModel)]="to" />
        </div>
        <div class="field" style="margin:0;">
          <label>&nbsp;</label>
          <button class="btn btn-primary" (click)="run()">Generate</button>
        </div>
      </div>
    </div>

    @if (loaded) {
      @if (rows.length === 0) {
        <div class="card"><div class="empty">No school days in this range, or invalid range (check From ≤ To).</div></div>
      } @else {
        <div class="stat-grid">
          <div class="stat-tile">
            <div class="stat-label">Attendance</div>
            <div class="stat-value">{{ pct }}%</div>
            <div class="stat-sub" [class.up]="pct >= 90" [class.down]="pct < 75">{{ present + late }} of {{ schoolDays }} school days</div>
          </div>
          <div class="stat-tile">
            <div class="stat-label">Present</div>
            <div class="stat-value">{{ present }}</div>
            <div class="stat-sub">full days</div>
          </div>
          <div class="stat-tile">
            <div class="stat-label">Late</div>
            <div class="stat-value">{{ late }}</div>
            <div class="stat-sub">counted as present</div>
          </div>
          <div class="stat-tile">
            <div class="stat-label">Absent</div>
            <div class="stat-value">{{ absent }}</div>
            <div class="stat-sub" [class.down]="absent > 0">days missed</div>
          </div>
        </div>

        <div class="card">
          <div class="card-head">
            <h2 class="grow">{{ studentName }} · {{ from }} → {{ to }}</h2>
            <button class="btn btn-ghost btn-sm" (click)="print()">Print / PDF</button>
          </div>
          <div class="table-wrap">
            <table class="data-table">
              <thead><tr><th>Date</th><th>Day</th><th>Status</th></tr></thead>
              <tbody>
                @for (r of rows; track r.date) {
                  <tr>
                    <td class="td-sub">{{ r.date }}</td>
                    <td>{{ r.day }}</td>
                    <td><span class="badge" [class]="'badge ' + badge(r.status)">{{ r.status }}</span></td>
                  </tr>
                }
              </tbody>
            </table>
          </div>
        </div>
      }
    } @else {
      <div class="card"><div class="empty">Pick a student and date range, then click <strong>Generate</strong>.</div></div>
    }
  `,
})
export class AdAttendanceReportComponent {
  readonly data = inject(DataService);
  adm = '';
  from = '2026-06-01';
  to = '2026-06-30';
  loaded = false;
  rows: AttRow[] = [];
  studentName = '';

  run(): void {
    if (!this.adm) { alert('Please select a student.'); return; }
    const student = this.data.students.find(s => s.adm === this.adm);
    this.studentName = student ? `${student.name} (${student.cls}-${student.sec})` : '';
    this.rows = this.data.studentAttendanceBetween(this.adm, this.from, this.to);
    this.loaded = true;
  }

  get present() { return this.rows.filter(r => r.status === 'Present').length; }
  get late() { return this.rows.filter(r => r.status === 'Late').length; }
  get absent() { return this.rows.filter(r => r.status === 'Absent').length; }
  get schoolDays() { return this.rows.filter(r => r.status !== 'Holiday').length; }
  get pct() {
    return this.schoolDays ? Math.round(((this.present + this.late) / this.schoolDays) * 100) : 0;
  }

  badge(status: string): string {
    switch (status) {
      case 'Present': return 'success';
      case 'Late': return 'warning';
      case 'Absent': return 'danger';
      default: return 'neutral';
    }
  }

  print(): void {
    window.print();
  }
}
