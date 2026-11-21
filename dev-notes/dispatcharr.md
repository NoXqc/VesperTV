# Dispatcharr API (2026-11-18, `claude/dispatcharr`, test +834)

AMD (Discord, 2026-11-17): the live Sources drawer (+813..+817) lists copies that exist as
separate channels, but Dispatcharr merges a channel's streams into ONE channel on the server:
its M3U / Xtream output has a single URL per channel and it switches sources behind it. The
other streams are only visible through its REST API.

## What it does
- **Settings > Playlists & sources > Dispatcharr** (`screens/settings/dispatcharr_screen.dart`):
  server address + user name + password, Connect. Shows "Connected to … as …", the Dispatcharr
  version, which playlists load from that server (same host / port), **Add as a playlist** (opens
  Add Playlist filled in: Xtream with the user's Dispatcharr XC password, else
  `/output/m3u` + `/output/epg`; `AddPlaylistScreen.prefill`) and Disconnect.
- **Connect adds the playlist itself (+888, 2026-11-19):** roman (LOG-G67D3G, iOS build on a
  Mac) connected and saw "no playlist/content/groups": Add as a playlist was a second step nobody
  expected. Now, when no playlist loads from that server yet, Connect opens Add Playlist with
  `autoSave: true`: it saves at once (same Xtream login check, rollback on failure, "Download
  content" question, guide refresh, back to the first page). A refused login leaves the form open
  with the error; Back = the Dispatcharr page with Add as a playlist (fills in, no auto-save).
  A server that already has a playlist (same host / port) adds nothing. Disconnect keeps the
  playlist. Send log: `Dispatcharr: adding its playlist (Xtream|M3U)`; the connect line says
  `xcLogin=yes/no` (it was `XC password=…`, which the log's redaction blanked).
- **Player > Sources** (`player_screen.dart _openLiveSources`): on a channel of that server, after
  the usual sources, one row per Dispatcharr stream: stream name, `Dispatcharr · <M3U account>`
  (account names only for admins: `/api/m3u/accounts/` is admin-only), and what Dispatcharr
  measured (`1080p · H.264 · 30 fps`, from `stream_stats`, null until Dispatcharr played it once).
  OK plays `/proxy/ts/stream/{stream_hash}`: Dispatcharr's own stream preview, **for this viewer
  only** (`change_stream` would switch the channel for everyone and is admin-only: not used).
  The drawer waits at most 4 s for the server; no answer = it opens without those rows.
- Android only (Windows has no live Sources drawer).

## Sign-in and what is stored
- `POST /api/accounts/token/` (JWT) once, then `GET /api/accounts/api-keys/`: **a user has ONE
  API key and `generate` replaces it**, so an existing key is reused and a new one is made only
  when there is none. Only `{server, apiKey, username}` is saved (`vesper_dispatcharr`,
  goes with Transfer, sync and backups (owner 2026-11-20); a backup or transfer without it keeps the
  device's own). Never the password.
- Afterwards every call sends `X-API-Key`. Bad key = 401 -> "refused the saved sign-in".
- Dispatcharr throttles sign-ins: a few quick tries give **HTTP 429** ("Too many tries. Wait a
  minute").

## Matching a playlist channel to Dispatcharr (`dispatcharrChannelRef`)
Same host (case-insensitive) and port (scheme may differ: an https proxy in front), then:
- Xtream `…/live/{user}/{pass}/{id}[.ts|.m3u8]` -> channel id (Dispatcharr's XC `stream_id` IS
  the channel id);
- M3U `…/proxy/ts/stream/{uuid}` -> `POST /api/channels/channels/by-uuids/` (cached per run).
A playlist added through a different hostname than the one signed in (LAN IP vs domain) won't
match: the Settings page lists "Playlists on this server" so that shows.

## Endpoints used (Dispatcharr 0.34.1)
`/api/core/version/` (no login), `/api/accounts/token/`, `/api/accounts/api-keys/` (+`generate/`),
`/api/accounts/users/me/` (`custom_properties.xc_password`, `user_level` 10 = admin),
`/api/channels/channels/by-uuids/`, `/api/channels/channels/{id}/streams/` (ordered as the channel
uses them), `/api/m3u/accounts/`, `/proxy/ts/stream/{hash}`.

## Tests
`test/dispatcharr_test.dart` (URL matching, sign-in reuses / makes the key, 401, not-Dispatcharr,
streams + caching + timeout; fixtures recorded from a real 0.34.1) and
`test/dispatcharr_screen_test.dart` (sign in, linked playlist, Add as a playlist prefill Xtream /
M3U, wrong password, drawer row). Live-checked against a throwaway Dispatcharr in Docker on the PC
(`vespertv-dispatcharr-test`, port 9191, public iptv-org lists, test channel 2 "VesperTV test (4
streams)"): both the Xtream and M3U paths list the 4 streams, a stream plays through the proxy.

## Box test
The Homatics (10.0.0.64) can't reach the PC (192.168.1.224): `adb reverse tcp:9191 tcp:9191`, then
address `127.0.0.1:9191` on the box.

## Not done
- ~~No server-side "switch for everyone" (admin `change_stream`).~~ Done +865, see below.
- No Dispatcharr Multiview plugin control (layouts are server-side; no client API).
- Windows / iOS players.

## +835 (2026-11-18, owner tested +834 against the test server: "Your test channel works")
- The Dispatcharr row is the LAST row of Playlists & sources (owner: few users run one).
- **From phone** beside Connect: `PairingKind.dispatcharr` (pair.html `#dispatcharr` = the
  Jellyfin form worded for Dispatcharr, same `{"mode":"server"}` payload, Wi-Fi only, no relay
  change).
- An account with no XC password shows an amber note: Add as a playlist would be M3U; give the
  user an XC password in Dispatcharr (Users > Edit) for an Xtream playlist (owner wants Xtream:
  M3U playlists were the unstable ones). Movies and shows: Dispatcharr's XC output has
  get_vod_streams / get_series (its VOD module, from Xtream-type provider accounts, per-user
  `vod_movies_enabled` / `vod_series_enabled`), so they come in through the Xtream playlist like any
  provider. The Sources drawer part is live only.
- Every floating Settings panel (this one, Jellyfin, Stream badges, Trakt...) drew a live
  BackdropFilter: 30-60 ms frames on the Homatics while a field's cursor blinked (logcat
  `Frames:` avgRaster 54-60 ms, builds 3-51 ms). `openSettingsPage` now takes a `GlassFrost`
  capture and `GlassPanel(blur: true)` paints it (+ the barrier dim). Test: no BackdropFilter
  under `SettingsFloating` (settings_categories_test).
- **API key instead of a password** (owner: "aren't they supposed to add their API key?"): an
  "Or your API key" field under the password; filled = `DispatcharrApi.withKey` (version check +
  users/me with `X-API-Key`), no token call, no password. Refused = "Dispatcharr refused this API
  key." The phone form (#dispatcharr) has the same field and sends `key` (`PairingResult.apiKey`;
  'server' accepts a key without a user name).

## +836 (2026-11-18, AMD's real server on a public https domain)
- AMD connected with his API key (Dispatcharr 0.34.0) but the user name + password said "Couldn't
  find a Dispatcharr server": `/api/accounts/token/` answers **403** when the server's network
  rules don't allow the web login ("UI" network access) from where the box comes in; API keys aren't
  under that rule. Now: token 403 -> `DispatcharrNetworkException` ("…only allows the password sign-in
  from some networks. Use your API key instead."), `/api/core/version/` failing -> `DispatcharrNotFound
  Exception` (the only "Couldn't find"), anything else -> "refused the sign-in (HTTP n)".
- **Correction after AMD's LOG-DJ39QW + his server log:** Dispatcharr logged "Login success" for
  aeriotv, so the 403 is the NEXT step, `/api/accounts/api-keys/` with the JWT. Dispatcharr's own
  check can't explain it (same `Authenticated` + per-user network rule passed on users/me with his key;
  a missing token gives 401), so most likely his reverse proxy in front of stream-api.blackbriar.tech
  blocks that path or the Bearer header. Now `DispatcharrKeyLookupException`: "Your password works,
  but your server refused to hand over your API key (HTTP n). Paste your API key instead." A refused
  lookup never falls through to `generate` (that would replace his key). Sign-in tokens live 30 min /
  refresh 1 day (SIMPLE_JWT), so the API key stays the thing to keep. Send log lines: `Dispatcharr:
  signed in to <host>` at start, `connected to <host> (API key|password), admin, XC password, playlists
  on it`, `password accepted, asking for the API key`, step + HTTP code on failures, and `"<channel>"
  plays from <host>, not <host>: no streams listed` (hosts only, never paths or keys).
- AMD's view: Dispatcharr should be a **playlist type** (API key, no XC password: he says XC isn't
  recommended for API users). Pending owner decision: full API playlist type vs relabel first.
- **Live Sources picks never switched (since +813, so also in 1.0.69):** owner photo, TVA Montreal,
  Blcktv -> AA TREX: log `source picked` then nothing. `playLiveSource` plays the same channel id with
  the source URL and `_playChannel`'s same-channel guard returned (only Media Hub ids were exempt).
  Now `play(..., switchSource: true)` from `playLiveSource`; the guide's OK on the playing channel is
  still a no-op. `test/live_source_switch_test.dart` (fails on the old code). Dispatcharr streams go
  through the same path, so +834/+835 only listed them.
- **Sources didn't offer the Trex copy** (`QC: TVA MONTREAL` vs `CA| TVA MONTREAL HD`, owner added it
  by hand): `channelCopyKey` keeps the region tag. Now one country = one tag (`_sameRegion`: QC/QUEBEC/
  CAFR/FRCA/CAEN = CA, USA = US, GB = UK; US vs CA stay apart) and accents don't count (`MONTRÉAL` =
  `MONTREAL`, `_plainUpper`). `channelCopyMayMatch` keeps accented names past the probe pre-filter
  (300k channels still ~48 ms). Also applies to Combine playlists, Multiview copies and Sports copies.
  `test/channel_copy_region_test.dart`.

## +865 (2026-11-18): same format + Dispatcharr switches the channel (clayts450)
clayts450 tested three settings pairs: a picked stream played in **Dispatcharr's** default format while the
channel played in **VesperTV's** (the Xtream link's `.ts` / `.m3u8` forces the format in `stream_xc`; the
preview link `/proxy/ts/stream/{hash}` had none), and a picked stream played **on its own** (Dispatcharr's
preview worker), so Dispatcharr's channel failover was off for it. His goal: Dispatcharr keeps control, same
format, a smooth "manual failover".
- **Format:** `dispatcharrOutputFormat(own.url)` (after `LiveStreamFormat.urlFor`) -> `?output_format=hls|mpegts|fmp4`
  on every Dispatcharr row (`_resolve_output_format` reads it; checked on the PC's server: hls = 302 to
  `/proxy/hls/{token}/index.m3u8`, mpegts = `video/mp2t`). Android's `_streamUsesHls` treats `output_format=hls`
  as HLS at once (before: a failed read, a sniff, a retry).
- **Admin = Dispatcharr switches:** `Dispatcharr.switchChannelTo` -> `POST /proxy/ts/change_stream/{channel uuid}`
  `{"stream_id"}` with `X-API-Key` (IsAdmin; DRF's ApiKeyAuthentication covers it). The player stays on the
  channel (no reconnect); a viewer on a preview goes back to the channel. **Switches the channel for everyone
  watching it on that server.** Checked on the PC's server: a 45 s curl of the channel kept receiving bytes
  through the switch, `/proxy/ts/status/{uuid}` then reported the new `stream_id`. Xtream refs need the uuid:
  `GET /api/channels/channels/{id}/` (cached). Admin = `users/me` `user_level >= 10`, asked once per sign-in.
  Not admin / refused / not playing on the server = the stream plays on its own, in the matched format.
- Sources marks the stream the channel plays now (`activeStreamOf`, admin, 2 s cap) when on the channel.
- Snack bar "Dispatcharr switched the channel to {stream}." (7 languages). Vesper AI `sources` play uses it too.
- **iOS / Windows / macOS / Linux:** `DesktopPlayerScreen` had no live Sources: `_openLiveSources` (same
  `liveSourceRows` + `playPickedLiveSource`), a Sources button in the computer bar (after Reload) and the
  iPhone top bar (live, no Media Hub sources). No "Add another source" row there. Not run on a device.
- Tests: `test/dispatcharr_switch_test.dart` (format rule, admin / non-admin / refused switch, active stream,
  pick helper). Analyze 16, 2139 tests.
