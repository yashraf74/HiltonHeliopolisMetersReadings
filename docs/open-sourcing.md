# Making the repo forkable (parked)

Goal: let someone fork this and ship their own app for a different hotel or
site, without inheriting this deployment's identity. This is a separate
piece of work from the app backlog (`backlog.md`); start it in its own
session.

## Audit summary (2026-09-24)

**No credentials are in the repo or its history.** The JWT secret, Mailjet
keys, signing keystore and password, and the Shorebird token all live in
Cloudflare secrets, GitHub Actions secrets, or git-ignored local files
(`.dev.vars`, `key.properties`, `*.jks`, `worker/backups/`). Database
backups, which hold real readings and personal data, are ignored too.

**Identifying, and already public** (the repo is public): the developer's
name and bio on the About page, the gmail sender address, Cloudflare
resource IDs and the worker URL, the Apple Team ID, the Shorebird app ID,
the GitHub owner/repo used for update checks, the `null@hilton.com`
placeholder and the `com.hiltonheliopolis.meters_app` package name. None of
these are usable without the matching account logins.

## What a fork has to change (~25 spots in ~15 files)

1. **Branding**: app name (both languages), Android label, iOS display
   name, package / bundle id, launcher icon, login photo, palette in
   `app/lib/core/theme.dart`.
2. **Endpoints**: API URL in `app/lib/core/config.dart`, the release links
   in `app/lib/ui/gate_screen.dart` and `worker/src/routes/settings.ts`.
3. **Infrastructure**: `worker/wrangler.toml` (worker name, D1 / KV ids, R2
   bucket, MAIL_FROM), `app/shorebird.yaml`, Apple team in the Xcode
   project, the certificate fingerprint in
   `.github/actions/verify-apk-signature`, the `hilton-meters-*.apk` asset
   name in `release.yml`.
4. **Locale assumptions**: Egyptian mobile format and EGP currency in
   `app/lib/core/strings.dart`, Arabic/English only, and the About page's
   personal content (title and account already come from KV).

The domain model itself — meters, readings with photos and gains, roles,
the offline queue, dashboard, exports, settings — carries no hotel-specific
logic and should need no changes.

## Plan

1. One config surface per side: a single Dart file (or `--dart-define`
   flags) for names, colours, currency, phone rule, URLs; `wrangler.toml`
   vars plus KV for the server.
2. Neutral placeholder assets; the current icon and hotel photo are Hilton
   property and must not ship in a template.
3. Move the remaining About content into settings, or make the page
   optional.
4. A setup script that creates the D1 database, R2 bucket and KV namespace,
   writes their ids, and lists the secrets to set.
5. Per-fork CI values (signing fingerprint, release asset name).
6. Add a LICENSE, and relax the in-app "proprietary, internal use" text.
   Remove Hilton naming and imagery from the template.

**Estimate**: about one working session for steps 1-5, plus one to test a
clean fork end to end. Each fork owner still needs their own Cloudflare
account, email sender, signing key, Shorebird account, and (for iOS) an
Apple developer account.
