import { Injectable, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, map } from 'rxjs';
import { environment } from '../../environments/environment';

export type Role = 'super_admin' | 'school_admin' | 'teacher' | 'student';

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
}

export interface ForgotResult { message: string; demoToken: string | null; }

const STORAGE_KEY = 'erp.session';

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
        };
        localStorage.setItem(STORAGE_KEY, JSON.stringify(u));
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

  logout(): void {
    localStorage.removeItem(STORAGE_KEY);
    this.user.set(null);
  }

  private restore(): SessionUser | null {
    try {
      return JSON.parse(localStorage.getItem(STORAGE_KEY) ?? 'null');
    } catch {
      return null;
    }
  }
}
