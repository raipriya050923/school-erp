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
        { label: 'Homework', path: 'homework', icon: 'book' },
        { label: 'Marks Entry', path: 'marks', icon: 'exam' },
        { label: 'My Timetable', path: 'timetable', icon: 'calendar' },
      ],
    },
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'dashboard' },
      { path: 'dashboard', component: TDashboardComponent },
      { path: 'classes', component: TMyClassesComponent },
      { path: 'attendance', component: TAttendanceComponent },
      { path: 'homework', component: THomeworkComponent },
      { path: 'marks', component: TMarksComponent },
      { path: 'timetable', component: TTimetableComponent },
    ],
  },
];
