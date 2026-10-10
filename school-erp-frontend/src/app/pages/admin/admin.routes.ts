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
import { AdSubjectsComponent } from './admin-subjects.page';
import { AdFeeStructureComponent } from './admin-fee-structure.page';
import { AdTransportComponent } from './admin-transport.page';
import { AdStaffAttendanceComponent, AdLeaveComponent } from './admin-staff.pages';
import { ProfilePageComponent } from '../../shared/profile.page';

import { AdAcademicYearsComponent } from './academic-years.page';
import { AdTimetableComponent } from './timetable.page';
import { AdPeriodsComponent } from './periods.page';
export const ADMIN_ROUTES: Routes = [
  {
    path: '',
    component: PortalLayoutComponent,
    canActivate: [roleGuard('school_admin')],
    data: {
      portal: 'School Admin',
      // Sixteen modules, as six tabs. `group` collapses consecutive items into
      // one menu in the masthead; the order here is the order they appear in.
      nav: [
        { label: 'Dashboard', path: 'dashboard', icon: 'grid' },
        { label: 'Students', path: 'students', icon: 'users', group: 'People' },
        { label: 'Teachers', path: 'teachers', icon: 'teacher', group: 'People' },
        { label: 'Classes & Sections', path: 'classes', icon: 'layers', group: 'Academics' },
        { label: 'Subjects', path: 'subjects', icon: 'book', group: 'Academics' },
        { label: 'Academic Years', path: 'academic-years', icon: 'calendar', group: 'Academics' },
        { label: 'Timetable', path: 'timetable', icon: 'presentation', group: 'Academics' },
        { label: 'Attendance', path: 'attendance', icon: 'clipboard', group: 'Attendance' },
        { label: 'Attendance Report', path: 'attendance-report', icon: 'chart', group: 'Attendance' },
        { label: 'Staff Attendance', path: 'staff-attendance', icon: 'user', group: 'Attendance' },
        { label: 'Leave Requests', path: 'leave', icon: 'calendar', group: 'Attendance' },
        { label: 'Fee Structure', path: 'fee-structure', icon: 'money', group: 'Fees' },
        { label: 'Transport Fee', path: 'transport', icon: 'package', group: 'Fees' },
        { label: 'Fee Management', path: 'fees', icon: 'money', group: 'Fees' },
        { label: 'Examinations', path: 'exams', icon: 'exam' },
        { label: 'Notice Board', path: 'notices', icon: 'bell' },
      ],
    },
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'dashboard' },
      { path: 'profile', component: ProfilePageComponent },
      { path: 'dashboard', component: AdDashboardComponent },
      { path: 'students', component: AdStudentsComponent },
      { path: 'teachers', component: AdTeachersComponent },
      { path: 'classes', component: AdClassesComponent },
      { path: 'subjects', component: AdSubjectsComponent },
      { path: 'academic-years', component: AdAcademicYearsComponent },
      { path: 'timetable', component: AdTimetableComponent },
      // The timetable's own columns. A sibling path rather than a nested outlet — the grid is a
      // screen, not a shell — so it still reads as /admin/timetable/periods and keeps Timetable
      // lit in the masthead, without earning a menu entry of its own.
      { path: 'timetable/periods', component: AdPeriodsComponent },
      { path: 'attendance', component: AdAttendanceComponent },
      { path: 'attendance-report', component: AdAttendanceReportComponent },
      { path: 'staff-attendance', component: AdStaffAttendanceComponent },
      { path: 'leave', component: AdLeaveComponent },
      { path: 'fee-structure', component: AdFeeStructureComponent },
      { path: 'transport', component: AdTransportComponent },
      { path: 'fees', component: AdFeesComponent },
      { path: 'exams', component: AdExamsComponent },
      { path: 'notices', component: AdNoticesComponent },
    ],
  },
];
