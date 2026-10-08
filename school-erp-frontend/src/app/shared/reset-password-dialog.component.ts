import { Component, EventEmitter, Input, Output } from '@angular/core';
import { FormsModule } from '@angular/forms';

/**
 * Asks an administrator to confirm resetting someone's portal password.
 *
 * Two deliberate choices. The generated password is the default, because an administrator
 * choosing passwords by hand ends up issuing the same one to a whole class. And typing one is
 * still offered, because the real task is usually reading it down a telephone to a parent, and
 * a generated string of symbols does not survive that trip.
 *
 * Either way the holder is forced to replace it at their next sign-in, which the dialog says
 * plainly — an administrator should know the password they are about to read out is temporary.
 *
 *   <app-reset-password-dialog
 *     [who]="t.name" role="teacher" [username]="login?.username" [note]="login?.note"
 *     [saving]="resetting" (confirmed)="doReset($event)" (cancelled)="resetTarget = null" />
 */
@Component({
  selector: 'app-reset-password-dialog',
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="modal-backdrop">
      <div class="modal">
        <div class="modal-head">
          <h2>Reset password</h2>
          <button class="modal-close" (click)="cancelled.emit()" [disabled]="saving">✕</button>
        </div>
        <div class="modal-body">
          <p class="rp-intro">
            Issue a new password for <strong>{{ who }}</strong>'s {{ role }} login.
            @if (username) { <br /><span class="rp-user">Signs in as <code>{{ username }}</code></span> }
          </p>
          @if (note) { <div class="rp-note">{{ note }}</div> }

          <div class="rp-choice">
            <label class="rp-opt">
              <input type="radio" name="rp-mode" value="auto" [(ngModel)]="mode" [disabled]="saving" />
              <span>
                <b>Generate a password</b>
                <small>A strong 12-character one. Shown once, so copy it before closing.</small>
              </span>
            </label>
            <label class="rp-opt">
              <input type="radio" name="rp-mode" value="manual" [(ngModel)]="mode" [disabled]="saving" />
              <span>
                <b>Set one myself</b>
                <small>Easier to read out over the phone.</small>
              </span>
            </label>
          </div>

          @if (mode === 'manual') {
            <div class="field">
              <label>New password <span class="req">*</span></label>
              <input class="input" type="text" [(ngModel)]="password" [disabled]="saving"
                     (ngModelChange)="error = ''" placeholder="At least 8 characters" autocomplete="off" />
              <div class="field-hint">
                Shown as you type on purpose — you are about to read it out, and there is nobody
                to hide it from here.
              </div>
            </div>
          }

          <div class="rp-warn">
            {{ who }} will have to choose their own password the next time they sign in, and the
            portal stays closed to them until they do.
          </div>

          @if (error) { <div class="field-error">{{ error }}</div> }
        </div>
        <div class="modal-foot">
          <button class="btn btn-ghost" (click)="cancelled.emit()" [disabled]="saving">Cancel</button>
          <button class="btn btn-primary" (click)="submit()" [disabled]="saving">
            {{ saving ? 'Resetting…' : 'Reset password' }}
          </button>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .rp-intro { font-size: 13.5px; line-height: 1.6; margin: 0 0 12px; }
    .rp-user { color: var(--muted); font-size: 12.5px; }
    .rp-user code { background: var(--neutral-tint); padding: 1px 6px; border-radius: 5px; }
    .rp-note {
      font-size: 12.5px; color: var(--ink-2); background: var(--neutral-tint);
      padding: 8px 11px; border-radius: 8px; margin-bottom: 14px;
    }
    .rp-choice { display: flex; flex-direction: column; gap: 8px; margin-bottom: 14px; }
    .rp-opt {
      display: flex; align-items: flex-start; gap: 10px;
      padding: 10px 12px; border: 1px solid var(--border); border-radius: 10px;
      cursor: pointer; font-size: 13px;
    }
    .rp-opt:hover { border-color: var(--brand); background: var(--brand-tint); }
    .rp-opt b { display: block; font-weight: 600; }
    .rp-opt small { display: block; color: var(--muted); font-size: 12px; margin-top: 2px; }
    .rp-warn {
      background: var(--warn-tint); color: var(--warn-text);
      font-size: 12.5px; line-height: 1.5; padding: 9px 12px; border-radius: 8px; margin-top: 4px;
    }
  `],
})
export class ResetPasswordDialogComponent {
  /** Whose password is being reset, for the sentence at the top. */
  @Input() who = '';
  /** teacher | student | parent — only ever used as a word in that sentence. */
  @Input() role = 'portal';
  @Input() username: string | null = null;
  /** Anything worth knowing about the account, e.g. that it is still on an issued password. */
  @Input() note: string | null = null;
  @Input() saving = false;

  /** The password the administrator chose, or null to let the server generate one. */
  @Output() confirmed = new EventEmitter<string | null>();
  @Output() cancelled = new EventEmitter<void>();

  mode: 'auto' | 'manual' = 'auto';
  password = '';
  error = '';

  submit(): void {
    if (this.mode === 'auto') { this.confirmed.emit(null); return; }
    const typed = this.password.trim();
    // Checked here as well as on the server so the administrator is not told off after the
    // account has already been touched.
    if (typed.length < 8) { this.error = 'Use at least 8 characters.'; return; }
    this.confirmed.emit(typed);
  }
}
