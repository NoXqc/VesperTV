# Previous releases (before 1.0.0)

VesperTV restarted its version numbers at **1.0.0** on 2026-10-13. This file keeps the history of the
3.x line (released as NoXPlayer until 3.52.3, then VesperTV). The GitHub releases and git tags older
than 3.52 were deleted at that point; their notes are preserved below. Tags `3.52.0`-`3.53.3` and the
`3.53.3` release still exist on GitHub.

## Upgrade note
- **3.53.0 and newer** offer any release whose version is *different* from the installed one, so
  they see 1.0.0 in Settings -> Check for Updates.
- **3.52.3 and older** only offer a *higher* version number and will never offer 1.0.0. Reinstall
  from https://vespertv.app or Downloader code `1760256` (updating in place keeps all data: same
  package `com.nox.nox_iptv`, same signing key).

## Timeline of the 3.x line (highlights)
| Version | Date | Highlights |
|---|---|---|
| 3.31.0 | 2026-09-16 | Real multi-playlist support |
| 3.49.0 | 2026-10-04 | Multiview added; TMDB enrichment fix; Windows browse/hero layout |
| 3.50.0-3.50.2 | 2026-10-06/07 | AC3/E-AC3 5.1 audio via FFmpeg decoder; audio-bleed diagnostics |
| 3.50.3-3.50.7 | 2026-09-24 to 10-07 | Audio-bleed root cause (HDMI passthrough ignores volume) fixed; Timeline guide filter + virtual keyboard fixes (notes below) |
| 3.50.8-3.50.11 | 2026-10-07/08 | Timeline filter Back resets query; Multiview audio-mixer overload fix, quality badge, max-connections visibility; Multiview auto-recovery from fatal playback errors |
| 3.51.0 | 2026-10-09 | First-launch welcome prompt to add a playlist |
| 3.52.0 | 2026-10-09 | Multiview redesign, player controls revamp, Add Playlist redesign |
| 3.52.1-3.52.3 | 2026-10-09 | Windows: true fullscreen, mouse hold-to-activate, minimize/close fixes, auto-resume last channel |
| 3.53.0 | 2026-10-10 | **Renamed NoXPlayer -> VesperTV** (repo `NoXqc/VesperTV`, site vespertv.app), gold theme; updater now offers any *different* version (prepares the 1.0.0 reset) |
| 3.53.1 | 2026-10-10 | Fire TV launcher icon cache fix (renamed icon/banner resources) |
| 3.53.2 | 2026-10-11 | `VesperTV.exe` rename on Windows, splash stars, group reordering, History group, exit prompt |
| 3.53.3 | 2026-10-13 | EPG in SQLite (guide ready ~0.5 s instead of ~50 s, 36 h ahead); visible password in Add Playlist |

## Notes of the deleted releases (verbatim)

### NoXPlayer 3.50.7 (`3.50.7`, 2026-10-07)

#### Timeline guide filter: keyboard layout polish

- Shrunk the virtual keyboard panel to half width, with the live preview video still shown
  alongside it instead of being hidden while filtering.
- Made the panel translucent instead of a solid opaque box.

No functional changes otherwise - same data path, same fixes as 3.50.6.

### NoXPlayer 3.50.6 (`3.50.6`, 2026-10-07)

#### Timeline guide filter: three real fixes

- **Fixed:** typing into the virtual keyboard stealing focus back into the guide after every
  single keystroke. The check for "did the guide have focus before this update" was using a stale
  flag that, once the guide had ever been browsed in the session, stayed true forever and
  re-triggered itself every keystroke. Now checks the real, current focus state instead.
- **Fixed:** the virtual keyboard being way too large - shrunk the panel and key text.
- **Fixed:** the filter staying stuck open after picking a channel, going fullscreen, and coming
  back - it's now closed automatically the moment a channel is actually opened from it.

Multiview audio-bleed/stop-streaming investigation continues separately - not included in this one.

### NoXPlayer 3.50.5 (`3.50.5`, 2026-10-07)

#### Two real fixes this time

- **Fixed:** the Timeline guide filter button (and every key on its new virtual keyboard) not
  responding to Select at all on real remote hardware. Root cause: a plain `InkWell`'s default
  keyboard activation doesn't recognize every "Select"-equivalent key this app's remotes actually
  send - the same already-solved problem `_ProgramBlockState` (the guide's own channel cells)
  handles via `HoldToActivate`. The button/keyboard just weren't using it. This should be the one
  that actually makes the Timeline guide's channel filter work on Formuler/Fire Stick.
- **Fixed:** Multiview and the mini-player/live island playing every active player's audio at once,
  regardless of which was selected/muted - without giving up AC3/E-AC3 support this time. Root
  cause, confirmed via two diagnostic builds: the audio decoder setup was letting ExoPlayer
  auto-detect and use real HDMI bitstream passthrough for AC3/E-AC3, which bypasses per-instance
  volume control entirely (a well-documented ExoPlayer limitation). AC3/E-AC3 now always decodes to
  PCM instead, which keeps volume control reliable with any number of simultaneous players.

### NoXPlayer 3.50.4 (diagnostic + keyboard fix) (`3.50.4`, 2026-10-07)

#### Still a diagnostic build for the audio-bleed investigation, plus a real keyboard fix

(Replaces the 3.50.3 release, which hit an unrelated GitHub-side upload corruption issue.)

- **Audio-bleed diagnostic (unchanged intent from 3.50.3):** an explicit renderer factory is used
  again with the AC3 extension left off, to isolate whether the factory itself (not the extension)
  is the cause of Multiview/mini-player audio bleeding together. AC3/E-AC3 audio is still silent on
  this build, same as pre-3.50.0 - that's expected for this test, not a new bug.
- **Fixed:** the Timeline guide's new virtual keyboard not rendering at all on real hardware
  (reported directly on a Fire Stick) - a real layout bug (`Column(mainAxisSize: MainAxisSize.min)`
  containing an `Expanded` child, which conflicts and collapses to nothing in release builds
  without the debug-mode assertion that would normally catch it). Should actually show up now.

### NoXPlayer 3.50.3 (diagnostic round 2) (`3.50.3`, 2026-09-24)

#### Diagnostic build, round 2 — audio-bleed investigation continued

Round 1 (3.50.2) confirmed the custom audio-decoder renderer swap from 3.50.0/3.50.1 was causing
Multiview and the mini-player/live island to bleed audio from every active player instance. This
build isolates which part of that change is responsible: an explicit renderer factory is back,
but with the AC3 extension left off (so AC3/E-AC3 audio is silent again here, same as pre-3.50.0).

If Multiview/background audio is correct on this build too, the mere act of using an explicit
renderer factory per player instance is the cause, not the FFmpeg extension specifically — that
narrows down where the real fix needs to go.
