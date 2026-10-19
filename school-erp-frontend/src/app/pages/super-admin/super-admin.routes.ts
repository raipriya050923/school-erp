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
import { ProfilePageComponent } from '../../shared/profile.page';
import { SaTemplatesComponent } from './templates.page';
import { SaEmailSettingsComponent } from './email-settings.page';
import { SaGeographyComponent } from './geography.page';

export const SUPER_ADMIN_ROUTES: Routes = [
  {
    path: '',
    component: PortalLayoutComponent,
    canActivate: [roleGuard('super_admin')],
    data: {
      portal: 'Super Admin',
      // `group` collapses consecutive items into one menu in the masthead client.
      // The rail client ignores it and lists every module, so both read the same array.
      nav: [
        { label: 'Dashboard', path: 'dashboard', icon: 'grid' },
        { label: 'Schools', path: 'schools', icon: 'school' },
        { label: 'Subscription Plans', path: 'plans', icon: 'tag', group: 'Subscriptions' },
        { label: 'School Subscriptions', path: 'subscriptions', icon: 'package', group: 'Subscriptions' },
        { label: 'Billing & Payments', path: 'billing', icon: 'card', group: 'Subscriptions' },
        { label: 'Support Tickets', path: 'tickets', icon: 'ticket' },
        { label: 'Geography', path: 'geography', icon: 'layers' },
        { label: 'Message Templates', path: 'templates', icon: 'template', group: 'Messaging' },
        { label: 'Email Settings', path: 'email-settings', icon: 'card', group: 'Messaging' },
      ],
    },
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'dashboard' },
      { path: 'profile', component: ProfilePageComponent },
      { path: 'templates', component: SaTemplatesComponent },
      { path: 'email-settings', component: SaEmailSettingsComponent },
      { path: 'dashboard', component: SaDashboardComponent },
      { path: 'schools', component: SaSchoolsComponent },
      { path: 'plans', component: SaPlansComponent },
      { path: 'geography', component: SaGeographyComponent },
      { path: 'subscriptions', component: SaSubscriptionsComponent },
      { path: 'billing', component: SaBillingComponent },
      { path: 'tickets', component: SaTicketsComponent },
    ],
  },
];
