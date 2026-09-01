import { HttpClient } from '@angular/common/http';
import { Injectable, inject, signal } from '@angular/core';
import { Observable, tap } from 'rxjs';
import { environment } from '../../environments/environment';

export interface AppNotification {
  id: number;
  title: string;
  body: string | null;
  /** admission | fee | ticket | school | general — drives the icon. */
  type: string;
  isUnread: boolean;
  createdAt: string;
}
export interface NotificationFeed { unreadCount: number; items: AppNotification[]; }

export interface AcademicYear { id: number; name: string; isCurrent: boolean; }

/**
 * Bell feed + academic years for the top bar. Both are per-user reads the shell needs on
 * every page, so the state lives here as signals rather than in the layout component.
 */
@Injectable({ providedIn: 'root' })
export class NotificationService {
  private readonly http = inject(HttpClient);
  private readonly base = environment.apiBaseUrl;

  readonly feed = signal<NotificationFeed>({ unreadCount: 0, items: [] });
  readonly years = signal<AcademicYear[]>([]);
  readonly selectedYear = signal<string>(localStorage.getItem('erp.academicYear') ?? '');

  load(): void {
    this.http.get<NotificationFeed>(`${this.base}/notifications`)
      .subscribe({ next: f => this.feed.set(f), error: () => {} });
  }

  loadYears(): void {
    this.http.get<AcademicYear[]>(`${this.base}/academic-years`).subscribe({
      next: ys => {
        this.years.set(ys);
        // Keep a stored choice only while it still exists; otherwise fall back to the current year.
        const stored = this.selectedYear();
        const valid = ys.some(y => y.name === stored);
        if (!valid) this.selectYear(ys.find(y => y.isCurrent)?.name ?? ys[0]?.name ?? '');
      },
      error: () => this.years.set([]),
    });
  }

  selectYear(name: string): void {
    this.selectedYear.set(name);
    if (name) localStorage.setItem('erp.academicYear', name);
  }

  markRead(id: number): Observable<void> {
    return this.http.post<void>(`${this.base}/notifications/${id}/read`, {}).pipe(tap(() => this.load()));
  }

  markAllRead(): Observable<void> {
    return this.http.post<void>(`${this.base}/notifications/read-all`, {}).pipe(tap(() => this.load()));
  }
}
