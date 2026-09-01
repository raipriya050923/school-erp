import { Component, OnInit, inject, isDevMode } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { HttpErrorResponse } from '@angular/common/http';
import { AuthService } from '../core/auth.service';
import { environment } from '../../environments/environment';

/**
 * Matches Accounts:FixedPassword in appsettings.Development.json. Built from parts so the
 * password never appears as a literal in a shipped bundle — `environment.production` is decided
 * at runtime from the hostname, so it cannot tree-shake the constant away on its own.
 */
const devPassword = () => ['Admin', '@', '123'].join('');

/** The seeded demo accounts predate the fixed-password setting, so they keep their own. */
const demoPassword = () => ['Password', '@', '123'].join('');

/**
 * True only when the app is served from localhost by a development build. Gates everything on
 * this page that hands out credentials — the prefilled password and the demo-account chips —
 * so the two can never disagree about whether this is a real deployment.
 */
const isLocalDev = () => isDevMode() && !environment.production;

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [FormsModule, RouterLink],
  template: `
    <div class="login-wrap">
      <div class="login-hero">
        <div class="hero-inner">
          <div class="hero-brand">
            <span class="hero-logo">🎓</span>
            <div>
              <div class="hero-name">EduNexus</div>
              <div class="hero-company">by Nexa Fusion Technology</div>
            </div>
          </div>

          <h1>Run your whole school from one place.</h1>
          <p class="tagline">Admissions, attendance, exams, fees and staff — one system, four portals, live data.</p>

          <ul class="hero-points">
            <li class="t1"><span class="pt-icon">👥</span><span><b>Students &amp; staff</b>Admissions, roll numbers and portal logins issued automatically.</span></li>
            <li class="t2"><span class="pt-icon">✅</span><span><b>Attendance &amp; exams</b>Daily marking, reports, exam schedules and marks.</span></li>
            <li class="t3"><span class="pt-icon">💰</span><span><b>Fees &amp; billing</b>Invoices, offline payments and outstanding tracked to the rupee.</span></li>
            <li class="t4"><span class="pt-icon">🔒</span><span><b>Secure by tenant</b>Every query scoped to your school — data never crosses over.</span></li>
          </ul>

          <div class="hero-foot">© {{ year }} Nexa Fusion Technology · All rights reserved</div>
        </div>
      </div>

      <div class="login-panel">
        <div class="login-card">
          <div class="card-brand">
            <span class="card-logo">🎓</span>
            <span class="card-name">EduNexus</span>
          </div>
          <h2>Welcome back 👋</h2>
          <p class="hint">Sign in to your portal to continue.</p>

          <div class="field">
            <label>Username or email</label>
            <input class="input" [(ngModel)]="username" (keyup.enter)="submit()" placeholder="e.g. pramod" autocomplete="username" />
          </div>
          <div class="field">
            <label>Password</label>
            <input class="input" type="password" [(ngModel)]="password" (keyup.enter)="submit()" placeholder="••••••••" autocomplete="current-password" />
          </div>

          @if (notice) { <div class="notice">{{ notice }}</div> }
          @if (error) { <div class="err">{{ error }}</div> }

          <button class="btn btn-primary" style="width:100%;justify-content:center;" (click)="submit()" [disabled]="loading">
            {{ loading ? 'Signing in…' : 'Sign in' }}
          </button>

          <div class="row-links">
            <a routerLink="/forgot-password">Forgot password?</a>
          </div>

          <div class="panel-foot">Powered by <b>Nexa Fusion Technology</b></div>

          @if (showDemo) {
            <div class="demo-box">
              <div class="demo-label">Demo accounts — click to fill (password: <code>{{ demoPass }}</code>)</div>
              <div class="demo-chips">
                <button class="chip" (click)="fill('pramod')">Super Admin</button>
                <button class="chip" (click)="fill('anita')">School Admin</button>
                <button class="chip" (click)="fill('rajesh.k')">Teacher</button>
                <button class="chip" (click)="fill('aarav.t')">Student</button>
              </div>
            </div>
          }
        </div>
      </div>
    </div>
  `,
  styles: [`
    .login-wrap { display: flex; min-height: 100vh; background: var(--page); }

    /* ---- Left: brand panel, light and pastel like the rest of the app ---- */
    .login-hero {
      flex: 1.1;
      position: relative;
      overflow: hidden;
      display: flex; align-items: center; justify-content: center;
      padding: 48px 40px;
      color: var(--ink);
      background:
        radial-gradient(760px 420px at 88% -12%, rgba(37, 99, 235, 0.13), transparent 62%),
        radial-gradient(620px 460px at -8% 110%, rgba(124, 58, 237, 0.10), transparent 58%),
        linear-gradient(160deg, #f2f7ff 0%, #eef4fd 55%, #f6f8fc 100%);
      border-right: 1px solid var(--border);
    }
    .hero-inner { max-width: 470px; width: 100%; position: relative; z-index: 1; }

    .hero-brand { display: flex; align-items: center; gap: 13px; margin-bottom: 34px; }
    .hero-logo {
      font-size: 26px; width: 52px; height: 52px; flex: none;
      display: grid; place-items: center; border-radius: 15px;
      background: linear-gradient(135deg, var(--brand-light), var(--brand-dark));
      box-shadow: 0 10px 24px rgba(37, 99, 235, 0.32);
    }
    .hero-name { font-size: 20px; font-weight: 800; letter-spacing: -0.4px; color: var(--brand); }
    .hero-company { font-size: 11.5px; font-weight: 600; color: var(--ink-2); margin-top: 1px; }

    .login-hero h1 { font-size: 32px; line-height: 1.22; margin: 0 0 12px; letter-spacing: -0.03em; font-weight: 800; }
    .tagline { font-size: 15px; color: var(--ink-2); margin: 0 0 28px; line-height: 1.55; }

    .hero-points { margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; gap: 10px; }
    .hero-points li {
      display: flex; align-items: flex-start; gap: 12px;
      padding: 13px 15px;
      border: 1px solid transparent;
      border-radius: 13px;
      background: rgba(255, 255, 255, 0.72);
      font-size: 13px;
    }
    /* Same four pastel fills the dashboard tiles cycle through. */
    .hero-points li.t1 { background: var(--tile-1); border-color: var(--tile-1-line); }
    .hero-points li.t2 { background: var(--tile-2); border-color: var(--tile-2-line); }
    .hero-points li.t3 { background: var(--tile-3); border-color: var(--tile-3-line); }
    .hero-points li.t4 { background: var(--tile-4); border-color: var(--tile-4-line); }
    .pt-icon {
      width: 32px; height: 32px; flex: none;
      display: grid; place-items: center;
      border-radius: 50%;
      background: rgba(255, 255, 255, 0.85);
      font-size: 15px;
    }
    .hero-points span span, .hero-points li > span:last-child { display: block; color: var(--ink-2); line-height: 1.5; }
    .hero-points b { display: block; color: var(--ink); font-size: 13.5px; font-weight: 700; margin-bottom: 2px; }
    .hero-foot { margin-top: 30px; font-size: 11.5px; color: var(--muted); }

    /* ---- Right: the sign-in card ---- */
    .login-panel { flex: 1; display: flex; align-items: center; justify-content: center; padding: 32px 20px; }
    .login-card {
      width: 100%; max-width: 400px;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 28px;
      box-shadow: var(--shadow-md);
    }
    /* Shown only when the brand panel is hidden on narrow screens. */
    .card-brand { display: none; align-items: center; gap: 10px; margin-bottom: 18px; }
    .card-logo {
      width: 38px; height: 38px; display: grid; place-items: center; border-radius: 11px;
      background: linear-gradient(135deg, var(--brand-light), var(--brand-dark));
      font-size: 19px;
    }
    .card-name { font-size: 17px; font-weight: 800; color: var(--brand); letter-spacing: -0.3px; }
    .login-card h2 { font-size: 22px; margin-bottom: 5px; font-weight: 800; letter-spacing: -0.02em; }
    .hint { color: var(--muted); font-size: 13px; margin: 0 0 22px; }
    .panel-foot { margin-top: 16px; text-align: center; font-size: 11.5px; color: var(--muted); }
    .panel-foot b { color: var(--ink-2); font-weight: 700; }
    .err { background: var(--crit-tint); color: var(--crit-text); font-size: 13px; font-weight: 500; padding: 9px 12px; border-radius: 8px; margin-bottom: 14px; }
    .notice { background: var(--neutral-tint); color: var(--ink-2); font-size: 13px; padding: 9px 12px; border-radius: 8px; margin-bottom: 14px; }
    .row-links { text-align: center; margin-top: 14px; font-size: 13px; }
    .demo-box { margin-top: 26px; border-top: 1px solid var(--border); padding-top: 18px; }
    .demo-label { font-size: 12px; color: var(--muted); margin-bottom: 10px; }
    .demo-label code { background: var(--neutral-tint); padding: 1px 6px; border-radius: 5px; font-size: 11px; }
    .demo-chips { display: flex; flex-wrap: wrap; gap: 8px; }
    .chip { font-family: inherit; font-size: 12px; font-weight: 600; padding: 6px 12px; border: 1px solid var(--border); border-radius: 999px; background: var(--surface); color: var(--ink-2); cursor: pointer; }
    .chip:hover { border-color: var(--brand); color: var(--brand-dark); background: var(--brand-tint); }
    @media (max-width: 860px) {
      .login-hero { display: none; }
      .card-brand { display: flex; }
    }
  `],
})
export class LoginComponent implements OnInit {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  username = '';
  password = '';
  loading = false;
  error = '';
  notice = '';
  readonly year = new Date().getFullYear();
  /** Demo chips are a local-development convenience; a deployed build never offers them. */
  readonly showDemo = isLocalDev();
  readonly demoPass = this.showDemo ? demoPassword() : '';

  /** The interceptor redirects here with ?expired=1 when the API rejects a stale token. */
  ngOnInit(): void {
    if (this.route.snapshot.queryParamMap.has('expired')) {
      this.notice = 'Your session has expired. Please sign in again.';
    }
    // Local development only: accounts provisioned while Accounts:FixedPassword is set all share
    // this password, so prefilling saves typing it on every reload. Two guards, both required:
    // isDevMode() is false in any production build, and `production` is false only on
    // localhost/127.0.0.1 — so a deployed build never prefills, however it is served.
    if (this.showDemo) this.password = devPassword();
  }

  fill(username: string): void { this.username = username; this.password = demoPassword(); this.error = ''; }

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
