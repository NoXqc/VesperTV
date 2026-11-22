# Silo media server (owner, 2026-11-21)

Discord (BallerMC): Silo (siloserver.org, github.com/Silo-Server, AGPL, Go server + Apple /
Android / Roku apps) can already be added as a Jellyfin server, "however direct integration
would be better". Owner: add it to the servers connector, every OS including iOS.

## Why the native API, not its Jellyfin port
Silo's Jellyfin compatibility runs on a **second listener** (port 8096 in Docker) whose address
the admin must set (Admin > Integrations > Compatibility; until then Silo shows
`http://127.0.0.1:8096`), and sign-in there is `username#Profile` + `password#PIN`. That path
already works through Connect Jellyfin / Emby. The native API (`/api/v2`) is on the address
people already use, signs in with a TV code and has real profiles, so "Connect Silo" uses it.
Owner (same day): "add it as a standalone not just through jellyfin": Settings > Media Hub sources
has its own **Connect Silo** row (beside Connect a media server = Jellyfin, Emby or Plex), and the
server screen lists it too.

## Flow (`lib/services/silo_api.dart`, `lib/screens/settings/silo_connect_screen.dart`)
1. Address -> `GET /api/v2/system/info` (public, `api_major: 2`); a pasted page path falls back
   to the origin. The address + this install's device id are kept in archive options
   `silo_client`.
2. TV code: `POST /auth/device/start` -> 8-digit `user_code` + QR of
   `verification_uri_complete` (`<server>/activate?code=…`), polled with `device_code` every
   `interval` s until `approved` (tokens + maybe `profile_id`/`profile_token`), `denied`,
   expired (15 min, extended by lookups). Leaving the screen cancels the code
   (`/auth/device/cancel`). Or a password (`POST /auth/login`).
3. Profile: `GET /profiles`; one profile without a PIN = automatic; a PIN profile ->
   `POST /profiles/{id}/verify-pin` -> `profile_token` (5 wrong PINs = 5-minute lock, never
   retried by the app). Every later request sends `X-Profile-Id` (+ `X-Profile-Token`).
4. Source: `ArchiveSource(manifestUrl: '<base>#<userId>:<profileId>', server:
   MediaServerLogin(kind: silo, token: access, refreshToken, profileId, profileName,
   profileToken))`, libraries = `GET /user/libraries` (movies / series only).

Tokens: access token 8 h; on a 401 `SiloApi._send` calls `POST /auth/refresh` once (deduped per
source), keeps the new pair in memory (`_fresh`) and `ArchiveService._keepServerLogin` saves it.
Checked on a real server: an older refresh token still works after a rotation, so a source
synced to a second device keeps working. A refused refresh = `MediaServerLoginException`
("connect the server again").

## Browse
`GET /catalog?library_id&type=movie|series&limit=100&seek=<skip>&skip_total=true&sort=-added_at`
(search: `q=`), image widths in the query (posters default to 300 px). Cards: `content_id`,
`title`, `year`, `imdb_id` (Trakt/Simkl + skip intro), `poster_url` / `backdrop_url` (TMDB or a
server path), `logo_url` is TMDB's SVG -> dropped. Title page `GET /catalog/items/{id}`
(`runtime` in minutes, `versions[]`); series `GET /catalog/series/{id}/seasons` then
`/seasons/{n}/episodes` (episodes with `files: []` = metadata only, left out).

## Play
A version is a placeholder link `<base>/api/v2/catalog/items/<item>#silo-file=<file_id>`
(`SiloApi.playLink`): stable for resume/history, never opened. `archive_playback._resolve` turns
it into a session: `GET /playback/capabilities` (`installation_id`, once per server) then
`POST /playback/start` (protocol v3, `quality_preference: original`, `allow_alternate_versions:
false`, `declared` evidence with every codec / container the players handle, deliveries
`original_http` + `hls` as the server's fallback, `form_factor` tv / mobile / desktop). The plan's
`stream.url` (`/api/v2/stream/<session>?st=<signed>`) needs no header: ranges work, 410 after the
stop. A resume never reuses a saved URL for Silo (`_isSilo`), the resume probe is skipped
(`archive_resume_source.dart`), downloads leave Silo files out (the link belongs to one play).

Sessions end after 5 min without activity (30 paused). `SiloSessions` (same file): both players
call `playing(url, sampler)` where they call `WatchTracker.started` (PlaybackService.play,
DesktopPlayerScreen init + `_switchTo`) and `stopped(url, position)` where they report the stop.
In between a 60 s heartbeat `POST /playback/{session}/progress` (`sequence`, position, paused)
also gives Silo the viewer's place (its Continue watching). A sampler answering null (player
gone) ends the play with the last position. A refused start (`adaptation_unavailable` +
`terminal.message`) is shown as "The server can't play this file: …".

## Tested
- `test/silo_api_test.dart` (13, MockClient).
- A real Silo (ghcr.io/silo-server/silo-server:latest, server 1bbc479c, Docker on the owner's PC,
  container `silo-test`, port 8090) from a throwaway test: code approved through the API, browse,
  search, seek, episodes, `original_http` start, 206 range, stop -> 410, a second play = a new
  session. Not run on a TV box or iPhone yet.

## Not done
Server watched state / resume in the app (Silo's own Continue watching gets our progress), Silo's
downloads API, subtitles served as sidecars, HLS fallback untested (needs a server bitrate limit),
an expired PIN-profile token (`profile_verification_required`) asks for a new sign-in.
