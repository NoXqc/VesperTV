# Tuliprox Player API in VesperTV (2026-11-23)

Tuliprox's developer (euzu, "uzumaki" on Discord) added a user-level API on branch
`feature/player_user_api` (`{web_ui_path}/api/v1/me/*`, docs/src/player-api.md there) after our
request. The owner's VPS runs a local build of that branch since 2026-11-23 (rollback steps in
the owner's private VPS notes). Branch `claude/tuliprox-user-api` (worktree
`VesperTV-claude-tpxuser`, from main 1e0d09d), test APK +971.

## What VesperTV does with it

All in `lib/services/tuliprox.dart` (`Tuliprox` singleton, `TuliproxApi`).

1. **Player sign-in per playlist.** The playlist's own Xtream user + password come from the
   stream URL (`tuliproxChannelRef`, `…/live/{user}/{pass}/{id}`): `playerLogin` signs that user
   in at `POST {base}/auth/token` (Tuliprox accepts it when `player_features.api_enabled` is on
   for the user). Kept 20 min in memory, never saved, never logged; a refusal is not retried for
   10 min. When the saved Settings > Tuliprox login IS that user, it is used as is. Still needs the
   server address from Settings > Tuliprox (the Web UI path cannot be discovered from a stream
   URL yet: asked the dev for it).
2. **Sources for normal users.** `groupFor` asks the player routes first (`_playerGroup`): own
   streams `GET /me/streams`, the one of this channel (`TuliproxOwnStream.isOf`: virtual id, group
   virtual id or member vid), then `GET /me/streams/{uid}/failover-members` (health = quality
   label `1080p · H.264 · 5.5 Mbit/s`, failing members say "Not working right now"). Rows name no
   input ("Tuliprox · Source 2"): the player routes don't expose input names. A pick switches with
   `POST /me/streams/{uid}/failover-switch`; refusals get words (`tuliproxRefusalText`: 409
   shared stream = "Someone else is watching…", switch in progress, 429 cooldown, 502 = "That
   source didn't start. Still on the one before."). No player routes (old Tuliprox, feature off,
   403/404) = the admin routes as before.
3. **Drop the previous stream (uzumaki's request).** `noteStarted` (both players, after a live
   channel opens) finds this device's own stream 3 s later (`_ownStream`: the remembered uid, else
   the newest stream of the channel started since this device pressed play, minus 5 s: never
   another TV's older stream of the same channel). `release` = `DELETE /me/streams/{uid}`:
   - Android `PlaybackService._playChannel`: before opening the next channel (awaited, at most
     1.5 s, only when the URL changes), and `stop()` (not awaited).
   - Computer player `DesktopPlayerScreen._openMedia`: before the next channel only (closing the
     full-screen player may hand the stream to the mini player).
   - Zapping before the 3 s lookup: `release` looks the stream up itself.
   Log: `Tuliprox: own stream N for …`, `Tuliprox: released stream N (ended|already gone)`.
4. **Busy / refused (`X-Tuliprox-Fallback`).** Native: `StreamStats.fallback` keeps the header of
   the latest response (`onTransferStart`), StatsBridge returns it as `fallback`;
   `ExoPlayerEventListener.describeCause` appends `[Tuliprox <reason>]` to an HTTP error.
   Dart: a refused start (`_noteTuliproxRefusal`) or a busy video read 4 s after the start
   (`_checkTuliproxSlate`, Android only) calls `Tuliprox.noteFallback`: the reason in words
   (`tuliproxFallbackText`, all 8 documented reasons), and for
   `provider_connections_exhausted` / `user_connections_exhausted` the channels already playing
   that join for free (`GET /me/streams/joinable`, `requires_free_slot: false` only). The error
   screen (`friendlyPlaybackError`) and, for a busy video, a player message say it; Sources lists
   up to 12 of them right under the channel ("Tuliprox · Playing now on the server"), picked =
   a channel change (`Tuliprox.joinMark` rows, `playPickedLiveSource(playChannel:)`).

5. **No setup (Tuliprox e5704880, +973).** `XtreamApiService.authenticate` hands
   `server_info.player_api_path` to `Tuliprox.noteServer`: the host's Player API address is saved
   (`vesper_tuliprox_found`, `{host: base}`, no login, device-only) and `refOf` uses it when
   Settings > Tuliprox is empty or another server. No field = forgotten. The admin routes still need
   the Settings sign-in on that server.
6. **Exact stream uid (Android, +973).** Live MPEG-TS answers carry `X-Tuliprox-Stream-Uid`:
   `StreamStats.streamUid` -> StatsBridge `streamUid` -> `PlaybackService._readTuliproxHeaders`
   (1.5 s and 4 s after the start) -> `Tuliprox.noteOwnUid`; the 3 s `/me/streams` lookup is skipped
   then. Computers (mpv) and HLS keep the lookup.
7. **Source switch delay = Tuliprox's burst.** `shared_burst_buffer_mb` (default 12) is replayed to
   every new viewer of a shared live stream: ~21 s of HD, so the player sits ~21 s behind and a
   switched source shows that late (owner +971: 35 s). Set to 4 on the owner's VPS (2026-11-23). A
   reconnect after the switch does not help: a new connection is ranked again (health, quality,
   order), not the picked member.

8. **Messages roll down from the top (+974).** The busy message, "Changing source to…", "Source
   changed to…", refusals and "That source is already on the list." use `TopNotice.show`
   (`widgets/top_notice_overlay.dart`, mounted in main.dart next to the goal card: never takes focus or
   touches). The bottom snackbar covered the player bar's options row and the Sources list.
9. **Free joins for a full account** are a server setting: `player_features.free_shared_joins: true` +
   `max_free_shared_joins` (lab user on the owner's VPS since 2026-11-23). Without it, joinable streams
   say `requires_free_slot: true` when the account is full and VesperTV offers none.

10. **M3U playlists + reverse-proxy prefixes (Tuliprox 2bfb3991, +975, `claude/tuliprox-m3u-discovery`).** An M3U
    download reads `X-Tuliprox-Player-Api-Path` (response header) or `#EXTM3U x-tuliprox-player-api`
    (`M3uParser.fetchAndParse onPlayerApi` -> `M3uList.playerApi`, through the isolate and `M3uImport`) ->
    `Tuliprox.noteM3uServer` (server root = the list URL without `get.php` / `apiget` / `m3u` and query,
    `tuliproxServerRoot`; a list from a file uses a channel's stream URL). `noteServer` now keeps a server's path
    prefix (`https://host/tuliprox` + `/ui`), and `tuliproxChannelRef` reads M3U streams
    (`/m3u-stream/live/{u}/{p}/{id}.ts`, `/m3u-stream/{u}/{p}/{id}/live.m3u8`) and prefixed paths. Existing M3U
    playlists learn it at their next download (Update Content). `test/tuliprox_m3u_discovery_test.dart`.

## Not done / open

- The lab's grouping splits channels: `strip_regex` misses U+02B0 (the ʰ of ʰᵉᵛᶜ), and
  SPORT/SPORTS differ (`aliases`). Proposed to the owner, not applied (lab ids may change).
- The computer player can't read response headers (mpv), so no busy-video message there; refusals
  show mpv's own error.
- Events WebSocket (`/me/events`), watch progress, split: not used.
- Not box-tested yet (2026-11-23). The VPS lab user DM200lab has every player feature on.

## Tests

`test/tuliprox_player_routes_test.dart` (fake server answering like the branch: sign-in once,
player-route Sources, admin fallback, switch + refusal words, release after start, quick zap,
never an older stream, fallback reasons + joinable), `test/tuliprox_test.dart` (admin path),
native `StreamStatsTest.keepsTuliproxFallbackReasonOfTheLatestAnswer`.
