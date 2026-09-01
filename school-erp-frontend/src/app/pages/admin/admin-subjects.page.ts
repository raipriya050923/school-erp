import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AdminApiService, adminApiError, SubjectDto, SaveSubject } from '../../core/admin-api.service';
import { FieldErrors } from '../../shared/field-errors';

/**
 * Manage the subjects a school teaches. These feed the exam "Add Subject" dropdown, which is why
 * retiring is offered instead of deleting: exam papers record the subject as plain text, so a
 * deleted subject would leave past schedules referring to something that no longer exists.
 */
@Component({
  selector: 'app-ad-subjects',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Subjects</h1>
        <div class="page-sub">{{ active.length }} active · {{ subjects.length }} total</div>
      </div>
      <button class="btn btn-primary" (click)="openForm()">+ Add Subject</button>
    </div>

    <div class="card">
      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Subject</th><th>Code</th><th>Type</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              @for (s of subjects; track s.id) {
                <tr>
                  <td class="td-main">{{ s.name }}</td>
                  <td class="td-sub">{{ s.code || '—' }}</td>
                  <td>{{ typeLabel(s.subjectType) }}</td>
                  <td><span class="badge" [class]="s.isActive ? 'badge success' : 'badge neutral'">{{ s.isActive ? 'Active' : 'Retired' }}</span></td>
                  <td>
                    <div class="row-actions">
                      <button class="icon-action primary" (click)="edit(s)" title="Edit" aria-label="Edit">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/></svg>
                      </button>
                      @if (s.isActive) {
                        <button class="icon-action danger" (click)="setActive(s, false)" title="Retire" aria-label="Retire">
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><line x1="5.6" y1="5.6" x2="18.4" y2="18.4"/></svg>
                        </button>
                      } @else {
                        <button class="icon-action success" (click)="setActive(s, true)" title="Restore" aria-label="Restore">
                          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.5 2.5L16 9"/></svg>
                        </button>
                      }
                    </div>
                  </td>
                </tr>
              } @empty { <tr><td colspan="5"><div class="empty">No subjects yet.</div></td></tr> }
            </tbody>
          </table>
        </div>
      }
    </div>

    @if (showForm) {
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head"><h2>{{ editingId ? 'Edit Subject' : 'Add Subject' }}</h2><button class="modal-close" (click)="showForm = false">✕</button></div>
          <div class="modal-body">
            <div class="field">
              <label>Name <span class="req">*</span></label>
              <input class="input" [class.invalid]="err.has('name')" [(ngModel)]="form.name"
                     (ngModelChange)="err.clear('name')" placeholder="e.g. Nepali" />
              @if (err.has('name')) { <div class="field-error">{{ err.get('name') }}</div> }
            </div>
            <div class="form-row">
              <div class="field"><label>Code</label><input class="input" [(ngModel)]="form.code" placeholder="NEP" /></div>
              <div class="field"><label>Type</label>
                <select class="select" [(ngModel)]="form.subjectType">
                  <option value="theory">Theory</option>
                  <option value="practical">Practical</option>
                  <option value="both">Both</option>
                </select>
              </div>
            </div>
            @if (editingId) {
              <div class="field-hint">Renaming does not change exam papers already scheduled under the old name.</div>
            }
            @if (formError) { <div style="color:var(--crit-text);font-size:13px;">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showForm = false">Cancel</button>
            <button class="btn btn-primary" (click)="save()" [disabled]="saving">{{ saving ? 'Saving…' : (editingId ? 'Save Changes' : 'Add Subject') }}</button>
          </div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class AdSubjectsComponent implements OnInit {
  private readonly api = inject(AdminApiService);
  subjects: SubjectDto[] = [];
  loading = true;
  error = '';
  formError = '';
  toast = '';
  showForm = false;
  saving = false;
  editingId: number | null = null;
  form: SaveSubject = this.empty();
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void { this.reload(); }

  get active(): SubjectDto[] { return this.subjects.filter(s => s.isActive); }

  reload(): void {
    this.api.getSubjectList().subscribe({
      next: s => { this.subjects = s; this.loading = false; this.error = ''; },
      error: e => { this.error = adminApiError(e); this.loading = false; },
    });
  }

  typeLabel(t: string): string { return t === 'both' ? 'Theory + Practical' : t.charAt(0).toUpperCase() + t.slice(1); }

  readonly err = new FieldErrors();
  openForm(): void { this.editingId = null; this.form = this.empty(); this.formError = ''; this.err.reset(); this.showForm = true; }
  edit(s: SubjectDto): void {
    this.editingId = s.id;
    this.form = { name: s.name, code: s.code ?? '', subjectType: s.subjectType };
    this.formError = '';
    this.err.reset();
    this.showForm = true;
  }

  save(): void {
    this.formError = '';
    this.err.reset();
    if (!this.err.require('name', this.form.name, 'Subject name is required.')) return;
    this.saving = true;
    const dto: SaveSubject = { ...this.form, name: this.form.name.trim(), code: (this.form.code ?? '').trim() || null };
    const done = (m: string) => { this.saving = false; this.showForm = false; this.showToast(m); this.reload(); };
    const fail = (e: unknown) => { this.saving = false; this.formError = adminApiError(e); };
    if (this.editingId) this.api.updateSubject(this.editingId, dto).subscribe({ next: () => done('Subject updated'), error: fail });
    else this.api.createSubject(dto).subscribe({ next: () => done('Subject added'), error: fail });
  }

  setActive(s: SubjectDto, value: boolean): void {
    if (!value && !confirm(`Retire ${s.name}? It stops appearing when scheduling exams; existing papers are untouched.`)) return;
    this.api.setSubjectActive(s.id, value).subscribe({
      next: () => { this.showToast(`${s.name} ${value ? 'restored' : 'retired'}`); this.reload(); },
      error: e => alert(adminApiError(e)),
    });
  }

  private showToast(m: string): void { this.toast = m; clearTimeout(this.timer); this.timer = setTimeout(() => this.toast = '', 3000); }
  private empty(): SaveSubject { return { name: '', code: '', subjectType: 'theory' }; }
}
