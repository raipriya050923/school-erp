/**
 * Runtime configuration.
 *
 * The API base is derived from the browser's hostname:
 *   - localhost / 127.0.0.1  → dev API on http://localhost:5162/api
 *   - anything else          → same origin as the app, at `/api`
 *     (i.e. the API is served/proxied under the same domain in production)
 *
 * All per-portal endpoints are derived from that single base, so there is
 * only one place to change.
 */
const hostname = window.location.hostname;
const production = hostname !== 'localhost' && hostname !== '127.0.0.1';

const apiBaseUrl = production
  ? `${window.location.origin}/api`
  : 'http://localhost:5204/api';

export const environment = {
  production,
  apiBaseUrl,
  authApi: `${apiBaseUrl}/auth`,
  superAdminApi: `${apiBaseUrl}/super-admin`,
  adminApi: `${apiBaseUrl}/admin`,
  teacherApi: `${apiBaseUrl}/teacher`,
  studentApi: `${apiBaseUrl}/student`,
  /** Shared country/state/city master — readable by every signed-in role. */
  geographyApi: `${apiBaseUrl}/geography`,
};
