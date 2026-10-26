# Building and releasing the web portal

One codebase serves two clients. They share every page, every service and every
API call; they differ only in where the navigation sits and which brand tokens
load. The client is chosen **at build time**, so a release is one command with
the right configuration name.

| Client | Config  | Navigation              | Deployed at                 |
| ------ | ------- | ----------------------- | --------------------------- |
| KSS    | `kss`   | Masthead — across the top | `school.kssinfonet.com`   |
| Nexa   | `nexa`  | Rail — left side panel    | `school.nexafusion.cloud` |

Both call the same API: `https://school.nexafusion.cloud/api`. Which school a
request sees comes from the signed token, not from the URL.

---

## Prerequisites

- **Node 20 or newer.** Built and verified on Node 24.18.1 with npm 11.16.0.
- **Angular CLI 18** — comes from `devDependencies`, no global install needed.
- **Internet access on the build machine.** A production build inlines Google
  Fonts. Offline, the build fails at that step. Development builds are fine
  offline.

Install dependencies once, from this directory:

```powershell
cd D:\projects\school-erp\school-erp-frontend
npm ci
```

`npm ci` rather than `npm install` — it installs exactly what `package-lock.json`
pins, so a release build is reproducible.

---

## Running locally

The dev server talks to a local API on `http://localhost:5204`, so start that
first, from the repository root:

```powershell
cd D:\projects\school-erp\SchoolErp.Api
dotnet run --project src\SchoolErp.Api\SchoolErp.Api.csproj --urls http://localhost:5204
```

Then, in a second terminal, whichever client you want to look at:

```powershell
cd D:\projects\school-erp\school-erp-frontend

npx ng serve --configuration kss  --port 4300    # http://localhost:4300
npx ng serve --configuration nexa --port 4300    # http://localhost:4300
```

Both can run at once, which is the quickest way to compare the two layouts on
the same page.

Keep to those two ports: `4300` and `4311` are the ones listed in the API's
`Cors.AllowedOrigins`. A different port is refused by the browser, and the
failure shows up as requests dying in the console with nothing in the API log.

Plain `npm start` runs the default configuration. It builds and works, but it
is neither client's release build — it ships the masthead and no brand layer.
Pass `--configuration` when you mean a specific client.

---

## Building a release

```powershell
cd D:\projects\school-erp\school-erp-frontend

npx ng build --configuration production,kss  --output-path dist\kss
npx ng build --configuration production,nexa --output-path dist\nexa
```

Two configurations, comma-separated, and both are needed:

- `production` — minification, tree-shaking, hashed filenames, budget checks
- `kss` / `nexa` — swaps in that client's `environment.*.ts` and brand stylesheet

`-c kss` on its own produces an unoptimised build. Always pass `production` too.

A build takes a few seconds and ends with `Application bundle generation
complete.` Anything else — especially a budget error — is a failed build; do not
deploy the output.

---

## What to upload

The deployable files are **one level down**, in `browser/`:

```
dist\kss\
  3rdpartylicenses.txt        <- not deployed
  browser\                    <- deploy the CONTENTS of this folder
    index.html
    main-<hash>.js
    styles-<hash>.css
    favicon.ico, apple-touch-icon.png, ...
```

Upload the **contents of `dist\kss\browser\`** to the KSS web root, and
`dist\nexa\browser\` to the Nexa web root. About 1.1 MB each.

Uploading `dist\kss\` itself is the usual mistake — the site then 404s, because
`index.html` is a directory deeper than the server expects.

### Server requirements

**SPA fallback.** Any path that is not a real file must serve `index.html`.
Without it the site loads, but refreshing on `/admin/students` returns 404 —
the Angular router never gets a chance to handle the URL.

Apache (`.htaccess`):

```apache
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^ index.html [L]
```

nginx:

```nginx
location / {
  try_files $uri $uri/ /index.html;
}
```

**CORS.** Both sites call `school.nexafusion.cloud/api`, so for KSS that is a
cross-origin request. The deployed API's `Cors.AllowedOrigins` must list the
site's own origin:

```json
"AllowedOrigins": [
  "https://school.kssinfonet.com",
  "https://school.nexafusion.cloud",
  "http://localhost:4300",
  "http://localhost:4311",
  "http://localhost:4200"
]
```

Exact match, no trailing slash — an origin is scheme + host + port. Worth
checking after any deploy that replaces `appsettings.json`, because a missing
origin fails silently from the API's side.

**Caching.** Filenames are content-hashed, so `*.js` and `*.css` can be cached
hard. `index.html` must not be — it is what points at the new hashes, and a
cached copy pins visitors to the previous release.

---

## Checking a build before you ship it

The client, the brand and the API are compiled into the bundle, so you can read
them back out of `dist` and confirm you built what you meant to:

```powershell
cd dist\kss\browser
Select-String -Path *.js -Pattern 'shell:"(masthead|rail)"' | Select-Object -First 1
Select-String -Path *.js -Pattern 'https://school\.[a-z.]+/api'  | Select-Object -First 1
```

A correct KSS build reports `shell:"masthead"`; Nexa reports `shell:"rail"`.
Both report `https://school.nexafusion.cloud/api`.

Then open the deployed site and confirm:

- the navigation is in the right place — top bar for KSS, left panel for Nexa
- a grouped menu (People, Academics, Fees) opens **and** its items navigate
- a hard refresh on an inner page such as `/admin/students` still loads

---

## Where the per-client settings live

| File                                      | Holds                                   |
| ----------------------------------------- | --------------------------------------- |
| `src/environments/environment.kss.ts`     | KSS: shell, brand, API base             |
| `src/environments/environment.nexa.ts`    | Nexa: shell, brand, API base            |
| `src/environments/environment.ts`         | the default when no config is passed    |
| `src/branding/_kss.scss`, `_nexa.scss`    | per-client colour tokens                |
| `src/app/shared/shells/`                  | the two shells themselves               |
| `angular.json`                            | the `kss` / `nexa` build and serve configs |

`src/app/shared/portal-layout.component.ts` reads `environment.shell` and picks
the shell. Every route points at that one component, so pages never know which
client they are rendering in — which is what keeps the two in step.

### Adding a third client

1. Copy an `environment.*.ts` and set `shell`, `brand` and the API base.
2. Add a `src/branding/_<name>.scss`.
3. Add a `build` and a `serve` configuration in `angular.json`, mirroring `kss`.
4. Add the dev port to the API's `Cors.AllowedOrigins`.

No page, route or service changes.
