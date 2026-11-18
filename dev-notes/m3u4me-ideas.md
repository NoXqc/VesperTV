# m3u4me / Dispatcharr comparison and what to borrow (2026-11-13, not started)

Written for a fresh Opus session. Read `CLAUDE.md` first (esp. §10 rules, §14 Git), then this file.
Owner asked: analyse https://github.com/andrei-savin/m3u4me against Dispatcharr and our playlist
editor, then hand the useful parts to Opus. Nothing here is built yet.

## What the two projects are
**m3u4me** (TypeScript, Express + React 19, one `data/db.json`, Docker / `install.sh`, GPL-3, 89 stars,
created 2026-07-04, AI-written by a designer; README calls it a self-hosted alternative to m3u4u.com).
A single-user **M3U/EPG manager**, not a player and (per its docs) not a proxy:
- Sources: Xtream account, M3U/XSPF URL or file. Pick channels into the user's own playlists.
- Edit names, logos, groups, TVG IDs, per-channel stream headers (referrer / UA). Bulk move / delete /
  hide / find-replace, undo, basic stream checker (it warns providers may dislike it).
- **Channel sync:** linked channels follow the provider (link, name, logo, TVG ID; never the group).
  The user's own edits win: the provider's change waits for accept / skip (dot on the channel).
  Channels that vanish are hidden and tagged **Source lost**; they return if the provider re-adds them.
  Per-source **changelog** (added / removed / renamed, pruned after 90 days), per-playlist sync log.
- Source refresh every 24 h (EPG 12 h), sequential, retried every 5 min after a failure; a source has
  a **User agent** (presets TiviMate / VLC / Kodi / browser / custom) because some providers only
  answer certain apps. 502/503/504 retried up to 5 times.
- EPG sources + automatic TVG-ID matching; each playlist is served as `http://ip:port/N` and its own
  filtered XMLTV at `/N/epg` (short links so nobody types a long URL on a TV remote).
- Extras: printable A4 channel list (PDF), Cmd+K accent-insensitive search, backup = whole db.

**Dispatcharr** (Python / Django / Celery / Redis / Postgres, AGPL-3, ~4.5k stars): a different class,
a **stream proxy and relay** (shares one provider connection across clients, failover, ffmpeg / VLC /
streamlink profiles, transcoding, DVR + Comskip, HDHomeRun emulation for Plex / Emby / Jellyfin, Xtream
API output, VOD, catch-up proxy, multi-user permissions, VPN container, plugins). Out of scope for us.

## Where our editor stands (verified by grep 2026-11-13)
Our editor is a **client-side edit layer** inside VesperTV: a LAN page (`assets/editor/editor.html`,
served by `lib/services/playlist_editor_server.dart`, QR or typed address + 6-digit code), edits stored
per viewer (`services/playlist_edits.dart`: names, logos, hidden / shown, fallbacks, rules, stream-test
results; groups in `services/user_groups.dart`). It never rewrites provider data, never hosts a playlist,
never touches a provider login. Plan and phases: `dev-notes/iptv-editor-plan.md`; group move / copy:
`dev-notes/editor-group-move-copy.md`.

We already do what m3u4me does and more: rename / hide rules re-applied on every update, duplicate
detection with merge / split, hide lower-quality copies, separator rows, EPG link / extra XMLTV / logos,
opt-in stream test, automatic failover to another copy, Vesper AI editor tool with undo (`AiEditLog`,
`guide_link_log.dart`), real-4K tag from playback.

## Gaps worth closing (what Opus should do)

### 1. "What changed" log for a source update (+ "Source lost")  [recommended first]
Verified: nothing diffs the channel list when Update Content runs. `guide_link_log.dart` and
`playlist_edits_diff.dart` only record *our own* edits.
- Per playlist, on each content update, record channels added / removed / renamed (by `Channel.id`
  composite `playlistId::rawId`; renamed = same id, other provider name). Bounded (e.g. last N entries
  or 90 days), device-local, shown in Playlist Manager's detail pane and/or the editor page.
- **Source lost:** an edit (name, logo, hidden, fallback, own-group move, favourite) whose channel is no
  longer in the provider list stays stored and is shown as missing, never deleted (same rule as the
  plan's "a fallback whose channel is gone is skipped and shown as missing"). If the channel returns the
  edit applies again.
- "Provider changed this" hint when the provider renames a channel the user also renamed (override
  still wins, as now).
- **Performance is the hard part.** Users have up to ~350k channels across 13 playlists (§13, 1.0.56).
  Never diff on the main thread or during the cold-start splash (§10). Xtream lists live in the sqflite
  catalog (`catalog_database.dart`), M3U in a cached text: diff ids / names only, in the background,
  after the update has landed. Prove it on a big list with the `Frames:` / `SlowMain` diagnostics.
- Every new update path must still run `Channel.withUniqueIds` (§10).

### 2. M3U per-channel stream headers (a real parser gap)
Verified: `lib/services/m3u_parser.dart` only reads `#EXTVLCOPT:sub-file=`. Playlists that carry
`#EXTVLCOPT:http-user-agent=…` / `#EXTVLCOPT:http-referrer=…` (also `http-referer`, `http-origin`) or a
Kodi-style `|User-Agent=…&Referer=…` URL suffix lose those headers, so channels that need them fail.
- Parse them into `Channel.httpHeaders` (already carried through playback: `playback_service.dart`
  `createController(httpHeaders:)`, backup-server / retry / copy paths pass `channel.httpHeaders`; the
  Windows player merges `channel.httpHeaders` over its default UA in `desktop_player_screen.dart`).
- Run values through `streamRequestHeaders` (`services/stream_headers.dart`, blocks transport headers
  and CR/LF) and respect `redirectedStreamHeaders`. **Never log header values or credentialed URLs**
  (Send log redaction).
- Persist in the cached M3U channel list (legacy cache restore and recent-history restore must apply the
  same rule as the parser: §10 "M3U playback type"). Check the cache schema / migration.
- Verify the vendored ExoPlayer path actually sends them on Android (`HttpVideoAsset`), and that
  Multiview, recordings (`RecorderService.kt`, `desktop_recorder.dart`) and the stream test
  (`stream_probe.dart`) use the same headers. Android + Windows are separate stacks: do both.
- Editor page: show a small "headers" tag on channels that have them; editing them is optional / later.
- Second step, only if (1)-(2) go well: a per-playlist **User agent** choice (presets like m3u4me).
  `PlaylistProfile` (`models/playlist_profile.dart`) has no such field and Windows hard-codes
  `kDesktopStreamUserAgent`. UNVERIFIED: which UA Android sends for playlist downloads and streams.
  A new profile field needs Backup / Transfer / sync mapping (`sync_merge.dart`) and the Add Playlist
  screen (TV text fields go through `TvTextFieldGate`).

### 3. Printable channel list  [low priority, optional]
No PDF dependency in `pubspec.yaml`. Cheapest route: a "Print channel list" view on the editor web page
(numbers, logos, names, guide yes/no) so the phone / PC browser does Print > Save as PDF. No new Dart
package, nothing leaves the device. Skip if it costs more than that.

### Not doing (do not re-propose)
- Hosting or proxying playlists, `/N` short links, a server `db.json`, a relay for rewritten lists:
  VesperTV must never become a content relay (`iptv-editor-plan.md`). The From phone pairing already
  solves typing on a TV.
- Porting m3u4me code: same licence (GPL-3) but different stack and AI-written; reimplement the ideas.
- Dispatcharr features (proxy, transcode, DVR server, HDHomeRun, users).
- Accept / skip queue for provider edits: our "manual override > rule > provider" model already makes
  user edits win; item 1's hint covers the visibility.

## Rules that apply (from CLAUDE.md)
- Every user-visible string through `tr()` with entries in `lib/l10n/` (fr, es, it, el, de like recent
  features); never `tr()` an id used in logic.
- `flutter analyze` must stay at the **16** info baseline. Add tests (`test/playlist_editor_*`,
  `test/m3u_parser*` style). Run `dart format` only on files you edited.
- Edits stay per viewer, keyed by composite `Channel.id`; Sports matching and EPG lookups keep the
  provider name / `epgId` (§10). Anything new in the edit layer needs Backup, Transfer and sync mapping.
- D-pad: explicit focus handling for any new TV screen; text fields gated; pause timers when covered.
- Branch `claude/m3u4me-ideas`, not main. The working tree already has another session's uncommitted
  glass-menu / theme files, `CLAUDE.md` and `pubspec.yaml`: use a worktree or stage only your files.
  Commit only when the owner asks. Rewrite `HANDOFF.md` after each commit. versionCode must exceed the
  latest build (main is at 1.0.67 / +781 at time of writing; check `pubspec.yaml`).
- Owner tests on real boxes (Homatics Box R 4K Plus `10.0.0.64:5555`); list the checks you could not
  run instead of claiming them.

## Open questions for the owner
- Change log: per device or per viewer? (Playlist data is per device; edits are per viewer.)
- Retention: 90 days like m3u4me, or the last N updates?
- Should "Source lost" channels also be flagged in the TV live list, or only in the editor / manager?
