# Hilton Heliopolis Meters Readings

Offline-first mobile app (Android + iOS, Arabic / RTL) for logging electricity, water and gas meter readings in the hotel, backed by a Cloudflare Worker API.

Three roles:

- **Technician** — signs in, works through the daily meter list, takes a photo, enters the value. The reading is saved on the phone instantly and synced whenever there is connectivity. Sees, edits and deletes only their own readings.
- **Engineer** — everything a technician can do, plus the full readings list (all users) with filters, sort, edit, delete and Excel export, and the dashboard.
- **Moderator** — everything an engineer can do, plus meter management, user accounts, and the app settings (runtime switches).

Every meter is expected to get one reading per calendar day; the reading screen is a to-do list that ticks meters off as readings come in (from anyone) and floats the remaining ones to the top. Extra readings on the same day are allowed.

See [`CHEATSHEET.md`](CHEATSHEET.md) for the day-to-day commands.

## Repository layout

```
app/       Flutter app (lib/ = Dart source, android/ and ios/ = platform projects)
worker/    Cloudflare Worker API (Hono + D1 + R2) and its D1 migrations
.github/   CI workflow that builds and publishes the Android APK
```

## Architecture

```
Flutter app ── REST + JWT ──▶ Cloudflare Worker ──▶ D1 (SQLite): users, meters, readings
   │                                 └────────────▶ R2: photos (readings/…, meters/…)
   └─ local SQLite (drift): meter cache + readings queue with sync bookkeeping
```

- **Local-first.** Every reading is written to the on-device database first. A sync engine drains the queue on app start, on reconnect, after each save, every two minutes, and on demand. Reading ids are generated on the device, so a retried upload is a no-op on the server, never a duplicate.
- **Auth.** Passwords are PBKDF2-SHA256 hashes; sessions are HS256 JWTs (12 h, carrying a token version so a role change can force a one-time re-login) stored in secure storage. The app stays usable offline with a stored session; a rejected token shows a re-login banner without losing local data.
- **Photos** are downscaled on the device (1600 px, quality 70) and capped at 3 MB on both sides. Reading photos are stored under `readings/`, moderator-uploaded meter reference photos under `meters/`. A weekly cron (Friday 10:00 UTC) purges reading photos older than 90 days and nulls their key; the app then shows an "expired" placeholder. Meter photos are never purged.
- **Gain.** Every reading stores its difference from the previous reading of the same meter (`gain`, NULL for a meter's first reading). The server recomputes a meter's gains after every insert, edit and delete, so out-of-order syncs and corrections never leave a stale value. Consumption on the dashboard is the sum of gains. Units: kWh for electricity, m³ for water and gas.
- **Runtime settings** live in a Workers KV namespace and are edited from the app by moderators: minimum app version (older builds get 426 and an update screen), maintenance mode (503 for non-moderators), reading delete, Excel export, photo retention days. Every switch is enforced by the API.
- **Once a reading reaches the server it leaves the phone.** The local database is purely the upload queue; the readings tab reads from the server, with still-queued readings pinned on top.
- **Names are never denormalised.** Readings reference `users.id`; names are joined at read time, so renaming an account updates history.

## Live environment

| What | Where |
|---|---|
| API | `https://hilton-heliopolis-meters-api.y-ashraf74.workers.dev` |
| Android APK (always latest) | GitHub Releases → tag `latest` |
| Cloudflare | Worker `hilton-heliopolis-meters-api`, D1 `hilton-heliopolis-meters-db`, R2 `hilton-heliopolis-meter-photos` |

Every request carries `X-App-Version` (the app's semantic version); builds below the minimum in settings are refused with 426.

Every push to `main`:

- changes under `worker/` are deployed by Cloudflare's Git integration (root directory `worker`);
- changes under `app/` trigger the GitHub Actions workflow, which runs analyze + tests, builds a release APK, and replaces the asset on the `latest` release.

## API

All routes are under `/api`. Every route except `/health` and `/auth/login` needs `Authorization: Bearer <token>`.

| Method | Route | Role | Notes |
|---|---|---|---|
| POST | `/auth/login` | — | `{username, password}` → `{token, user}` |
| GET | `/config` | — | public switches: `minAppVersion, maintenanceMode, readingDeleteEnabled, exportEnabled` |
| GET/PUT | `/settings` | moderator | all switches incl. `photoRetentionDays` |
| GET | `/meters` | any | active meters with `last_logged_at`, `todo_order`, `export_order`; moderators may add `?includeInactive=1` |
| POST | `/meters` | moderator | `{name, area, type, location, number?, description?, photoKey?, todoOrder?, exportOrder?}`; duplicate (name, number, area) → 409 |
| PUT | `/meters/:id` | moderator | partial update; `photoKey: null` clears the photo, `number: ""` clears the number, `todoOrder/exportOrder: null` clear |
| DELETE | `/meters/:id` | moderator | soft delete (hidden from technicians, readings kept) |
| POST | `/photos` | any | raw image body (`image/jpeg`, `png`, `webp`), ≤ 3 MB → `{photoKey}`; `?kind=meter` is moderator-only |
| GET | `/photos?key=` | any | streams the image |
| POST | `/readings` | any | `{id, meterId, value, photoKey, loggedAt}`; idempotent by `id` |
| GET | `/readings` | any | technicians get only their own; filters `type` (comma list), `number`, `userId`, `dateFrom`, `dateTo`, `search`; `sort` (`default` = export order then newest, `logged_at`, `value`, `meter_name`, `meter_type`, `technician`) + `dir`; pagination `limit` (≤ 200) + `cursor`; `export=1` honours the export switch |
| PUT | `/readings/:id` | owner or engineer/moderator | `{value}`; gains recomputed |
| DELETE | `/readings/:id` | owner or engineer/moderator | when enabled in settings; removes the row and its photo, gains recomputed |
| GET | `/users/names` | moderator, engineer | `{id, fullName}` list for the "by user" filter |
| GET | `/dashboard` | moderator, engineer | `from`, `to` (ISO), `tz` (minutes): counts, most/least-read meter, daily gains per type, totals |
| GET | `/users` | moderator | active accounts |
| POST | `/users` | moderator | `{username, password, fullName, role}`; re-creating a deleted username revives the same account |
| PUT | `/users/:id` | moderator | `{fullName?, role?, isActive?, password?}`; `isActive: false` is the delete; cannot delete/demote yourself |

## Database

`worker/migrations/` is the source of truth; applied in order with `wrangler d1 migrations apply`.

- **users** — id, username (unique), password_hash, full_name, role (`moderator`/`engineer`/`technician`), is_active
- **meters** — id, name, area, number, type, location, description, photo_key, todo_order, export_order, is_active, created_by; unique `(name, number, area)` among active meters
- **readings** — id (device-generated uuid), meter_id, value, gain (null for the first reading), photo_key (null once purged), logged_by → users, logged_at (device time), synced_at (server time)
- **KV `SETTINGS`** — `min_app_version`, `maintenance_mode`, `reading_delete_enabled`, `export_enabled`, `photo_retention_days`

The phone caches `meters` (plus `last_logged_at`) and keeps `readings` only as the upload queue, with device-only columns: `local_photo_path`, `sync_status`, `retry_count`, `last_error`.

## App structure (`app/lib`)

```
core/        config (API base URL), Arabic strings (S.*), theme
data/        drift database + generated code, API client, models, photo store, Excel export
state/       SessionController, ConnectivityController, MetersController, SyncController
ui/          login, HomeShell (role-based tabs), screens/, shared widgets/
```

Tabs — technician: new reading, readings. Engineer: new reading, readings, dashboard. Moderator: new reading, meters, readings, dashboard; app settings and user management sit in the account menu.

## Local development

Prerequisites on this machine: Flutter (stable), Android SDK with platform 36, JDK 21 (JDK 26 does not work with the Android toolchain), Xcode with the iOS platform installed, Node 22. Details and commands are in [`CHEATSHEET.md`](CHEATSHEET.md).

```
# API
cd worker && npm install && npm run db:migrate:local && npm run dev

# App (points at the live API by default; override with --dart-define=API_BASE_URL=http://localhost:8787)
cd app && flutter pub get && flutter run
```

## Roadmap

- Session length: currently 12 h; longer would reduce re-logins for offline-heavy technicians
