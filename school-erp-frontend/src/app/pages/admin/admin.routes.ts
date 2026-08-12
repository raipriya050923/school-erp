import { Routes } from '@angular/router';
import { PortalLayoutComponent } from '../../shared/portal-layout.component';
import { roleGuard } from '../../core/auth.guard';
// API-backed pages (live data from the .NET admin API)
import {
  AdDashboardComponent,
  AdStudentsComponent,
  AdTeachersComponent,
  AdClassesComponent,
  AdNoticesComponent,
} from './admin-api.pages';
// API-backed transactional pages (live data from the .NET admin API)
import {
  AdAttendanceComponent,
  AdAttendanceReportComponent,
  AdFeesComponent,
  AdExamsComponent,
} from './admin-txn.pages';

export const ADMIN_ROUTES: Routes = [
  {
    path: '',
    component: PortalLayoutComponent,
    canActivate: [roleGuard('school_admin')],
    data: {
      portal: 'School Admin',
      nav: [
        { label: 'Dashboard', path: 'dashboard', icon: 'grid' },
        { label: 'Students', path: 'students', icon: 'users' },
        { label: 'Teachers', path: 'teachers', icon: 'teacher' },
        { label: 'Classes & Sections', path: 'classes', icon: 'layers' },
        { label: 'Attendance', path: 'attendance', icon: 'clipboard' },
        { label: 'Attendance Report', path: 'attendance-report', icon: 'chart' },
        { label: 'Fee Management', path: 'fees', icon: 'money' },
        { label: 'Examinations', path: 'exams', icon: 'exam' },
        { label: 'Notice Board', path: 'notices', icon: 'bell' },
      ],
    },
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'dashboard' },
      { path: 'dashboard', component: AdDashboardComponent },
      { path: 'students', component: AdStudentsComponent },
      { path: 'teachers', component: AdTeachersComponent },
      { path: 'classes', component: AdClassesComponent },
      { path: 'attendance', component: AdAttendanceComponent },
      { path: 'attendance-report', component: AdAttendanceReportComponent },
      { path: 'fees', component: AdFeesComponent },
      { path: 'exams', component: AdExamsComponent },
      { path: 'notices', component: AdNoticesComponent },
    ],
  },
];
