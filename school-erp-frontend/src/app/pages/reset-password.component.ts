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
    <div class="auth-page">
      <div class="auth-card">
        <div class="auth-logo">🎓</div>
        <h2>Reset password</h2>
        <p class="hint">Enter the token from your email and choose a new password.</p>

        @if (!done) {
          <div class="field"><label>Reset token</label><input class="input" [(ngModel)]="token" placeholder="token" /></div>
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
  private readonly route = inject(ActivatedRoute);
  protected readonly router = inject(Router);
  token = '';
  newPassword = '';
  confirm = '';
  loading = false;
  done = false;
  error = '';

  ngOnInit(): void {
    this.token = this.route.snapshot.queryParamMap.get('token') ?? '';
  }

  submit(): void {
    if (!this.token.trim()) { this.error = 'The reset token is required.'; return; }
    if (this.newPassword.length < 6) { this.error = 'Password must be at least 6 characters.'; return; }
    if (this.newPassword !== this.confirm) { this.error = 'Passwords do not match.'; return; }
    this.loading = true; this.error = '';
    this.auth.resetPassword(this.token.trim(), this.newPassword).subscribe({
      next: () => { this.loading = false; this.done = true; },
      error: (e: HttpErrorResponse) => { this.loading = false; this.error = e.status === 0 ? 'Cannot reach the API.' : (e.error?.message ?? 'Reset failed.'); },
    });
  }
}
