# Cheat sheet

Everyday commands, in the order you'd run them. Paths assume the repo is at `~/projects/HiltonHeliopolisMetersReadings`.

## 1. After editing the app (Dart, strings, screens)

```
cd ~/projects/HiltonHeliopolisMetersReadings/app
flutter analyze
flutter test
git add -A
git commit -m "Describe the change"
git push origin main
```

Pushing app code builds nothing by itself. Ship it one of two ways — the
full rules are in [`docs/shipping.md`](docs/shipping.md):

**Patch** (Dart-only changes; no new APK, Android only):

```
gh workflow run patch.yml            # keep app/pubspec.yaml's version unchanged
```

Phones download it on the next launch and run it from the launch after.

**Release** (assets, native changes, a new Flutter version, or when you want
a visible version):

```
# bump version: in app/pubspec.yaml, then
flutter build ios --config-only      # so Xcode picks up the new version
git commit -am "vX.Y.Z" && git push origin main
git tag -a vX.Y.Z -m "vX.Y.Z"        # add "beta" to the message for a pre-release
git push origin vX.Y.Z
```

Watch either with `gh run list` / `gh run view <id>`; a release takes ~10
minutes and publishes a signed APK to GitHub Releases. The app sends its
version to the server, so a new "minimum app version" must never exceed the
version you have shipped.

## 2. Running on the iOS simulator

```
cd ~/projects/HiltonHeliopolisMetersReadings/app
flutter devices                 # find the simulator name
flutter run -d "iPhone 17"
```

While it runs: `r` hot reload (UI tweaks), `R` full restart (new screens, providers, startup code), `q` quit.

## 3. Running from Xcode instead of the terminal

Open `app/ios/Runner.xcworkspace` (the **workspace**, not the project) and press Run. Xcode compiles the Dart code itself, so no terminal step is needed for ordinary edits.

Do run these in the terminal first when they apply:

```
flutter pub get                                   # after any change to pubspec.yaml or after pulling one
dart run build_runner build --delete-conflicting-outputs   # after changing lib/data/db/database.dart
```

Pick the scheme next to the Run button: **Runner** builds Release for a real
iPhone (so the app works without the Mac attached), **Runner (Simulator)**
builds Debug for simulators. Flutter's Release mode doesn't support
simulators, which is why there are two.

After any version bump, run `flutter build ios --config-only` and then
Product → Clean Build Folder (⇧⌘K), or Xcode keeps showing the old version.

## 4. Installing on your own iPhone (one-time setup)

1. In Xcode: select the Runner target → Signing & Capabilities → tick "Automatically manage signing" → Team → add your Apple ID. If the bundle id is taken, change it to something unique.
2. iPhone: Settings → Privacy & Security → Developer Mode → on (phone restarts).
3. Connect by cable, tap Trust, then `flutter run -d "<your iPhone>" --release` or Run in Xcode.
4. First launch: Settings → General → VPN & Device Management → trust your certificate.

With a free Apple ID the install expires after 7 days; just run it again.

## 5. Building an APK locally (without waiting for CI)

```
cd ~/projects/HiltonHeliopolisMetersReadings/app
flutter build apk --release --target-platform android-arm64
# → build/app/outputs/flutter-apk/app-release.apk
```

Use `--target-platform android-arm64` on this Mac: building all CPU targets at once runs out of memory. CI builds the full APK.

## 6. After editing the API (`worker/`)

```
cd ~/projects/HiltonHeliopolisMetersReadings/worker
npm run typecheck
git add -A
git commit -m "Describe the change"
git push origin main            # Cloudflare deploys automatically
```

**If you added a migration file** in `worker/migrations/`, apply it to the live database *before* pushing, so the new code never runs against the old schema:

```
npm run db:migrate:remote
```

## 7. Running the API locally

```
cd ~/projects/HiltonHeliopolisMetersReadings/worker
npm run db:migrate:local        # first time, and after adding migrations
npm run create-user -- eng 'Passw0rd!' "Test Engineer" engineer   # prints a command; run it with --local instead of --remote
npm run dev                     # http://localhost:8787
```

Point the app at it: `flutter run --dart-define=API_BASE_URL=http://localhost:8787`.

Note: the local database is keyed by the D1 `database_id` in `wrangler.toml`; changing that id starts a fresh empty local database.

## 8. Creating the very first moderator account (no app access yet)

```
cd ~/projects/HiltonHeliopolisMetersReadings/worker
npm run create-user -- <username> '<password>' "<Full Name>" moderator
```

It prints a `wrangler d1 execute ... --file` command; run that. After that, create every other account from the app's Users tab.

## 9. Runtime settings (site properties)

Moderators change these from the app (account menu → app settings). They live in the Workers KV namespace `SETTINGS` and can also be edited in the Cloudflare dashboard (Storage & Databases → KV → SETTINGS) or from the terminal:

```
cd ~/projects/HiltonHeliopolisMetersReadings/worker
npx wrangler kv key put --binding SETTINGS --remote min_app_version 2.0.0
npx wrangler kv key get --binding SETTINGS --remote maintenance_mode
```

Keys: `min_app_version`, `maintenance_mode` (true/false), `reading_delete_enabled`, `export_enabled`, `photo_retention_days`, `token_lifetime_days`, `profile_editing_enabled`, `export_settings` (JSON), `price_electricity`, `price_water`, `price_gas`.

Two keys are deliberately not in the app's settings screen — the About page reads them:

```
npx wrangler kv key put --binding SETTINGS --remote developer_title "Senior Shift Engineer"
npx wrangler kv key put --binding SETTINGS --remote developer_username khalidabdoo
```

## 10. Cloudflare account tasks

```
npx wrangler login                # once per machine
npx wrangler secret put JWT_SECRET          # also: MAILJET_API_KEY, MAILJET_SECRET_KEY
npx wrangler secret list
npx wrangler d1 execute DB --remote --command "SELECT username, role FROM users"
npx wrangler d1 export DB --remote --output backups/backup.sql   # full backup before risky migrations
```

Trigger the weekly photo purge by hand (local dev server started with `npm run dev -- --test-scheduled`):

```
curl "http://localhost:8787/__scheduled?cron=0+10+*+*+5"
```

## 11. Where things are

| Need | File |
|---|---|
| All text (Arabic + English) | `app/lib/core/strings.dart` |
| API base URL | `app/lib/core/config.dart` |
| Colours / fonts | `app/lib/core/theme.dart` |
| Local DB schema | `app/lib/data/db/database.dart` (regenerate after editing) |
| Sync engine | `app/lib/state/sync_controller.dart` |
| Runtime settings / version gate | `worker/src/settings.ts`, `worker/src/middleware.ts` |
| Gain recompute | `worker/src/gain.ts` |
| Dashboard | `worker/src/routes/dashboard.ts`, `app/lib/ui/screens/dashboard_screen.dart` |
| Launcher icon source | `app/assets/icon/icon.png` (`dart run flutter_launcher_icons` after replacing) |
| Login background | `app/assets/images/login_bg.jpg` |
| Tabs per role | `app/lib/ui/home_shell.dart` |
| Server DB schema | `worker/migrations/` |
| API routes | `worker/src/routes/` |
| Excel export | `app/lib/data/export/excel_export.dart` (options come from settings) |
| Popups (meter / user / reading) | `app/lib/ui/popups.dart` |
| Language switching | `app/lib/state/language_controller.dart` |
| CI workflows | `.github/workflows/release.yml` (tags), `patch.yml` (over the air) |
| Shipping rules, backlog | `docs/` |

## Environment notes for this Mac

- Flutter and the Android SDK are installed via Homebrew at `~/homebrew`; `ANDROID_HOME` and `JAVA_HOME` are set in `~/.zshrc`.
- Flutter uses JDK 21 at `~/.local/jdk` (set via `flutter config --jdk-dir`). The system JDK 26 breaks the Android build; don't switch to it.
- iOS uses Swift Package Manager; CocoaPods is not needed.
- If Xcode says "iOS platform not installed", never delete a runtime marked as a duplicate — the records share one disk image. Re-download with `xcodebuild -downloadPlatform iOS`.
