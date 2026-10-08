import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { HttpErrorResponse } from '@angular/common/http';
import { AuthService } from '../core/auth.service';

@Component({
  selector: 'app-forgot-password',
  standalone: true,
  imports: [FormsModule, RouterLink],
  template: `
    <div class="auth-page" [attr.data-theme]="theme">
      <div class="auth-card">
        <div class="auth-logo">🎓</div>
        <h2>Forgot your password?</h2>
        <p class="hint">Enter your account email and we'll send you a link to choose a new password.</p>

        @if (!sent) {
          <div class="field">
            <label>Email</label>
            <input class="input" type="email" [(ngModel)]="email" (keyup.enter)="submit()" placeholder="you@school.edu.np" />
          </div>
          @if (error) { <div class="err">{{ error }}</div> }
          <button class="btn btn-primary" style="width:100%;justify-content:center;" (click)="submit()" [disabled]="loading">
            {{ loading ? 'Sending…' : 'Send reset link' }}
          </button>
        } @else {
          <div class="ok">{{ message }}</div>
          <p class="hint" style="margin:14px 0 0;">
            The link is valid for one hour and can be used once. If it does not arrive, check
            your spam folder — or ask your school office to reset the password for you.
          </p>
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
export class ForgotPasswordComponent {
  private readonly auth = inject(AuthService);

  /** The school's palette, remembered from the last sign-in on this device. */
  get theme(): string { return this.auth.signedOutTheme; }
  protected readonly router = inject(Router);
  email = '';
  loading = false;
  sent = false;
  error = '';
  message = '';

  submit(): void {
    if (!this.email.trim()) { this.error = 'Enter your email.'; return; }
    this.loading = true; this.error = '';
    this.auth.forgotPassword(this.email.trim()).subscribe({
      next: r => { this.loading = false; this.sent = true; this.message = r.message; },
      error: (e: HttpErrorResponse) => { this.loading = false; this.error = e.status === 0 ? 'Cannot reach the API.' : (e.error?.message ?? 'Request failed.'); },
    });
  }
}
