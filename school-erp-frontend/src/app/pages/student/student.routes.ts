import { Routes } from '@angular/router';
import { PortalLayoutComponent } from '../../shared/portal-layout.component';
import { roleGuard } from '../../core/auth.guard';
// API-backed pages (live data from the .NET student API)
import {
  StDashboardComponent,
  StAttendanceComponent,
  StTimetableComponent,
  StHomeworkComponent,
  StExamsComponent,
  StFeesComponent,
  StNoticesComponent,
} from './student-api.pages';
import { ProfilePageComponent } from '../../shared/profile.page';

/**
 * The screens both portals show. A parent reads exactly what their child does —
 * the API scopes every student endpoint by the student_id on the token, so the
 * parent build differs only in the guard and the label above the nav.
 */
function portalRoutes(role: 'student' | 'parent', portal: string): Routes {
  return [
  {
    path: '',
    component: PortalLayoutComponent,
    canActivate: [roleGuard(role)],
    data: {
      portal,
      nav: [
        { label: 'Dashboard', path: 'dashboard', icon: 'grid' },
        { label: 'Attendance', path: 'attendance', icon: 'clipboard' },
        { label: 'Timetable', path: 'timetable', icon: 'calendar' },
        // Homework is hidden from the nav; the route below still resolves if linked to.
        { label: 'Exams & Results', path: 'exams', icon: 'exam' },
        { label: 'Fees', path: 'fees', icon: 'money' },
        { label: 'Notices', path: 'notices', icon: 'bell' },
      ],
    },
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'dashboard' },
      { path: 'profile', component: ProfilePageComponent },
      { path: 'dashboard', component: StDashboardComponent },
      { path: 'attendance', component: StAttendanceComponent },
      { path: 'timetable', component: StTimetableComponent },
      { path: 'homework', component: StHomeworkComponent },
      { path: 'exams', component: StExamsComponent },
      { path: 'fees', component: StFeesComponent },
      { path: 'notices', component: StNoticesComponent },
    ],
  },
  ];
}

export const STUDENT_ROUTES: Routes = portalRoutes('student', 'Student');
export const PARENT_ROUTES: Routes = portalRoutes('parent', 'Parent');
