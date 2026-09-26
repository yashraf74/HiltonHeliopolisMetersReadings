# Backlog — app and server

Known issues and ideas for the meter-reading app itself, in rough priority
order. Shipping rules (patch vs release) are in `shipping.md`.

## Queued readings aren't tied to the account that logged them

A reading waits on the device until it uploads, and the server records it
under whoever is signed in at that moment. If a technician signs out with
readings still queued and someone else signs in on that phone before they
sync, those readings are attributed to the new user.

Nothing is lost when the *same* user signs in again (an expired token is
safe: the queue and photos stay on the device and upload afterwards).

Fix: upload only readings whose `logged_by` matches the signed-in user, and
hold the rest until that user signs in. App-only change, ships as a patch.

## Email to Hilton mailboxes is filtered

Exports sent to `@hilton.com` addresses are accepted by Microsoft 365 and
then quarantined, so they never reach the inbox (Mailjet still reports
"delivered"). The sender is a gmail.com address sent through Mailjet, which
Microsoft treats as spoofing, and the attachment adds suspicion.

Options, best first: an address on Hilton's own mail system; a domain the
hotel owns, verified in Mailjet with SPF/DKIM; or Hilton IT allow-listing
the sender. A mail-tester.com run would confirm the verdict first.

## Apply a patch without waiting for the next launch

Shorebird downloads a patch on one launch and runs it from the next. The
`shorebird_code_push` package can show "update ready → Restart" instead.
Adding a package needs a release build, so fold it into the next release
that happens for another reason — don't tag a version just for this.

## The "by user" filter list is cached for the whole session

Hiding or unhiding an account (the switch in the user form) doesn't change
the readings filter's dropdown until the app is closed and reopened; pulling
to refresh the readings list doesn't help either.

Cause: `ReadingsScreen` fetches `GET /api/users/names` once in `initState`
(`_loadUserNames`) and keeps it in `_userNames` for the life of the screen.
Pull-to-refresh calls `_load()`, which only refetches readings, and the
screen is kept alive by the tab's IndexedStack, so `initState` doesn't run
again when switching tabs.

Fix options: refetch the names inside `_load()` (simplest); or have the user
form return a flag and refresh the list when user management closes; or move
the names into a small controller that user edits can invalidate.

## The all-dates unusual check scans every reading (raise this soon)

The dashboard's red indicator and the export warning both call
`GET /api/readings/unusual` without a date range, and the shared check in
`worker/src/unusual.ts` loads every reading (with a window function for each
one's previous reading) and recomputes medians on the fly. The dashboard
does this on every load.

At 70 meters read daily that's about 25,000 readings a year, so the scan
grows steadily: more D1 rows read per dashboard load, and a slower response.
It is fine at today's size (hundreds) but will not stay that way.

Fix, in order of preference:

1. **Store the verdict with the reading**, the way `gain` already is: add an
   `unusual` column written by the same recompute that runs after every
   insert, edit and delete. Counting then becomes an indexed `COUNT(*)`
   instead of a full scan, and the dashboard list can be a plain query.
2. **Cache the all-dates count** in KV for a few minutes. Much cheaper to
   build, but only hides the cost.
3. **Bound the window** (say 12 months). Simplest, but the indicator would
   no longer mean "any date", which is what it promises today.

Raise this with the next batch of enhancements rather than waiting for it to
hurt.

## A safer way to test against production

The idea of a "test user" flag (their readings hidden from lists, exports and
the dashboard) was considered and dropped on 2026-09-24: it would put an
"unless this user is a test user" condition into every query that reads
readings, including the gain chain, and the failure mode is silent wrong
numbers when a later feature forgets the filter.

For now: log test readings and delete them afterwards — deleting recomputes
that meter's gains, so the numbers heal. If daily testing on production ever
becomes routine, set up a staging Worker + D1 + R2 + KV instead and point a
build at it with `--dart-define=API_BASE_URL=...`; that also exercises
migrations, which the flag never would.

## Photos left in storage

Replacing or removing a meter or user photo leaves the old object in R2.
Reading photos are purged weekly by retention; these aren't. Harmless at
this scale; worth a cleanup pass if storage ever matters.

## Compatibility shims for 2.0.x apps

`GET /api/meters` and `GET /api/readings` still return `location` /
`meter_location` (a copy of `area`) so apps from 2.0.x don't crash. Once
the minimum app version is comfortably above that, drop them from
`worker/src/routes/meters.ts` and `readings.ts`.

## Operational

* Raise the minimum app version in Settings once everyone is on the current
  release.
* Real-device testing pass across roles (technician / engineer / moderator).
