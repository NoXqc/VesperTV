# Windows parity plan

Started as `codexwin.md` (Claude, 2026-11-05, written for Codex); moved here 2026-11-06 when the
owner asked Claude to do the work. Read `AGENTS.md` and `CLAUDE.md` first (§3 layout, §4 Windows
build, §10 Windows rules). **One phase per branch, in order**; each ends with a HANDOFF block
(added at the top of `HANDOFF.md`, never replacing other blocks). Tick a phase off below when the
owner has tested it.

| Phase | What | Status |
|---|---|---|
| 0 | Windows build of current code, Android-only calls guarded, owner checklist | done, waiting for the owner's checklist (`claude/windows-parity`) |
| 1 | Audio tracks + surround passthrough + audio delay (no ATMOS badge: mpv can't tell) | done, owner test pending (`claude/windows-parity`) |
| 2 | Data pool + quality / FPS / surround badges | done, owner test pending (`claude/windows-parity`) |
| 3 | Catch-up | done, owner test pending (`claude/windows-parity`) |
| 4 | Toast notifications while the app runs | waiting for the owner (plugin = Start-menu shortcut / registry entry) |
| 5 | Multiview 1+3 and Swap | done, owner test pending (`claude/windows-parity`) |

## Why
Public Windows is still **1.0.45**; Android is 1.0.58 (+632 public, +659 local). Every release
since 1.0.46 shipped the APK only. Windows uses its **own playback stack** (`media_kit` / mpv:
`desktop_player_screen.dart`, `desktop_mini_player.dart`, `desktop_multiview_screen.dart`,
`desktop_stream_setup.dart`), so player features are rebuilt for mpv, never copied from ExoPlayer
code. Settings, storage, l10n, guide and most services are shared Dart.

**Out of scope:** recording (owner, 2026-11-05), anything TV-only (Match frame rate, Native video
surface, Compatibility video, Background video, Fire TV fixes, overlay test, TV keyboard gates),
phone PiP.

## Rules for every phase
- Never edit `third_party/` (vendored Android plugins) or Android native code in these phases.
- Kill the running app before building (`Get-Process VesperTV | Stop-Process -Force`), build with
  `flutter build windows --release`, zip the **whole** `build\windows\x64\runner\Release` folder.
  Don't launch the exe from an automated session to "test" it (blank window, §4); the owner tests.
- Every new user-visible string: `tr()` + entries in fr/es/it/el/de.
- `flutter analyze` stays at the baseline (16); full `flutter test` green; widget tests for new
  Windows UI where the platform can be faked (`debugDefaultTargetPlatformOverride`).
- Settings rows currently gated `Platform.isAndroid` that a phase makes work on Windows: un-gate
  them for Windows only, keep the same preference keys (one setting, both platforms). Today the
  Playback category hides on Windows: Audio, Data pool, Catch-up (plus the TV-only rows above).
- **Not approved in any phase unless the owner says so:** version bump for release, GitHub
  release, push, website/Downloader changes, Discord posts. Test zips only when the owner asks.
- Add a Send-log diagnostic line for each new Windows feature (no URLs/credentials).

## Phase 0: ship what already exists
- Already in the code, never shipped on Windows: live reconnect + copy failover, VOD cut resume,
  Up Next, Skip intro, Live buffer, Software video (commit `cd6654c`, +598); plus every shared
  feature since 1.0.46: Sports Mode, Media Hub redesign, Plex, cloud sync, playlist editor (Dart
  HttpServer + QR page), Notify me + Home "New episodes" row, German, guide transparency, hide
  tabs, Peru Liga 1, goal-disallowed alerts (in-app popup only on Windows).
- **Big M3U (+646..+659)** is shared Dart and needs a Windows check: the M3U import writes from its
  own SQLite connection (FFI in a background isolate), the Xtream conversion of `get.php` links,
  WAL mode, chunked playlist deletes.
- Android-only platform channels (`vespertv/notify`, `episode_background`, `sports_notifications`,
  `audio`, `stats`, `display`, `native_surface`, `goal_overlay_probe`, `recorder`, `subtitles`,
  `phone_pip`, …): audited 2026-11-06 - every call reachable on Windows is behind a
  `Platform.isAndroid` check at the service's start or inside a `try`/`catchError`; the rest live
  in Android-only screens (`player_screen.dart`, `multiview_screen.dart`). Re-run the audit when
  adding a channel (scratch script idea: list `invokeMethod` sites and look 40 lines up for a
  platform check or `try`).
- **Fixed 2026-11-06:** catalog DB `PRAGMA busy_timeout=10000` (`CatalogDatabase._open`
  onConfigure). Without it the app's own connection failed with "database is locked" while an M3U
  import committed a batch on Windows (`test/catalog_concurrent_import_test.dart` fails without it).
- Deliver: the owner's click-through checklist (below) + a zip only if the owner asked for one.

### Owner checklist (Windows PC)
1. Launch: splash, Home, TV guide, play a channel (mini player and full screen), Back out.
2. Add an Xtream `get.php` link in M3U mode: it should become Xtream (download-scope question).
3. Add a plain M3U file/URL: import progress, TV Shows grouped into shows with seasons.
4. While that import runs, favourite a channel or a movie: no error.
5. Movies / TV Shows: open a show, play an episode, Up Next, Skip intro, resume from Continue
   Watching.
6. Media Hub: browse, open a title, play, source drawer (Right).
7. Sports Trak + Sports Mode: games, a goal popup if a followed team plays.
8. Settings > Playback: Skip intro, Up Next, Live buffer, Software video work; no Android-only rows.
9. Playlist editor: the QR page opens on the phone/PC browser; cloud sync pairing.
10. Windowed / Full screen toggle, Minimize, Exit.

## Phase 1: audio tracks + surround
**Done 2026-11-06 (Claude):** `services/desktop_audio.dart` (`DesktopAudio`: `audio-spdif`
ac3,eac3,dts,dts-hd,truehd when passthrough is on, never in Multiview; `audio-delay` from
Settings / Audio sync, applied live to every tracked player; labels; remembered track via the
shared `AudioTrackPreferences.matchWith` / `rememberChoice`), `widgets/desktop_audio_button.dart`
(player bar: tracks when 2+, Audio sync row), Settings > Playback > Audio shown on Windows.
Send log: `DesktopAudio:` / `DesktopAudioTracks:`. **No ATMOS badge:** media_kit's libmpv is
mpv 0.36 / FFmpeg 6.0, which has no `codec-profile` and no E-AC-3 JOC profile, so Atmos can't be
told from plain E-AC-3; passthrough still sends Atmos to a receiver. Also fixed: the Audio
section's rows had no icon (`TvMenuTile` assert, debug only, never drawn in tests before).

Original plan:
- Audio-track picker in the Windows player bar, same look as the Windows subtitle picker
  (`widgets/desktop_subtitles.dart`): mpv `player.state.tracks.audio` / `setAudioTrack`. Labels
  like Android: name, else language (skip `mis/mul/und/zxx/qaa`), else "Audio n", plus codec +
  channel layout.
- Reuse `services/audio_track_preferences.dart`: preferred audio language per viewer and the
  remembered manual VOD choice (language + label, not track ids), applied on open/reconnect.
  Un-gate Settings > Playback > Audio language rows for Windows.
- Surround passthrough (same `AppPreferences.audioPassthrough` key): mpv
  `audio-spdif=ac3,eac3,dts,dts-hd,truehd` when on (`NativePlayer.setProperty`), empty when off;
  app volume doesn't apply while passing through (say so like Android). Multiview never passes
  through.
- ATMOS badge when mpv reports E-AC3 JOC / TrueHD Atmos (`audio-codec-name`, `audio-params`); if
  mpv can't tell JOC apart, show the codec only and note it. Never guess Atmos from the name.
- Owner test: a channel/movie with several audio tracks; switch, reopen (remembered); with a
  receiver, passthrough on.

## Phase 2: Data pool + badges
**Done 2026-11-06 (Claude):** `widgets/desktop_data_pool_card.dart` (`DesktopDataPoolCard` +
`DesktopStreamStats`: mpv properties once a second while open; adds a Decoder row,
hardware API or software), drawn with the shared `DataPoolFrame` (pulled out of
`data_pool_card.dart`, Android unchanged). Player bar button + I key when Settings > Playback >
Data pool is on (setting now shown on Windows). `widgets/desktop_quality_badges.dart`: HD / FHD /
4K, FPS and 5.1 / 7.1 pills under the title (every 5 s). Real 4K tag was already fed on Windows.
No Device HDR row (no Windows API for it here).

Original plan:
- Settings > Playback > Data pool on Windows (same key). Click on the video / a bar button opens
  the shared `widgets/data_pool_card.dart` fed from mpv properties: `video-params` (w/h/pixel
  format/colormatrix/gamma for HDR kind), `container-fps`/`estimated-vf-fps`, `video-codec`,
  `audio-codec-name`, `audio-params/channel-count`, `video-bitrate`/`audio-bitrate`,
  `demuxer-cache-duration`, `frame-drop-count`/`decoder-frame-drop-count`, playing-for timer.
  Poll at most once a second only while the card is open. Never show the server host.
- Quality badge (`utils/video_quality.dart` `qualityLabelForTrack`: 720p HD, 1080p FHD, 2160p 4K
  since +659) + FPS badge in the Windows player bar, from mpv `video-params` / fps.
- Feed the Real 4K tag from the same height reading if it isn't already (`real_4k_channels.dart`).

## Phase 3: catch-up
**Done 2026-11-06 (Claude):** `services/desktop_catchup.dart` (`DesktopCatchup`: `plan()` = the
same rules as `PlaybackService.playCatchup`, tested in `test/desktop_catchup_test.dart`; request
end carries on / goes live, programme-end pause with Keep playing off, seek inside the request or
a new request). `DesktopPlayerScreen(catchupAt:)`: `_currentChannel` stays the live channel,
`_inCatchup` drives the programme scrub bar (clock times), LIVE button, ±10 s, no recall /
reload / side panel, Back closes (never minimizes an archive stream). Live recovery is stopped
for catch-up and watched again on live. Pause on live > 90 s then Play = timeshift. Guide OK on
a past programme opens it full screen (no preview step on Windows; the mini player is cleared
first: one connection). Settings > Playback > Catch-up shown on Windows. Send log:
`DesktopCatchup:` lines. Not done: the Windows side panel / info card have no catch-up entry.

Original plan:
Read `dev-notes/catchup-plan.md` (C4 = this task).
- Shared already: `services/catchup_url.dart`, `catchup_session.dart`, EPG past days, the guide's
  past navigation. Windows needs: play a transient `cu_` channel in `DesktopPlayerScreen` (never
  saved as last channel/history, own id), pause > 90 s = timeshift on resume, Back to live, seek
  inside the programme, end-of-programme behaviour from the Catch-up setting. Rows/groups/history
  use `liveChannel` (same rule as Android).
- Finite archive streams must not trigger `DesktopLiveRecovery` live reconnects.
- Un-gate Settings > Playback > Catch-up for Windows.

## Phase 4: notifications while the app is open
- Windows toast notifications for Notify me new episodes, game reminders, goal alerts (and goal
  disallowed), only while VesperTV is running (minimized counts). Pick a maintained plugin with
  Windows toast support (`local_notifier` or `flutter_local_notifications` Windows); justify the
  choice, no new native C++ unless required.
- Same per-viewer switches as Android's phone notifications and episode alerts; no viewer names
  in the text; click brings the window to the front on the relevant page.
- Not in scope: alerts while the app is fully closed (needs a startup helper; ask the owner).

## Phase 5: Multiview 1+3 and Swap
**Done 2026-11-06 (Claude):** `desktop_multiview_screen.dart`: layout menu gains 1 + 3 screens
(big left, three stacked right), all layouts remembered with Android's `getMultiviewMain` /
`getMultiviewQuad`. Swap mode button (1 + 3 with 2+ playing): arrows rotate the playing screens
through the big one (`swapRotation`, shared with Android), a click on a small screen moves it up,
click on the big one / Esc / Enter / Back ends; only the big one has sound; the `_MultiviewCell`
objects (player + controller) move, nothing reconnects (`Video` keyed by controller). Blinking
SWAP pill in the header, gold flash on the big screen per swap. `test/desktop_multiview_test.dart`.

Original plan:
- `desktop_multiview_screen.dart`: the 1 + 3 layout and Swap mode like Android
  (`multiview_screen.dart`): arrows/clicks rotate the playing screens through the big one without
  reconnecting (move players, don't recreate), sound only from the big screen, SWAP pill + gold
  flash, Esc/OK ends. Remember the layout like the 2/4 choice.
- One provider connection per screen (CLAUDE.md §10); no new connections on a swap.

## Done means
Per phase: code + tests + translations, analyze 16, full tests green, a short owner test list, and
a HANDOFF block saying exactly what was and wasn't verified (nobody ran the Windows UI unless the
owner did).
