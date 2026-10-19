import { Component, inject, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AdminApiService, SchoolMessageTemplate } from '../../core/admin-api.service';

import { HttpErrorResponse } from '@angular/common/http';

/** Matches the helper each page in this folder defines; the API's own message wins. */
function apiError(err: unknown, fallback = 'Something went wrong.'): string {
  const e = err as HttpErrorResponse;
  if (e?.status === 0) return 'Cannot reach the API. Is it running on the configured URL?';
  return e?.error?.message ?? e?.message ?? fallback;
}

/**
 * Every message that goes out in this school's name.
 *
 * A school does not create templates — the codes are what the sending code asks for, so one a
 * school invented would be sent by nothing. It either uses the platform's wording or supplies
 * its own, and only where the platform allowed that.
 *
 * Where it is not allowed, the reason is printed rather than the control being quietly absent:
 * a locked field with an explanation is accepted, a missing one generates a support ticket.
 */
@Component({
  selector: 'app-admin-templates',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Message Templates</h1>
        <div class="page-sub">
          What your parents and staff receive. Some are set by the platform and cannot be
          reworded, but you can switch any of them off.
        </div>
      </div>
    </div>

    <div class="card">
      @if (loading) { <div class="empty">Loading…</div> }
      @else if (error) { <div class="empty">{{ error }}</div> }
      @else if (!templates.length) { <div class="empty">No messages are configured yet.</div> }
      @else {
        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr>
                <th>Message</th>
                <th>Channel</th>
                <th>Wording</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              @for (t of templates; track t.channel + t.code + t.locale) {
                <tr>
                  <td>
                    <div class="td-main">{{ label(t.code) }}</div>
                    <div class="td-sub">{{ t.body.slice(0, 72) }}{{ t.body.length > 72 ? '…' : '' }}</div>
                  </td>
                  <td>{{ t.channel === 'sms' ? 'SMS' : 'Email' }}</td>
                  <td>
                    <span class="badge" [class]="t.isOverridden ? 'badge info' : 'badge neutral'">
                      {{ t.isOverridden ? 'Yours' : 'Platform' }}
                    </span>
                  </td>
                  <td>
                    <span class="badge" [class]="t.isActive ? 'badge success' : 'badge danger'">
                      {{ t.isActive ? 'On' : 'Off' }}
                    </span>
                  </td>
                  <td>
                    <div class="row-actions">
                      @if (t.canEdit) {
                        <button class="btn btn-ghost btn-sm" (click)="edit(t)">Edit</button>
                      } @else {
                        <!-- Stated, not hidden. -->
                        <span class="td-sub" title="Set by the platform">Set by platform</span>
                      }
                      <button class="btn btn-ghost btn-sm" (click)="toggle(t)">
                        {{ t.isActive ? 'Switch off' : 'Switch on' }}
                      </button>
                      @if (t.isOverridden) {
                        <button class="btn btn-ghost btn-sm" (click)="revert(t)">Use platform's</button>
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

    @if (editing; as t) {
      <div class="modal-backdrop">
        <div class="modal">
          <div class="modal-head">
            <h2>{{ label(t.code) }}</h2>
            <button class="modal-close" (click)="editing = null">✕</button>
          </div>
          <div class="modal-body">
            @if (t.channel === 'email') {
              <div class="field">
                <label>Subject</label>
                <input class="input" [(ngModel)]="form.subject" />
              </div>
            }
            <div class="field">
              <label>Message <span class="req">*</span></label>
              <textarea class="input" rows="4" [(ngModel)]="form.body"></textarea>
              <div class="field-hint">
                Keep the <code>{{ sampleToken }}</code> — they are filled in
                with real names and amounts when the message is sent.
                @if (t.channel === 'sms') { One SMS is 160 characters. }
              </div>
            </div>

            <!-- What they are departing from, so the edit is a decision rather than a guess. -->
            <div class="field">
              <label>The platform's wording</label>
              <div class="notice-box" style="white-space:pre-wrap;">{{ t.platformBody }}</div>
            </div>

            @if (formError) { <div class="field-error">{{ formError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="editing = null">Cancel</button>
            <button class="btn btn-primary" (click)="save()" [disabled]="saving">
              {{ saving ? 'Saving…' : 'Save' }}
            </button>
          </div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class AdminTemplatesComponent implements OnInit {
  private readonly api = inject(AdminApiService);

  /** See the note on the platform page: braces cannot be escaped in a template. */
  readonly sampleToken = '{{placeholders}}';

  templates: SchoolMessageTemplate[] = [];
  loading = true;
  error = '';

  editing: SchoolMessageTemplate | null = null;
  form = { subject: null as string | null, body: '', isActive: true };
  saving = false;
  formError = '';
  toast = '';
  private timer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void { this.reload(); }

  /** The code is how the system names a message; this is how a person does. */
  label(code: string): string {
    const known: Record<string, string> = {
      otp_login: 'Login code',
      welcome: 'Welcome / new account',
      fee_reminder: 'Fee reminder',
    };
    return known[code] ?? code.replace(/_/g, ' ');
  }

  reload(): void {
    this.loading = true;
    this.api.getMessageTemplates().subscribe({
      next: t => { this.templates = t; this.loading = false; this.error = ''; },
      error: e => { this.error = apiError(e); this.loading = false; },
    });
  }

  edit(t: SchoolMessageTemplate): void {
    this.editing = t;
    this.form = { subject: t.subject, body: t.body, isActive: t.isActive };
    this.formError = '';
  }

  save(): void {
    const t = this.editing;
    if (!t) return;
    this.saving = true;
    this.formError = '';
    this.api.saveMessageTemplate(t.channel, t.code, t.locale, this.form).subscribe({
      next: () => {
        this.saving = false; this.editing = null;
        this.showToast(`${this.label(t.code)} saved`); this.reload();
      },
      error: e => { this.saving = false; this.formError = apiError(e); },
    });
  }

  /**
   * Switching off is allowed on every message, including the ones a school may not reword —
   * it writes an override carrying the current wording with isActive false.
   */
  toggle(t: SchoolMessageTemplate): void {
    this.api.saveMessageTemplate(t.channel, t.code, t.locale, {
      subject: t.subject, body: t.body, isActive: !t.isActive,
    }).subscribe({
      next: () => {
        this.showToast(`${this.label(t.code)} switched ${t.isActive ? 'off' : 'on'}`);
        this.reload();
      },
      error: e => alert(apiError(e)),
    });
  }

  revert(t: SchoolMessageTemplate): void {
    if (!confirm(`Go back to the platform's wording for "${this.label(t.code)}"? Your version will be discarded.`)) return;
    this.api.clearMessageTemplate(t.channel, t.code, t.locale).subscribe({
      next: () => { this.showToast(`${this.label(t.code)} reverted`); this.reload(); },
      error: e => alert(apiError(e)),
    });
  }

  private showToast(m: string): void {
    this.toast = m;
    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.toast = '', 3500);
  }
}
