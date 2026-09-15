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

- Pushing triggers the Android build on GitHub. Watch it with `gh run watch`; ~5 minutes later the APK on the `latest` release is replaced.
- If analyze or test fails, the push still goes through but CI fails and no APK is published. Fix first.

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

Xcode's Run is a debug build (slower; shows red assertion screens on framework bugs). For a realistic test on a phone: Product → Scheme → Edit Scheme → Run → Build Configuration → Release.

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

## 9. Cloudflare account tasks

```
npx wrangler login                # once per machine
npx wrangler secret put JWT_SECRET
npx wrangler d1 execute DB --remote --command "SELECT username, role FROM users"
npx wrangler d1 export DB --remote --output backups/backup.sql   # full backup before risky migrations
```

Trigger the weekly photo purge by hand (local dev server started with `npm run dev -- --test-scheduled`):

```
curl "http://localhost:8787/__scheduled?cron=0+10+*+*+5"
```

## 10. Where things are

| Need | File |
|---|---|
| All Arabic text | `app/lib/core/strings.dart` |
| API base URL | `app/lib/core/config.dart` |
| Colours / fonts | `app/lib/core/theme.dart` |
| Local DB schema | `app/lib/data/db/database.dart` (regenerate after editing) |
| Sync engine | `app/lib/state/sync_controller.dart` |
| Tabs per role | `app/lib/ui/home_shell.dart` |
| Server DB schema | `worker/migrations/` |
| API routes | `worker/src/routes/` |
| CI workflow | `.github/workflows/android-apk.yml` |

## Environment notes for this Mac

- Flutter and the Android SDK are installed via Homebrew at `~/homebrew`; `ANDROID_HOME` and `JAVA_HOME` are set in `~/.zshrc`.
- Flutter uses JDK 21 at `~/.local/jdk` (set via `flutter config --jdk-dir`). The system JDK 26 breaks the Android build; don't switch to it.
- iOS uses Swift Package Manager; CocoaPods is not needed.
- If Xcode says "iOS platform not installed", never delete a runtime marked as a duplicate — the records share one disk image. Re-download with `xcodebuild -downloadPlatform iOS`.
