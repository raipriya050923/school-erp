import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, throwError } from 'rxjs';
import { AuthService } from './auth.service';
import { environment } from '../../environments/environment';

/**
 * Attaches the session's bearer token to API calls, and drops the session on a 401 so a
 * user whose token expired lands back on the login page instead of an endless wall of errors.
 * A 403 saying the password must be changed is routed the same way, to the change screen.
 *
 * Only same-API requests get the header — the token must never leak to a third-party host.
 */
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthService);
  const router = inject(Router);

  const token = auth.token;
  const isApiCall = req.url.startsWith(environment.apiBaseUrl);
  const authorized = token && isApiCall
    ? req.clone({ setHeaders: { Authorization: `Bearer ${token}` } })
    : req;

  return next(authorized).pipe(
    catchError((err: HttpErrorResponse) => {
      if (err.status === 401 && isApiCall) {
        auth.logout();
        router.navigate(['/login'], { queryParams: { expired: 1 } });
      }
      // A stale tab opened before the password was issued still holds a flagged token. The API
      // says so on every call; send them to set it rather than showing the refusal repeatedly.
      if (err.status === 403 && isApiCall && err.error?.error === 'password_change_required') {
        router.navigate(['/set-password']);
      }
      return throwError(() => err);
    }),
  );
};
