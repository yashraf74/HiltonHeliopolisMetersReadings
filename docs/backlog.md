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
