import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { DataService } from '../../core/data.service';

/* =====================  DASHBOARD  ===================== */

@Component({
  selector: 'app-t-dashboard',
  standalone: true,
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Good afternoon, Rajesh</h1>
        <div class="page-sub">Friday, July 4, 2026 · 5 periods scheduled today</div>
      </div>
    </div>

    <div class="stat-grid">
      @for (s of data.teacherStats; track s.label) {
        <div class="stat-tile">
          <div class="stat-label">{{ s.label }}</div>
          <div class="stat-value">{{ s.value }}</div>
          <div class="stat-sub" [class.down]="s.trend === 'down'">{{ s.sub }}</div>
        </div>
      }
    </div>

    <div class="grid-2">
      <div class="card">
        <div class="card-head"><h2 class="grow">Today’s Schedule (Friday)</h2></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Period</th><th>Time</th><th>Class</th><th>Room</th></tr></thead>
            <tbody>
              @for (p of today; track p.period) {
                <tr>
                  <td class="td-main">{{ p.period }}</td>
                  <td>{{ p.time }}</td>
                  <td>{{ p.cls }}</td>
                  <td class="td-sub">{{ p.room }}</td>
                </tr>
              } @empty {
                <tr><td colspan="4"><div class="empty">No periods today 🎉</div></td></tr>
              }
            </tbody>
          </table>
        </div>
      </div>

      <div class="card">
        <div class="card-head"><h2 class="grow">Homework Needing Attention</h2></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Assignment</th><th>Class</th><th class="num">Submitted</th><th>Status</th></tr></thead>
            <tbody>
              @for (h of data.teacherHomework.slice(0, 3); track h.title) {
                <tr>
                  <td class="td-main">{{ h.title }}</td>
                  <td>{{ h.cls }}</td>
                  <td class="num">{{ h.submitted }}/{{ h.total }}</td>
                  <td><span class="badge" [class]="'badge ' + data.badgeClass(h.status)">{{ h.status }}</span></td>
                </tr>
              }
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `,
})
export class TDashboardComponent {
  readonly data = inject(DataService);
  readonly today = this.data.teacherTimetable['Friday'] ?? [];
}

/* =====================  MY CLASSES  ===================== */

@Component({
  selector: 'app-t-classes',
  standalone: true,
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>My Classes</h1>
        <div class="page-sub">Academic Year 2083</div>
      </div>
    </div>

    <div class="stat-grid">
      @for (c of data.myClasses; track c.cls + c.sec) {
        <div class="stat-tile">
          <div class="stat-label">{{ c.subject }}</div>
          <div class="stat-value">{{ c.cls }} — {{ c.sec }}</div>
          <div class="stat-sub">{{ c.students }} students · Room {{ c.room }}</div>
          @if (c.isClassTeacher) {
            <div style="margin-top: 8px;"><span class="badge info">Class Teacher</span></div>
          }
        </div>
      }
    </div>

    <div class="card">
      <div class="card-head"><h2 class="grow">Students — Grade 8-A (Class Teacher)</h2></div>
      <div class="table-wrap">
        <table class="data-table">
          <thead><tr><th class="num">Roll</th><th>Name</th></tr></thead>
          <tbody>
            @for (s of data.classStudents; track s.roll) {
              <tr><td class="num">{{ s.roll }}</td><td class="td-main">{{ s.name }}</td></tr>
            }
          </tbody>
        </table>
      </div>
    </div>
  `,
})
export class TMyClassesComponent {
  readonly data = inject(DataService);
}

/* =====================  ATTENDANCE  ===================== */

type AttStatus = 'P' | 'A' | 'L';

@Component({
  selector: 'app-t-attendance',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Student Attendance</h1>
        <div class="page-sub">Mark attendance for your class</div>
      </div>
    </div>

    <div class="card">
      <div class="card-head filters">
        <input class="input" type="date" [(ngModel)]="date" />
        <select class="select" [(ngModel)]="section">
          @for (c of data.myClasses; track c.cls + c.sec) {
            <option>{{ c.cls }} — {{ c.sec }}</option>
          }
        </select>
        <div class="grow"></div>
        <span class="td-sub">{{ presentCount }}/{{ roster.length }} present</span>
        <button class="btn btn-ghost btn-sm" (click)="markAll('P')">All Present</button>
        <button class="btn btn-primary" (click)="save()">Save</button>
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
export class TAttendanceComponent {
  readonly data = inject(DataService);
  date = '2026-07-04';
  section = 'Grade 8 — A';
  readonly roster = this.data.classStudents;
  marks: Record<number, AttStatus> = Object.fromEntries(this.roster.map(s => [s.roll, 'P'])) as Record<number, AttStatus>;

  get presentCount() { return Object.values(this.marks).filter(v => v === 'P').length; }

  markAll(v: AttStatus): void {
    for (const s of this.roster) this.marks[s.roll] = v;
  }

  save(): void {
    alert(`Attendance saved (demo): ${this.presentCount}/${this.roster.length} present for ${this.section} on ${this.date}.`);
  }
}

/* =====================  HOMEWORK  ===================== */

@Component({
  selector: 'app-t-homework',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Homework Management</h1>
        <div class="page-sub">{{ list.length }} assignments this term</div>
      </div>
    </div>

    <div class="grid-2">
      <div class="card">
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Assignment</th><th>Class</th><th>Due</th><th class="num">Submitted</th><th>Status</th></tr></thead>
            <tbody>
              @for (h of list; track h.title) {
                <tr>
                  <td><div class="td-main">{{ h.title }}</div><div class="td-sub">{{ h.subject }}</div></td>
                  <td>{{ h.cls }}</td>
                  <td class="td-sub">{{ h.due }}</td>
                  <td class="num">{{ h.submitted }}/{{ h.total }}</td>
                  <td><span class="badge" [class]="'badge ' + data.badgeClass(h.status)">{{ h.status }}</span></td>
                </tr>
              }
            </tbody>
          </table>
        </div>
      </div>

      <div class="card">
        <div class="card-head"><h2 class="grow">Assign New Homework</h2></div>
        <div class="card-body">
          <div class="field">
            <label>Title</label>
            <input class="input" [(ngModel)]="title" placeholder="e.g. Quadratic Equations Set 2" />
          </div>
          <div class="field">
            <label>Class</label>
            <select class="select" [(ngModel)]="cls">
              @for (c of data.myClasses; track c.cls + c.sec) {
                <option>{{ c.cls }}-{{ c.sec }}</option>
              }
            </select>
          </div>
          <div class="field">
            <label>Due date</label>
            <input class="input" type="date" [(ngModel)]="due" />
          </div>
          <button class="btn btn-primary" (click)="assign()" [disabled]="!title.trim()">Assign Homework</button>
        </div>
      </div>
    </div>
  `,
})
export class THomeworkComponent {
  readonly data = inject(DataService);
  list = [...this.data.teacherHomework];
  title = '';
  cls = 'Grade 8-A';
  due = '2026-07-10';

  assign(): void {
    this.list.unshift({
      title: this.title.trim(),
      cls: this.cls,
      subject: 'Mathematics',
      assigned: '2026-07-04',
      due: this.due,
      submitted: 0,
      total: 38,
      status: 'Open',
    });
    this.title = '';
  }
}

/* =====================  MARKS ENTRY  ===================== */

@Component({
  selector: 'app-t-marks',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Marks Entry</h1>
        <div class="page-sub">Quarterly Assessment 2083 · Mathematics · Full marks 100</div>
      </div>
    </div>

    <div class="card">
      <div class="card-head filters">
        <select class="select" [(ngModel)]="exam">
          <option>Quarterly Assessment 2083</option>
          <option>Unit Test — July</option>
        </select>
        <select class="select" [(ngModel)]="section">
          <option>Grade 8 — A</option>
          <option>Grade 8 — B</option>
          <option>Grade 9 — A</option>
        </select>
        <div class="grow"></div>
        <span class="td-sub">Class average: {{ average }}%</span>
        <button class="btn btn-primary" (click)="save()">Submit Marks</button>
      </div>
      <div class="table-wrap">
        <table class="data-table">
          <thead><tr><th class="num">Roll</th><th>Student</th><th style="width:140px;">Marks / 100</th><th>Grade</th></tr></thead>
          <tbody>
            @for (s of roster; track s.roll) {
              <tr>
                <td class="num">{{ s.roll }}</td>
                <td class="td-main">{{ s.name }}</td>
                <td>
                  <input class="input" type="number" min="0" max="100" style="width:90px;"
                         [(ngModel)]="marks[s.roll]" />
                </td>
                <td><span class="badge" [class]="'badge ' + gradeBadge(marks[s.roll])">{{ data.grade(marks[s.roll] || 0) }}</span></td>
              </tr>
            }
          </tbody>
        </table>
      </div>
    </div>
  `,
})
export class TMarksComponent {
  readonly data = inject(DataService);
  exam = 'Quarterly Assessment 2083';
  section = 'Grade 8 — A';
  readonly roster = this.data.classStudents;
  marks: Record<number, number> = Object.fromEntries(
    this.roster.map((s, i) => [s.roll, [78, 91, 66, 84, 72, 88, 59, 95, 81, 74][i % 10]]),
  );

  get average(): number {
    const v = Object.values(this.marks);
    return Math.round(v.reduce((a, b) => a + (b || 0), 0) / v.length);
  }

  gradeBadge(m: number | undefined): string {
    const pct = m || 0;
    if (pct >= 80) return 'success';
    if (pct >= 60) return 'info';
    if (pct >= 40) return 'warning';
    return 'danger';
  }

  save(): void {
    alert(`Marks submitted (demo) for ${this.section} — ${this.exam}. Class average ${this.average}%.`);
  }
}

/* =====================  TIMETABLE  ===================== */

@Component({
  selector: 'app-t-timetable',
  standalone: true,
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>My Timetable</h1>
        <div class="page-sub">Weekly teaching schedule</div>
      </div>
    </div>

    <div class="card">
      <div class="table-wrap">
        <table class="tt-grid">
          <thead>
            <tr><th>Day</th>@for (p of periods; track p) { <th>{{ p }}</th> }</tr>
          </thead>
          <tbody>
            @for (day of days; track day) {
              <tr>
                <th>{{ day }}</th>
                @for (p of periods; track p) {
                  <td>
                    @if (slot(day, p); as s) {
                      <div class="tt-subject">{{ s.cls }}</div>
                      <div class="tt-meta">{{ s.time }} · {{ s.room }}</div>
                    } @else {
                      <span class="tt-meta">—</span>
                    }
                  </td>
                }
              </tr>
            }
          </tbody>
        </table>
      </div>
    </div>
  `,
})
export class TTimetableComponent {
  readonly data = inject(DataService);
  readonly days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  readonly periods = ['P1', 'P2', 'P3', 'P4', 'P5', 'P6'];

  slot(day: string, period: string) {
    return (this.data.teacherTimetable[day] ?? []).find(s => s.period === period) ?? null;
  }
}
