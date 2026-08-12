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

export const STUDENT_ROUTES: Routes = [
  {
    path: '',
    component: PortalLayoutComponent,
    canActivate: [roleGuard('student')],
    data: {
      portal: 'Student',
      nav: [
        { label: 'Dashboard', path: 'dashboard', icon: 'grid' },
        { label: 'Attendance', path: 'attendance', icon: 'clipboard' },
        { label: 'Timetable', path: 'timetable', icon: 'calendar' },
        { label: 'Homework', path: 'homework', icon: 'book' },
        { label: 'Exams & Results', path: 'exams', icon: 'exam' },
        { label: 'Fees', path: 'fees', icon: 'money' },
        { label: 'Notices', path: 'notices', icon: 'bell' },
      ],
    },
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'dashboard' },
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
