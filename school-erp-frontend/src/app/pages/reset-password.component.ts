import { Component, inject, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { HttpErrorResponse } from '@angular/common/http';
import { AuthService } from '../core/auth.service';

@Component({
  selector: 'app-reset-password',
  standalone: true,
  imports: [FormsModule, RouterLink],
  template: `
    <div class="auth-page" [attr.data-theme]="theme">
      <div class="auth-card">
        <div class="auth-logo">🎓</div>
        <h2>Reset password</h2>
        <p class="hint">{{ fromLink ? 'Choose a new password for your account.' : 'Paste the link from your email, or the token it carries, then choose a new password.' }}</p>

        @if (!done) {
          <!-- Arriving from the emailed link the token is already in hand; showing it as an
               editable box invites people to "fix" a value they should never have to touch. -->
          @if (!fromLink) {
            <div class="field">
              <label>Reset token</label>
              <input class="input" [(ngModel)]="token" placeholder="Paste the link or token from your email" />
              <div class="hint" style="margin:5px 0 0;">Opening the link from the email fills this in for you.</div>
            </div>
          }
          <div class="field"><label>New password</label><input class="input" type="password" [(ngModel)]="newPassword" placeholder="At least 6 characters" /></div>
          <div class="field"><label>Confirm password</label><input class="input" type="password" [(ngModel)]="confirm" (keyup.enter)="submit()" placeholder="Re-type new password" /></div>
          @if (error) { <div class="err">{{ error }}</div> }
          <button class="btn btn-primary" style="width:100%;justify-content:center;" (click)="submit()" [disabled]="loading">{{ loading ? 'Resetting…' : 'Reset password' }}</button>
        } @else {
          <div class="ok">Your password has been reset. You can now sign in with your new password.</div>
          <a class="btn btn-primary" style="margin-top:16px;justify-content:center;width:100%;" routerLink="/login">Go to sign in →</a>
        }

        <div class="row-links"><a routerLink="/login">← Back to sign in</a></div>
      </div>
    </div>
  `,
  styles: [`
    .auth-page { min-height: 100vh; display: grid; place-items: center; background: var(--page); padding: 24px; }
    .auth-card { width: 100%; max-width: 400px; background: var(--surface); border: 1px solid var(--border); border-radius: 16px; box-shadow: var(--shadow-md); padding: 30px; }
    .auth-logo { font-size: 26px; width: 52px; height: 52px; display: grid; place-items: center; border-radius: 14px; background: linear-gradient(135deg, #3b82f6, #1d4ed8); color:#fff; box-shadow: 0 8px 20px rgba(37,99,235,0.35); margin-bottom: 18px; }
    h2 { font-size: 20px; font-weight: 800; margin-bottom: 5px; }
    .hint { color: var(--muted); font-size: 13px; margin: 0 0 20px; }
    .err { background: var(--crit-tint); color: var(--crit-text); font-size: 13px; padding: 9px 12px; border-radius: 8px; margin-bottom: 14px; }
    .ok { background: var(--good-tint); color: var(--good-text); font-size: 13px; padding: 10px 12px; border-radius: 8px; }
    .row-links { text-align: center; margin-top: 18px; font-size: 13px; }
  `],
})
export class ResetPasswordComponent implements OnInit {
  private readonly auth = inject(AuthService);

  /** The school's palette, remembered from the last sign-in on this device. */
  get theme(): string { return this.auth.signedOutTheme; }
  private readonly route = inject(ActivatedRoute);
  protected readonly router = inject(Router);
  token = '';
  newPassword = '';
  confirm = '';
  loading = false;
  done = false;
  error = '';

  /** True when the token arrived on the URL, i.e. the reader followed the emailed link. */
  fromLink = false;

  ngOnInit(): void {
    this.token = this.route.snapshot.queryParamMap.get('token') ?? '';
    this.fromLink = !!this.token;
  }

  /**
   * Accepts a pasted link as readily as a bare token. People copy the whole address out of the
   * mail far more often than they pick the token out of it, and failing them for it is needless.
   */
  private cleanToken(): string {
    const raw = this.token.trim();
    const match = /[?&]token=([^&#\s]+)/.exec(raw);
    return match ? decodeURIComponent(match[1]) : raw;
  }

  submit(): void {
    this.token = this.cleanToken();
    if (!this.token) { this.error = 'The reset token is required.'; return; }
    if (this.newPassword.length < 6) { this.error = 'Password must be at least 6 characters.'; return; }
    if (this.newPassword !== this.confirm) { this.error = 'Passwords do not match.'; return; }
    this.loading = true; this.error = '';
    this.auth.resetPassword(this.token, this.newPassword).subscribe({
      next: () => { this.loading = false; this.done = true; },
      error: (e: HttpErrorResponse) => {
        this.loading = false;
        this.error = e.status === 0 ? 'Cannot reach the API.' : (e.error?.message ?? 'Reset failed.');
        // An expired or spent link is not something retyping fixes, so offer the way out.
        if (/expired|already been used|Invalid/i.test(this.error)) this.fromLink = false;
      },
    });
  }
}
