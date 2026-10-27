# Catch-up — plan (Claude, 2026-10-27)

Owner decisions (2026-10-27):
- **Pause on a catch-up channel = timeshift**: Play resumes from where it was paused, via the archive.
- **Programme end = keep playing** into the next programme of that channel; when the playhead
  reaches now, switch to live.
- **Windows in the same release**: Codex ports it from Task C4 after Android lands.
- Probe account: the owner provides one (Phase 0).

Mapped from the code on 2026-10-27 (three explore passes). Nothing exists today. Only a comment
in `epg_database.dart:23` and `constants.dart:515` anticipates it. **Naming:** "Archive" already
means Media Hub (`arc_*`, `keyArchive*`, `_isArchiveKey` in transfer). Everything here is
**`catchup`**: never put "archive" in a key, id or class name.

---

## 1. Core model (read this before any task)

### The playhead is a wall-clock time, not a file position
A catch-up session is **one channel + an absolute time `T`** (DateTime, UTC). Programmes are only
markers on that timeline. This is why the owner's "keep playing" is free: when a request's stream
ends, we request again from `T`, and the next programme simply follows.

- Displayed position = `requestStart + controller.position`.
- Scrub bar = the **programme at T** (start..stop in clock times), not the request.
- Seek to time X:
  1. If X is inside the current request **and** the controller reports a seekable duration > 0,
     use native `seekTo(X - requestStart)`.
  2. Otherwise open a new request at X. **This is the fallback that always works**: it is how
     TiviMate seeks on Xtream panels that stream timeshift through ffmpeg (no Content-Length,
     not seekable).
- Xtream URLs have **minute** granularity. A seek lands on the minute floor; the bar shows the
  real position after the jump (no fake seconds).
- Request span = `min(now - X, 6 h)`, rounded up to whole minutes. When the stream ENDS:
  `T = requestStart + position`. If `now - T < 90 s` → **go live** (normal live channel),
  otherwise request again from T.
- Back to live = play the live `Channel` normally. Never seek "forward to the end".

### Identity
The playing `Channel` for catch-up is synthesised:
`rawId = 'cu_<liveRawId>_<requestStartEpochSeconds>'`, same `playlistId`, `url` = archive URL,
`transientPlayback: true`.
- `Channel.isCatchupId(rawId)` (prefix `cu_`) and `isLiveId` returns **false** for it.
  - Without a unique id, `_playChannel`'s same-id no-op (`playback_service.dart:431`) makes it
    play nothing.
  - Without it, the recording tap (`main.dart:335`) swaps in the live recording.
  - Without it, History/Recall would store the archive URL under the live channel.
- `transientPlayback` keeps it out of history, resume saves and WatchTracker. **Recent channels
  get the live channel** (Recall must return to live), recorded once when the session starts.
- `setLastChannelId` stays the **live** id.
- `PlaybackService.catchup` (a `CatchupSession?`) holds `liveChannel`, `requestStart`, the
  programme list, and `pausedAt`. UI asks `playback.catchup != null`, never parses ids.

### Live channel ⇒ "has catch-up"
A `Channel` gets three new fields:
- `catchupDays` (int, 0 = none)
- `catchupKind` (enum `xc`, `default`, `append`, `shift`, `flussonic`, `flussonicTs`)
- `catchupSource` (String?, the template)

Plus `streamId` for Xtream live channels (not recoverable today when `epg_channel_id` is set).

### Native rules (vendored ExoPlayer, §9)
- Today, an error on a non-live source runs `seekToDefaultPosition(); prepare()`
  (`ExoPlayerEventListener.java:237`) — a catch-up glitch would restart the request from 0.
- On texture players (Multiview, Compatibility video) an ENDED with unknown duration reconnects
  forever (`reconnectWhenLiveEnds`).
- **Fix:** a per-player **recovery mode** set over a new method on the existing `vespertv/stats`
  channel (or a new `vespertv/playback` channel): `reportOnly` = no in-place recovery, no
  reconnect-on-end, no frozen-video restart. Errors and ENDED go to Dart, and `CatchupSession`
  re-requests from `T`. It is set for every catch-up controller and reset on dispose.

---

## 2. Phases and owners

| # | Task | Owner | Depends on |
|---|------|-------|------------|
| 0 | Provider probe + decide URL/time rules | Claude | done (§6) |
| C1 | Data fields: Channel, Xtream, M3U, server time offset | Claude | 0 |
| C2 | `CatchupUrlBuilder` pure Dart + tests | **Codex** (now) | 0, runs beside C1 |
| C3 | EPG past retention for catch-up channels | Claude | C1 |
| 3 | `CatchupSession` in PlaybackService + native recovery mode | Claude | C1, C2 |
| 4 | Timeline guide: past window, styling, OK/hold, Back-to-now | Claude | 3, C3 |
| 5 | Player bar catch-up mode + pause-live timeshift + Live ⏩ | Claude | 3 |
| C4 | Windows port (desktop player + mini player) | Claude (Codex if time is short) | 3-5 merged |
| C5 | Strings (ES/IT/EL), remote tips page, README/site line | **Codex** (later) | 4-5 |
| 6 | Device test pass (Formuler + Fire Stick), release | Claude + owner | all |

Owner, 2026-10-27: Codex has limited usage, so **Codex does only C2 now and C5 at the end**.
Claude does the rest. The C1/C3 specs stay below as Claude's checklist.

---

## 3. Phase 0 — provider probe (Claude)
Read-only, credentials never printed or saved in the repo; the script lives in the scratchpad.
1. `player_api.php` auth → record `server_info` (`timezone`, `time_now`, `timestamp_now`,
   `server_protocol`, ports).
2. `get_live_streams` → count `tv_archive==1`, histogram of `tv_archive_duration`.
3. For 2 archive channels, `get_simple_data_table&stream_id=` → do past programmes come back with
   `has_archive=1`? What timezone are `start`/`end` in?
4. Request one programme from 3 h ago, both forms:
   - `/timeshift/u/p/{dur}/{Y-m-d:H-M}/{id}.ts`
   - `/streaming/timeshift.php?...`

   For each, record status, redirects, Content-Type, **Content-Length, Accept-Ranges**, whether a
   Range request returns 206, the first bytes (TS `0x47` or `#EXTM3U`), and whether the start
   matches the EPG (check with server-local time **and** UTC to settle the timezone question).
5. Through Tuliprox too (does it pass `/timeshift/`?).

Output: §6 of this file filled in (facts table), which picks the default URL form and confirms
the time rule. **C1/C2 must not hard-code a timezone rule before this is written.**

---

## 4. Codex task specs

General rules for every Codex task (from CLAUDE.md; Codex forgets these):
- Branch `codex/catchup-<task>` from `main`.
- `flutter analyze` stays at the **16** baseline. `dart format` only on files you edit.
- `git checkout` the generated plugin files after `flutter pub get`.
- Every user-visible string goes through `tr()` with an entry in `fr.dart`, `es.dart`, `it.dart`
  and `el.dart`.
- No new settings unless the spec says so.
- No version bump, no build/install/push/release.
- Update `HANDOFF.md`. Add a short dated bullet under CLAUDE.md §13 (at most 6 lines).
- Never name anything "archive" (see the naming note above).

### C1 — Catch-up data fields
**Files:** `lib/models/channel.dart`, `lib/services/xtream_api_service.dart`,
`lib/services/m3u_parser.dart`, `lib/models/playlist_profile.dart` (only if persisting the offset),
tests `test/catchup_data_test.dart`.

1. `Channel` gets:
   - `final int catchupDays;` (default 0)
   - `final CatchupKind? catchupKind;`
   - `final String? catchupSource;`
   - `final String? streamId;`
   - getter `bool get hasCatchup => isLive && catchupDays > 0 && catchupKind != null;`

   `enum CatchupKind { xc, defaultKind, append, shift, flussonic, flussonicTs }`, in a new file
   `lib/models/catchup.dart`.

   **Thread the four fields through ALL of:** the constructor, `copyWith`
   (`channel.dart:255-289`), `toJson`/`fromJson` (absent key ⇒ 0/null; old caches must load),
   `withUniqueIds` / `_withUniqueRawId` (`channel.dart:240-253`) and `M3uParser.withCatalogType`.
   A test must round-trip a channel through every one of these and assert the fields survive.
   **This is the step that gets forgotten.**
2. `Channel.isCatchupId(String rawId)`: prefix `cu_`, `static const catchupPrefix = 'cu_'`.
   `isLiveId` returns false for it. Test it.
3. Xtream `_buildLiveChannels` (`xtream_api_service.dart:457`):
   - Read `tv_archive` (int or "1" string) and `tv_archive_duration` (int or string days).
   - `catchupDays = tv_archive==1 ? clamp(duration, 0, 30) : 0`, `catchupKind = CatchupKind.xc`
     when days > 0.
   - `streamId = stream_id.toString()` **always** (also when there is no archive).
   - Bad values (null, "", "abc") give 0.
4. Xtream `authenticate()` (`:103`):
   - Read `server_info` → store `serverTimeOffset` (a `Duration?`) on `XtreamApiService`:
     `DateTime.parse('${time_now}Z') - DateTime.fromMillisecondsSinceEpoch(timestamp_now*1000, isUtc: true)`,
     **rounded to the nearest 15 min**.
   - Missing or unparsable fields give null. Also keep `timezone` (String?) for the log line.
   - The first line of the method must stay the same throw behaviour.
   - Expose both through `PlaylistSession` (getter only).
   - Persist on `PlaylistProfile` as `serverTimeOffsetMinutes` (int?, JSON key
     `serverTimeOffsetMinutes`, absent ⇒ null) so playback works before re-auth.
   - Log once: `Catchup: server tz=<tz> offset=<+hh:mm>`. **Never the URL.**
5. M3U parser (`m3u_parser.dart:95`):
   - Capture `#EXTM3U` header attributes into `_headerAttrs` with the same regex. Today
     `#EXTM3U` hits the "ignore" branch, so handle it **before** the generic `#` branch.
   - Per channel: the `#EXTINF` attr wins, else the header attr.
   - Keys: `catchup`, `catchup-type` (alias of `catchup`), `catchup-days`, `catchup-source`,
     `tvg-rec` (days, alias), `timeshift` (days, alias).
   - Kind mapping (lowercase):
     - `default` → `defaultKind`
     - `append` → `append`
     - `shift` → `shift`
     - `flussonic`, `flussonic-hls`, `fs` → `flussonic`
     - `flussonic-ts`, `fs-ts` → `flussonicTs`
     - `xc` → `xc`
     - unknown → null
   - Days present but no kind:
     - URL matches `/<a>/<b>/<digits>(\.ts|\.m3u8)?$` (Xtream-style) → `xc`.
     - `catchup-source` present → `defaultKind`.
     - Otherwise `shift` (Kodi's behaviour).
   - Kind present but no days → `catchupDays = 7`, per Kodi.
   - Clamp days to 0..30. **Only for `!onDemand` channels.**
6. Tests (`test/catchup_data_test.dart`) — fixtures inline:
   - Xtream JSON with `tv_archive` int, string and missing.
   - Auth with `server_info` at +02:00, -05:00 and missing.
   - M3U header-level `catchup="flussonic" catchup-days="3"` inherited by entries.
   - An entry overriding the header.
   - `tvg-rec="5"` alone on an Xtream-style URL → xc/5.
   - A VOD group entry with catchup attrs → `catchupDays 0`.
   - JSON round-trip of an old-cache channel without the keys.
   - `withUniqueIds` keeps the fields.

**Done when:** analyze 16, all tests pass, no UI changes.

### C2 — `CatchupUrlBuilder` (pure Dart)
**Files:** `lib/models/catchup.dart` (**C2 creates it**: only the `CatchupKind` enum from C1 §1,
plus a doc comment; C1 imports it), `lib/services/catchup_url.dart`, tests
`test/catchup_url_test.dart`.
**No dependency on `Channel`** (C1 is being written in parallel). Plain arguments only:
`String? catchupUrl({required CatchupKind kind, required String liveUrl, String? catchupSource, String? streamId, required DateTime start, required Duration span, required DateTime now, Duration? serverOffset, String? xtreamServer, String? user, String? pass, String ext = 'm3u8'})`
returns null when it can't be built (e.g. xc without a stream id, or without credentials and a
liveUrl that doesn't parse as `/u/p/id`).
- **xc** (Xtream playlist, or an M3U xc URL `scheme://host[:port]/u/p/id[.ext]`):
  - Extra named argument `String ext = 'm3u8'` (only `m3u8` or `ts`).
  - URL: `{server}/timeshift/{u}/{p}/{minutes}/{YYYY-MM-DD:HH-MM}/{streamId}.{ext}`.
  - Also expose `catchupPhpUrl(...)` for the `timeshift.php?username=&password=&stream=&start=&duration=`
    form (same time rule). Phase 3 doesn't use it by default; it's there as a fallback.
  - `minutes = ceil(span)`, at least 1.
  - The start is formatted in **server-local** time, `start.toUtc() + serverOffset` (offset null →
    UTC + log a warning once).
  - Phase 0 may change this rule; keep it in one function `_xcLocal(start, offset)`.
- **defaultKind**: substitute placeholders in `catchupSource` (absolute, or relative = appended to
  the channel URL).
- **append**: channel URL + substituted `catchupSource`.
- **shift**: channel URL + (`?` or `&`) + `utc={startEpoch}&lutc={nowEpoch}`.
- **flussonic** (HLS): `http://h/name/index.m3u8?token` or `.../mono.m3u8` →
  `http://h/name/index-{startEpoch}-{spanSeconds}.m3u8?token`; `.../video.m3u8` →
  `video-{start}-{dur}.m3u8`.
- **flussonicTs**: `http://h/name/mpegts?token` → `http://h/name/timeshift_abs-{startEpoch}.ts?token`.
- Placeholders. All epoch values are UTC seconds. Date parts use UTC unless the placeholder
  says local:
  - `{utc}`, `${start}`, `{start}` = start epoch
  - `{utcend}`, `${end}`, `{end}` = start + span
  - `{lutc}`, `${now}`, `${timestamp}`, `{now}` = now epoch
  - `{duration}` = span seconds; `{duration:N}` = span seconds ÷ N, integer
  - `{offset:N}` = (now − start) seconds ÷ N
  - `{Y}`, `{m}`, `{d}`, `{H}`, `{M}`, `{S}` = zero-padded start parts in UTC
  - `{utc:FMT}`, `${start:FMT}`, `{end:FMT}`, `{now:FMT}` where FMT uses the letters
    `Y m d H M S` (e.g. `Y-m-d:H-M`)
  - Unknown placeholders are left untouched.
- Credentials in the URL must never be logged. Add one helper `catchupUrlForLog` that returns
  only the scheme, kind and placeholder names.
- Tests: one golden URL per kind, xc at offsets +02:00/−05:00/null, DST-independent (the offset is
  a fixed Duration), a span of 59.5 min → 60, a token query preserved for flussonic, `{duration:60}`,
  a relative template, an unknown placeholder kept.

**Done when:** analyze 16, tests pass. Nothing calls it yet (Claude wires it in Phase 3).

### C3 — EPG past retention for catch-up channels
**Files:** `lib/services/epg_service.dart`, `lib/utils/constants.dart`, `lib/main.dart`
(EpgSource build ~742), tests.
1. `EpgSource` gains `Map<String,int> catchupDaysById` (normalised EPG id → days). Fill it in
   `main.dart` from each enabled playlist's live channels with `hasCatchup` (key =
   `Channel.epgId` normalised exactly as `epg_service.dart:27` does).
2. Parser drop rule (`epg_service.dart:424`): keep a programme if `stop > now - 2h`, **or** it
   belongs to a catch-up id and `stop > now - min(days, 7)d`. The 7-day cap is the constant
   `AppConstants.catchupEpgMaxDays = 7`.
3. Pruning (`:263`): the `deleteEndedBefore(now-2h)` call must keep catch-up ids' rows to their
   own horizon. Add `EpgDatabase.deleteEndedBeforeExcept(cutoff, Map<id, cutoffForId>)`, or
   delete twice. **One transaction, no whole-table load.**
4. Loading: `_loadPending` (`:707`) loads from `now - catchupHorizon(id)` for catch-up ids.
   `_withData` / `channelIdsWithData(now)` (`:190`) must also include ids that have **past** rows
   inside their horizon (a channel whose feed has only past rows is "no data" today).
5. New sync getter `List<EpgProgram> programsBetween(String epgId, DateTime from, DateTime to)`
   served from `_full` (empty + queue a load when missing, like `getPrograms`). Signal through
   `guideRowsLoaded`, **never `notifyListeners`** (CLAUDE.md §10).
6. Keep `epgPastRetention` = 2 h for everything else. Do NOT widen it globally.
7. Measure: log the parse duration and row count before/after (`EPG: parsed n rows in Xms`
   already exists? if not, add one line). Note numbers in HANDOFF.md.
8. Tests: the parse fixture with a catch-up id keeps 3-day-old rows, a non-catch-up id drops them;
   prune keeps them; `programsBetween` returns past rows; the 7-day cap.

**Done when:** analyze 16, tests pass. **Don't touch** the Timeline guide (Claude, Phase 4).

### C4 — Windows port (after Claude merges 3-5; Claude writes the exact spec then)
Placeholder. Scope: `desktop_player_screen.dart` catch-up bar (same layout as Android),
`DesktopMiniPlayer` + desktop `Player` opened **without** `reconnect_at_eof`/`reconnect_streamed`
for catch-up (they would loop a finished request), Completed → `CatchupSession` advance instead of
`_reload`, and the guide OK/hold paths in the Windows branch of `_previewOrOpenChannel`.

### C5 — Strings + docs (after 4-5)
All `tr()` strings added in 3-5 → `es/it/el` (Claude writes EN + FR). `docs/remote.html`:
- a Guide entry: Left into the past, OK on a past programme, hold menu, Back = now
- a Player entry: catch-up bar, Live ⏩, pause = timeshift

Then regenerate `tools/discord_help_bot/guide.json`. README + `docs/index.html` features line.

---

## 5. Claude phases — design notes

### Phase 3: `CatchupSession` (`lib/services/catchup_session.dart`) + PlaybackService
- `PlaybackService.playCatchup(Channel live, DateTime at, {bool fromPause=false})`:
  - Builds the URL (C2) and the synthetic channel.
  - Goes through the normal `_playChannel`, so its teardown, switching flag and spinner are reused.
  - **Never** the native live zap (`_reuseNativeLive` requires `isLive` on both, and the cu_
    channel is not live; check).
- `backToLive()` = `play(liveChannel)`.
- Set the native `reportOnly` recovery mode on every catch-up controller (vendored plugin, both
  players + texture).
- On error:
  - HTTP 404/410/400 within 3 s of open → "This programme isn't in the provider's catch-up".
    Blcktv answers a missing window with `404 {"message":"no archive for the requested window"}`.
    For xc, retry once with `.ts` first, then `timeshift.php`.
  - Remember per playlist which xc form worked (in memory), so the next request uses it first.
  - Otherwise re-request from T, at most 3 times per 60 s, then the error screen.
- Not reachable in catch-up: `reloadCurrentChannel`, the restart-loop reload and backup-server
  retry. Make the guards explicit.
- **Pause timeshift:** on pause of a live channel with `hasCatchup`, store `pausedAt = now`.
  - On Play, if more than 5 s paused, `playCatchup(live, pausedAt)`.
  - If not catch-up capable → today's behaviour.
- **Hooks that must learn about catch-up:**
  - `_parkLiveChannel` (tv_home:1158): park it too.
  - Preview show/hide (tv_home:2707, 4449).
  - `LiveResumeHint._canResume`: resume live.
  - Multiview button hidden.
  - `PlayerSidePanel` and CH± leave catch-up for live.
  - `Real4kChannels.record`: skip.
  - Recording conflict popup: unchanged (unique id).

### Phase 4: Timeline guide (`tv_home_screen.dart` `_TimelineGuideState`)
- **Movable window instead of a wider one** (cells are non-lazy per row; 7 days × 6 px/min =
  60k px):
  - `_windowStart` / `_windowEnd` become mutable.
  - Left past the edge, on a row whose channel `hasCatchup` and while the target is still inside
    its archive, shifts the window by −3 h: `setState`, `jumpTo` the same visual slot, then
    focus. Same for Right back towards now.
  - Rows that have no catch-up keep today's −1 h floor, so Left falls to the groups column as
    today (no extra presses for non-catch-up users).
- **Fast moves:**
  - CH−/CH+ or Rewind/FastForward in the guide = ±1 day (clamped).
  - **Back while the window is not at now = jump back to now** (`jumpToNow`, `_cursorSlot=null`).
    The next Back walks to groups as today.
  - A gold "Now ▸" chip on the ruler while scrolled away (touch/mouse tap = the same).
- **Styling:**
  - Ended programmes are dimmed.
  - On catch-up rows, ended programmes inside the archive get a small ⟲ glyph before the title.
    Past the archive they get no glyph.
  - The channel label corner `Row` gets a `CatchupTag` (`⟲ 7d` GoldTag compact), following the
    `Real4kTag` pattern; it never takes width from the name.
- **Select on a past programme:**
  - Thread the `EpgProgram` through `onOpen` (`_ProgramBlock` → row → guide).
  - Past + replayable → `_previewOrOpenCatchup(channel, program)`: the first OK plays it in the
    preview, the second OK goes full screen (compare `catchup.programStart`, not the channel id).
  - Past + not replayable → toast "No catch-up for this programme" and play live (today's
    behaviour).
  - The now programme keeps live.
- **Hold OK on a programme:** existing channel menu + programme rows at the top:
  - "Watch from the start" (now programme on a catch-up channel)
  - "Play this programme" (past)
  - "Back to live"
- **Description card:** for ended programmes, "Ended · Catch-up available until <date>" or "Ended".
- **Return from full screen in catch-up:** `restoreFocusToProgram(channelId, programStart)` moves
  the window there instead of resetting to now (`didPopNext` → today it calls
  `restoreFocusToChannel`, which resets `_cursorSlot`).
- **Live list (non-timeline) and the phone layout:** hold menu gets "Watch from the start" only.
  The past is reached through the guide.
- Keep every rule in §10: explicit dispatch, `jumpTo`, the block registry keys, `guideRowsLoaded`,
  the stale-window remount (it must not snap a scrolled-back window to now — skip the stale check
  while the window is shifted).

### Phase 5: Player (`player_controls.dart`, `player_screen.dart`)
- `isLive` stays false in catch-up, so the VOD scrub bar and ±skip appear. Feed them a
  **virtual** position/duration from `CatchupSession` (programme-relative), not the controller's.
  `_ScrubBar.seekTo` goes through `CatchupSession.seekTo`.
- **Bar:**
  - A gold `CATCH-UP` tag before the title.
  - Clock times (`20:14 / 21:00`) and "−1:23 behind live".
  - Buttons: ⏮ previous programme, ±skip, Play/Pause, ⏭ next programme, **Live ⏩** (gold), and
    "Start" (restart programme).
  - Media FastForward key → Live, Rewind → previous programme start.
- Left side panel and CH± are allowed; they leave for live.
- `_LiveRemainingLabel`, `_ZapInfoCard` and the top `EpgGuide` read the **playhead** time
  (`catchup.playheadTime`), not `DateTime.now()`.
- Back from the player keeps catch-up playing in the preview (like live), not stop
  (`player_screen.dart:598` stops non-live: add the catch-up exception).
- **Pause on live (catch-up channel):** Play/Pause stays visible on live for these channels.
  - Pause → the frame freezes and the bar shows "Paused · Play resumes from here".
  - Play → catch-up at `pausedAt`.
  - Left on the live bar (scrub focused) → rewind into catch-up: −30 s steps target a time; OK
    plays from it.

---

## 6. Provider facts (Phase 0, probed 2026-10-27 on the owner's Blcktv Xtream account)
| Fact | Value |
|------|-------|
| server_info | `timezone: UTC`, `time_now` == `timestamp_now` → offset 0. **The server-local vs UTC rule can't be settled on this account** (both are UTC). Keep the offset rule; log it. |
| tv_archive | 741 of 26,837 live channels; `tv_archive_duration` 2 (698) or 1 (43). `tv_archive` comes back as an int. Mostly USA Entertainment/Sports/Movies, CA Français, UK, CA Sports, NFL Teams. |
| Real archive depth | **Deeper than declared:** a 50 h-old request still played with duration 2. Trust the declared days for the UI; don't probe deeper. |
| URL forms | `/timeshift/u/p/{min}/{Y-m-d:H-M}/{id}.ts`, the same with **`.m3u8`**, and `timeshift.php` all return 200. Each 302s to an `arc2.cdnbp.net` CDN with a tokenised path. |
| `.ts` | `video/mp2t`, **Content-Length + `Accept-Ranges: bytes`, Range → 206**, so ExoPlayer can seek natively. Length ≈ 8.3 Mbit/s × the span that exists (a 6 h request = 22 GB). |
| `.m3u8` | `#EXT-X-PLAYLIST-TYPE:VOD` + `#EXT-X-ENDLIST`, 10 s segments, **`#EXT-X-PROGRAM-DATE-TIME`** on the first segment, about 7-10 s before the requested minute. Static, precisely seekable; the manifest is fetched once (no Tuliprox-style mid-session refetch risk). |
| On-air programme | Request from now−10 min for 60 min: the m3u8 holds **only what has aired** (640 s, ENDLIST), and the .ts length is the aired part. So "keep playing" = re-request from T at ENDED: each chunk is (now − T) long. |
| Future window | `404 {"message":"no archive for the requested window"}`. |
| Start alignment | The requested UTC minute matches the EPG `start_timestamp` (both UTC). |
| EPG past depth | xmltv.php (101 MB, 385k programmes, all `+0000`) reaches back only **~12 h**. `get_simple_data_table` returns the same ~13 h (`has_archive: 1` on every past row, titles base64). **The archive goes back 2 days, but the guide only knows the last 12 h.** |
| Tuliprox | Not probed (the owner's Tuliprox accounts mostly allow 1 connection). Check in Phase 6. |

**Decisions from the probe:**
- **xc uses `.m3u8` first** (exact start from PDT, cheap precise seeks, finite VOD = no reconnect
  loops), then falls back to `.ts` once on a playback error. C2's builder takes an `ext` argument.
- Native seek is the normal path. The re-request seek stays as the fallback for providers without
  ranges or HLS.
- Phase 4: past slots on a catch-up row that have **no EPG data** (older than the guide's ~12 h)
  are still playable by time: placeholder blocks per hour labelled "Catch-up 14:00", OK plays from
  that hour. Otherwise days 1-2 of the archive would be unreachable on this provider.
- C3's retention matters (2 h → about 12 h of real data here); the DB growth is small because only
  catch-up ids keep extra rows (741 channels × ~10 h).

## 7. Risks to test on devices
- **Formuler:** shifting the guide window repeatedly (jank/ANR), and EPG DB size with 7 days of
  catch-up rows (parse time on the UI isolate).
- **Fire Stick:** memory (BufferBudget) on long catch-up requests.
- **1-connection accounts:** catch-up uses the same single connection as live, so the switch
  must fully stop live first (`_playChannel` teardown does).
- **Compatibility video / texture:** the `reportOnly` mode must stop the ENDED reconnect loop.
- **DST:** offset taken from `server_info` at each auth; persisted value can be 1 h stale after
  a DST change until the next re-auth (accept; log it).
