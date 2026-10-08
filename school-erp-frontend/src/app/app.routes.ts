import { Routes } from '@angular/router';
import { setPasswordGuard } from './core/auth.guard';

export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'login' },
  {
    path: 'login',
    loadComponent: () => import('./pages/login.component').then(m => m.LoginComponent),
  },
  {
    path: 'forgot-password',
    loadComponent: () => import('./pages/forgot-password.component').then(m => m.ForgotPasswordComponent),
  },
  {
    path: 'set-password',
    canActivate: [setPasswordGuard],
    loadComponent: () => import('./pages/set-password.component').then(m => m.SetPasswordComponent),
  },
  {
    path: 'reset-password',
    loadComponent: () => import('./pages/reset-password.component').then(m => m.ResetPasswordComponent),
  },
  {
    path: 'super-admin',
    loadChildren: () => import('./pages/super-admin/super-admin.routes').then(m => m.SUPER_ADMIN_ROUTES),
  },
  {
    path: 'admin',
    loadChildren: () => import('./pages/admin/admin.routes').then(m => m.ADMIN_ROUTES),
  },
  {
    path: 'teacher',
    loadChildren: () => import('./pages/teacher/teacher.routes').then(m => m.TEACHER_ROUTES),
  },
  {
    path: 'student',
    loadChildren: () => import('./pages/student/student.routes').then(m => m.STUDENT_ROUTES),
  },
  {
    // Parents see their child's portal. Same screens, same endpoints — the API
    // scopes everything to the student_id on the parent's token — so this shares
    // the student routes rather than copying them.
    path: 'parent',
    loadChildren: () => import('./pages/student/student.routes').then(m => m.PARENT_ROUTES),
  },
  { path: '**', redirectTo: 'login' },
];
