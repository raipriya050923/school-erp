import { Routes } from '@angular/router';

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
  { path: '**', redirectTo: 'login' },
];
