import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService, Role } from './auth.service';

/** Route guard factory: only lets the given role into a portal. */
export function roleGuard(role: Role): CanActivateFn {
  return () => {
    const auth = inject(AuthService);
    const router = inject(Router);
    return auth.user()?.role === role ? true : router.createUrlTree(['/login']);
  };
}
