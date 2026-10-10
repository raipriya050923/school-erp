import { Component, OnInit, inject } from '@angular/core';
import { DatePipe, DecimalPipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {
  TeacherApiService, Exam, MyClassSection, ClassResult, ClassResultStudent,
} from '../../core/teacher-api.service';

/** Turns an HTTP failure into something that names the actual cause. */
function describe(e: unknown, fallback: string): string {
  const err = e as { status?: number; error?: { message?: string } };
  if (err?.error?.message) return err.error.message;
  if (err?.status === 404) return 'This screen needs a newer API build — the results endpoint is not there yet. Restart the API.';
  if (err?.status === 0) return 'The API is not reachable.';
  return fallback;
}

/**
 * The class teacher's review of their own section.
 *
 * Read-only on purpose. Every subject of the exam is shown, including ones this teacher does not
 * take, because reviewing the section as a whole is the class teacher's job — but the marks stay
 * the subject teacher's to enter, and publishing stays the admin's to decide.
 */
@Component({
  selector: 'app-tc-class-results',
  standalone: true,
  imports: [FormsModule, DatePipe, DecimalPipe],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Class Results</h1>
        <div class="page-sub">
          @if (result) { {{ result.examName }} · {{ result.className }} — {{ result.sectionName }} ·
            {{ result.subjects.length }} subjects · {{ result.students.length }} students }
          @else { Review every subject of the section you are class teacher of }
        </div>
      </div>
      @if (result) {
        <button class="btn" (click)="exportCsv()" [disabled]="!result.students.length">Export CSV</button>
        @if (result.approvalStatus === 'approved') {
          <button class="btn btn-ghost" (click)="approve(false)" [disabled]="saving || result.isPublished"
                  [title]="result.isPublished ? 'Already published — ask your admin to unpublish first' : 'Withdraw your approval'">
            Withdraw approval
          </button>
        } @else {
          <button class="btn btn-primary" (click)="approve(true)" [disabled]="saving || !result.canApprove"
                  [title]="result.canApprove ? 'Sign this sheet off for the admin to publish' : 'Every paper must be marked first'">
            {{ saving ? 'Approving…' : 'Approve Results' }}
          </button>
        }
      }
    </div>

    <div class="card">
      <div class="card-head filters">
        <select class="select" [(ngModel)]="examId" (ngModelChange)="load()" [disabled]="!exams.length">
          @for (e of exams; track e.id) { <option [value]="e.id">{{ e.name }}</option> }
          @if (!exams.length) { <option value="">No exams</option> }
        </select>
        <select class="select" [(ngModel)]="section" (ngModelChange)="load()" [disabled]="!sections.length">
          @for (c of sections; track c.className + c.sectionName) {
            <option [value]="c.className + '|' + c.sectionName">{{ c.className }} — {{ c.sectionName }}</option>
          }
          @if (!sections.length) { <option value="">No class of your own</option> }
        </select>
        <div class="grow"></div>
        @if (result) {
          @if (result.approvalStatus === 'approved') {
            <span class="badge badge-success" [title]="approvedTitle">
              Approved by you{{ result.approvedAt ? ' · ' + (result.approvedAt | date:'mediumDate') : '' }}
            </span>
          } @else if (result.canApprove) {
            <span class="badge badge-warning">Ready to approve</span>
          } @else {
            <span class="badge badge-neutral">Awaiting marks</span>
          }
          @if (result.isPublished) {
            <span class="badge badge-success">Published to students</span>
          } @else {
            <span class="badge badge-neutral">Not published</span>
          }
        }
      </div>

      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else if (!sections.length) {
        <div class="empty">
          You are not the class teacher of any section. Result review is scoped to your own class —
          ask your admin to set you as class teacher under Classes &amp; Sections.
        </div>
      }
      @else if (result) {
        @if (!result.subjects.length) {
          <div class="empty">
            {{ result.examName }} has no papers scheduled for {{ result.className }} —
            {{ result.sectionName }} yet.
          </div>
        } @else {
          <div class="paper-strip">
            @if (result.missingMarks === 0) {
              <span class="ready">All {{ result.subjects.length }} subjects complete — ready for the admin to publish.</span>
            } @else {
              <span class="pending">{{ result.missingMarks }} mark{{ result.missingMarks === 1 ? '' : 's' }} still missing:</span>
            }
            @for (p of result.subjects; track p.subject) {
              <span class="paper-chip" [class.done]="p.total > 0 && p.entered >= p.total">
                {{ p.subject }}
                <span class="paper-count">{{ p.entered }}/{{ p.total }}</span>
                @if (p.teacherName) { <span class="paper-who">{{ p.teacherName }}</span> }
              </span>
            }
          </div>

          <div class="table-wrap">
            <table class="data-table grid-table">
              <thead>
                <tr>
                  <th class="num stick stick-1">Roll</th>
                  <th class="stick stick-2">Student</th>
                  @for (p of result.subjects; track p.subject) {
                    <th class="num">{{ p.subject }}<div class="td-sub">/ {{ p.fullMarks }}</div></th>
                  }
                  <th class="num">Total</th>
                  <th class="num">%</th>
                  <th>Grade</th>
                </tr>
              </thead>
              <tbody>
                @for (s of result.students; track s.studentId) {
                  <tr>
                    <td class="num stick stick-1">{{ s.rollNo }}</td>
                    <td class="td-main stick stick-2">{{ s.name }}</td>
                    @for (p of result.subjects; track p.subject) {
                      <td class="num">
                        @if (s.marks[p.subject] !== null && s.marks[p.subject] !== undefined) { {{ s.marks[p.subject] }} }
                        @else { <span class="missing" title="Not entered by the subject teacher yet">—</span> }
                      </td>
                    }
                    <td class="num">{{ s.total }} / {{ s.fullTotal }}</td>
                    <td class="num" [class.provisional]="!s.isComplete"
                        [title]="s.isComplete ? '' : s.missing + ' paper(s) unmarked — this can still rise'">
                      <strong>{{ s.percent | number:'1.0-2' }}%</strong>
                    </td>
                    <td>
                      <span class="badge" [class]="'badge ' + gradeBadge(s)"
                            [title]="s.isComplete ? '' : 'Provisional until every paper is marked'">{{ s.grade || '—' }}</span>
                    </td>
                  </tr>
                } @empty { <tr><td [attr.colspan]="result.subjects.length + 5"><div class="empty">No students in this section.</div></td></tr> }
              </tbody>
              @if (result.students.length) {
                <tfoot>
                  <tr>
                    <td class="stick stick-1"></td>
                    <td class="td-sub stick stick-2">Subject average</td>
                    @for (p of result.subjects; track p.subject) { <td class="num td-sub">{{ columnAverage(p.subject) }}</td> }
                    <td class="num td-sub" colspan="3">Class average {{ classAverage }}%</td>
                  </tr>
                </tfoot>
              }
            </table>
          </div>

          <div class="td-sub" style="padding:10px 14px;">
            Marks are entered by each subject's own teacher; totals, percentage and grade are
            computed and stored when they save. A figure shown in grey is provisional — papers are
            still outstanding, so it can only rise. Once every paper is in, approve the sheet; the
            admin can then publish it to students. Editing a mark afterwards withdraws the approval.
          </div>
        }
      }
    </div>
  `,
  styles: [`
    .paper-strip { display:flex; flex-wrap:wrap; align-items:center; gap:8px; padding:10px 14px; border-bottom:1px solid var(--border,#e5e7eb); }
    .paper-chip { display:inline-flex; align-items:center; gap:6px; padding:4px 10px; border-radius:999px;
                  border:1px solid var(--border,#e5e7eb); font-size:12px; }
    .paper-chip.done { border-color:var(--good); }
    .paper-chip.done .paper-count { color:var(--good); font-weight:600; }
    .paper-count { font-variant-numeric: tabular-nums; opacity:.75; }
    .paper-who { color:var(--muted,#6b7280); border-left:1px solid var(--border,#e5e7eb); padding-left:6px; }
    .ready { font-size:12px; font-weight:600; color:var(--good); }
    .pending { font-size:12px; font-weight:600; color:var(--crit-text,#b91c1c); }
    .missing { color:var(--muted,#9ca3af); }
    /* A percentage over unmarked papers is real but not final — greyed so it does not read as a verdict. */
    .provisional { color:var(--muted,#9ca3af); }

    /* Roll and Student stay put while the subject columns scroll sideways. */
    .grid-table th, .grid-table td { white-space:nowrap; }
    .grid-table .stick { position:sticky; background:var(--surface); z-index:1; }
    .grid-table .stick-1 { left:0; }
    .grid-table .stick-2 { left:56px; }
    .grid-table tfoot td { border-top:1px solid var(--border,#e5e7eb); }
  `],
})
export class TcClassResultsComponent implements OnInit {
  private readonly api = inject(TeacherApiService);

  exams: Exam[] = [];
  sections: MyClassSection[] = [];
  examId: number | string = '';
  /** "Class|Section", matching the option values. */
  section = '';
  result: ClassResult | null = null;
  loading = true;
  saving = false;
  error = '';

  get approvedTitle(): string {
    const r = this.result;
    if (!r || r.approvalStatus !== 'approved') return '';
    return `Approved by ${r.approvedByName ?? 'you'}${r.approvedAt ? ' on ' + new Date(r.approvedAt).toLocaleString() : ''}`;
  }

  /**
   * Sign the sheet off, or withdraw it. Approval is the class teacher's statement that the
   * section's marks are complete and correct; the admin's publish step is gated on it.
   */
  approve(yes: boolean): void {
    const r = this.result;
    if (!r) return;
    if (!yes && !confirm('Withdraw your approval? The admin will not be able to publish until you approve again.')) return;
    this.saving = true;
    this.api.approveResult(r.examId, r.className, r.sectionName, yes).subscribe({
      next: () => { this.saving = false; this.load(); },
      error: e => { this.saving = false; alert(describe(e, 'Could not update the approval.')); },
    });
  }

  ngOnInit(): void {
    this.api.getExams().subscribe({
      next: e => {
        this.exams = e;
        if (e.length) this.examId = e[0].id;
        this.api.myClassSections().subscribe({
          next: s => {
            this.sections = s;
            if (s.length) this.section = s[0].className + '|' + s[0].sectionName;
            this.load();
          },
          // A 404 here means the API predates this screen, not that the teacher has no class.
          // Reporting it as a data problem sent people looking at class-teacher assignments.
          error: e => { this.loading = false; this.error = describe(e, 'Could not load your class.'); },
        });
      },
      error: e => { this.loading = false; this.error = describe(e, 'Could not load exams.'); },
    });
  }

  load(): void {
    const parts = this.section.split('|');
    const className = parts[0], sectionName = parts[1];
    if (!this.examId || !className || !sectionName) { this.loading = false; this.result = null; return; }
    this.loading = true; this.error = ''; this.result = null;
    this.api.classResult(Number(this.examId), className, sectionName).subscribe({
      next: r => { this.result = r; this.loading = false; },
      error: e => { this.loading = false; this.error = describe(e, 'Could not load the result sheet.'); },
    });
  }

  /** Averaged over the marks actually entered, so a half-marked paper is not scored as zeros. */
  columnAverage(subject: string): string {
    const vals = (this.result?.students ?? [])
      .map(s => s.marks[subject])
      .filter((v): v is number => v !== null && v !== undefined);
    if (!vals.length) return '—';
    return (vals.reduce((a, b) => a + b, 0) / vals.length).toFixed(1);
  }

  /** Only students with a complete sheet count, for the same reason. */
  get classAverage(): number {
    const done = (this.result?.students ?? []).filter(s => s.missing === 0);
    if (!done.length) return 0;
    return Math.round(done.reduce((a, s) => a + s.percent, 0) / done.length);
  }

  gradeBadge(s: ClassResultStudent): string {
    if (s.missing) return 'badge-neutral';
    if (s.percent >= 70) return 'badge-success';
    if (s.percent >= 33) return 'badge-warning';
    return 'badge-danger';
  }

  exportCsv(): void {
    const r = this.result;
    if (!r) return;
    const esc = (v: unknown) => '"' + String(v ?? '').replace(/"/g, '""') + '"';
    const header = ['Roll', 'Student']
      .concat(r.subjects.map(p => p.subject + ' (/' + p.fullMarks + ')'), ['Total', '%', 'Grade']);
    const lines = [header.map(esc).join(',')];
    for (const s of r.students) {
      const cells: unknown[] = [s.rollNo, s.name];
      for (const p of r.subjects) cells.push(s.marks[p.subject] ?? '');
      cells.push(s.total + '/' + s.fullTotal, s.missing ? '' : s.percent, s.grade);
      lines.push(cells.map(esc).join(','));
    }
    const blob = new Blob([lines.join('\r\n')], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = (r.examName + '-' + r.className + '-' + r.sectionName + '.csv').replace(/[\\/:*?"<>|]/g, '-');
    a.click();
    URL.revokeObjectURL(url);
  }
}
