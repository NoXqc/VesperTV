# Release workflow, signing details & updater (VesperTV)

Moved out of CLAUDE.md so it is only read when actually releasing. Section numbers (§6.x) are referenced from `bugs-and-fixes.md`. Signing essentials (§5) stay in CLAUDE.md.

## 6. Release workflow
Only release when the owner asks ("update the latest", "cut it", "fully release").
1. Bump `version:` in `pubspec.yaml` (`x.y.z+build`). Settings shows it.
2. `flutter analyze`, build APK, **verify signature (§5)**, build Windows + zip, **commit + push
   source first** (the tag must land on HEAD).
3. Update the latest release in place (don't cut a new release per test build):
   `gh release upload <tag> build/app/outputs/flutter-apk/app-release.apk VesperTV-windows-x64.zip --clobber`
   then `gh release edit <tag> --tag <new-version> --title "VesperTV <ver>" --notes-file <file>`.
   **`--notes` replaces the whole body** — write self-contained notes (never "see below").
4. **Gotcha:** `gh release edit --tag` leaves the old git tag behind and may put the new tag on a
   stale commit — confirm `git ls-remote --tags origin <ver>` equals `git rev-parse HEAD`. Repoint
   with `gh api -X PATCH repos/NoXqc/VesperTV/git/refs/tags/<tag> -f sha=<full-sha> -F force=true`.
5. Experimental builds → `--prerelease` (skipped by `/releases/latest`, so Downloader and Check for
   Updates ignore them). Promote with `gh release edit <tag> --prerelease=false --latest`.
6. **Verify what users get:** download
   `https://github.com/NoXqc/VesperTV/releases/latest/download/app-release.apk` and
   `.../VesperTV-windows-x64.zip`, `sha256sum` against the local files; also check the OLD
   `https://github.com/NoXqc/NoXPlayer/releases/latest/download/app-release.apk` and
   `https://api.github.com/repos/NoXqc/NoXPlayer/releases/latest` still redirect to the new repo,
   and `curl -sL http://go.aftvnews.com/1760256 | grep -o 'https://github[^"'"'"' ]*'` resolves
   (AFTVnews still stores the **old** `NoXqc/NoXPlayer/...` URL — it works only through GitHub's
   redirect, so that redirect is load-bearing).
7. **Updater semantics (changed in 3.53.0):** `AppUpdateService` offers a release when its
   `tag_name` is **different** from the installed version (`_isDifferent`), no longer only when
   newer. Reason: versioning is meant to restart at 1.0.0, which is numerically lower than the old
   3.x tags. Any Android asset ending `.apk` / Windows asset ending `.zip` is picked by extension —
   never leave two `.zip` (or two `.apk`) assets on the latest release.
