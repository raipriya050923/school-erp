import { Component, OnInit, inject } from '@angular/core';
import { ActivatedRoute, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { HttpErrorResponse } from '@angular/common/http';
import { AuthService } from '../core/auth.service';
import { NotificationService, AppNotification } from '../core/notification.service';
import { IconComponent } from './icon.component';

export interface NavItem {
  label: string;
  path: string;
  icon: string;
}

@Component({
  selector: 'app-portal-layout',
  standalone: true,
  imports: [RouterOutlet, RouterLink, RouterLinkActive, IconComponent, FormsModule],
  template: `
    <div class="layout" [attr.data-theme]="theme" [class.nav-open]="navOpen" [class.collapsed]="collapsed">
      <aside class="sidebar">
        <div class="brand">
          <span class="brand-mark"><app-icon name="cap" [size]="22" /></span>
          <div class="brand-text">
            <div class="brand-name">पाठशाला</div>
            <div class="brand-portal">{{ portal }}</div>
          </div>
        </div>
        <div class="nav-section">Menu</div>
        <nav class="side-nav">
          @for (item of nav; track item.path) {
            <a [routerLink]="item.path" routerLinkActive="active" (click)="navOpen = false"
               [title]="collapsed ? item.label : ''">
              <span class="nav-icon"><app-icon [name]="item.icon" [size]="18" /></span>
              <span class="nav-label">{{ item.label }}</span>
            </a>
          }
        </nav>

        <!--
          Sticky, so it stays reachable on a long module list rather than scrolling away with
          the nav. The same action also lives in the avatar menu — this is the one people
          actually look for, at the foot of the thing they navigate with.
        -->
        <div class="side-foot">
          <button class="side-logout" (click)="logout()" [title]="collapsed ? 'Sign out' : ''">
            <span class="nav-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/>
              </svg>
            </span>
            <span class="nav-label">Sign out</span>
          </button>
        </div>
      </aside>

      <div class="scrim" (click)="navOpen = false"></div>

      <div class="main">
        <header class="topbar">
          <button class="icon-btn sidebar-toggle" (click)="toggleSidebar()" aria-label="Toggle sidebar">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="18" x2="21" y2="18"/>
            </svg>
          </button>
          <div class="topbar-title">{{ portal }} Portal</div>
          <div class="spacer"></div>

          <!-- Academic year (tenant portals only — platform staff belong to no school) -->
          @if (notify.years().length) {
            <select class="select fy-select" [ngModel]="notify.selectedYear()"
                    (ngModelChange)="notify.selectYear($event)" aria-label="Academic year">
              @for (y of notify.years(); track y.id) {
                <option [value]="y.name">{{ y.name }}{{ y.isCurrent ? ' (current)' : '' }}</option>
              }
            </select>
          }

          <!-- Notifications -->
          <div class="bell-menu">
            <button class="bell-btn" [class.active]="bellOpen" (click)="toggleBell()" aria-label="Notifications">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/>
              </svg>
              @if (notify.feed().unreadCount > 0) {
                <span class="bell-count">{{ notify.feed().unreadCount > 9 ? '9+' : notify.feed().unreadCount }}</span>
              }
            </button>

            @if (bellOpen) {
              <div class="menu-scrim" (click)="bellOpen = false"></div>
              <div class="bell-dropdown">
                <div class="bell-head">
                  <span class="grow">Notifications</span>
                  @if (notify.feed().unreadCount > 0) {
                    <button class="link-btn" (click)="markAllRead()">Mark all read</button>
                  }
                </div>
                <div class="bell-list">
                  @for (n of notify.feed().items; track n.id) {
                    <button class="bell-item" [class.unread]="n.isUnread" (click)="openNotification(n)">
                      <span class="bell-dot" [class]="'bell-dot ' + n.type"></span>
                      <span class="bell-text">
                        <span class="bell-title">{{ n.title }}</span>
                        @if (n.body) { <span class="bell-body">{{ n.body }}</span> }
                        <span class="bell-time">{{ ago(n.createdAt) }}</span>
                      </span>
                    </button>
                  } @empty {
                    <div class="empty">You're all caught up.</div>
                  }
                </div>
              </div>
            }
          </div>

          <div class="user-menu">
            <button class="user-chip" (click)="menuOpen = !menuOpen" [class.active]="menuOpen">
              <div class="user-meta">
                <div class="user-name">{{ auth.user()?.name }}</div>
                <span class="role-badge">{{ auth.user()?.title }}</span>
              </div>
              <div class="avatar">{{ initials }}</div>
              <svg class="chevron" [class.open]="menuOpen" viewBox="0 0 24 24" fill="none"
                   stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="6 9 12 15 18 9"/>
              </svg>
            </button>

            @if (menuOpen) {
              <div class="menu-scrim" (click)="menuOpen = false"></div>
              <div class="user-dropdown">
                <div class="dd-head">
                  <div class="avatar lg">{{ initials }}</div>
                  <div class="dd-head-meta">
                    <div class="user-name">{{ auth.user()?.name }}</div>
                    <div class="user-title">{{ auth.user()?.email }}</div>
                  </div>
                </div>
                <a class="dd-item" [routerLink]="profilePath" (click)="menuOpen = false">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>
                  </svg>
                  My Profile
                </a>
                <button class="dd-item" (click)="openChangePassword()">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>
                  </svg>
                  Change Password
                </button>
                <button class="dd-item" (click)="openSettings()">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>
                  </svg>
                  Settings
                </button>
                <div class="dd-sep"></div>
                <button class="dd-item danger" (click)="logout()">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/>
                  </svg>
                  Logout
                </button>
              </div>
            }
          </div>
        </header>
        <main class="content">
          <router-outlet />
        </main>
      </div>
    </div>

    <!-- Change password modal -->
    @if (showPassword) {
      <div class="modal-backdrop">
        <div class="modal" style="max-width: 460px;">
          <div class="modal-head">
            <h2>Change Password</h2>
            <button class="modal-close" (click)="showPassword = false" aria-label="Close">✕</button>
          </div>
          <div class="modal-body">
            <div class="field">
              <label>Current password <span class="req">*</span></label>
              <input class="input" type="password" [class.invalid]="!!pwErrors.current" [(ngModel)]="pw.current"
                     (ngModelChange)="pwErrors.current = ''" placeholder="••••••••" />
              @if (pwErrors.current) { <div class="field-error">{{ pwErrors.current }}</div> }
            </div>
            <div class="field">
              <label>New password <span class="req">*</span></label>
              <input class="input" type="password" [class.invalid]="!!pwErrors.next" [(ngModel)]="pw.next"
                     (ngModelChange)="pwErrors.next = ''" placeholder="At least 6 characters" />
              @if (pwErrors.next) { <div class="field-error">{{ pwErrors.next }}</div> }
            </div>
            <div class="field">
              <label>Confirm new password <span class="req">*</span></label>
              <input class="input" type="password" [class.invalid]="!!pwErrors.confirm" [(ngModel)]="pw.confirm"
                     (ngModelChange)="pwErrors.confirm = ''" placeholder="Re-type new password" />
              @if (pwErrors.confirm) { <div class="field-error">{{ pwErrors.confirm }}</div> }
            </div>
            @if (pwError) { <div class="field-error">{{ pwError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showPassword = false">Cancel</button>
            <button class="btn btn-primary" (click)="savePassword()" [disabled]="pwSaving">{{ pwSaving ? 'Updating…' : 'Update Password' }}</button>
          </div>
        </div>
      </div>
    }

    <!--
      Appearance. The palette belongs to the school, not the person: an admin picking Forest
      changes what their teachers and students see too, which the copy says out loud.
    -->
    @if (showSettings) {
      <div class="modal-backdrop">
        <div class="modal" style="max-width: 560px;">
          <div class="modal-head">
            <div class="grow">
              <h2>Settings</h2>
              <div class="td-sub" style="margin-top:2px;">{{ auth.user()?.name }}</div>
            </div>
            <button class="modal-close" (click)="showSettings = false">✕</button>
          </div>
          <div class="modal-body">
            @if (canSetTheme) {
              <div class="field">
                <label>Portal colour</label>
                <div class="theme-picker">
                  @for (t of palettes; track t.key) {
                    <button type="button" class="theme-swatch" [class.on]="theme === t.key"
                            (click)="chooseTheme(t.key)" [disabled]="savingTheme"
                            [attr.aria-pressed]="theme === t.key" [title]="t.note">
                      <span class="theme-chip" [style.background]="t.rail">
                        <span class="theme-pill" [style.background]="t.pill"></span>
                      </span>
                      <span class="theme-name">{{ t.name }}</span>
                    </button>
                  }
                </div>
                <div class="field-hint">
                  Changes the sidebar for everyone at your school — teachers and students included.
                </div>
                @if (themeError) { <div class="field-error">{{ themeError }}</div> }
              </div>
            } @else {
              <div class="field">
                <label>Portal colour</label>
                <div class="theme-picker">
                  @for (t of palettes; track t.key) {
                    @if (theme === t.key) {
                      <span class="theme-swatch on">
                        <span class="theme-chip" [style.background]="t.rail">
                          <span class="theme-pill" [style.background]="t.pill"></span>
                        </span>
                        <span class="theme-name">{{ t.name }}</span>
                      </span>
                    }
                  }
                </div>
                <div class="field-hint">Your school's administrator chooses this.</div>
              </div>
            }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showSettings = false">Close</button>
          </div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class PortalLayoutComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  readonly auth = inject(AuthService);
  readonly notify = inject(NotificationService);

  readonly portal: string = this.route.snapshot.data['portal'] ?? '';
  readonly nav: NavItem[] = this.route.snapshot.data['nav'] ?? [];
  bellOpen = false;
  /**
   * The school's shell palette, stamped on the layout so `styles.scss` can redefine the sidebar
   * tokens for it. Falls back to classic for a platform user, who belongs to no school.
   */
  get theme(): string { return this.auth.user()?.theme || 'classic'; }

  navOpen = false;
  collapsed = localStorage.getItem('erp.sidebarCollapsed') === '1';
  menuOpen = false;

  /** Profile lives inside whichever portal the user is in, e.g. /admin/profile. */
  get profilePath(): string { return `${this.auth.user()?.portalPath ?? ''}/profile`; }
  showPassword = false;
  pw = { current: '', next: '', confirm: '' };
  pwError = '';
  /** Inline messages; pwError is kept for what the API rejects. */
  pwErrors: { current?: string; next?: string; confirm?: string } = {};
  pwSaving = false;
  toast = '';
  private toastTimer?: ReturnType<typeof setTimeout>;

  ngOnInit(): void {
    this.notify.load();
    this.notify.loadYears();
  }

  toggleBell(): void {
    this.bellOpen = !this.bellOpen;
    if (this.bellOpen) this.notify.load();   // refresh on open rather than polling in the background
  }

  markAllRead(): void {
    this.notify.markAllRead().subscribe({ error: () => {} });
  }

  openNotification(n: AppNotification): void {
    if (n.isUnread) this.notify.markRead(n.id).subscribe({ error: () => {} });
  }

  /** Compact relative time — "just now", "3h", "2d". */
  ago(iso: string): string {
    const mins = Math.max(0, Math.round((Date.now() - new Date(iso).getTime()) / 60000));
    if (mins < 1) return 'just now';
    if (mins < 60) return `${mins}m ago`;
    const hours = Math.round(mins / 60);
    if (hours < 24) return `${hours}h ago`;
    const days = Math.round(hours / 24);
    return days < 30 ? `${days}d ago` : new Date(iso).toLocaleDateString();
  }

  /** On mobile the button opens the overlay; on desktop it collapses the rail. */
  toggleSidebar(): void {
    if (window.innerWidth <= 900) {
      this.navOpen = !this.navOpen;
    } else {
      this.collapsed = !this.collapsed;
      localStorage.setItem('erp.sidebarCollapsed', this.collapsed ? '1' : '0');
    }
  }

  get initials(): string {
    const name = this.auth.user()?.name ?? '';
    return name.split(/\s+/).map(w => w.charAt(0)).join('').slice(0, 2).toUpperCase();
  }

  openChangePassword(): void {
    this.menuOpen = false;
    this.pw = { current: '', next: '', confirm: '' };
    this.pwError = '';
    this.pwErrors = {};
    this.showPassword = true;
  }

  savePassword(): void {
    const e: typeof this.pwErrors = {};
    if (!this.pw.current) e.current = 'Enter your current password.';
    if (!this.pw.next) e.next = 'Enter a new password.';
    else if (this.pw.next.length < 6) e.next = 'New password must be at least 6 characters.';
    if (!this.pw.confirm) e.confirm = 'Re-type the new password.';
    else if (this.pw.next && this.pw.next !== this.pw.confirm) e.confirm = 'New passwords do not match.';
    this.pwErrors = e;
    this.pwError = '';
    if (Object.keys(e).length) return;
    this.pwSaving = true;
    this.auth.changePassword(this.pw.current, this.pw.next).subscribe({
      next: () => { this.pwSaving = false; this.showPassword = false; this.showToast('Password updated successfully'); },
      error: (e: HttpErrorResponse) => {
        this.pwSaving = false;
        this.pwError = e.status === 0 ? 'Cannot reach the API.' : (e.error?.message ?? 'Could not update password.');
      },
    });
  }

  showSettings = false;
  savingTheme = false;
  themeError = '';
  readonly palettes = AuthService.THEMES;

  /** Only a school admin owns the school's colour; everyone else sees which one is in force. */
  get canSetTheme(): boolean { return this.auth.user()?.role === 'school_admin'; }

  openSettings(): void {
    this.menuOpen = false;
    this.themeError = '';
    this.showSettings = true;
  }

  chooseTheme(key: string): void {
    if (key === this.theme) return;
    this.savingTheme = true;
    this.themeError = '';
    this.auth.setTheme(key).subscribe({
      next: name => {
        this.savingTheme = false;
        // The session is already patched, so the rail has repainted behind the dialog.
        this.showToast(`Portal colour set to ${this.palettes.find(p => p.key === name)?.name ?? name}`);
      },
      error: e => {
        this.savingTheme = false;
        this.themeError = e?.error?.message ?? 'Could not change the colour.';
      },
    });
  }

  logout(): void {
    this.menuOpen = false;
    this.auth.logout();
    this.router.navigate(['/login']);
  }

  private showToast(msg: string): void {
    this.toast = msg;
    clearTimeout(this.toastTimer);
    this.toastTimer = setTimeout(() => (this.toast = ''), 3000);
  }
}
