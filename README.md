# Hilton Heliopolis Meters Readings

Offline-first mobile app (Android + iOS, Arabic / RTL) for logging electricity, water and gas meter readings in the hotel, backed by a Cloudflare Worker API.

Three roles:

- **Technician** — signs in, works through the daily meter list, takes a photo, enters the value. The reading is saved on the phone instantly and synced whenever there is connectivity. Sees, edits and deletes only their own readings.
- **Engineer** — everything a technician can do, plus the full readings list (all users) with filters, sort, edit, delete and Excel export, and the dashboard.
- **Moderator** — everything an engineer can do, plus meter management and user accounts.

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
- **Once a reading reaches the server it leaves the phone.** The local database is purely the upload queue; the readings tab reads from the server, with still-queued readings pinned on top.
- **Names are never denormalised.** Readings reference `users.id`; names are joined at read time, so renaming an account updates history.

## Live environment

| What | Where |
|---|---|
| API | `https://hilton-heliopolis-meters-api.y-ashraf74.workers.dev` |
| Android APK (always latest) | GitHub Releases → tag `latest` |
| Cloudflare | Worker `hilton-heliopolis-meters-api`, D1 `hilton-heliopolis-meters-db`, R2 `hilton-heliopolis-meter-photos` |

Every push to `main`:

- changes under `worker/` are deployed by Cloudflare's Git integration (root directory `worker`);
- changes under `app/` trigger the GitHub Actions workflow, which runs analyze + tests, builds a release APK, and replaces the asset on the `latest` release.

## API

All routes are under `/api`. Every route except `/health` and `/auth/login` needs `Authorization: Bearer <token>`.

| Method | Route | Role | Notes |
|---|---|---|---|
| POST | `/auth/login` | — | `{username, password}` → `{token, user}` |
| GET | `/meters` | any | active meters with `last_logged_at`; moderators may add `?includeInactive=1` |
| POST | `/meters` | moderator | `{name, area, type, location, floorNumber, number?, description?, photoKey?}`; duplicate (name, floor, number, area) → 409 |
| PUT | `/meters/:id` | moderator | partial update; `photoKey: null` clears the photo, `number: ""` clears the number |
| DELETE | `/meters/:id` | moderator | soft delete (hidden from technicians, readings kept) |
| POST | `/photos` | any | raw image body (`image/jpeg`, `png`, `webp`), ≤ 3 MB → `{photoKey}`; `?kind=meter` is moderator-only |
| GET | `/photos?key=` | any | streams the image |
| POST | `/readings` | any | `{id, meterId, value, photoKey, loggedAt}`; idempotent by `id` |
| GET | `/readings` | any | technicians get only their own; filters `type, floor, technician, dateFrom, dateTo, search`; `sort` (`logged_at`, `value`, `meter_name`, `floor`, `technician`) + `dir`; pagination `limit` (≤ 200) + `cursor` → `{readings, nextCursor}` |
| PUT | `/readings/:id` | owner or engineer/moderator | `{value}` |
| DELETE | `/readings/:id` | owner or engineer/moderator | removes the row and its photo |
| GET | `/users` | moderator | active accounts |
| POST | `/users` | moderator | `{username, password, fullName, role}`; re-creating a deleted username revives the same account |
| PUT | `/users/:id` | moderator | `{fullName?, role?, isActive?, password?}`; `isActive: false` is the delete; cannot delete/demote yourself |

## Database

`worker/migrations/` is the source of truth; applied in order with `wrangler d1 migrations apply`.

- **users** — id, username (unique), password_hash, full_name, role (`moderator`/`engineer`/`technician`), is_active
- **meters** — id, name, area, number, type, location, floor_number, description, photo_key, is_active, created_by; unique `(name, floor_number, number, area)` among active meters
- **readings** — id (device-generated uuid), meter_id, value, photo_key (null once purged), logged_by → users, logged_at (device time), synced_at (server time)

The phone caches `meters` (plus `last_logged_at`) and keeps `readings` only as the upload queue, with device-only columns: `local_photo_path`, `sync_status`, `retry_count`, `last_error`.

## App structure (`app/lib`)

```
core/        config (API base URL), Arabic strings (S.*), theme
data/        drift database + generated code, API client, models, photo store, Excel export
state/       SessionController, ConnectivityController, MetersController, SyncController
ui/          login, HomeShell (role-based tabs), screens/, shared widgets/
```

Tabs — technician: new reading, readings. Engineer: new reading, readings, dashboard (placeholder). Moderator: new reading, meters, readings, users, dashboard.

## Local development

Prerequisites on this machine: Flutter (stable), Android SDK with platform 36, JDK 21 (JDK 26 does not work with the Android toolchain), Xcode with the iOS platform installed, Node 22. Details and commands are in [`CHEATSHEET.md`](CHEATSHEET.md).

```
# API
cd worker && npm install && npm run db:migrate:local && npm run dev

# App (points at the live API by default; override with --dart-define=API_BASE_URL=http://localhost:8787)
cd app && flutter pub get && flutter run
```

## Roadmap

- Dashboard (placeholder tab exists for engineers and moderators)
- Session length: currently 12 h; longer would reduce re-logins for offline-heavy technicians
