import { Component, inject, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { HttpErrorResponse } from '@angular/common/http';
import {
  MessageTemplate, SaveMessageTemplate, SuperAdminApiService, TemplatePreview,
} from '../../core/super-admin-api.service';

/** Matches the helper each page in this folder defines; the API's own message wins. */
function apiError(err: unknown, fallback = 'Something went wrong.'): string {
  const e = err as HttpErrorResponse;
  if (e?.status === 0) return 'Cannot reach the API. Is it running on the configured URL?';
  return e?.error?.message ?? e?.message ?? fallback;
}

/**
 * The message library: every SMS and email the product sends, as text rather than as code.
 *
 * The platform writes them all. `editableBy` is the permission it grants per message — a fee
 * reminder is usually a school's to reword, an OTP never is. The override count is the column
 * that matters in support: when a school says a message reads wrong, the first question is
 * whether they replaced it.
 */
@Component({
  selector: 'app-sa-templates',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Message Templates</h1>
        <div class="page-sub">
          Every SMS and email the product sends. Schools inherit these unless you let them
          write their own.
        </div>
      </div>
      <button class="btn btn-primary" (click)="openForm()">+ New Template</button>
    </div>

    <div class="card">
      <div class="card-head filters">
        <h2 class="grow">{{ shown.length }} template{{ shown.length === 1 ? '' : 's' }}</h2>
        <select class="select sm" [(ngModel)]="channel" (ngModelChange)="reload()">
          <option value="">All channels</option>
          <option value="sms">SMS</option>
          <option value="email">Email</option>
        </select>
      </div>

      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else if (!shown.length) { <div class="empty">No templates yet.</div> }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr>
                <th>Message</th>
                <th>Channel</th>
                <th>Schools may edit</th>
                <th class="num">Overridden by</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              @for (t of shown; track t.id) {
                <tr>
                  <td>
                    <div class="td-main">{{ t.code }}</div>
                    <div class="td-sub">{{ t.body.slice(0, 68) }}{{ t.body.length > 68 ? '…' : '' }}</div>
                  </td>
                  <td>{{ t.channel === 'sms' ? 'SMS' : 'Email' }}</td>
                  <td>
                    <span class="badge" [class]="t.editableBy === 'school' ? 'badge success' : 'badge neutral'">
                      {{ t.editableBy === 'school' ? 'Yes' : 'Reserved' }}
                    </span>
                  </td>
                  <!-- The support column: a school that overrode is not reading your words. -->
                  <td class="num">{{ t.overrideCount || '—' }}</td>
                  <td>
                    <span class="badge" [class]="t.isActive ? 'badge success' : 'badge danger'">
                      {{ t.isActive ? 'On' : 'Off' }}
                    </span>
                  </td>
                  <td>
                    <div class="row-actions">
                      <button class="btn btn-ghost btn-sm" (click)="edit(t)">Edit</button>
                      <button class="btn btn-ghost btn-sm danger" (click)="remove(t)">Delete</button>
                    </div>
                  </td>
                </tr>
              }
            </tbody>
          </table>
        </div>
      }
    </div>

    @if (showForm) {
      <div class="modal-backdrop">
        <div class="modal wide">
          <div class="modal-head">
            <h2>{{ editingId ? 'Edit Template' : 'New Template' }}</h2>
            <button class="modal-close" (click)="showForm = false">✕</button>
          </div>
          <div class="modal-body">
            <div class="form-row">
              <div class="field">
                <label>Channel <span class="req">*</span></label>
                <select class="select" [(ngModel)]="form.channel" [disabled]="!!editingId">
                  <option value="sms">SMS</option>
                  <option value="email">Email</option>
                </select>
              </div>
              <div class="field">
                <label>Code <span class="req">*</span></label>
                <input class="input" [(ngModel)]="form.code" [disabled]="!!editingId"
                       placeholder="fee_reminder" />
                <div class="field-hint">
                  What the sending code asks for. Lower case, digits and underscores.
                  @if (editingId) { Fixed once created — changing it would repoint every override. }
                </div>
              </div>
            </div>

            @if (form.channel === 'email') {
              <div class="field">
                <label>Subject <span class="req">*</span></label>
                <input class="input" [(ngModel)]="form.subject" />
              </div>
            }

            <div class="field">
              <label>Body <span class="req">*</span></label>
              <textarea class="input" rows="4" [(ngModel)]="form.body"
                        (ngModelChange)="preview = null"></textarea>
              <div class="field-hint">
                Placeholders look like <code>{{ sampleToken }}</code>.
                @if (form.channel === 'sms') {
                  <!-- Stated because the cost is invisible until the bill arrives. -->
                  {{ bareLength }} characters before placeholders are filled; one SMS is 160.
                }
              </div>
            </div>

            <div class="form-row">
              <div class="field">
                <label>Schools may reword this</label>
                <select class="select" [(ngModel)]="form.editableBy">
                  <option value="platform">No — platform only</option>
                  <option value="school">Yes</option>
                </select>
                <div class="field-hint">
                  Anything carrying a login code should stay platform-only.
                </div>
              </div>
              <div class="field">
                <label>Locale</label>
                <input class="input" [(ngModel)]="form.locale" placeholder="en" />
              </div>
            </div>

            @if (form.channel === 'sms') {
              <div class="field">
                <label>Registered template id</label>
                <input class="input" [(ngModel)]="form.providerTemplateId" />
                <div class="field-hint">
                  India's DLT rules need every SMS registered before it will deliver, and the
                  sent text must match the registered text exactly. Leave blank until registered.
                </div>
              </div>
            }

            <div class="field">
              <label>
                <input type="checkbox" [(ngModel)]="form.isActive" /> Active
              </label>
            </div>

            <div class="row-actions">
              <button class="btn btn-ghost btn-sm" (click)="runPreview()">Preview</button>
            </div>
            @if (preview) {
              <div class="notice-box" style="margin-top:10px;">
                @if (preview.subject) { <div><b>{{ preview.subject }}</b></div> }
                <div style="white-space:pre-wrap;">{{ preview.body }}</div>
                @if (preview.unfilledPlaceholders.length) {
                  <div style="margin-top:6px;">
                    Nothing supplied for: {{ preview.unfilledPlaceholders.join(', ') }}
                  </div>
                }
              </div>
            }

            @if (formError) { <div class="field-error">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showForm = false">Cancel</button>
            <button class="btn btn-primary" (click)="save()" [disabled]="saving">
              {{ saving ? 'Saving…' : (editingId ? 'Save Changes' : 'Create Template') }}
            </button>
          </div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class SaTemplatesComponent implements OnInit {
  private readonly api = inject(SuperAdminApiService);

  /**
   * Shown as an example of placeholder syntax. It lives here rather than in the
   * template because Angular decodes &#123;&#123; back to braces and then parses
   * them as interpolation — escaping it in the HTML does not work.
   */
  readonly sampleToken = '{{student_name}}';

  templates: MessageTemplate[] = [];
  channel = '';
  loading = true;
  error = '';

  showForm = false;
  saving = false;
  formError = '';
  editingId: number | null = null;
  form: SaveMessageTemplate = this.empty();
  preview: TemplatePreview | null = null;
  toast = '';
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void { this.reload(); }

  get shown(): MessageTemplate[] { return this.templates; }

  /** Roughly what an SMS costs before placeholders grow it; a floor, not a guarantee. */
  get bareLength(): number {
    return this.form.body.replace(/\{\{\s*[\w.]+\s*\}\}/g, '').trim().length;
  }

  reload(): void {
    this.loading = true;
    this.api.getTemplates(this.channel || undefined).subscribe({
      next: t => { this.templates = t; this.loading = false; this.error = ''; },
      error: e => { this.error = apiError(e); this.loading = false; },
    });
  }

  openForm(): void {
    this.editingId = null;
    this.form = this.empty();
    this.preview = null;
    this.formError = '';
    this.showForm = true;
  }

  edit(t: MessageTemplate): void {
    this.editingId = t.id;
    this.form = {
      channel: t.channel, code: t.code, locale: t.locale, subject: t.subject,
      body: t.body, providerTemplateId: t.providerTemplateId,
      editableBy: t.editableBy, isActive: t.isActive,
    };
    this.preview = null;
    this.formError = '';
    this.showForm = true;
  }

  runPreview(): void {
    // Sample values rather than real ones: the point is to see the shape of the sentence.
    const values: Record<string, string> = {
      school_name: 'Sunrise Public School', student_name: 'Reyaz Ahmed',
      guardian_name: 'Sita Ahmed', amount: 'Rs 4,200', due_date: '15 Nov 2026',
      name: 'Reyaz Ahmed', username: 'reyaz.a', portal_url: 'https://school.kssinfonet.com',
      code: '482913', minutes: '5',
    };
    this.api.previewTemplate(this.form.body, this.form.subject, values).subscribe({
      next: p => this.preview = p,
      error: e => this.formError = apiError(e),
    });
  }

  save(): void {
    this.formError = '';
    this.saving = true;
    const done = (m: string) => {
      this.saving = false; this.showForm = false; this.showToast(m); this.reload();
    };
    const fail = (e: unknown) => { this.saving = false; this.formError = apiError(e); };

    if (this.editingId) {
      this.api.updateTemplate(this.editingId, this.form)
        .subscribe({ next: () => done(`${this.form.code} updated`), error: fail });
    } else {
      this.api.createTemplate(this.form)
        .subscribe({ next: () => done(`${this.form.code} created`), error: fail });
    }
  }

  remove(t: MessageTemplate): void {
    // The API refuses this outright once a school has overridden it; the confirm is about the
    // schools still inheriting, who would lose the message entirely.
    if (!confirm(`Delete the ${t.channel} template "${t.code}"? Schools inheriting it will stop receiving this message.`)) return;
    this.api.deleteTemplate(t.id).subscribe({
      next: () => { this.showToast(`${t.code} deleted`); this.reload(); },
      error: e => alert(apiError(e)),
    });
  }

  private empty(): SaveMessageTemplate {
    return {
      channel: 'sms', code: '', locale: 'en', subject: null, body: '',
      providerTemplateId: null, editableBy: 'platform', isActive: true,
    };
  }

  private showToast(m: string): void {
    this.toast = m;
    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.toast = '', 3500);
  }
}
