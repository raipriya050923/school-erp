import { Component, OnInit, inject } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {
  TeacherApiService, teacherApiError, hwStatusBadge, hwStatusLabel,
  TeacherDashboard, MyClass, RosterStudent, Homework,
} from '../../core/teacher-api.service';

/* =====================  DASHBOARD  ===================== */

@Component({
  selector: 'app-t-dashboard',
  standalone: true,
  imports: [DatePipe],
  template: `
    @if (loading) { <div class="card"><div class="empty">Loading…</div></div> }
    @else if (error) { <div class="card"><div class="empty">{{ error }}</div></div> }
    @else if (d) {
      <div class="page-head">
        <div class="grow">
          <h1>Good day, {{ firstName }}</h1>
          <div class="page-sub">{{ d.profile.subject }} · {{ d.profile.employeeCode }} · live data from the API</div>
        </div>
      </div>

      <div class="stat-grid">
        <div class="stat-tile"><div class="stat-label">My Classes</div><div class="stat-value">{{ d.myClassesCount }}</div><div class="stat-sub">sections as class teacher</div></div>
        <div class="stat-tile"><div class="stat-label">Students Taught</div><div class="stat-value">{{ d.studentsTaught }}</div><div class="stat-sub">across my sections</div></div>
        <div class="stat-tile"><div class="stat-label">Submissions To Grade</div><div class="stat-value">{{ d.submissionsToGrade }}</div><div class="stat-sub">pending review</div></div>
        <div class="stat-tile"><div class="stat-label">Open Homework</div><div class="stat-value">{{ d.openHomework }}</div><div class="stat-sub">still accepting</div></div>
      </div>

      <div class="card">
        <div class="card-head"><h2 class="grow">Homework Needing Attention</h2></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Assignment</th><th>Class</th><th>Due</th><th class="num">Submitted</th><th>Status</th></tr></thead>
            <tbody>
              @for (h of d.recentHomework; track h.id) {
                <tr>
                  <td class="td-main">{{ h.title }}</td>
                  <td>{{ h.classLabel }}</td>
                  <td class="td-sub">{{ h.dueDate | date:'mediumDate' }}</td>
                  <td class="num">{{ h.submitted }}/{{ h.total }}</td>
                  <td><span class="badge" [class]="'badge ' + badge(h.status)">{{ hlabel(h.status) }}</span></td>
                </tr>
              } @empty { <tr><td colspan="5"><div class="empty">No homework yet.</div></td></tr> }
            </tbody>
          </table>
        </div>
      </div>
    }
  `,
})
export class TDashboardComponent implements OnInit {
  private readonly api = inject(TeacherApiService);
  d: TeacherDashboard | null = null;
  loading = true;
  error = '';
  badge = hwStatusBadge;
  hlabel = hwStatusLabel;
  get firstName(): string { return (this.d?.profile.name ?? '').split(' ')[0]; }
  ngOnInit(): void {
    this.api.getDashboard().subscribe({
      next: d => { this.d = d; this.loading = false; },
      error: e => { this.error = teacherApiError(e); this.loading = false; },
    });
  }
}

/* =====================  MY CLASSES  ===================== */

@Component({
  selector: 'app-t-classes',
  standalone: true,
  template: `
    <div class="page-head"><div class="grow"><h1>My Classes</h1><div class="page-sub">Sections you are the class teacher for</div></div></div>

    @if (loading) { <div class="card"><div class="empty">Loading…</div></div> }
    @else if (error) { <div class="card"><div class="empty">{{ error }}</div></div> }
    @else {
      <div class="stat-grid">
        @for (c of classes; track c.sectionId) {
          <div class="stat-tile" style="cursor:pointer;" (click)="loadRoster(c)">
            <div class="stat-label">{{ c.subject }}</div>
            <div class="stat-value">{{ c.className }} — {{ c.sectionName }}</div>
            <div class="stat-sub">{{ c.studentCount }} students@if (c.room) { · Room {{ c.room }} }</div>
            <div style="margin-top:8px;"><span class="badge info">Class Teacher</span></div>
          </div>
        } @empty { <div class="card" style="grid-column:1/-1;"><div class="empty">No classes assigned yet.</div></div> }
      </div>

      @if (selected) {
        <div class="card">
          <div class="card-head"><h2 class="grow">Students — {{ selected.className }}-{{ selected.sectionName }}</h2><span class="td-sub">{{ roster.length }} students</span></div>
          <div class="table-wrap">
            <table class="data-table">
              <thead><tr><th class="num">Roll</th><th>Name</th></tr></thead>
              <tbody>
                @for (s of roster; track s.id) { <tr><td class="num">{{ s.rollNo }}</td><td class="td-main">{{ s.name }}</td></tr> }
                @empty { <tr><td colspan="2"><div class="empty">No students in this section.</div></td></tr> }
              </tbody>
            </table>
          </div>
        </div>
      } @else if (classes.length) {
        <div class="card"><div class="empty">Click a class above to see its student roster.</div></div>
      }
    }
  `,
})
export class TMyClassesComponent implements OnInit {
  private readonly api = inject(TeacherApiService);
  classes: MyClass[] = [];
  roster: RosterStudent[] = [];
  selected: MyClass | null = null;
  loading = true;
  error = '';
  ngOnInit(): void {
    this.api.getMyClasses().subscribe({
      next: c => { this.classes = c; this.loading = false; if (c.length) this.loadRoster(c[0]); },
      error: e => { this.error = teacherApiError(e); this.loading = false; },
    });
  }
  loadRoster(c: MyClass): void {
    this.selected = c;
    this.api.getRoster(c.className, c.sectionName).subscribe({ next: r => this.roster = r, error: () => this.roster = [] });
  }
}

/* =====================  HOMEWORK  ===================== */

@Component({
  selector: 'app-t-homework',
  standalone: true,
  imports: [FormsModule, DatePipe],
  template: `
    <div class="page-head"><div class="grow"><h1>Homework Management</h1><div class="page-sub">{{ list.length }} assignments</div></div></div>

    <div class="grid-2">
      <div class="card">
        @if (loading) { <div class="empty">Loading…</div> }
        @else if (error) { <div class="empty">{{ error }}</div> }
        @else {
          <div class="table-wrap">
            <table class="data-table">
              <thead><tr><th>Assignment</th><th>Class</th><th>Due</th><th class="num">Submitted</th><th>Status</th></tr></thead>
              <tbody>
                @for (h of list; track h.id) {
                  <tr>
                    <td><div class="td-main">{{ h.title }}</div><div class="td-sub">{{ h.subject }}</div></td>
                    <td>{{ h.classLabel }}</td>
                    <td class="td-sub">{{ h.dueDate | date:'mediumDate' }}</td>
                    <td class="num">{{ h.submitted }}/{{ h.total }}</td>
                    <td><span class="badge" [class]="'badge ' + badge(h.status)">{{ hlabel(h.status) }}</span></td>
                  </tr>
                } @empty { <tr><td colspan="5"><div class="empty">No homework yet.</div></td></tr> }
              </tbody>
            </table>
          </div>
        }
      </div>

      <div class="card">
        <div class="card-head"><h2 class="grow">Assign New Homework</h2></div>
        <div class="card-body">
          <div class="field"><label>Title *</label><input class="input" [(ngModel)]="title" placeholder="e.g. Quadratic Equations Set 2" /></div>
          <div class="form-row">
            <div class="field"><label>Class</label><input class="input" [(ngModel)]="classLabel" placeholder="Grade 8-A" /></div>
            <div class="field"><label>Subject</label><input class="input" [(ngModel)]="subject" placeholder="Mathematics" /></div>
          </div>
          <div class="form-row">
            <div class="field"><label>Due date</label><input class="input" type="date" [(ngModel)]="dueDate" /></div>
            <div class="field"><label>Total students</label><input class="input" type="number" [(ngModel)]="total" /></div>
          </div>
          @if (formError) { <div style="color:var(--crit-text);font-size:13px;">{{ formError }}</div> }
          <button class="btn btn-primary" (click)="assign()" [disabled]="saving || !title.trim()">{{ saving ? 'Assigning…' : 'Assign Homework' }}</button>
        </div>
      </div>
    </div>

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class THomeworkComponent implements OnInit {
  private readonly api = inject(TeacherApiService);
  list: Homework[] = [];
  loading = true;
  error = '';
  formError = '';
  saving = false;
  title = '';
  classLabel = 'Grade 8-A';
  subject = 'Mathematics';
  dueDate = '2026-07-10';
  total = 38;
  toast = '';
  badge = hwStatusBadge;
  hlabel = hwStatusLabel;
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void { this.reload(); }
  reload(): void {
    this.api.getHomework().subscribe({
      next: h => { this.list = h; this.loading = false; this.error = ''; },
      error: e => { this.error = teacherApiError(e); this.loading = false; },
    });
  }
  assign(): void {
    if (!this.title.trim()) { this.formError = 'Title is required.'; return; }
    this.saving = true; this.formError = '';
    this.api.createHomework(this.title.trim(), this.subject.trim(), this.classLabel.trim(), this.dueDate, Number(this.total) || 0).subscribe({
      next: () => { this.saving = false; this.title = ''; this.showToast('Homework assigned'); this.reload(); },
      error: e => { this.saving = false; this.formError = teacherApiError(e); },
    });
  }
  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }
}
