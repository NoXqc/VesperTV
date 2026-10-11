# Known bugs & their fixes (history — don't regress these)

Check this before investigating a bug: it may already have been root-caused. Section references (§6.4, §10 …) point to `release.md` and `CLAUDE.md`.

## 11. Known bugs & their fixes (history — don't regress these)
| Symptom | Cause | Fix / where |
|---|---|---|
| Add Playlist: Back to close the keyboard on the **Name** field jumped to fullscreen live; Back again returned | `LiveResumeHint`'s global hold-Right (1200 ms) timer was armed while a text field had focus, and the Fire/remote keyboard sequence fired it | `LiveResumeHint._textFieldFocused` gates both arming **and** `_resume()` (`live_resume_hint.dart`) |
| Cold launch opened the first live group instead of Favourites | `_effectiveLiveGroup` used only `currentChannel`, which is null on cold launch | favourites-first using `currentChannel ?? pendingResumeChannel` (`tv_home_screen.dart`) |
| Add Playlist: Right from fields never reached the Add button; up/down escapes buggy | focus escape logic per field | explicit `_modeScope/_fieldsScope/_statusScope`, `_handleFieldEscapeKey` with a unified field list; mode rows use `TvMenuTile(focusNode:)` |
| Multiview: main stream/audio kept playing after "Open in Multiview" | player not stopped | `await _playback.stop()` before push |
| Multiview: in-place audio toggle stalled / no audio | see §10 | reverted to recreate-via-`_assign` |
| Windows: "can't go truly full screen" (title bar + taskbar, ~98%) | native runner only shows a bordered window | `window_manager` always-fullscreen launch |
| Windows: Minimize did nothing / Close did nothing / Alt+Tab-away fine | minimize blocked in fullscreen; `SystemNavigator.pop` no-op | see §10 Windows |
| Windows: hold-to-menu only worked with keyboard Enter | no pointer long-press | `RawGestureDetector` in `HoldToActivate` |
| Windows: last channel not resumed at launch | nothing recorded it | `DesktopPlayerScreen` records `setLastChannelId`; `_autoResumeLastChannel` pushes it |
| Windows build `LNK1104` | exe still running | kill `nox_iptv` first |
| Rebranded APK still purple (default theme) | Platinum's accent pair + splash were hardcoded purple/magenta | gold values in `constants.dart` and `main.dart` splash |
| Fire TV home tile still shows the old purple "N" after updating (phones show the gold V) | Fire OS keeps the launcher icon captured at first install | **not fixable in-app**; renaming the icon resources (3.53.1) did not help; only uninstall + reinstall refreshes it |
| Updater never offers a lower-numbered release (1.0.0 < 3.x) | strict "newer" compare | `_isDifferent` (§6.7) |
| `gh release edit --notes` referenced "notes below" and wiped them | `--notes` replaces body | write self-contained notes with `--notes-file` |
| Release asset update didn't change what `/latest` serves | tag left on old commit | repoint tag to HEAD (§6.4) |
| Formuler adb "device not found" | its IP changed | reconnect on `192.168.1.46:5555` / check its Settings > Network |
| **Open: EPG not ready for ~58 s after the UI appears on the Formuler** (PC: 1-2 s; LokTV is near-instant) | unproven — hypothesis: eager full in-memory decode vs a lazily-queried DB, on weak hardware | not fixed. Concurrent-init attempt gave no improvement. `traceEpgTiming` in `epg_service.dart`/`main.dart` is **TEMPORARY instrumentation** (its output file is unreadable on the Formuler) — remove it when this is resolved or abandoned |
