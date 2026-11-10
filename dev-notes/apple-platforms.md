# Apple platforms (macOS, iPhone/iPad, Apple TV)

Notes from 2026-11-06 (owner + Claude). Nothing here is built or decided yet.

## macOS: prototype exists (outside contributor)

- PR #3 (`gmtherien`, branch `macos-host-tests`): the test suite passes on a
  macOS host, plus a narrow Android guide preview fix. Merges into main
  cleanly (1378 tests, analyze 16). One change asked before merging: keep
  the 284 px guide preview on TV and cap it to half the row only on
  phones/tablets. On a Formuler (960 logical px) with the tabs column open,
  the row is ~540 px, so the video would shrink to ~270 px and resize every
  frame while the columns slide. The `owned()` symlink fix in
  `local_playlist_files.dart` is macOS-only in effect: `/data/user/0` is not
  a link on the Formuler.
- Fork branch `macos-desktop-prototype` (not a PR yet): macOS reuses the
  Windows media_kit stack via `isDesktop` (Windows or macOS) at the 83
  `Platform.isWindows` sites that meant "a computer". It includes
  `media_kit_libs_macos_video`, CocoaPods, sandbox entitlements and no
  update offers on macOS. The owner has a screenshot of it playing live TV
  with the Timeline guide. As of 2026-11-06 it is 102 commits behind main,
  conflicts in 4 files (tv_home_screen, guide_settings, sports_channels,
  startup_profile), and main now has 88 `Platform.isWindows` sites to
  re-audit. Its own notes list Multiview, trailers, subtitles, backup and
  transfer as not checked.
- To ship outside the App Store: Apple Developer account (~$99/year),
  signing + notarization (otherwise Gatekeeper says the app can't be
  opened), a Mac release asset, and `app_update_service.dart` taught to
  pick it.

## iPhone / iPad: separate, bigger project

- Player: media_kit (mpv) runs on iOS. Apple's own AVPlayer can't play raw
  MPEG-TS (`.ts`) live streams, which most IPTV providers send, so not
  `video_player`'s iOS backend.
- Layout: the phone/tablet touch screens are shared Dart. iOS needs those
  screens on the media_kit player, while the macOS prototype uses the desktop
  screens. Split the check in two: which player stack (media_kit:
  Windows/macOS/iOS) and which layout (desktop/touch/TV).
- Android-only (Kotlin / vendored ExoPlayer) features that would need
  redoing or dropping:
  - native video surface
  - recording (an Android foreground service)
  - Notify me with the app closed
  - picture-in-picture
  - Match frame rate
  - surround passthrough
  - Data pool stats
- No self-update: App Store / TestFlight only (a few EU alternative stores
  aside). The GitHub updater must be off.

## Apple TV

Flutter has no official tvOS support. Out of reach for now.

## App Store rules that matter

- Apple reviews the binary and the store listing, never the git repository.
  One repo for every platform is normal (most Flutter apps). A separate
  repo doesn't help and would double every fix.
- In the iOS app and its listing, never mention Android, APKs, Fire TV
  sideloading or the Downloader code.
- No in-app updater, no downloading of executable code, no pointing users
  to sideloading.
- Review needs a working demo login with clean content (see below).
- App Review is inconsistent: nothing here guarantees approval.

## GPL-3.0 vs the App Store

The App Store's terms conflict with the GPL; VLC was pulled in 2011 for
this. The owner, as copyright holder, can add an App Store exception for his
own code. Outside contributors' code (e.g. `gmtherien`) needs their
agreement. If iOS becomes a real plan, get contributors to agree early (a
line in CONTRIBUTING or a CLA), before more outside code lands. Check
dependencies' licences too, e.g. the libmpv build that media_kit ships.

## Legit Media Hub sources

The app ships no content and recommends none, the same position as VLC and
Infuse: we can't control what users add. Keep it that way: no default
sources, and no piracy add-on names in screenshots or docs (already a rule).
Legit sources to point to:

1. The user's own Jellyfin / Emby / Plex server (already supported): the
   strongest case, the same pitch as Infuse.
2. Public-domain films: the Internet Archive's feature-films collection
   (public API). Could become a recommended add-on or a built-in demo source.
3. Jellyfin's public demo server: a ready review demo for the Media Hub.
4. IPTV: free channels that broadcasters stream themselves. The iptv-org
   list mixes sources of varying legitimacy, so don't use it as the review
   demo.

On an Apple build, leave out the debrid-specific parts: Debrid accounts,
the torrent-hash Ready check and the "being downloaded" clip handling
(`ArchiveReadyWatch`, `DebridApi`). They openly serve torrent add-ons and
are what a reviewer would most likely object to.
