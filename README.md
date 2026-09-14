# Hilton Heliopolis Meters Readings

Offline-first mobile app (Android + iOS, Arabic / RTL) for logging electricity, water and gas meter readings in the hotel, backed by a Cloudflare Worker API.

Two roles:

- **Technician** — signs in, picks a meter, takes a photo, enters the value. The reading is saved on the phone instantly and synced to the server whenever there is connectivity.
- **Engineer** — everything a technician can do, plus meter management, user accounts, the full readings list with filters and Excel export, and deleting readings.

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
- **Auth.** Passwords are PBKDF2-SHA256 hashes; sessions are HS256 JWTs (12 h) stored in secure storage. The app stays usable offline with a stored session; a rejected token shows a re-login banner without losing local data.
- **Photos** are downscaled on the device (1600 px, quality 70) and capped at 3 MB on both sides. Reading photos are stored under `readings/`, engineer-uploaded meter reference photos under `meters/`.
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
| GET | `/meters` | any | active meters; engineers may add `?includeInactive=1` |
| POST | `/meters` | engineer | `{name, type, location, floorNumber, description?, photoKey?}`; name unique per floor → 409 |
| PUT | `/meters/:id` | engineer | partial update; `photoKey: null` clears the photo |
| DELETE | `/meters/:id` | engineer | soft delete (hidden from technicians, readings kept) |
| POST | `/photos` | any | raw image body (`image/jpeg`, `png`, `webp`), ≤ 3 MB → `{photoKey}`; `?kind=meter` is engineer-only |
| GET | `/photos?key=` | any | streams the image |
| POST | `/readings` | any | `{id, meterId, value, photoKey, loggedAt, notes?}`; idempotent by `id` |
| GET | `/readings` | engineer | filters `type, floor, technician, dateFrom, dateTo, search`; pagination `limit` (≤ 200) + `cursor` → `{readings, nextCursor}` |
| DELETE | `/readings/:id` | engineer | removes the row and its photo |
| GET | `/users` | engineer | all accounts |
| POST | `/users` | engineer | `{username, password, fullName, role}` |
| PUT | `/users/:id` | engineer | `{fullName?, role?, isActive?, password?}`; cannot deactivate/demote yourself |

## Database

`worker/migrations/` is the source of truth; applied in order with `wrangler d1 migrations apply`.

- **users** — id, username (unique), password_hash, full_name, role (`engineer`/`technician`), is_active
- **meters** — id, name, type, location, floor_number, description, photo_key, is_active, created_by; unique `(floor_number, name)` among active meters
- **readings** — id (device-generated uuid), meter_id, value, photo_key, notes, logged_by → users, logged_at (device time), synced_at (server time)

The phone mirrors `meters` (as a cache) and `readings` (as the queue) in drift, adding device-only columns: `local_photo_path`, `sync_status`, `retry_count`, `last_error`.

## App structure (`app/lib`)

```
core/        config (API base URL), Arabic strings (S.*), theme
data/        drift database + generated code, API client, models, photo store, Excel export
state/       SessionController, ConnectivityController, MetersController, SyncController
ui/          login, HomeShell (role-based tabs), screens/, shared widgets/
```

Tabs — technician: new reading, my readings. Engineer: new reading, meters, readings, users, dashboard (placeholder).

## Local development

Prerequisites on this machine: Flutter (stable), Android SDK with platform 36, JDK 21 (JDK 26 does not work with the Android toolchain), Xcode with the iOS platform installed, Node 22. Details and commands are in [`CHEATSHEET.md`](CHEATSHEET.md).

```
# API
cd worker && npm install && npm run db:migrate:local && npm run dev

# App (points at the live API by default; override with --dart-define=API_BASE_URL=http://localhost:8787)
cd app && flutter pub get && flutter run
```

## Roadmap

- Dashboard (placeholder tab exists for engineers)
- Session length: currently 12 h; longer would reduce re-logins for offline-heavy technicians
