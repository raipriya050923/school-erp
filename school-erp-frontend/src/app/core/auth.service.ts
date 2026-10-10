import { Injectable, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, map } from 'rxjs';
import { environment } from '../../environments/environment';

export type Role = 'super_admin' | 'school_admin' | 'teacher' | 'student' | 'parent';

export interface SessionUser {
  id: number;
  schoolId: number | null;
  role: Role;
  userType: string;
  username: string;
  name: string;
  email: string;
  title: string;
  portalPath: string;
  /** Bearer token carrying the signed school id that scopes every API call. */
  token: string;
  expiresAtUtc: string;
  /** True while still on a password the school issued; the API refuses everything until cleared. */
  mustChangePassword: boolean;
  /** The school's shell palette: classic | brand | forest | mist. */
  theme: string;
}

/** Raw shape returned by POST /api/auth/login. */
interface AuthUserResponse {
  id: number;
  schoolId: number | null;
  userType: string;
  role: Role;
  username: string;
  email: string | null;
  fullName: string;
  portalPath: string;
  title: string;
  token: string;
  expiresAtUtc: string;
  mustChangePassword: boolean;
  theme: string;
}

/** Deliberately message-only: the reset token leaves the server by email and nowhere else. */
export interface ForgotResult { message: string; }

const STORAGE_KEY = 'erp.session';
/**
 * The palette of the school last signed in from on this device. Kept apart from the session
 * because it must survive logout: the sign-in page has no session to read, so without this it
 * would be the one screen in the product that ignores the school's colours.
 */
const THEME_KEY = 'erp.lastTheme';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);
  private readonly base = environment.authApi;
  readonly user = signal<SessionUser | null>(this.restore());

  /** Authenticate against the API. Persists the session on success. */
  login(username: string, password: string): Observable<SessionUser> {
    return this.http.post<AuthUserResponse>(`${this.base}/login`, { username, password }).pipe(
      map(r => {
        const u: SessionUser = {
          id: r.id, schoolId: r.schoolId, role: r.role, userType: r.userType,
          username: r.username, name: r.fullName, email: r.email ?? '',
          title: r.title, portalPath: r.portalPath,
          token: r.token, expiresAtUtc: r.expiresAtUtc,
          mustChangePassword: r.mustChangePassword ?? false,
          theme: r.theme || 'classic',
        };
        localStorage.setItem(STORAGE_KEY, JSON.stringify(u));
        // Remembered separately so the sign-in page can wear it next time.
        try { localStorage.setItem(THEME_KEY, u.theme); } catch { /* private mode */ }
        this.user.set(u);
        return u;
      }),
    );
  }

  changePassword(currentPassword: string, newPassword: string): Observable<void> {
    const username = this.user()?.username ?? '';
    return this.http.post<void>(`${this.base}/change-password`, { username, currentPassword, newPassword });
  }

  forgotPassword(email: string): Observable<ForgotResult> {
    return this.http.post<ForgotResult>(`${this.base}/forgot-password`, { email });
  }

  resetPassword(token: string, newPassword: string): Observable<void> {
    return this.http.post<void>(`${this.base}/reset-password`, { token, newPassword });
  }

  /**
   * The palettes a school may wear. Kept beside the session because the layout reads the
   * session's `theme`, and these are the values it understands.
   */
  static readonly THEMES = [
    { key: 'classic', name: 'Classic', rail: '#ffffff',                                 pill: '#4f46e5', note: 'The white masthead the product ships with' },
    { key: 'brand',   name: 'Brand',   rail: 'linear-gradient(160deg,#2563eb,#1d4ed8)', pill: '#ffffff', note: 'Royal blue masthead' },
    { key: 'forest',  name: 'Forest',  rail: 'linear-gradient(160deg,#154439,#10362f)', pill: '#0f9b76', note: 'Deep green, the traditional school colour' },
    { key: 'mist',    name: 'Mist',    rail: '#eef2f9',                                 pill: '#2563eb', note: 'Pale blue-grey masthead' },
  ];

  /**
   * Changes the school's palette. The stored session is patched from the response so the rail
   * repaints immediately — waiting for the next sign-in to see a colour you just picked reads
   * as the setting not having worked.
   */
  setTheme(theme: string): Observable<string> {
    return this.http.put<{ theme: string }>(`${environment.adminApi}/appearance`, { theme }).pipe(
      map(r => {
        const u = this.user();
        if (u) {
          const next = { ...u, theme: r.theme };
          localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
          try { localStorage.setItem(THEME_KEY, r.theme); } catch { /* private mode */ }
          this.user.set(next);
        }
        return r.theme;
      }),
    );
  }

  /**
   * The palette to paint a signed-out page with: the live session's if there is one, otherwise
   * whatever this device last signed in as. Classic on a first visit, which is the right guess
   * when there is nothing to go on.
   */
  get signedOutTheme(): string {
    const live = this.user()?.theme;
    if (live) return live;
    try { return localStorage.getItem(THEME_KEY) || 'classic'; } catch { return 'classic'; }
  }

  logout(): void {
    localStorage.removeItem(STORAGE_KEY);
    this.user.set(null);
  }

  /** The bearer token for outgoing requests, or null when signed out / expired. */
  get token(): string | null {
    const u = this.user();
    if (!u?.token) return null;
    if (Date.parse(u.expiresAtUtc) <= Date.now()) { this.logout(); return null; }
    return u.token;
  }

  private restore(): SessionUser | null {
    try {
      const u: SessionUser | null = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? 'null');
      // Sessions from before tokens existed, and expired ones, are not usable.
      if (!u?.token || Date.parse(u.expiresAtUtc) <= Date.now()) {
        localStorage.removeItem(STORAGE_KEY);
        return null;
      }
      return u;
    } catch {
      return null;
    }
  }
}
