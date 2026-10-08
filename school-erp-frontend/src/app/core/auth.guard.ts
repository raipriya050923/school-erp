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
    // A user still on the password their school issued has nowhere to go but the change screen.
    // The API refuses every other endpoint anyway; this stops them landing on a portal that
    // would only fill with 403s.
    if (auth.user()?.mustChangePassword) return router.createUrlTree(['/set-password']);
    return auth.user()?.role === role ? true : router.createUrlTree(['/login']);
  };
}

/** Lets a signed-in user reach the change screen, and only while they actually need it. */
export const setPasswordGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  const user = auth.user();
  if (!auth.token || !user) return router.createUrlTree(['/login']);
  return user.mustChangePassword ? true : router.createUrlTree([user.portalPath]);
};
