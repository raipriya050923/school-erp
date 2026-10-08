import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../core/auth.service';
import { IconComponent } from '../shared/icon.component';
import { FieldErrors } from '../shared/field-errors';

/** One live requirement shown under the new-password field. */
interface Rule { label: string; ok: boolean; }

/**
 * Where a user lands when they are still on the password their school issued.
 *
 * Not the same as Reset password: there is no token and no email round trip, because the holder
 * is already signed in — they simply have to replace a password an administrator has seen. The
 * API refuses every other endpoint until they do, so this is a dead end by design: there is no
 * Skip, and the only way out is to set a password or sign out.
 *
 * Because it is a dead end, the page has to carry its own weight: it names the account being
 * changed (there is no shell around it to say so), shows the rules as they are met rather than
 * failing on submit, and offers to reveal what has been typed — people mistype far more often
 * on a screen that blocks everything else until they get it right.
 */
@Component({
  selector: 'app-set-password',
  standalone: true,
  imports: [FormsModule, IconComponent],
  template: `
    <div class="auth-page" [attr.data-theme]="theme">
      <div class="auth-card">
        <div class="auth-badge"><app-icon name="lock" [size]="24" /></div>

        <h1>Set your password</h1>
        <p class="hint">
          You signed in with a password your school issued, so it is not private to you yet.
          Choose your own to continue.
        </p>

        @if (who) {
          <div class="whoami">
            <span class="who-avatar">{{ initials }}</span>
            <span class="who-text">
              <b>{{ who.name || who.username }}</b>
              <small>{{ who.title }} · {{ who.username }}</small>
            </span>
          </div>
        }

        <div class="field">
          <label>Current password <span class="req">*</span></label>
          <div class="pw">
            <input class="input" [type]="show.current ? 'text' : 'password'" autocomplete="current-password"
                   [class.invalid]="err.has('current')" [(ngModel)]="current"
                   (ngModelChange)="err.clear('current')" (keyup)="trackCaps($event)"
                   placeholder="The one you just signed in with" />
            <button type="button" class="pw-toggle" (click)="show.current = !show.current"
                    [attr.aria-label]="show.current ? 'Hide password' : 'Show password'">
              {{ show.current ? 'Hide' : 'Show' }}
            </button>
          </div>
          @if (err.has('current')) { <div class="field-error">{{ err.get('current') }}</div> }
        </div>

        <div class="field">
          <label>New password <span class="req">*</span></label>
          <div class="pw">
            <input class="input" [type]="show.next ? 'text' : 'password'" autocomplete="new-password"
                   [class.invalid]="err.has('next')" [(ngModel)]="next"
                   (ngModelChange)="err.clear('next'); err.clear('confirm')"
                   (keyup)="trackCaps($event)" (keyup.enter)="submit()" placeholder="At least 8 characters" />
            <button type="button" class="pw-toggle" (click)="show.next = !show.next"
                    [attr.aria-label]="show.next ? 'Hide password' : 'Show password'">
              {{ show.next ? 'Hide' : 'Show' }}
            </button>
          </div>
          @if (err.has('next')) { <div class="field-error">{{ err.get('next') }}</div> }

          <!--
            The meter is advice, not a gate — the only hard conditions are the three listed
            below it, so a strong-looking password is never demanded and a weak one is never
            silently refused.
          -->
          @if (next) {
            <div class="meter" [attr.data-level]="strength">
              <span class="seg" [class.on]="strength >= 1"></span>
              <span class="seg" [class.on]="strength >= 2"></span>
              <span class="seg" [class.on]="strength >= 3"></span>
              <span class="seg" [class.on]="strength >= 4"></span>
              <span class="meter-label">{{ strengthLabel }}</span>
            </div>
          }

          <ul class="rules">
            @for (r of rules; track r.label) {
              <li [class.ok]="r.ok"><span class="tick">{{ r.ok ? '✓' : '○' }}</span>{{ r.label }}</li>
            }
          </ul>
        </div>

        <div class="field">
          <label>Confirm new password <span class="req">*</span></label>
          <div class="pw">
            <input class="input" [type]="show.confirm ? 'text' : 'password'" autocomplete="new-password"
                   [class.invalid]="err.has('confirm')" [(ngModel)]="confirm"
                   (ngModelChange)="err.clear('confirm')" (keyup)="trackCaps($event)"
                   (keyup.enter)="submit()" placeholder="Type it again" />
            <button type="button" class="pw-toggle" (click)="show.confirm = !show.confirm"
                    [attr.aria-label]="show.confirm ? 'Hide password' : 'Show password'">
              {{ show.confirm ? 'Hide' : 'Show' }}
            </button>
          </div>
          @if (err.has('confirm')) { <div class="field-error">{{ err.get('confirm') }}</div> }
        </div>

        @if (capsLock) { <div class="warn">Caps Lock is on.</div> }
        @if (error) { <div class="err">{{ error }}</div> }

        <button class="btn btn-primary block" (click)="submit()" [disabled]="saving">
          {{ saving ? 'Saving…' : 'Set password and continue' }}
        </button>
        <button class="btn btn-ghost block" style="margin-top:8px;" (click)="signOut()">Sign out instead</button>

        <p class="foot">Nobody else can see the password you choose — it is stored only as a hash.</p>
      </div>
    </div>
  `,
  styles: [`
    .auth-page { min-height: 100vh; display: grid; place-items: center; background: var(--page); padding: 24px; }
    .auth-card {
      width: 100%; max-width: 430px;
      background: var(--surface); border: 1px solid var(--border);
      border-radius: 16px; box-shadow: var(--shadow-md); padding: 30px;
    }
    /* Follows the school's palette rather than a fixed blue — this screen is reached straight
       from the themed login page and would otherwise be the one place the colour reverts. */
    .auth-badge {
      width: 52px; height: 52px; display: grid; place-items: center;
      border-radius: 14px; color: #fff; margin-bottom: 18px;
      background: linear-gradient(135deg, var(--brand-light), var(--brand-dark));
      box-shadow: 0 8px 20px rgba(var(--brand-glow), 0.35);
    }
    h1 { font-size: 20px; font-weight: 800; letter-spacing: -0.01em; margin: 0 0 5px; }
    .hint { color: var(--muted); font-size: 13px; margin: 0 0 18px; line-height: 1.55; }

    /* There is no shell around this page, so the account being changed has to be named here. */
    .whoami {
      display: flex; align-items: center; gap: 10px;
      padding: 10px 12px; margin-bottom: 20px;
      border: 1px solid var(--border); border-radius: 10px; background: var(--neutral-tint);
    }
    .who-avatar {
      width: 34px; height: 34px; flex: none; display: grid; place-items: center;
      border-radius: 50%; background: var(--brand-tint); color: var(--brand-dark);
      font-size: 12.5px; font-weight: 700;
    }
    .who-text { min-width: 0; display: flex; flex-direction: column; line-height: 1.35; }
    .who-text b { font-size: 13.5px; color: var(--ink); }
    .who-text small { font-size: 11.5px; color: var(--muted); }

    /* The reveal control sits inside the field, so the input keeps room for it. */
    .pw { position: relative; }
    .pw .input { width: 100%; padding-right: 62px; }
    .pw-toggle {
      position: absolute; top: 50%; right: 6px; transform: translateY(-50%);
      font-family: inherit; font-size: 11.5px; font-weight: 600;
      padding: 5px 9px; border-radius: 7px; border: 0; cursor: pointer;
      background: transparent; color: var(--muted);
    }
    .pw-toggle:hover { background: var(--neutral-tint); color: var(--ink-2); }

    .meter { display: flex; align-items: center; gap: 4px; margin-top: 8px; }
    .seg { height: 4px; flex: 1 1 0; border-radius: 999px; background: var(--neutral-tint); transition: background 160ms; }
    .meter-label { flex: none; font-size: 11.5px; font-weight: 600; color: var(--muted); margin-left: 4px; min-width: 44px; text-align: right; }
    .meter[data-level="1"] .seg.on { background: var(--crit-text); }
    .meter[data-level="2"] .seg.on { background: var(--warn-text); }
    .meter[data-level="3"] .seg.on { background: var(--brand); }
    .meter[data-level="4"] .seg.on { background: var(--good-text); }
    .meter[data-level="1"] .meter-label { color: var(--crit-text); }
    .meter[data-level="2"] .meter-label { color: var(--warn-text); }
    .meter[data-level="3"] .meter-label { color: var(--brand-dark); }
    .meter[data-level="4"] .meter-label { color: var(--good-text); }

    /* The conditions the form actually enforces, ticked as they are met — cheaper than three
       rounds of rejection for someone who cannot get past this screen. */
    .rules { list-style: none; margin: 10px 0 0; padding: 0; display: flex; flex-direction: column; gap: 5px; }
    .rules li { display: flex; align-items: center; gap: 7px; font-size: 12.5px; color: var(--muted); }
    .rules li.ok { color: var(--good-text); }
    .tick { width: 14px; flex: none; text-align: center; font-weight: 700; }

    .err { background: var(--crit-tint); color: var(--crit-text); font-size: 13px; font-weight: 500; padding: 9px 12px; border-radius: 8px; margin-bottom: 12px; }
    .warn { background: var(--warn-tint); color: var(--warn-text); font-size: 12.5px; font-weight: 500; padding: 8px 12px; border-radius: 8px; margin-bottom: 12px; }

    /* btn-block is not a class this app defines; the two actions stack on their own here. */
    .block { width: 100%; justify-content: center; }
    .foot { margin: 18px 0 0; text-align: center; font-size: 11.5px; color: var(--muted); line-height: 1.5; }

    @media (max-width: 480px) {
      .auth-page { padding: 0; place-items: stretch; }
      .auth-card { max-width: none; border: 0; border-radius: 0; box-shadow: none; padding: 26px 20px 34px; }
    }
  `],
})
export class SetPasswordComponent {
  private readonly auth = inject(AuthService);

  /** The school's palette, remembered from the last sign-in on this device. */
  get theme(): string { return this.auth.signedOutTheme; }
  private readonly router = inject(Router);

  readonly err = new FieldErrors();
  current = '';
  next = '';
  confirm = '';
  saving = false;
  error = '';
  capsLock = false;
  readonly show = { current: false, next: false, confirm: false };

  get who() { return this.auth.user(); }

  get initials(): string {
    const source = this.who?.name || this.who?.username || '';
    const parts = source.trim().split(/\s+/).filter(Boolean);
    if (!parts.length) return '?';
    return (parts[0][0] + (parts.length > 1 ? parts[parts.length - 1][0] : '')).toUpperCase();
  }

  /** The three conditions submit() enforces, so they can be read before submitting. */
  get rules(): Rule[] {
    return [
      { label: 'At least 8 characters', ok: this.next.length >= 8 },
      { label: 'Different from the issued password', ok: !!this.next && this.next !== this.current },
      { label: 'Both entries match', ok: !!this.next && this.next === this.confirm },
    ];
  }

  /**
   * A 0-4 hint, not a rule. Length carries most of the weight because it genuinely does: a long
   * passphrase beats a short password with a symbol bolted on the end.
   */
  get strength(): number {
    const p = this.next;
    if (!p) return 0;
    let score = 0;
    if (p.length >= 8) score++;
    if (p.length >= 12) score++;
    if (/[a-z]/.test(p) && /[A-Z]/.test(p)) score++;
    if (/\d/.test(p) && /[^A-Za-z0-9]/.test(p)) score++;
    return Math.min(4, Math.max(1, score));
  }

  get strengthLabel(): string {
    return ['', 'Weak', 'Fair', 'Good', 'Strong'][this.strength];
  }

  /** Caps Lock explains most "the password I just typed is wrong" reports on a masked field. */
  trackCaps(e: Event): void {
    const key = e as KeyboardEvent;
    if (typeof key.getModifierState === 'function') this.capsLock = key.getModifierState('CapsLock');
  }

  submit(): void {
    this.error = '';
    this.err.reset();
    this.err.require('current', this.current, 'Enter the password you signed in with.');
    if (this.err.require('next', this.next, 'Choose a new password.')) {
      this.err.check('next', this.next.length >= 8, 'Use at least 8 characters.');
      // Checked here as well as on the server: retyping the issued password would leave the
      // account exactly as exposed as it was.
      this.err.check('next', this.next !== this.current, 'The new password must be different.');
    }
    if (this.err.require('confirm', this.confirm, 'Type the new password again'))
      this.err.check('confirm', this.confirm === this.next, 'The two passwords do not match.');
    if (this.err.any) return;

    this.saving = true;
    this.auth.changePassword(this.current, this.next).subscribe({
      next: () => {
        // The token still carries the old flag, so the session is re-established from scratch
        // rather than patched — the API would keep refusing requests otherwise.
        this.auth.login(this.auth.user()?.username ?? '', this.next).subscribe({
          next: u => { this.saving = false; this.router.navigateByUrl(u.portalPath); },
          error: () => { this.saving = false; this.auth.logout(); this.router.navigateByUrl('/login'); },
        });
      },
      error: e => {
        this.saving = false;
        const message = e?.error?.message ?? 'Could not set your password.';
        if (/current password/i.test(message)) this.err.set('current', message);
        else this.error = message;
      },
    });
  }

  signOut(): void {
    this.auth.logout();
    this.router.navigateByUrl('/login');
  }
}
