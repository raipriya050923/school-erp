/**
 * Runtime configuration.
 *
 * The API base is chosen from the browser's hostname:
 *   - localhost / 127.0.0.1  -> dev API on http://localhost:5204/api
 *   - anything else          -> https://school.nexafusion.cloud/api
 *
 * One deployed API serves every client. The clients differ in layout and
 * branding, not in data, so kss, nexa and the default build all call the same
 * host; which school a request sees comes from the signed token, not the URL.
 *
 * `shell` and `brand` are what make one codebase serve two clients. They are
 * build-time constants, swapped by the fileReplacements in angular.json, so a
 * build ships one layout's markup and one client's tokens rather than both.
 */
const hostname = window.location.hostname;
const production = hostname !== 'localhost' && hostname !== '127.0.0.1';

const apiBaseUrl = production ? 'https://school.nexafusion.cloud/api' : 'http://localhost:5204/api';

export const environment = {
  production,
  /** 'masthead' puts the module nav across the top; 'rail' puts it in a left panel. */
  shell: 'rail' as 'masthead' | 'rail',
  /** Stamped on <html> as data-brand, so stylesheets can differ without code doing so. */
  brand: 'nexa' as 'kss' | 'nexa',
  productName: 'Nexa Fusion',
  apiBaseUrl,
  authApi: `${apiBaseUrl}/auth`,
  superAdminApi: `${apiBaseUrl}/super-admin`,
  adminApi: `${apiBaseUrl}/admin`,
  teacherApi: `${apiBaseUrl}/teacher`,
  studentApi: `${apiBaseUrl}/student`,
  /** Shared country/state/city master - readable by every signed-in role. */
  geographyApi: `${apiBaseUrl}/geography`,
};
