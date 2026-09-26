# Hilton Heliopolis Meters Readings

Offline-first mobile app (Android + iOS, Arabic and English) for logging electricity, water and gas meter readings in the hotel, backed by a Cloudflare Worker API.

Three roles:

- **Technician** — signs in, works through the daily meter list, takes a photo, enters the value. The reading is saved on the phone instantly and synced whenever there is connectivity. Sees, edits and deletes only their own readings.
- **Engineer** — everything a technician can do, plus the full readings list (all users) with filters, sort, edit, delete and Excel export, and the dashboard.
- **Moderator** — everything an engineer can do, plus meter management, user accounts, and the app settings (runtime switches).

Every meter is expected to get one reading per calendar day; the reading screen is a to-do list that ticks meters off as readings come in (from anyone) and floats the remaining ones to the top. Extra readings on the same day are allowed.

See [`CHEATSHEET.md`](CHEATSHEET.md) for the day-to-day commands, [`docs/shipping.md`](docs/shipping.md) for how a change reaches the phones, and [`docs/backlog.md`](docs/backlog.md) for known issues.

## Repository layout

```
app/       Flutter app (lib/ = Dart source, android/ and ios/ = platform projects)
worker/    Cloudflare Worker API (Hono + D1 + R2) and its D1 migrations
.github/   CI: versioned releases (Shorebird + signed APK) and over-the-air patches
docs/      shipping rules, backlog, and the forkable-repo plan
```

## Architecture

```
Flutter app ── REST + JWT ──▶ Cloudflare Worker ──▶ D1 (SQLite): users, meters, readings
   │                                 └────────────▶ R2: photos (readings/…, meters/…, users/…)
   └─ local SQLite (drift): meter cache + readings queue with sync bookkeeping
```

- **Local-first.** Every reading is written to the on-device database first. A sync engine drains the queue on app start, on reconnect, after each save, every two minutes, and on demand. Reading ids are generated on the device, so a retried upload is a no-op on the server, never a duplicate.
- **Auth.** Passwords are PBKDF2-SHA256 hashes; sessions are HS256 JWTs carrying a token version so a role change can force a one-time re-login, stored in secure storage. Session length is a setting (default 7 days). The app stays usable offline with a stored session; a rejected token shows a re-login banner without losing local data.
- **Photos** are downscaled on the device (1600 px, quality 70) and capped at 3 MB on both sides: reading photos under `readings/`, meter reference photos under `meters/`, user photos under `users/`. A weekly cron (Friday 10:00 UTC) purges reading photos older than the retention setting and nulls their key; the app then shows an "expired" placeholder. Meter and user photos are never purged. Technicians can load their own user photo but no one else's.
- **Gain.** Every reading stores its difference from the previous reading of the same meter (`gain`, NULL for a meter's first reading). The server recomputes a meter's gains after every insert, edit and delete, so out-of-order syncs and corrections never leave a stale value. Units: kWh for electricity, m³ for water and gas.
- **Dashboard.** For a date range: readings logged, meters read, most/least read meter, reading completion, consumption per type, change against the period average, cost (when unit prices are set), top consumers by meter or area, and overdue meters. The period picker offers the last 7 days, every date since the system went live, or a custom range. A gain is spread over the days since that meter's previous reading, so a missed day doesn't read as zero followed by a spike. Columns group by day, week or month to stay within 21 of them.
- **Language.** Every string exists in Arabic and English (`app/lib/core/strings.dart`). Each user's choice is stored on their account (default: English for moderators, Arabic otherwise) and follows them to any phone; the login screen uses the device's last choice.
- **Runtime settings** live in a Workers KV namespace and are edited from the app by moderators: minimum app version (older builds get 426 and an update screen), maintenance mode (503 for non-moderators), reading delete, Excel export, photo retention days, session length, unit prices, whether users may edit their own profile, and how the Excel export is built. Every switch is enforced by the API. Two keys are KV-only and never shown in the app: `developer_title` and `developer_username` (the About page).
- **Once a reading reaches the server it leaves the phone.** The local database is purely the upload queue; the readings tab reads from the server, with still-queued readings pinned on top.
- **Names are never denormalised.** Readings reference `users.id`; names are joined at read time, so renaming an account updates history.

## Live environment

| What | Where |
|---|---|
| API | `https://hilton-heliopolis-meters-api.y-ashraf74.workers.dev` |
| Android APK | GitHub Releases → the newest `v*` release |
| Cloudflare | Worker `hilton-heliopolis-meters-api`, D1 `hilton-heliopolis-meters-db`, R2 `hilton-heliopolis-meter-photos`, KV `SETTINGS` |
| Email | Exports are sent through Mailjet from the `MAIL_FROM` sender |

Every request carries `X-App-Version` (the app's semantic version); builds below the minimum in settings are refused with 426.

- **Pushing to `main`** deploys `worker/` changes through Cloudflare's Git integration (root directory `worker`). App changes alone do not build anything.
- **Tagging `v*`** builds a signed release APK through Shorebird and publishes it as a GitHub release (a tag message containing "beta" makes it a pre-release).
- **The patch workflow** ships Dart-only changes to installed Android apps without a new APK. See [`docs/shipping.md`](docs/shipping.md).

## API

All routes are under `/api`. Every route except `/health` and `/auth/login` needs `Authorization: Bearer <token>`.

| Method | Route | Role | Notes |
|---|---|---|---|
| POST | `/auth/login` | — | `{username, password}` → `{token, user}` (user includes email, phone, photoKey, language) |
| GET | `/config` | — | public switches: `minAppVersion, maintenanceMode, readingDeleteEnabled, exportEnabled, profileEditingEnabled, export` |
| GET/PUT | `/settings` | moderator | every switch: retention, session length, prices, profile editing, export settings; GET also returns `latestAppVersion` (newest GitHub release) |
| GET | `/about` | any | About page: `developerTitle`, `developerPhotoKey` (from KV `developer_title` / `developer_username`) |
| GET | `/about/photo` | any | the developer's photo, readable by every role |
| GET | `/meters` | any | active meters with `last_logged_at`, `last_value`, `todo_order`, `export_order`; moderators may add `?includeInactive=1` |
| POST | `/meters` | moderator | `{name, area, type, number?, photoKey?, todoOrder?, exportOrder?}`; duplicate (name, number, area) → 409 |
| PUT | `/meters/:id` | moderator | partial update; `photoKey: null` clears the photo, `number: ""` clears the number, `todoOrder/exportOrder: null` clear |
| DELETE | `/meters/:id` | moderator | soft delete (hidden from technicians, readings kept) |
| POST | `/photos` | any | raw image body (`image/jpeg`, `png`, `webp`), ≤ 3 MB → `{photoKey}`; `?kind=meter` is moderator-only, `?kind=user` needs moderator or the profile-editing switch |
| GET | `/photos?key=` | any | streams the image; `users/…` keys are hidden from technicians except their own |
| POST | `/readings` | any | `{id, meterId, value, photoKey, loggedAt}`; idempotent by `id` |
| GET | `/readings/unusual` | moderator, engineer | `from`, `to` (default: every date since the system went live) → `{count, from, to, unusual[]}` for the unusual readings page |
| GET | `/readings` | any | technicians get only their own; filters `type` (comma list), `number`, `userId`, `dateFrom`, `dateTo`, `search`; `sort` (`default` = newest local day, then export order, `logged_at`, `value`, `meter_name`, `meter_type`, `technician`) + `dir` + `tz`; pagination `limit` (≤ 200) + `cursor`; `export=1` honours the export switch |
| PUT | `/readings/:id` | owner or engineer/moderator | `{value}`; gains recomputed, and the reading is unflagged |
| POST | `/readings/:id/normal` | moderator, engineer | `{normal}`; marks a flagged reading as normal so it leaves the unusual list |
| DELETE | `/readings/:id` | owner or engineer/moderator | when enabled in settings; removes the row and its photo, gains recomputed |
| POST | `/exports/email` | any | `{fileName, content}` (base64 .xlsx ≤ 10 MB) → emails it to the caller's own address through Mailjet |
| GET | `/dashboard` | moderator, engineer | `from`, `to` (ISO), `tz` (minutes): counts, most/least-read meter, per-type consumption per day, completion, consumers, unusual readings, overdue meters, prices |
| GET | `/users/names` | moderator, engineer | `{id, fullName}` list for the "by user" filter |
| GET | `/users/me` | any | the caller's own record (profile page and account menu) |
| PUT | `/users/me/profile` | any | `{email?, phone?, photoKey?}` while profile editing is enabled |
| PUT | `/users/me/language` | any | `{language}` (`ar` / `en`) |
| GET | `/users/:id` | moderator, engineer | one user's card for the user popup |
| GET | `/users` | moderator | active accounts, moderators first |
| POST | `/users` | moderator | `{username, password, fullName, email, role, phone?, photoKey?}`; re-creating a deleted username revives the same account |
| PUT | `/users/:id` | moderator | `{fullName?, email?, phone?, photoKey?, role?, isActive?, password?}`; `isActive: false` is the delete; cannot delete/demote yourself |

## Database

`worker/migrations/` is the source of truth; applied in order with `wrangler d1 migrations apply`.

- **users** — id, username (unique), password_hash, full_name, email, phone, photo_key, language (null = role default), role (`moderator`/`engineer`/`technician`), is_active
- **meters** — id, name, area, number, type, photo_key, todo_order, export_order, is_active, created_by; unique `(name, number, area)` among active meters
- **readings** — id (device-generated uuid), meter_id, value, gain (null for the first reading), photo_key (null once purged), logged_by → users, logged_at (device time), synced_at (server time)
- **KV `SETTINGS`** — `min_app_version`, `maintenance_mode`, `reading_delete_enabled`, `export_enabled`, `photo_retention_days`, `token_lifetime_days`, `profile_editing_enabled`, `export_settings` (JSON), `price_electricity`, `price_water`, `price_gas`, `developer_title`, `developer_username`

The phone caches `meters` (plus `last_logged_at` and `last_value`) and keeps `readings` only as the upload queue, with device-only columns: `local_photo_path`, `sync_status`, `retry_count`, `last_error`.

## App structure (`app/lib`)

```
core/        config (API base URL), bilingual strings (S.*), theme
data/        drift database + generated code, API client, models, photo store, Excel export
state/       SessionController, LanguageController, ConnectivityController, MetersController, SyncController
ui/          login, HomeShell (role-based tabs), popups (meter / user / reading),
             reading edit+delete actions, screens/, shared widgets/
```

Tabs — technician: new reading, readings. Engineer: new reading, readings, dashboard. Moderator: new reading, meters, readings, dashboard. The account menu holds the profile page, language switch, About, and (moderators) app settings and user management.

Readings that look wrong (negative, or well above that meter's usual daily use) are collected on their own page, reached from a card at the top of the readings list and from the warning before an export. Each one can be edited, deleted or marked as normal; when none are left the card and the page go away.

Tapping a meter, user or reading name anywhere opens a popup with its details, the full photo (pinch to zoom) and, for moderators, an edit button.

## Local development

Prerequisites on this machine: Flutter (stable), Android SDK with platform 36, JDK 21 (JDK 26 does not work with the Android toolchain), Xcode with the iOS platform installed, Node 22. Details and commands are in [`CHEATSHEET.md`](CHEATSHEET.md).

```
# API
cd worker && npm install && npm run db:migrate:local && npm run dev

# App (points at the live API by default; override with --dart-define=API_BASE_URL=http://localhost:8787)
cd app && flutter pub get && flutter run
```
