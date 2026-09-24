# Shipping changes

Two ways to get a change to the phones.

## Patch (Android, no reinstall)

Dart-only changes reach installed Android apps over the air, with no new
APK: push to `main`, keep the version in `app/pubspec.yaml` unchanged, then
run the patch workflow (Actions -> "Shorebird patch", or
`gh workflow run patch.yml`). Phones download it on the next launch and use
it from the launch after that. iOS is not on Shorebird: rebuild from Xcode.

## Release (new APK)

Bump `version:` in `app/pubspec.yaml`, run `flutter build ios --config-only`
so Xcode picks the version up, then tag it:

    git tag -a v2.6.0 -m "v2.6.0"      # add the word "beta" to the message
    git push origin v2.6.0             # for a pre-release that isn't Latest

Everyone installs the APK from the GitHub release. Raise the minimum app
version in Settings once they have.

## A patch can't do these — they need a release

* **Assets**: anything under `app/assets/` (the login photo, app icon,
  fonts). Shorebird refuses the patch with "Your app contains asset
  changes".
* **New Material icons**: Flutter normally ships only the icons a build
  uses, so a patch using a new one would show blanks. Both workflows pass
  `--no-tree-shake-icons`, which ships the whole icon font and removes this
  limit — keep that flag.
* **Native code**: adding or removing a package with native code, app
  permissions, `AndroidManifest.xml`, `Info.plist`, Gradle or Xcode
  settings.
* **A different Flutter version**: a patch must be built with the release's
  Flutter (pinned to 3.47.4 in both workflows).
* **A changed `version:`**: patches attach to the version of an existing
  release.

Server (`worker/`) changes are separate: they deploy on push to `main` and
need no app update at all.
