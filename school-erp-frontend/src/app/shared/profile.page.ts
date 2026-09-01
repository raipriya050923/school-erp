import { Component, OnInit, inject } from '@angular/core';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { environment } from '../../environments/environment';

export interface ProfileDetail { label: string; value: string | null; }
export interface MyProfile {
  userId: number;
  username: string;
  fullName: string;
  email: string | null;
  phone: string | null;
  role: string;
  title: string;
  schoolId: number | null;
  schoolName: string | null;
  /** Role-specific rows built server-side, so this page renders every role unchanged. */
  details: ProfileDetail[];
}

/**
 * "My Profile" for whichever role is signed in. Mounted at `<portal>/profile` in all four
 * route files so it inherits each portal's own layout and nav.
 */
@Component({
  selector: 'app-profile',
  standalone: true,
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>My Profile</h1>
        <div class="page-sub">Your account details</div>
      </div>
    </div>

    @if (loading) { <div class="card"><div class="empty">Loading…</div></div> }
    @else if (error) { <div class="card"><div class="empty">{{ error }}</div></div> }

    <!-- Aliasing with "as" is only valid on a primary @if, so this is its own block. -->
    @if (p; as me) {
      <div class="card">
        <div class="profile-head">
          <div class="avatar xl">{{ initials }}</div>
          <div>
            <h2 class="profile-name">{{ me.fullName }}</h2>
            <div class="profile-role">{{ me.title }}@if (me.schoolName) { · {{ me.schoolName }} }</div>
          </div>
        </div>
        <div class="card-body">
          <div class="kv-row"><span class="kv-label">Username</span><span class="kv-value"><code>{{ me.username }}</code></span></div>
          <div class="kv-row"><span class="kv-label">Email</span><span class="kv-value">{{ me.email || '—' }}</span></div>
          <div class="kv-row"><span class="kv-label">Phone</span><span class="kv-value">{{ me.phone || '—' }}</span></div>
          @if (me.schoolName) {
            <div class="kv-row"><span class="kv-label">School</span><span class="kv-value">{{ me.schoolName }}</span></div>
          }
          @for (d of me.details; track d.label) {
            <div class="kv-row"><span class="kv-label">{{ d.label }}</span><span class="kv-value">{{ d.value || '—' }}</span></div>
          }
        </div>
      </div>

      <div class="card">
        <div class="card-head"><h2 class="grow">Security</h2></div>
        <div class="card-body">
          <p class="td-sub" style="margin:0 0 12px;">
            Change your password from the account menu in the top-right corner.
          </p>
        </div>
      </div>
    }
  `,
  styles: [`
    .profile-head { display: flex; align-items: center; gap: 18px; padding: 20px; border-bottom: 1px solid var(--border); }
    .profile-name { font-size: 20px; font-weight: 800; letter-spacing: -0.02em; margin: 0 0 2px; }
    .profile-role { font-size: 13px; color: var(--muted); }
    .avatar.xl { width: 64px; height: 64px; font-size: 22px; flex: 0 0 64px; }
  `],
})
export class ProfilePageComponent implements OnInit {
  private readonly http = inject(HttpClient);
  p: MyProfile | null = null;
  loading = true;
  error = '';

  get initials(): string {
    return (this.p?.fullName ?? '')
      .split(' ').filter(Boolean).slice(0, 2).map(w => w[0]).join('').toUpperCase() || '?';
  }

  ngOnInit(): void {
    this.http.get<MyProfile>(`${environment.authApi}/me`).subscribe({
      next: p => { this.p = p; this.loading = false; },
      error: (e: HttpErrorResponse) => {
        this.error = e.status === 0 ? 'Cannot reach the API.' : (e.error?.message ?? 'Could not load your profile.');
        this.loading = false;
      },
    });
  }
}
