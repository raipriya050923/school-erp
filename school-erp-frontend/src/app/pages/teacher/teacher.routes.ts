import { Routes } from '@angular/router';
import { PortalLayoutComponent } from '../../shared/portal-layout.component';
import { roleGuard } from '../../core/auth.guard';
// API-backed pages (live data from the .NET teacher API)
import {
  TDashboardComponent,
  TMyClassesComponent,
  THomeworkComponent,
} from './teacher-api.pages';
import {
  TAttendanceComponent,
  TMarksComponent,
  TTimetableComponent,
} from './teacher-txn.pages';
import { ProfilePageComponent } from '../../shared/profile.page';
import { TcMyLeaveComponent } from './my-leave.page';
import { TcClassResultsComponent } from './class-results.page';

export const TEACHER_ROUTES: Routes = [
  {
    path: '',
    component: PortalLayoutComponent,
    canActivate: [roleGuard('teacher')],
    data: {
      portal: 'Teacher',
      nav: [
        { label: 'Dashboard', path: 'dashboard', icon: 'grid' },
        { label: 'My Classes', path: 'classes', icon: 'presentation' },
        { label: 'Attendance', path: 'attendance', icon: 'clipboard' },
        // Homework is hidden from the sidebar; the route below still resolves if linked to.
        { label: 'Marks Entry', path: 'marks', icon: 'exam' },
        { label: 'Class Results', path: 'results', icon: 'exam' },
        { label: 'My Timetable', path: 'timetable', icon: 'calendar' },
        { label: 'My Leave', path: 'leave', icon: 'clipboard' },
      ],
    },
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'dashboard' },
      { path: 'profile', component: ProfilePageComponent },
      { path: 'dashboard', component: TDashboardComponent },
      { path: 'classes', component: TMyClassesComponent },
      { path: 'attendance', component: TAttendanceComponent },
      { path: 'homework', component: THomeworkComponent },
      { path: 'marks', component: TMarksComponent },
      { path: 'results', component: TcClassResultsComponent },
      { path: 'timetable', component: TTimetableComponent },
      { path: 'leave', component: TcMyLeaveComponent },
    ],
  },
];
