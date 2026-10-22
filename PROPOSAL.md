# Proposal for Claude Code: trailers in IPTV and Media Hub

Written by Codex · 2026-10-22 · branch `codex/trailer-research`.

## Goal and scope

Add a **Trailer** action beside Play on movie and TV show detail pages in
both the IPTV catalog and Media Hub. Use one discovery/launch service so all
entry points behave consistently on Android TV, Fire TV, phones and Windows.

This is an implementation proposal, not an implemented feature or an instruction
to release. Read `AGENTS.md` and all of `CLAUDE.md` before starting. Research,
public endpoint results and primary-source references are in
[`dev-notes/trailers-research.md`](dev-notes/trailers-research.md).

## Recommended first version

- Put the Trailer action inside VesperTV; play YouTube trailers in the installed
  YouTube app or browser. This follows the owner's earlier external-only choice.
- Use source-provided trailer metadata first, optional TMDB lookup second, then
  a strict Cinemeta identity lookup where needed. No mandatory API key.
- Hide the action when no suitable trailer or supported handler exists. Handle
  launch failure without leaving a broken page or losing focus.
- Resolve on detail-page entry, not during startup or for every catalog poster.
- No automatic previews, embedded WebView, YouTube stream extraction, patched
  player changes or VPS changes in this first version.

Fully embedded YouTube playback is technically possible through the official
iframe player, but needs a separate owner decision and platform prototype.
Genuine direct/local server trailers also need a separate native playback flow;
do not silently route either case through normal movie/episode playback.

## 1. Shared trailer discovery

Introduce a small `TrailerCandidate` model and `TrailerService` (names flexible).
A candidate should carry its source, label, validated YouTube video ID or
explicit playback kind, and language/type/official status when supplied.

Normalize and deduplicate these inputs:

- Xtream: optional `youtube_trailer` in movie/series metadata, accepting a bare
  video ID or recognized YouTube URL. Provider formats are not guaranteed;
  verify with redacted fixtures, never log account URLs or credentials.
- Media Hub: legacy `trailers: [{source, type}]` and stream-shaped YouTube
  candidates such as `trailerStreams: [{ytId, title}]`. Keep missing fields valid.
- Jellyfin/Emby: `RemoteTrailers`; YouTube entries can use the same external
  route. Classify local/direct trailers separately for later support.
- TMDB, only with the user's configured key: movie/series `/videos` endpoints.
  Prefer existing TMDB IDs; resolve a known IMDb ID through `/find` if needed.
  Prefer official Trailers, then teasers, app language then English.
- Cinemeta: use a known IMDb ID directly; otherwise search by media type and
  cleaned title/year, require an unambiguous strong match, then fetch its meta.
  Localized names/remakes may have no confident match; do not guess.

Reuse `cleanDisplayTitle`, extracting the year before stripping decorations.
The subtitle helper `AddonService._searchImdb` falls back to the first search
result: **do not reuse that fallback for automatic trailer selection**.
Keep external metadata lookups to title/type/IDs, never provider credentials.

Cache by media type, stable identity and requested language, with bounded cache
size, timeouts, request deduplication and positive/negative expiry. Reuse full
metadata already loaded. Do not block Play or the rest of the detail page.

## 2. Preserve metadata through existing adapters

| Location | Change |
| --- | --- |
| `lib/models/vod_details.dart`, `series_details.dart` | Optional provider trailer candidates. |
| `lib/services/xtream_api_service.dart` | Parse supplied trailer metadata without new per-poster API requests. |
| `lib/models/archive_models.dart` (`ArchiveMeta`) | Parse and serialize trailer candidates, preserving old caches without the field. |
| `lib/services/media_server_api.dart` | Preserve remote trailer metadata from full items. |
| `lib/screens/archive_playback.dart` | Pass real Hub source/meta trailer loading through the series adapter. |

Media Hub shows are adapted to a synthetic `XtreamSeries` with id 0. Add an
optional trailer loader/action hook to `SeriesDetailScreen`, like its existing
episode hooks, rather than querying Xtream using that synthetic identity.

## 3. Detail-page action and external launch

Add matching `DetailPillButton` actions to:

1. `MovieDetailScreen`: IPTV movies, including titles opened from Search/Expand.
2. `ArchiveDetailScreen`: Media Hub movies.
3. `SeriesDetailScreen`: IPTV series and Media Hub shows through the hook above.

Use `url_launcher`, already a dependency, through a shared launcher. Detect a
handler without assuming a particular YouTube package or a browser on every TV.
The Android manifest currently queries only PROCESS_TEXT: configure the required
VIEW/URL visibility before trusting capability checks on Android 11+.
An affirmative capability check does not guarantee launch success; handle both
false returns and exceptions, and return focus to the Trailer action if present.

Use existing D-pad/focus conventions. Keep new focus targets stable as async
metadata arrives; removing an unavailable/loading action must not strand focus.
If background playback is audible, pause/park it before launching externally;
test return behaviour independently for Android and Windows. Do not change
startup resume settings or resume the film/show automatically on return.

Every new displayed string uses `tr()` with matching placeholders in
`lib/l10n/fr.dart`, `es.dart`, `it.dart`, `el.dart`. Update `docs/remote.html`
for the final user-facing action. Avoid adding settings for the first version.

## 4. Playback state must stay separate

Watching a trailer must not create or modify title resume positions, watch
history, watched marks, Trakt/Simkl scrobbles, Ready-watch state, recordings or
episode auto-advance. Do not invoke `playArchiveTitle` or the normal episode
queue just to play a trailer. Provider/server direct-file support is deferred
until an isolated trailer route can meet these same requirements.

## 5. Validation and acceptance

- Parser tests: optional fields, both Stremio forms, provider URL/ID variants,
  invalid IDs/schemes, duplicates, and ArchiveMeta cache round trips.
- Resolver tests: known identity, movie vs series, title/year ambiguity,
  translated titles, language preference, no configured key, missing trailer,
  timeouts, cache expiry and concurrent request deduplication.
- UI/launcher tests where useful: each of the three pages, Hub series hook,
  absent handler, failed launch, async focus stability, returning from a detail
  page opened through Search/Expand, and no normal playback/tracker callbacks.
- Real devices: Fire Stick, phone, owner-operated Formuler Z11 and Windows;
  test available/unavailable YouTube/browser handlers, removed/unplayable
  videos, Back/return focus, background audio, and unchanged watch state.
- Preserve file line endings; format only changed Dart files; analyze must
  remain at 17 baseline infos and all tests must pass. Restore generated plugin
  files, commit on the task branch and update main-checkout `HANDOFF.md`.
- No version bump, APK build/install, merge, push or release without the
  owner's corresponding request. Do not drive the owner's Formuler over adb.

## Current evidence and limits

Four public Cinemeta samples returned trailer IDs: Interstellar, The Shawshank
Redemption, Breaking Bad and Game of Thrones. Two title searches returned the
expected IMDb IDs. This verifies metadata discovery only: not device playback,
global coverage, upload authenticity or localization quality.

Unmerged Codex work remains separate: `codex/fix-vod-favorites` (`2e0a834`) and
`codex/favorites-channel-order` (`2578427`). Do not overwrite or assume either
feature is already on main; both touch files involved in this proposal.
