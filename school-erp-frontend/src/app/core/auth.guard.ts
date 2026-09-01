import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService, Role } from './auth.service';

/**
 * Route guard factory: only lets the given role into a portal.
 * Reading `auth.token` also drops the session when it has expired, so a stale tab
 * bounces to the login page instead of firing requests the API will reject.
 */
export function roleGuard(role: Role): CanActivateFn {
  return () => {
    const auth = inject(AuthService);
    const router = inject(Router);
    if (!auth.token) return router.createUrlTree(['/login']);
    return auth.user()?.role === role ? true : router.createUrlTree(['/login']);
  };
}
