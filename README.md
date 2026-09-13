# Hilton Heliopolis Meters Readings

Offline-first Android app (Flutter, Arabic/RTL) for logging electricity, water and gas meter readings, backed by a Cloudflare Worker.

- `worker/` — Cloudflare Worker API (Hono + D1 + R2). Deployed automatically on push to `main` via Cloudflare's Git integration.
- `app/` — Flutter mobile app.

## Worker

```
cd worker
npm install
npm run dev                 # local API on http://localhost:8787 (needs .dev.vars with JWT_SECRET)
npm run typecheck
npm run db:migrate:local    # apply migrations to the local D1
npm run create-user -- <username> <password> "<full name>" <engineer|technician>
```
