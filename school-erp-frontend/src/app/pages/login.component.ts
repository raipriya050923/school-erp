import { Component, OnInit, inject, isDevMode } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { HttpErrorResponse } from '@angular/common/http';
import { AuthService } from '../core/auth.service';
import { IconComponent } from '../shared/icon.component';
import { SchoolDoodlesComponent } from '../shared/school-doodles.component';
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
  imports: [FormsModule, RouterLink, IconComponent, SchoolDoodlesComponent],
  template: `
    <div class="login-wrap" [attr.data-theme]="theme">
      <div class="login-hero">
        <app-school-doodles />

        <div class="hero-inner">
          <div class="hero-brand">
            <span class="hero-logo"><app-icon name="cap" [size]="27" /></span>
            <div>
              <div class="hero-name">पाठशाला</div>
              <div class="hero-company">by KSS INFONET</div>
            </div>
          </div>

          <div class="hero-kicker">Complete School ERP &amp; Management Platform</div>
          <h1>Empowering schools with simple, smart and connected digital management.</h1>
          <p class="tagline">Admissions, attendance, exams, fees and staff — one system, four portals, live data.</p>

          <ul class="hero-points">
            <li class="t1"><span class="pt-icon">👥</span><span><b>Students &amp; staff</b>Admissions, roll numbers and portal logins issued automatically.</span></li>
            <li class="t2"><span class="pt-icon">✅</span><span><b>Attendance &amp; exams</b>Daily marking, reports, exam schedules and marks.</span></li>
            <li class="t3"><span class="pt-icon">💰</span><span><b>Fees &amp; billing</b>Invoices, offline payments and outstanding tracked to the rupee.</span></li>
            <li class="t4"><span class="pt-icon">🔒</span><span><b>Secure by tenant</b>Every query scoped to your school — data never crosses over.</span></li>
          </ul>

          <div class="hero-foot">© {{ year }} KSS INFONET · All rights reserved</div>
        </div>
      </div>

      <div class="login-panel">
        <div class="login-card">
          <div class="card-brand">
            <span class="card-logo"><app-icon name="cap" [size]="20" /></span>
            <span class="card-name">पाठशाला</span>
          </div>
          <h2>Welcome back 👋</h2>
          <p class="hint">Sign in to your portal to continue.</p>

          <div class="field">
            <label>Username or email</label>
            <input class="input" [(ngModel)]="username" (keyup.enter)="submit()" placeholder="Username or email" autocomplete="username" />
          </div>
          <div class="field">
            <label>Password</label>
            <div class="pw">
              <input class="input" [type]="showPassword ? 'text' : 'password'" [(ngModel)]="password"
                     (keyup.enter)="submit()" placeholder="••••••••" autocomplete="current-password" />
              <!--
                type="button" matters: inside a form a bare button submits, so revealing the
                password would attempt a sign-in with whatever had been typed so far.
              -->
              <button type="button" class="pw-eye" (click)="showPassword = !showPassword"
                      [attr.aria-label]="showPassword ? 'Hide password' : 'Show password'"
                      [attr.aria-pressed]="showPassword"
                      [title]="showPassword ? 'Hide password' : 'Show password'">
                <app-icon [name]="showPassword ? 'eye-off' : 'eye'" [size]="18" />
              </button>
            </div>
          </div>

          @if (notice) { <div class="notice">{{ notice }}</div> }
          @if (error) { <div class="err">{{ error }}</div> }

          <button class="btn btn-primary" style="width:100%;justify-content:center;" (click)="submit()" [disabled]="loading">
            {{ loading ? 'Signing in…' : 'Sign in' }}
          </button>

          <div class="row-links">
            <a routerLink="/forgot-password">Forgot password?</a>
          </div>

          <div class="panel-foot">Powered by <b>KSS INFONET</b></div>

          @if (showDemo) {
            <div class="demo-box">
              <div class="demo-label">Demo accounts — click to fill (password: <code>{{ demoPass }}</code>)</div>
              <div class="demo-chips">
                <button class="chip" (click)="fill('pramod')">Super Admin</button>
                <button class="chip" (click)="fill('anita')">School Admin</button>
                <button class="chip" (click)="fill('rajesh.k')">Teacher</button>
                <button class="chip" (click)="fill('aarav.t')">Student</button>
                <button class="chip" (click)="fill('bikash.t')">Parent</button>
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
        radial-gradient(760px 420px at 88% -12%, var(--hero-wash), transparent 62%),
        radial-gradient(620px 460px at -8% 110%, var(--hero-wash-2), transparent 58%),
        var(--hero-bg);
      border-right: 1px solid var(--border);
    }
    /* Widened from 470px so the headline sets on two lines instead of three -
       a three-line sentence at display size reads as a paragraph, not a claim. */
    .hero-inner { max-width: 508px; width: 100%; position: relative; z-index: 1; }

    .hero-brand { display: flex; align-items: center; gap: 15px; margin-bottom: 40px; }
    .hero-logo {
      width: 56px; height: 56px; flex: none; color: #fff;
      display: grid; place-items: center; border-radius: 16px;
      background: linear-gradient(135deg, var(--brand-light), var(--brand-dark));
      box-shadow: 0 10px 24px rgba(var(--brand-glow), 0.32);
    }
    /* Devanagari carries a headline (shirorekha) above the letters and sits on a
       taller body than Latin, so the wordmark gets no negative tracking - that
       crushes the conjuncts in पाठशाला. It is also set larger than a Latin
       wordmark would be at the same rank: much of the glyph mass hangs below
       the shirorekha, so matched point sizes leave Devanagari looking smaller.
       This is the login page's primary brand signal, so it outranks the
       headline rather than sitting under it as a caption. */
    .hero-name {
      font-family: var(--font-brand);
      font-size: 34px; font-weight: 700; line-height: 1.22; color: var(--brand);
    }
    .hero-company {
      font-size: 12px; font-weight: 600; color: var(--muted);
      letter-spacing: 0.02em; margin-top: 3px;
    }

    /* An eyebrow, not a second headline. It was brand-blue and bold directly
       above an 800-weight headline, and the two competed for the same glance. */
    .hero-kicker {
      font-size: 11px; font-weight: 700; letter-spacing: 0.11em; text-transform: uppercase;
      color: var(--ink-2); margin-bottom: 12px;
      display: flex; align-items: center; gap: 10px;
    }
    .hero-kicker::before {
      content: ''; width: 22px; height: 2px; flex: none; border-radius: 2px;
      background: var(--brand);
    }
    .login-hero h1 { font-size: 27px; line-height: 1.3; margin: 0 0 14px; letter-spacing: -0.02em; font-weight: 800; }
    .tagline { font-size: 14.5px; color: var(--ink-2); margin: 0 0 26px; line-height: 1.55; }

    .hero-points { margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; gap: 10px; }
    .hero-points li {
      display: flex; align-items: flex-start; gap: 12px;
      padding: 13px 15px;
      border: 1px solid transparent;
      border-radius: 13px;
      /* Dealt in one after another on load, so the panel assembles itself rather
         than arriving as a finished block. "both" keeps them hidden until their
         turn instead of flashing at full opacity first. */
      animation: point-in 520ms cubic-bezier(0.22, 1, 0.36, 1) both;
      background: var(--surface);
      font-size: 13px;
    }
    /* Same four pastel fills the dashboard tiles cycle through. */
    .hero-points li.t1 { background: var(--tile-1); border-color: var(--tile-1-line); }
    .hero-points li.t2 { background: var(--tile-2); border-color: var(--tile-2-line); }
    .hero-points li.t3 { background: var(--tile-3); border-color: var(--tile-3-line); }
    .hero-points li.t4 { background: var(--tile-4); border-color: var(--tile-4-line); }

    .hero-points li.t1 { animation-delay: 160ms; }
    .hero-points li.t2 { animation-delay: 260ms; }
    .hero-points li.t3 { animation-delay: 360ms; }
    .hero-points li.t4 { animation-delay: 460ms; }
    @keyframes point-in {
      from { opacity: 0; transform: translate3d(0, 12px, 0); }
      to   { opacity: 1; transform: translate3d(0, 0, 0); }
    }

    /* A login form must never be withheld behind an entrance animation. */
    @media (prefers-reduced-motion: reduce) {
      .hero-points li { animation: none; }
    }
    .pt-icon {
      width: 32px; height: 32px; flex: none;
      display: grid; place-items: center;
      border-radius: 50%;
      background: var(--surface);
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
      width: 40px; height: 40px; display: grid; place-items: center; border-radius: 12px;
      background: linear-gradient(135deg, var(--brand-light), var(--brand-dark));
      color: #fff;
    }
    .card-name { font-family: var(--font-brand); font-size: 22px; font-weight: 700; line-height: 1.22; color: var(--brand); }
    .login-card h2 { font-size: 22px; margin-bottom: 5px; font-weight: 800; letter-spacing: -0.02em; }
    .hint { color: var(--muted); font-size: 13px; margin: 0 0 22px; }
    .panel-foot { margin-top: 16px; text-align: center; font-size: 11.5px; color: var(--muted); }
    .panel-foot b { color: var(--ink-2); font-weight: 700; }
    /* The reveal control sits inside the field, so the input keeps room for it. */
    .pw { position: relative; }
    .pw .input { width: 100%; padding-right: 44px; }
    .pw-eye {
      position: absolute; top: 50%; right: 4px; transform: translateY(-50%);
      display: grid; place-items: center;
      width: 34px; height: 34px; padding: 0;
      background: none; border: 0; border-radius: 8px; cursor: pointer;
      color: var(--muted);
    }
    .pw-eye:hover { color: var(--ink-2); background: var(--neutral-tint); }
    .pw-eye:focus-visible { outline: 2px solid var(--brand); outline-offset: 1px; }

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

  /** The school's palette, remembered from the last sign-in on this device. */
  get theme(): string { return this.auth.signedOutTheme; }
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  username = '';
  password = '';
  /** Whether the password is shown in clear. Starts hidden, and is never remembered. */
  showPassword = false;
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
      next: u => {
        this.loading = false;
        // Straight to the change screen when the password came from the school: the portal would
        // only fill with 403s until it is replaced.
        this.router.navigateByUrl(u.mustChangePassword ? '/set-password' : u.portalPath);
      },
      error: (e: HttpErrorResponse) => {
        this.loading = false;
        this.error = e.status === 0 ? 'Cannot reach the API. Is it running?' : (e.error?.message ?? 'Login failed.');
      },
    });
  }
}
