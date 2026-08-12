import { Component, inject } from '@angular/core';
import { ActivatedRoute, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { HttpErrorResponse } from '@angular/common/http';
import { AuthService } from '../core/auth.service';
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
    <div class="layout" [class.nav-open]="navOpen" [class.collapsed]="collapsed">
      <aside class="sidebar">
        <div class="brand">
          <span class="brand-mark"><app-icon name="cap" [size]="22" /></span>
          <div class="brand-text">
            <div class="brand-name">EduNexus</div>
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
        <div class="sidebar-foot">
          <span class="dot"></span> <span class="foot-text">Demo build · dummy data</span>
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

          <div class="user-menu">
            <button class="user-chip" (click)="menuOpen = !menuOpen" [class.active]="menuOpen">
              <div class="user-meta">
                <div class="user-name">{{ auth.user()?.name }}</div>
                <div class="user-title">{{ auth.user()?.title }}</div>
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
      <div class="modal-backdrop" (click)="showPassword = false">
        <div class="modal" (click)="$event.stopPropagation()" style="max-width: 460px;">
          <div class="modal-head">
            <h2>Change Password</h2>
            <button class="modal-close" (click)="showPassword = false" aria-label="Close">✕</button>
          </div>
          <div class="modal-body">
            <div class="field">
              <label>Current password</label>
              <input class="input" type="password" [(ngModel)]="pw.current" placeholder="••••••••" />
            </div>
            <div class="field">
              <label>New password</label>
              <input class="input" type="password" [(ngModel)]="pw.next" placeholder="At least 6 characters" />
            </div>
            <div class="field">
              <label>Confirm new password</label>
              <input class="input" type="password" [(ngModel)]="pw.confirm" placeholder="Re-type new password" />
            </div>
            @if (pwError) { <div style="color: var(--crit-text); font-size: 13px;">{{ pwError }}</div> }
          </div>
          <div class="modal-foot">
            <button class="btn btn-ghost" (click)="showPassword = false">Cancel</button>
            <button class="btn btn-primary" (click)="savePassword()" [disabled]="pwSaving">{{ pwSaving ? 'Updating…' : 'Update Password' }}</button>
          </div>
        </div>
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class PortalLayoutComponent {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  readonly auth = inject(AuthService);

  readonly portal: string = this.route.snapshot.data['portal'] ?? '';
  readonly nav: NavItem[] = this.route.snapshot.data['nav'] ?? [];
  navOpen = false;
  collapsed = localStorage.getItem('erp.sidebarCollapsed') === '1';
  menuOpen = false;
  showPassword = false;
  pw = { current: '', next: '', confirm: '' };
  pwError = '';
  pwSaving = false;
  toast = '';
  private toastTimer?: ReturnType<typeof setTimeout>;

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
    this.showPassword = true;
  }

  savePassword(): void {
    if (!this.pw.current || !this.pw.next) { this.pwError = 'All fields are required.'; return; }
    if (this.pw.next.length < 6) { this.pwError = 'New password must be at least 6 characters.'; return; }
    if (this.pw.next !== this.pw.confirm) { this.pwError = 'New passwords do not match.'; return; }
    this.pwSaving = true; this.pwError = '';
    this.auth.changePassword(this.pw.current, this.pw.next).subscribe({
      next: () => { this.pwSaving = false; this.showPassword = false; this.showToast('Password updated successfully'); },
      error: (e: HttpErrorResponse) => {
        this.pwSaving = false;
        this.pwError = e.status === 0 ? 'Cannot reach the API.' : (e.error?.message ?? 'Could not update password.');
      },
    });
  }

  openSettings(): void {
    this.menuOpen = false;
    this.showToast('Settings — coming soon');
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
