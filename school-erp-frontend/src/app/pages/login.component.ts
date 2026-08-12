import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { HttpErrorResponse } from '@angular/common/http';
import { AuthService } from '../core/auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [FormsModule, RouterLink],
  template: `
    <div class="login-wrap">
      <div class="login-hero">
        <div class="hero-inner">
          <div class="hero-logo">🎓</div>
          <h1>EduNexus</h1>
          <p class="tagline">Multi-tenant School ERP for mid-level schools</p>
          <ul class="hero-points">
            <li>4 role-based portals · 255+ screens</li>
            <li>Academics, attendance, exams, fees &amp; more</li>
            <li>Live data over a .NET + MySQL backend</li>
          </ul>
        </div>
      </div>

      <div class="login-panel">
        <div class="login-card">
          <h2>Sign in</h2>
          <p class="hint">Enter your credentials to access your portal.</p>

          <div class="field">
            <label>Username or email</label>
            <input class="input" [(ngModel)]="username" (keyup.enter)="submit()" placeholder="e.g. pramod" autocomplete="username" />
          </div>
          <div class="field">
            <label>Password</label>
            <input class="input" type="password" [(ngModel)]="password" (keyup.enter)="submit()" placeholder="••••••••" autocomplete="current-password" />
          </div>

          @if (error) { <div class="err">{{ error }}</div> }

          <button class="btn btn-primary" style="width:100%;justify-content:center;" (click)="submit()" [disabled]="loading">
            {{ loading ? 'Signing in…' : 'Sign in' }}
          </button>

          <div class="row-links">
            <a routerLink="/forgot-password">Forgot password?</a>
          </div>

          <div class="demo-box">
            <div class="demo-label">Demo accounts — click to fill (password: <code>Password&#64;123</code>)</div>
            <div class="demo-chips">
              <button class="chip" (click)="fill('pramod')">Super Admin</button>
              <button class="chip" (click)="fill('anita')">School Admin</button>
              <button class="chip" (click)="fill('rajesh.k')">Teacher</button>
              <button class="chip" (click)="fill('aarav.t')">Student</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .login-wrap { display: flex; min-height: 100vh; }
    .login-hero {
      flex: 1;
      background:
        radial-gradient(900px 500px at 85% -10%, rgba(57,135,229,0.35), transparent 60%),
        radial-gradient(700px 500px at -10% 110%, rgba(28,92,171,0.5), transparent 55%),
        #101828;
      color: #fff; display: flex; align-items: center; justify-content: center; padding: 40px;
      position: relative; overflow: hidden;
    }
    .login-hero::after {
      content: ""; position: absolute; inset: 0;
      background-image: linear-gradient(rgba(255,255,255,0.035) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.035) 1px, transparent 1px);
      background-size: 44px 44px; mask-image: radial-gradient(600px 500px at 50% 40%, #000 30%, transparent 75%);
    }
    .hero-inner { max-width: 400px; position: relative; z-index: 1; }
    .hero-logo { font-size: 40px; width: 60px; height: 60px; display: grid; place-items: center; border-radius: 16px; background: linear-gradient(135deg, #3987e5, #1c5cab); box-shadow: 0 12px 32px rgba(42,120,214,0.45); margin-bottom: 22px; }
    .login-hero h1 { font-size: 36px; margin: 0 0 10px; letter-spacing: -0.03em; font-weight: 800; }
    .tagline { font-size: 16px; color: #b9c0cc; margin: 0 0 28px; line-height: 1.5; }
    .hero-points { margin: 0; padding: 0; list-style: none; font-size: 14px; color: #d0d5dd; }
    .hero-points li { padding: 7px 0; display: flex; align-items: center; gap: 10px; }
    .hero-points li::before { content: "✓"; color: #4ade80; font-weight: 800; width: 22px; height: 22px; display: grid; place-items: center; background: rgba(74,222,128,0.12); border-radius: 50%; font-size: 12px; flex: 0 0 22px; }
    .login-panel { flex: 1; display: flex; align-items: center; justify-content: center; padding: 32px 20px; background: var(--page); }
    .login-card { width: 100%; max-width: 400px; }
    .login-card h2 { font-size: 22px; margin-bottom: 5px; font-weight: 800; letter-spacing: -0.02em; }
    .hint { color: var(--muted); font-size: 13px; margin: 0 0 22px; }
    .err { background: var(--crit-tint); color: var(--crit-text); font-size: 13px; font-weight: 500; padding: 9px 12px; border-radius: 8px; margin-bottom: 14px; }
    .row-links { text-align: center; margin-top: 14px; font-size: 13px; }
    .demo-box { margin-top: 26px; border-top: 1px solid var(--border); padding-top: 18px; }
    .demo-label { font-size: 12px; color: var(--muted); margin-bottom: 10px; }
    .demo-label code { background: var(--neutral-tint); padding: 1px 6px; border-radius: 5px; font-size: 11px; }
    .demo-chips { display: flex; flex-wrap: wrap; gap: 8px; }
    .chip { font-family: inherit; font-size: 12px; font-weight: 600; padding: 6px 12px; border: 1px solid var(--border); border-radius: 999px; background: var(--surface); color: var(--ink-2); cursor: pointer; }
    .chip:hover { border-color: var(--brand); color: var(--brand-dark); background: var(--brand-tint); }
    @media (max-width: 860px) { .login-hero { display: none; } }
  `],
})
export class LoginComponent {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  username = '';
  password = '';
  loading = false;
  error = '';

  fill(username: string): void { this.username = username; this.password = 'Password@123'; this.error = ''; }

  submit(): void {
    if (!this.username.trim() || !this.password) { this.error = 'Enter your username and password.'; return; }
    this.loading = true; this.error = '';
    this.auth.login(this.username.trim(), this.password).subscribe({
      next: u => { this.loading = false; this.router.navigateByUrl(u.portalPath); },
      error: (e: HttpErrorResponse) => {
        this.loading = false;
        this.error = e.status === 0 ? 'Cannot reach the API. Is it running?' : (e.error?.message ?? 'Login failed.');
      },
    });
  }
}
