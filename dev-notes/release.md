# Release workflow, signing details & updater (VesperTV)

Moved out of CLAUDE.md so it is only read when actually releasing. Section numbers (§6.x) are referenced from `bugs-and-fixes.md`. Signing essentials (§5) stay in CLAUDE.md.

## 0. Two channels: weekly stable + test builds (since 2026-11-21) — read first
Owner, 2026-11-21 (AMD's suggestion on Discord): "it will help me slow down", he spends 40+ h a week on
the project beside a 42 h job. Four releases in four days (1.0.69 → 1.0.72) meant four announcements and
four update prompts for everyone.

- **Stable = once a week, on Sunday.** A normal GitHub release (Latest). The site, README, Downloader code
  `1760256`, `releases/latest/download/...` and Check for Updates on its default channel (**Stable**) only
  ever see this one. Announced in the release channel (`DISCORD_RELEASE_WEBHOOK`).
- **Test builds = between Sundays, for fixes people are waiting to try.** A GitHub **pre-release** (never
  Latest: `/releases/latest` skips it, so stable users and the Downloader never get it). Tag
  `<next stable version>-dev.<build>`, e.g. `1.0.73-dev.951`; title `VesperTV 1.0.73 test build 951`;
  asset `app-release.apk` (Android only unless the owner asks for Windows). Testers get it from
  Settings > Check for Updates > **Update channel: Test builds** (this device only, `vesper_update_channel`)
  or the launch popup ("Test build … is available"). Announced in a testers channel
  (`DISCORD_TEST_WEBHOOK`, see §0.3) or not at all.
- **Hotfix = the only mid-week stable**: a crash at launch, lost data (favourites, playlists, settings),
  nothing plays for many people, or a broken updater. Everything else waits for Sunday.
- **Box test = the owner's own box only**, as before: a local APK (`C:\Users\aarse\VesperTV-test-<N>.apk`),
  installed by adb when he asks or put on the Downloader test link. Not a release.

### 0.1 Where does a change go? (Claude says it at the end of every fix, CLAUDE.md §1)
| Change | Goes to |
|---|---|
| A fix a tester / Discord user is waiting to try (AMD, clayts450…) | **test build** now, then Sunday |
| A risky change the owner wants feedback on before everyone gets it | **test build**, then Sunday |
| A fix for a bug that only a test build has | **next test build** |
| Small fixes, new features, settings, translations, look | **Sunday's weekly update** (in a test build first when one goes out that week) |
| Crash at launch, lost data, nothing plays for many, updater broken | **hotfix** (stable now, §0.4) |
| Something only the owner can judge on his box | **box test** (local APK), not a release |

A change merged into `main` is in the next test build *and* the next Sunday release; nothing extra to do.
Before Sunday's release, prefer what ran at least two days in a test build without a regression report;
anything newer can wait a week (say so in the notes for the owner, not in the public notes).

### 0.2 Branches and versions
- `main` = the dev line: every merged fix. Test builds are built from it.
- The weekly stable is built from the `main` commit chosen for it (usually the last test build's commit),
  tagged with the plain version (`1.0.73`). After publishing, move the `stable` branch there:
  `git push origin <full-sha>:refs/heads/stable` (create it the first time; never force anything else).
- `pubspec.yaml` `version:` holds the **next stable name + the newest build**: after 1.0.72 it is
  `1.0.73+N`. A test build overrides only the name: `--build-name=1.0.73-dev.<N> --build-number=<N>`.
  The weekly stable is built as `1.0.73+N` with a new N (higher than every test build); right after it,
  `main` moves to `1.0.74`. `+N` always rises, so a tester can go back to Stable: the updater offers a
  test-build install only *newer* versions (`AppUpdateService.shouldOffer`), i.e. the next Sunday's.
- Ordering (`AppUpdateService.compareVersions`, semver): `1.0.72 < 1.0.73-dev.951 < 1.0.73-dev.960 <
  1.0.73 < 1.0.74-dev.961`. A test build's name must therefore carry the **next** version, never the
  released one (`1.0.72-dev.N` would read as older than 1.0.72).
- iOS / Apple TV (TestFlight) use their own build numbers and never take a `-dev` name.

### 0.3 Discord
- Stable: posts itself when a new release is published (`discord-release.yml`, gold embed). An in-place
  edit doesn't fire: then `gh workflow run discord-release.yml -f tag=<ver>`.
- Test build: the same workflow posts a purple "🧪 Test build" embed to `DISCORD_TEST_WEBHOOK`, and skips it
  while that secret isn't set. Owner setup, once: create a testers channel, Edit channel > Integrations >
  Webhooks > New Webhook > Copy URL, then `gh secret set DISCORD_TEST_WEBHOOK` (paste the URL). Never put the
  URL in the repo or a log.
- Preview either post: `gh api repos/NoXqc/VesperTV/releases/tags/<tag> > r.json && python -X utf8 .github/scripts/discord_release.py r.json --dry-run`.

### 0.4 Hotfix
Branch from `stable` (`git switch -c hotfix/<ver> origin/stable`), apply only the fix (cherry-pick it from
`main` when it's there), build as the **next patch** version (1.0.74) with a new +N, release + announce like
a weekly (§6), move `stable` to it, merge the hotfix branch back into `main`. `main`'s next test builds are
then `1.0.75-dev.N` (one above the hotfix, or the updater reads them as older).

### 0.5 The switch-over (2026-11-21)
- 1.0.72 and older have no Update channel: their updater reads `/releases/latest` only, so test builds can
  never reach them. Testers get onto the test channel by installing **1.0.73** (the first Sunday release,
  Sunday 2026-11-22, which has the setting) and switching, or by installing one test build's APK by hand once.
- Old pre-releases pile up on the releases page: keep the newest three; delete older ones only with the
  owner's OK (`gh release delete <tag> --cleanup-tag -y`).

## 6. Weekly stable release (Sunday)
Only release when the owner asks ("update the latest", "cut it", "fully release", `/cutr`). If it isn't
Sunday, ask first: test build, hotfix, or release anyway (§0)?
1. `pubspec.yaml` `version:` = the stable name (`1.0.73+N`, N above every build so far). Settings shows it.
2. `flutter analyze`, tests, build APK, **verify signature (§5)**, build Windows + zip, **commit + push
   source first** (the tag must land on HEAD).
3. **A new release per weekly** (test builds are pre-releases now, so there is nothing to edit in place):
   `gh release create <ver> --target <full-sha> --latest --title "VesperTV <ver>" --notes-file <file> build/app/outputs/flutter-apk/app-release.apk VesperTV-windows-x64.zip`.
   Publishing announces it (step 8). Re-uploading the *same* version (a broken asset) is the only in-place edit:
   `gh release upload <tag> … --clobber` (`--notes` replaces the whole body — write self-contained notes).
   The notes cover everything since the previous stable, test builds included (not "see the test builds").
   **Every weekly ships Android + Windows + Linux (4b):** a new release object starts empty, so the site /
   README buttons (`releases/latest/download/VesperTV-windows-x64.zip`, the Linux files) 404 for an
   Android-only week, and until the Linux CI runs finish (~15 min). Android-only = ask the owner first.
4. **Gotcha:** `gh release edit --tag` leaves the old git tag behind and may put the new tag on a
   stale commit — confirm `git ls-remote --tags origin <ver>` equals `git rev-parse HEAD`. Repoint
   with `gh api -X PATCH repos/NoXqc/VesperTV/git/refs/tags/<tag> -f sha=<full-sha> -F force=true`.
   Then move `stable`: `git push origin <full-sha>:refs/heads/stable`, and bump `main` to the next
   version name (`1.0.74+N`).
4b. **Linux (since 1.0.72):** once the tag is on HEAD (step 4), run
   `gh workflow run linux-flatpak.yml --ref main -f release_tag=<ver>` and
   `gh workflow run linux-build.yml --ref main -f release_tag=<ver>`. Each builds main's HEAD, stops if
   the tag isn't that commit, uploads `VesperTV-linux-x86_64.flatpak` / `VesperTV-linux-x64.tar.gz`
   with `--clobber` and deletes older versioned Linux files on the release (Flatpak ~10-15 min, tarball
   ~4 min; the Flatpak job also installs it and runs it 20 s under Xvfb first). The names never change,
   so the site / README link `releases/latest/download/<name>`. Announce (step 8) after both finish.
   An Android-only release skips this (the Linux files stay those of the release they were built for).
5. Test builds: §6b. Never mark a test build Latest; promote nothing (the weekly is its own release).
6. **Verify what users get:** download
   `https://github.com/NoXqc/VesperTV/releases/latest/download/app-release.apk` and
   `.../VesperTV-windows-x64.zip`, `sha256sum` against the local files; also check the OLD
   `https://github.com/NoXqc/NoXPlayer/releases/latest/download/app-release.apk` and
   `https://api.github.com/repos/NoXqc/NoXPlayer/releases/latest` still redirect to the new repo,
   and `curl -sL http://go.aftvnews.com/1760256 | grep -o 'https://github[^"'"'"' ]*'` resolves
   (AFTVnews still stores the **old** `NoXqc/NoXPlayer/...` URL — it works only through GitHub's
   redirect, so that redirect is load-bearing).
   Since 2026-11 go.aftvnews.com often answers curl with a Cloudflare "Just a moment..." page (403):
   try it once, and if it's blocked note it and carry on (owner: don't stall on it); the old NoXPlayer
   link check covers the same path.
7. **Updater semantics:** `AppUpdateService` on the Stable channel reads `/releases/latest` and offers a
   release when its `tag_name` is **different** from the installed version (`_isDifferent`, since 3.53.0:
   versioning restarted at 1.0.0, numerically lower than the old 3.x tags) — except on a test-build install,
   which only takes a newer version. On Test builds it also reads `/releases?per_page=20` and offers the
   highest version (`pickNewest`) when it is newer. Any Android asset ending `.apk` / Windows asset ending
   `.zip` is picked by extension — never leave two `.zip` (or two `.apk`) assets on a release.
8. **Announce on Discord** (after step 6 checks out): a newly published release announces itself; after an
   in-place edit run `gh workflow run discord-release.yml -f tag=<ver>`. Check the run succeeded.
9. **Delete old local APKs, at release time only (owner, 2026-11-21):** when a release is cut
   (`/cutr`), delete the local Android APKs in `C:\Users\aarse` (`VesperTV-test-<N>*.apk`,
   `VesperTV-<ver>-<N>.apk`, `VesperTV-<ver>-dev.<N>.apk`) older than the two newest by build number `N`.
   Never during test builds. **Per platform:** a build made for another platform (Apple TV / iPhone
   branches such as `claude/appletv-*`, `claude/tvos-*`, `claude/ios-*`, and other players' test builds)
   is not counted against the Android ones: the newest one for that platform stays even when its number
   is lower. Each APK is ~105 MB: 90 of them (8.7 GB) filled C: on 2026-11-21 and a build failed
   with "not enough space on the disk". Released APKs stay downloadable from GitHub.

## 6b. Test build (pre-release)
Only when the owner asks ("test build", "pre-release", `/cutr test`). Android only unless he asks.
1. Build number N above every build so far (HANDOFF.md, `C:\Users\aarse\VesperTV-*.apk`, `gh release list`).
   `pubspec.yaml` = `<next stable>+N` (e.g. `1.0.73+951`); commit with what goes in.
2. `flutter analyze` (baseline), tests, then
   `flutter build apk --release --build-name=<next>-dev.<N> --build-number=<N>`; **verify signature (§5)**
   and that `aapt dump badging` (or the install) says versionName `<next>-dev.<N>`, versionCode `N`.
   Keep a copy as `C:\Users\aarse\VesperTV-<next>-dev.<N>.apk`.
3. Push `main` (the test build's commit must be on GitHub).
4. `gh release create <next>-dev.<N> --prerelease --target <full-sha> --title "VesperTV <next> test build <N>" --notes-file <file> build/app/outputs/flutter-apk/app-release.apk`.
   Notes: short, **What to test** first (who asked, what to check, what to send back), then the changes since
   the last test build. End with: "Settings > Check for Updates > Update channel: Test builds. Everyone else
   gets these fixes on Sunday."
5. Verify: `gh api repos/NoXqc/VesperTV/releases/latest --jq .tag_name` is still the stable release (a test
   build must never be Latest); the pre-release's APK downloads and its sha256 matches the local file.
6. Announce: automatic when `DISCORD_TEST_WEBHOOK` is set (check the workflow run); otherwise tell the owner
   it wasn't announced and give him a short text for his testers.
7. HANDOFF.md: one line (tag, N, what's in it). Next build > N.

### Android-only release (owner instruction, 2026-10-29)
For 1.0.46+514 the owner explicitly deferred Windows work. Do not build or test
Windows, and do not attach an older Windows zip as if it were the new version:
Windows' updater would repeatedly offer the old binary under the new tag.
Keep release1.0.45 and its Windows asset available, pin website Windows links to
that release, and publish a separate real1.0.46 release with the Android APK only.
The Windows updater sees no new zip and offers no update. Release notes and the
announcement must state that Windows stays at1.0.45. Prepare a draft, verify its
APK against the signed local artifact, then publish; this fires the announcement
workflow automatically, so do not dispatch a duplicate announcement afterward.
