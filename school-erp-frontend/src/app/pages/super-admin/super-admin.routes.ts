import { Routes } from '@angular/router';
import { PortalLayoutComponent } from '../../shared/portal-layout.component';
import { roleGuard } from '../../core/auth.guard';
import {
  SaDashboardComponent,
  SaSchoolsComponent,
  SaPlansComponent,
  SaSubscriptionsComponent,
  SaBillingComponent,
  SaTicketsComponent,
} from './super-admin.pages';

export const SUPER_ADMIN_ROUTES: Routes = [
  {
    path: '',
    component: PortalLayoutComponent,
    canActivate: [roleGuard('super_admin')],
    data: {
      portal: 'Super Admin',
      nav: [
        { label: 'Dashboard', path: 'dashboard', icon: 'grid' },
        { label: 'Schools', path: 'schools', icon: 'school' },
        { label: 'Subscription Plans', path: 'plans', icon: 'tag' },
        { label: 'School Subscriptions', path: 'subscriptions', icon: 'package' },
        { label: 'Billing & Payments', path: 'billing', icon: 'card' },
        { label: 'Support Tickets', path: 'tickets', icon: 'ticket' },
      ],
    },
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'dashboard' },
      { path: 'dashboard', component: SaDashboardComponent },
      { path: 'schools', component: SaSchoolsComponent },
      { path: 'plans', component: SaPlansComponent },
      { path: 'subscriptions', component: SaSubscriptionsComponent },
      { path: 'billing', component: SaBillingComponent },
      { path: 'tickets', component: SaTicketsComponent },
    ],
  },
];
