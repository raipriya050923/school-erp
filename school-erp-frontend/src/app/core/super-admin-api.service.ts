import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

/* ============ Response / request models (mirror the .NET DTOs) ============ */

export interface DashboardStats {
  totalSchools: number;
  activeSubscriptions: number;
  trialSubscriptions: number;
  monthlyRecurringRevenue: number;
  openTickets: number;
}

export interface SchoolListItem {
  id: number;
  schoolCode: string;
  name: string;
  city: string | null;
  status: string;
  planName: string | null;
  studentCount: number;
  createdAt: string;
}

export interface SchoolDetail {
  id: number;
  schoolCode: string;
  name: string;
  subdomain: string;
  email: string;
  phone: string;
  /** Street address, as typed on the onboarding form. */
  address: string | null;
  city: string | null;
  state: string | null;
  country: string | null;
  postalCode: string | null;
  affiliationBoard: string | null;
  /** Shell palette every portal of this school renders in: classic | brand | forest | mist. */
  theme: string;
  currency: string;
  timezone: string;
  status: string;
  onboardedAt: string | null;
  createdAt: string;
  /** Current subscription; null across the board for schools onboarded before plans were required. */
  planId: number | null;
  planName: string | null;
  billingCycle: string | null;
  subscriptionStatus: string | null;
  subscriptionEndsOn: string | null;
  adminUsername: string | null;
  adminEmail: string | null;
  countryId: number | null;
  stateId: number | null;
  cityId: number | null;
  /** Non-null only when a demo password is configured server-side; real ones are unreadable. */
  adminPassword: string | null;
}

export interface CreateSchool {
  name: string; email: string; phone: string;
  /** Street address; the geography master supplies everything coarser than this. */
  address?: string | null;
  city?: string | null; state?: string | null; country?: string | null;
  postalCode?: string | null; affiliationBoard?: string | null; status: string;
  /** Shell palette: classic | brand | forest | mist. Unknown names fall back to classic. */
  theme?: string;
  /** Required on create: a school with no subscription never appears under Subscriptions. */
  planId: number; billingCycle: string;
  /** Geography master ids; null when the typed name matched nothing. */
  countryId?: number | null; stateId?: number | null; cityId?: number | null;
}
/** Same shape on update; planId 0 leaves the existing subscription untouched. */
export type UpdateSchool = CreateSchool;

/**
 * Returned once when a school is onboarded. `temporaryPassword` is plaintext and is never
 * retrievable again — only its bcrypt hash is stored — so it must be shown to the super admin
 * straight away and never written to logs or local storage.
 */
/** Credentials handed back by a password reset — the plaintext exists only in this response. */
export interface AdminCredentials {
  userId: number;
  fullName: string;
  username: string;
  email: string | null;
  temporaryPassword: string;
}

export interface CreateSchoolResult {
  schoolId: number;
  schoolName: string;
  schoolCode: string;
  subdomain: string;
  adminFullName: string;
  username: string;
  email: string;
  temporaryPassword: string;
  planName: string;
  subscriptionStatus: string;
  subscriptionEndsOn: string;
}

export interface Plan {
  id: number;
  name: string;
  slug: string;
  description: string | null;
  priceMonthly: number;
  priceYearly: number;
  maxStudents: number | null;
  maxStaff: number | null;
  trialDays: number;
  isActive: boolean;
  subscriberCount: number;
}
export interface CreatePlan {
  name: string; description?: string | null;
  priceMonthly: number; priceYearly: number;
  maxStudents?: number | null; maxStaff?: number | null; trialDays: number;
}
export type UpdatePlan = Omit<CreatePlan, 'name'>;

export interface Subscription {
  id: number;
  schoolId: number;
  planId: number;
  billingCycle: string;
  startDate: string;
  endDate: string;
  price: number;
  status: string;
  autoRenew: boolean;
  schoolName: string | null;
  planName: string | null;
}

export interface Invoice {
  id: number;
  invoiceNo: string;
  schoolId: number;
  schoolName: string;
  totalAmount: number;
  issuedAt: string | null;
  dueDate: string;
  status: string;
  paidAt: string | null;
  remindedAt: string | null;
}
export interface BillingSummary {
  collected: number; outstanding: number; overdue: number;
  paidCount: number; sentCount: number; overdueCount: number;
}
export interface RecordPayment {
  amount: number; method: string;
  /** Required by the API when method is bank_transfer. */
  bankName?: string | null;
  transactionRef?: string | null;
  /** Path returned by uploadPaymentProof(). */
  proofUrl?: string | null;
  paidAt: string; remarks?: string | null;
}

/** Payment methods offered when recording a payment, in display order. */
export const PAYMENT_METHODS = [
  { value: 'bank_transfer', label: 'Bank transfer' },
  { value: 'upi', label: 'UPI' },
  { value: 'debit_card', label: 'Debit card' },
  { value: 'credit_card', label: 'Credit card' },
  { value: 'cash', label: 'Cash' },
];

export interface TicketListItem {
  id: number;
  ticketNo: string;
  schoolId: number;
  schoolName: string;
  raisedByName: string;
  subject: string;
  priority: string;
  status: string;
  commentCount: number;
  createdAt: string;
}
export interface TicketComment {
  id: number;
  userId: number;
  authorName: string;
  side: 'platform' | 'school';
  message: string;
  createdAt: string;
}
export interface TicketDetail {
  id: number;
  ticketNo: string;
  schoolName: string;
  raisedByName: string;
  subject: string;
  description: string;
  priority: string;
  status: string;
  createdAt: string;
  comments: TicketComment[];
}

/* ============ Service ============ */

@Injectable({ providedIn: 'root' })
export class SuperAdminApiService {
  private readonly http = inject(HttpClient);
  private readonly base = environment.superAdminApi;

  // Dashboard
  getDashboardStats(): Observable<DashboardStats> {
    return this.http.get<DashboardStats>(`${this.base}/dashboard/stats`);
  }

  // Schools
  getSchools(search?: string, status?: string): Observable<SchoolListItem[]> {
    let params = new HttpParams();
    if (search) params = params.set('search', search);
    if (status) params = params.set('status', status);
    return this.http.get<SchoolListItem[]>(`${this.base}/schools`, { params });
  }
  getSchool(id: number): Observable<SchoolDetail> {
    return this.http.get<SchoolDetail>(`${this.base}/schools/${id}`);
  }
  createSchool(dto: CreateSchool): Observable<CreateSchoolResult> {
    return this.http.post<CreateSchoolResult>(`${this.base}/schools`, dto);
  }
  updateSchool(id: number, dto: UpdateSchool): Observable<void> {
    return this.http.put<void>(`${this.base}/schools/${id}`, dto);
  }
  /** Issues a new admin password and returns it once — the old one is unrecoverable. */
  resetSchoolAdminPassword(id: number): Observable<AdminCredentials> {
    return this.http.post<AdminCredentials>(`${this.base}/schools/${id}/admin/reset-password`, {});
  }
  setSchoolStatus(id: number, status: string): Observable<void> {
    return this.http.patch<void>(`${this.base}/schools/${id}/status`, { status });
  }

  // Plans
  getPlans(): Observable<Plan[]> {
    return this.http.get<Plan[]>(`${this.base}/plans`);
  }
  createPlan(dto: CreatePlan): Observable<{ id: number }> {
    return this.http.post<{ id: number }>(`${this.base}/plans`, dto);
  }
  updatePlan(id: number, dto: UpdatePlan): Observable<void> {
    return this.http.put<void>(`${this.base}/plans/${id}`, dto);
  }
  setPlanActive(id: number, value: boolean): Observable<void> {
    return this.http.patch<void>(`${this.base}/plans/${id}/active?value=${value}`, {});
  }

  // Subscriptions
  getSubscriptions(status?: string, planId?: number): Observable<Subscription[]> {
    let params = new HttpParams();
    if (status) params = params.set('status', status);
    if (planId) params = params.set('planId', planId);
    return this.http.get<Subscription[]>(`${this.base}/subscriptions`, { params });
  }

  // Billing
  getInvoices(status?: string): Observable<Invoice[]> {
    let params = new HttpParams();
    if (status) params = params.set('status', status);
    return this.http.get<Invoice[]>(`${this.base}/billing/invoices`, { params });
  }
  getBillingSummary(): Observable<BillingSummary> {
    return this.http.get<BillingSummary>(`${this.base}/billing/summary`);
  }
  /** Raises an invoice against a school's current subscription. */
  raiseInvoice(dto: { schoolId: number; amount?: number | null; dueDate?: string | null }): Observable<Invoice> {
    return this.http.post<Invoice>(`${this.base}/billing/invoices`, dto);
  }
  /** Uploads a payment screenshot and returns the stored path to attach to the payment. */
  uploadPaymentProof(file: File): Observable<{ url: string; fileName: string }> {
    const body = new FormData();
    body.append('file', file);
    return this.http.post<{ url: string; fileName: string }>(`${this.base}/billing/payment-proof`, body);
  }
  recordPayment(invoiceId: number, dto: RecordPayment): Observable<void> {
    return this.http.post<void>(`${this.base}/billing/invoices/${invoiceId}/payments`, dto);
  }
  sendReminder(invoiceId: number): Observable<void> {
    return this.http.post<void>(`${this.base}/billing/invoices/${invoiceId}/reminder`, {});
  }

  // Tickets
  getTickets(status?: string): Observable<TicketListItem[]> {
    let params = new HttpParams();
    if (status) params = params.set('status', status);
    return this.http.get<TicketListItem[]>(`${this.base}/tickets`, { params });
  }
  getTicket(id: number): Observable<TicketDetail> {
    return this.http.get<TicketDetail>(`${this.base}/tickets/${id}`);
  }
  setTicketStatus(id: number, status: string): Observable<void> {
    return this.http.patch<void>(`${this.base}/tickets/${id}/status`, { status });
  }
  resolveTicket(id: number, resolutionNote: string, notifySchool: boolean): Observable<void> {
    return this.http.post<void>(`${this.base}/tickets/${id}/resolve`, { resolutionNote, notifySchool });
  }
  addComment(id: number, userId: number, message: string): Observable<TicketComment> {
    return this.http.post<TicketComment>(`${this.base}/tickets/${id}/comments`, { userId, message });
  }
}

/* ============ Display helpers (DB enum -> UI) ============ */

/** "past_due" -> "Past due", "in_progress" -> "In progress". */
export function statusLabel(status: string): string {
  if (!status) return '';
  const s = status.replace(/_/g, ' ');
  return s.charAt(0).toUpperCase() + s.slice(1);
}

/** Map a (possibly snake_case) status to a badge CSS class. */
export function statusBadge(status: string): string {
  const s = status.replace(/_/g, ' ').toLowerCase();
  if (['active', 'paid', 'resolved', 'completed', 'closed'].includes(s)) return 'success';
  if (['trial', 'partial', 'sent', 'in progress', 'waiting', 'pending', 'scheduled'].includes(s)) return 'warning';
  if (['overdue', 'suspended', 'past due', 'terminated', 'cancelled', 'expired', 'unpaid', 'void'].includes(s)) return 'danger';
  if (['open'].includes(s)) return 'info';
  return 'neutral';
}

export function priorityBadge(p: string): string {
  switch (p.toLowerCase()) {
    case 'urgent': return 'danger';
    case 'high': return 'serious';
    case 'medium': return 'warning';
    default: return 'neutral';
  }
}
