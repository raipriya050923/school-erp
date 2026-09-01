import { Component, EventEmitter, Input, Output } from '@angular/core';

/** An extra read-only row shown under the credentials, e.g. admission no or employee code. */
export interface CredentialDetail { label: string; value: string | null | undefined; }

/**
 * Shows a newly created account's username and password once, with copy buttons.
 *
 * The password only ever exists in the API response — the server stores a bcrypt hash — so this
 * dialog is the single chance to record it. It deliberately has no backdrop-click or Escape
 * dismissal: closing it must be an explicit acknowledgement.
 *
 *   <app-credentials-dialog
 *     [title]="'Teacher registered'"
 *     [username]="c.username" [password]="c.temporaryPassword"
 *     [details]="[{ label: 'Employee code', value: code }]"
 *     (closed)="credentials = null" (copied)="showToast($event)" />
 */
@Component({
  selector: 'app-credentials-dialog',
  standalone: true,
  template: `
    <div class="modal-backdrop">
      <div class="modal">
        <div class="modal-head"><h2>{{ title }}</h2></div>
        <div class="modal-body">
          <p class="cred-intro">
            A portal login was created for <strong>{{ fullName }}</strong>. Copy it now —
            <strong>the password cannot be shown again</strong> once you close this dialog.
          </p>

          <div class="cred-box">
            <div class="cred-row">
              <span class="cred-label">Username</span>
              <code class="cred-value">{{ username }}</code>
              <button class="btn btn-ghost cred-copy" (click)="copy(username, 'Username')">Copy</button>
            </div>
            <div class="cred-row">
              <span class="cred-label">Password</span>
              <code class="cred-value">{{ password }}</code>
              <button class="btn btn-ghost cred-copy" (click)="copy(password, 'Password')">Copy</button>
            </div>
          </div>

          @for (d of details; track d.label) {
            <div class="kv-row"><span class="kv-label">{{ d.label }}</span><span class="kv-value">{{ d.value || '—' }}</span></div>
          }

          @if (email) {
            <div class="kv-row"><span class="kv-label">Email</span><span class="kv-value">{{ email }}</span></div>
          } @else {
            <p class="cred-note">
              No email is attached to this account, so <em>Forgot password</em> will not work for
              them — you will need to reset it from here if it is lost.
            </p>
          }

          <p class="cred-note">
            Ask them to change this password after their first sign-in.
          </p>
        </div>
        <div class="modal-foot">
          <button class="btn btn-ghost" (click)="copyAll()">Copy all</button>
          <button class="btn btn-primary" (click)="closed.emit()">I've saved these</button>
        </div>
      </div>
    </div>
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
export class CredentialsDialogComponent {
  @Input() title = 'Account created';
  @Input() fullName = '';
  @Input() username = '';
  @Input() password = '';
  @Input() email: string | null = null;
  @Input() details: CredentialDetail[] = [];
  @Output() closed = new EventEmitter<void>();
  /** Emits a short confirmation the host can surface as a toast. */
  @Output() copied = new EventEmitter<string>();

  /** Copies to the clipboard, falling back to a prompt on browsers that block the async API. */
  copy(text: string, label: string): void {
    navigator.clipboard?.writeText(text).then(
      () => this.copied.emit(`${label} copied`),
      () => prompt(`Copy ${label.toLowerCase()}:`, text),
    ) ?? prompt(`Copy ${label.toLowerCase()}:`, text);
  }

  copyAll(): void {
    const lines = [
      `Name: ${this.fullName}`,
      ...this.details.filter(d => d.value).map(d => `${d.label}: ${d.value}`),
      `Username: ${this.username}`,
      `Password: ${this.password}`,
      'Please change this password after your first sign-in.',
    ];
    this.copy(lines.join('\n'), 'Credentials');
  }
}
