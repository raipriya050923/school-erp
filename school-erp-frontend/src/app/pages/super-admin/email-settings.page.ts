import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { DatePipe } from '@angular/common';
import { Component, inject, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { environment } from '../../../environments/environment';

function apiError(err: unknown, fallback = 'Something went wrong.'): string {
  const e = err as HttpErrorResponse;
  if (e?.status === 0) return 'Cannot reach the API. Is it running on the configured URL?';
  return e?.error?.message ?? e?.message ?? fallback;
}

interface EmailSettings {
  smtpHost: string | null;
  smtpPort: number;
  useSsl: boolean;
  useStartTls: boolean;
  userName: string | null;
  senderEmail: string | null;
  senderName: string | null;
  testRecipient: string | null;
  /** Whether a password is stored. Never the password itself. */
  hasPassword: boolean;
  updatedAt: string | null;
  /** True while appsettings.json is still in charge and nothing has been saved here. */
  usingFallback: boolean;
}

interface TestResult { sent: boolean; to: string; via: string; error?: string; }

/**
 * Outbound mail, as the platform owner sets it.
 *
 * The password is write-only: the API stores it encrypted and never hands it back, so this
 * page can say whether one is set and offer to replace it, and nothing else. Leaving the field
 * empty on save keeps the stored one — otherwise editing a sender name would silently wipe it.
 */
@Component({
  selector: 'app-sa-email-settings',
  standalone: true,
  imports: [FormsModule, DatePipe],
  template: `
    <div class="page-head">
      <div class="grow">
        <h1>Email Settings</h1>
        <div class="page-sub">
          The mailbox every welcome, reminder and reset is sent from.
        </div>
      </div>
    </div>

    @if (loading) { <div class="card"><div class="empty">Loading…</div></div> }
    @else {
      @if (form.usingFallback) {
        <!-- Said out loud: the form is pre-filled from the file, and nothing is stored yet. -->
        <div class="sub-banner warn">
          <div class="grow">
            <b>Not saved here yet</b>
            These values come from the deployment's configuration file. Saving stores them in
            the database, and from then on this page is what the application reads.
          </div>
        </div>
      }

      <div class="card">
        <div class="card-head"><h2 class="grow">Server</h2></div>
        <div class="card-body">
          <div class="form-row">
            <div class="field">
              <label>SMTP host <span class="req">*</span></label>
              <input class="input" [(ngModel)]="form.smtpHost" placeholder="smtp.hostinger.com" />
            </div>
            <div class="field">
              <label>Port <span class="req">*</span></label>
              <input class="input" type="number" [(ngModel)]="form.smtpPort" />
            </div>
          </div>

          <div class="field">
            <label>Encryption <span class="req">*</span></label>
            <select class="select" [ngModel]="encryption" (ngModelChange)="setEncryption($event)">
              <option value="starttls">STARTTLS — usually port 587</option>
              <option value="ssl">SSL on connect — usually port 465</option>
            </select>
            <div class="field-hint">
              Not interchangeable, and which one works depends on the host and this machine's
              certificate store rather than on preference.
            </div>
          </div>
        </div>
      </div>

      <div class="card">
        <div class="card-head"><h2 class="grow">Mailbox</h2></div>
        <div class="card-body">
          <div class="form-row">
            <div class="field">
              <label>Sender address <span class="req">*</span></label>
              <input class="input" [(ngModel)]="form.senderEmail" placeholder="info@yourdomain.com" />
              <div class="field-hint">What recipients see, and what they reply to.</div>
            </div>
            <div class="field">
              <label>Sender name</label>
              <input class="input" [(ngModel)]="form.senderName" placeholder="KSS INFONET" />
            </div>
          </div>

          <div class="field">
            <label>Username</label>
            <input class="input" [(ngModel)]="form.userName" />
            <div class="field-hint">
              Only when the login differs from the sender address. Most hosts want them equal.
            </div>
          </div>

          <div class="field">
            <label>Password</label>
            <div class="pw">
              <input class="input" [type]="showPassword ? 'text' : 'password'"
                     [(ngModel)]="password"
                     [placeholder]="form.hasPassword ? 'Stored — leave blank to keep it' : 'Not set'" />
              <button type="button" class="pw-eye" (click)="showPassword = !showPassword"
                      [attr.aria-label]="showPassword ? 'Hide password' : 'Show password'">
                {{ showPassword ? '🙈' : '👁' }}
              </button>
            </div>
            <div class="field-hint">
              Encrypted before it is stored and never shown again — not even here.
              @if (form.hasPassword) { Leave this empty to keep the one already saved. }
            </div>
          </div>
        </div>
      </div>

      <div class="card">
        <div class="card-head"><h2 class="grow">Testing</h2></div>
        <div class="card-body">
          <div class="field">
            <label>Default test recipient</label>
            <input class="input" [(ngModel)]="form.testRecipient" />
            <div class="field-hint">Where "Send test" goes when no address is given.</div>
          </div>

          <div class="filters">
            <input class="input" [(ngModel)]="testTo" placeholder="Send a test to… (optional)" />
            <button class="btn btn-ghost" (click)="sendTest()" [disabled]="testing">
              {{ testing ? 'Sending…' : 'Send test' }}
            </button>
          </div>

          @if (testResult) {
            <div class="notice-box" style="margin-top:12px;"
                 [style.background]="testResult.sent ? 'var(--good-tint)' : 'var(--crit-tint)'"
                 [style.color]="testResult.sent ? 'var(--good-text)' : 'var(--crit-text)'">
              @if (testResult.sent) {
                Sent to <b>{{ testResult.to }}</b> via {{ testResult.via }}.
              } @else {
                <!-- The server's own words: an auth rejection and a blocked port read
                     very differently, and "sending failed" tells nobody which. -->
                Could not send to <b>{{ testResult.to }}</b>: {{ testResult.error }}
              }
            </div>
          }
          <div class="field-hint" style="margin-top:8px;">
            A test uses what is <em>saved</em>, not what is on screen. Save first.
          </div>
        </div>
      </div>

      @if (error) { <div class="field-error">{{ error }}</div> }

      <div class="filters">
        <button class="btn btn-primary" (click)="save()" [disabled]="saving">
          {{ saving ? 'Saving…' : 'Save Settings' }}
        </button>
        @if (form.updatedAt) {
          <span class="td-sub">Last changed {{ form.updatedAt | date:'medium' }}</span>
        }
      </div>
    }

    @if (toast) { <div class="toast success">{{ toast }}</div> }
  `,
})
export class SaEmailSettingsComponent implements OnInit {
  private readonly http = inject(HttpClient);
  private readonly base = `${environment.superAdminApi}/email-settings`;

  form: EmailSettings = {
    smtpHost: '', smtpPort: 587, useSsl: false, useStartTls: true,
    userName: '', senderEmail: '', senderName: '', testRecipient: '',
    hasPassword: false, updatedAt: null, usingFallback: true,
  };
  password = '';
  showPassword = false;

  loading = true;
  saving = false;
  testing = false;
  error = '';
  testTo = '';
  testResult: TestResult | null = null;
  toast = '';
  private timer?: ReturnType<typeof setTimeout>;

  /** One choice in the UI; two mutually exclusive booleans on the wire. */
  get encryption(): 'ssl' | 'starttls' { return this.form.useSsl ? 'ssl' : 'starttls'; }

  setEncryption(value: 'ssl' | 'starttls'): void {
    this.form.useSsl = value === 'ssl';
    this.form.useStartTls = value === 'starttls';
    // Moving the port with it, because the pairing is near-universal and a mismatched port is
    // the most common reason mail silently stops working.
    if (value === 'ssl' && this.form.smtpPort === 587) this.form.smtpPort = 465;
    if (value === 'starttls' && this.form.smtpPort === 465) this.form.smtpPort = 587;
  }

  ngOnInit(): void { this.reload(); }

  reload(): void {
    this.loading = true;
    this.http.get<EmailSettings>(this.base).subscribe({
      next: s => { this.form = s; this.loading = false; this.error = ''; },
      error: e => { this.error = apiError(e); this.loading = false; },
    });
  }

  save(): void {
    this.saving = true;
    this.error = '';
    this.http.put<void>(this.base, {
      ...this.form,
      // Empty means "keep what is stored"; the API treats null that way.
      password: this.password ? this.password : null,
    }).subscribe({
      next: () => {
        this.saving = false;
        this.password = '';
        this.showToast('Email settings saved');
        this.reload();
      },
      error: e => { this.saving = false; this.error = apiError(e); },
    });
  }

  sendTest(): void {
    this.testing = true;
    this.testResult = null;
    const q = this.testTo.trim() ? `?to=${encodeURIComponent(this.testTo.trim())}` : '';
    this.http.post<TestResult>(`${this.base}/test${q}`, {}).subscribe({
      next: r => { this.testing = false; this.testResult = r; },
      error: e => {
        this.testing = false;
        this.testResult = { sent: false, to: this.testTo || '—', via: '—', error: apiError(e) };
      },
    });
  }

  private showToast(m: string): void {
    this.toast = m;
    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.toast = '', 3500);
  }
}
