/**
 * Runtime configuration.
 *
 * The API base is chosen from the browser's hostname:
 *   - localhost / 127.0.0.1  → dev API on http://localhost:5204/api
 *   - anything else          → https://school.nexafusion.cloud/api
 *
 * The deployed base is a fixed host rather than the page's own origin, because
 * the app is served from more than one domain — school.kssinfonet.com as well
 * as school.nexafusion.cloud — while the API runs in one place. Deriving it
 * from `window.location.origin` would have each site call an API at its own
 * domain, and only one of those exists.
 *
 * That makes the call cross-origin from any site other than the API's own, so
 * every front-end domain has to be listed in the API's `Cors:AllowedOrigins`.
 * Add a domain here and it needs adding there too, or the browser blocks it.
 *
 * All per-portal endpoints are derived from that single base, so there is
 * only one place to change.
 */
const hostname = window.location.hostname;
const production = hostname !== 'localhost' && hostname !== '127.0.0.1';

/** No trailing slash: every endpoint below appends its own path segment. */
const apiBaseUrl = production
  ? 'https://school.nexafusion.cloud/api'
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
