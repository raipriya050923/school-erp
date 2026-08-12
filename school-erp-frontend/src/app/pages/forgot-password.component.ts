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
    <div class="auth-page">
      <div class="auth-card">
        <div class="auth-logo">🎓</div>
        <h2>Forgot your password?</h2>
        <p class="hint">Enter your account email and we'll send you a reset token.</p>

        @if (!sent) {
          <div class="field">
            <label>Email</label>
            <input class="input" type="email" [(ngModel)]="email" (keyup.enter)="submit()" placeholder="you@school.edu.np" />
          </div>
          @if (error) { <div class="err">{{ error }}</div> }
          <button class="btn btn-primary" style="width:100%;justify-content:center;" (click)="submit()" [disabled]="loading">
            {{ loading ? 'Sending…' : 'Send reset token' }}
          </button>
        } @else {
          <div class="ok">{{ message }}</div>
          @if (demoToken) {
            <div class="demo-token">
              <div class="demo-label">Demo build — reset token (normally emailed):</div>
              <code>{{ demoToken }}</code>
              <a class="btn btn-primary btn-sm" style="margin-top:12px;justify-content:center;width:100%;" [routerLink]="['/reset-password']" [queryParams]="{ token: demoToken }">Continue to reset →</a>
            </div>
          }
        }

        <div class="row-links"><a routerLink="/login">← Back to sign in</a></div>
      </div>
    </div>
  `,
  styles: [`
    .auth-page { min-height: 100vh; display: grid; place-items: center; background: var(--page); padding: 24px; }
    .auth-card { width: 100%; max-width: 400px; background: var(--surface); border: 1px solid var(--border); border-radius: 16px; box-shadow: var(--shadow-md); padding: 30px; }
    .auth-logo { font-size: 26px; width: 52px; height: 52px; display: grid; place-items: center; border-radius: 14px; background: linear-gradient(135deg, #3987e5, #1c5cab); color:#fff; box-shadow: 0 8px 20px rgba(42,120,214,0.4); margin-bottom: 18px; }
    h2 { font-size: 20px; font-weight: 800; margin-bottom: 5px; }
    .hint { color: var(--muted); font-size: 13px; margin: 0 0 20px; }
    .err { background: var(--crit-tint); color: var(--crit-text); font-size: 13px; padding: 9px 12px; border-radius: 8px; margin-bottom: 14px; }
    .ok { background: var(--good-tint); color: var(--good-text); font-size: 13px; padding: 10px 12px; border-radius: 8px; }
    .demo-token { margin-top: 14px; padding: 14px; border: 1px dashed var(--border); border-radius: 10px; }
    .demo-label { font-size: 12px; color: var(--muted); margin-bottom: 6px; }
    .demo-token code { font-size: 12px; word-break: break-all; }
    .row-links { text-align: center; margin-top: 18px; font-size: 13px; }
  `],
})
export class ForgotPasswordComponent {
  private readonly auth = inject(AuthService);
  protected readonly router = inject(Router);
  email = '';
  loading = false;
  sent = false;
  error = '';
  message = '';
  demoToken: string | null = null;

  submit(): void {
    if (!this.email.trim()) { this.error = 'Enter your email.'; return; }
    this.loading = true; this.error = '';
    this.auth.forgotPassword(this.email.trim()).subscribe({
      next: r => { this.loading = false; this.sent = true; this.message = r.message; this.demoToken = r.demoToken; },
      error: (e: HttpErrorResponse) => { this.loading = false; this.error = e.status === 0 ? 'Cannot reach the API.' : (e.error?.message ?? 'Request failed.'); },
    });
  }
}
