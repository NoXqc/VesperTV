# Trailers for IPTV and Media Hub — research, 2026-10-22 (Codex)

Research only. No trailer feature implemented or device playback tested.
The owner's earlier decision (CLAUDE.md, 1.0.28) remains: external YouTube
app/browser playback, hide unavailable actions, no YouTube stream extraction.
This investigation was requested for both IPTV Movies/TV Shows and Media Hub.

## Recommendation

Add a shared Trailer action to all three detail-page entry points:
`MovieDetailScreen` (IPTV), `ArchiveDetailScreen` (Hub movies), and
`SeriesDetailScreen` (IPTV + Hub shows). Prefer supplied trailer metadata,
then optional TMDB, then a strictly matched Cinemeta lookup where needed.
Open YouTube links in the installed app/browser. This needs no mandatory
YouTube or TMDB API key. Coverage is best effort, not every title.

This puts the Trailer button inside both VesperTV areas; YouTube playback
itself leaves VesperTV. Fully embedded playback is a separate option below.

## Discovery sources and coverage

| Source | How | Credentials / limitations |
| --- | --- | --- |
| Xtream IPTV | Retain optional `youtube_trailer` in movie/series info; normalize ID or URL | No new key. Provider coverage/field variations need fixtures. |
| Hub add-ons / Cinemeta | Preserve `trailers` and observed `trailerStreams` in `ArchiveMeta` | No new key. Supplied metadata wins; fields are optional. |
| Jellyfin / Emby | Preserve `RemoteTrailers`; later support local trailer items | Use existing server session. Local trailers can be genuine direct video. |
| TMDB fallback | `/movie/{id}/videos`, `/tv/{id}/videos`; IMDb-to-TMDB via `/find/{imdb}` if needed | Use the user's existing optional TMDB key, never bundle one. |
| IPTV/M3U without usable IDs | Clean title, search Cinemeta by type, require a unique strong title/year match, fetch meta | No key; localized names, remakes and ambiguous titles reduce coverage. |

Xtream's `youtube_trailer` is an ecosystem convention, not a guarantee for
every server. Linux Mint's Hypnotix consumes it for series in its
[Xtream implementation](https://github.com/linuxmint/hypnotix/blob/master/usr/lib/hypnotix/xtream.py).
Our code currently drops unknown movie/series info fields; no provider
credentials or private catalog were inspected during this research.

Stremio's [Meta Object documentation](https://stremio.github.io/stremio-addon-sdk/api/responses/meta.html)
defines optional YouTube-ID trailers and describes migration toward stream
objects. Support the old `{source,type}` form and `ytId` stream form, dedupe
IDs, and accept direct-video candidates only through a separate playback kind.
Do not reinterpret a movie's normal `/stream/` results as trailers.

TMDB documents [movie videos](https://developer.themoviedb.org/reference/movie-videos),
[series videos](https://developer.themoviedb.org/reference/tv-series-videos),
[external-ID lookup](https://developer.themoviedb.org/reference/find-by-id),
and [application authentication](https://developer.themoviedb.org/docs/authentication-application).
Prefer official Trailer entries, then teasers; app language first, English
fallback. Cinemeta samples do not provide an equivalent language guarantee.

[Jellyfin's SDK](https://typescript-sdk.jellyfin.org/interfaces/generated-client.BaseItemDto.html)
exposes RemoteTrailers and LocalTrailerCount.
[Emby's API documentation](https://dev.emby.media/doc/restapi/Item-Information.html)
describes RemoteTrailers and `/Users/{UserId}/Items/{Id}/LocalTrailers`.
Remote links may still be YouTube webpages, not native-player video URLs.

## Public endpoint checks performed

Live unauthenticated GETs to the existing Cinemeta service on 2026-10-22:

| Type / IMDb | Title | `trailers` / `trailerStreams` entries |
| --- | --- | --- |
| movie / tt0816692 | Interstellar | 5 / 5 |
| movie / tt0111161 | The Shawshank Redemption | 2 / 2 |
| series / tt0903747 | Breaking Bad | 1 / 1 |
| series / tt0944947 | Game of Thrones | 2 / 2 |

Endpoints: `https://v3-cinemeta.strem.io/meta/{movie|series}/{imdb}.json`.
Both forms provided matching YouTube IDs in these four samples. Public
`/catalog/movie/top/search=Interstellar.json` and
`/catalog/series/top/search=Breaking%20Bad.json` also returned the expected
IMDb IDs and release years. This proves metadata availability for these
samples, not global coverage, official-upload status or playable videos.
No video was launched, embedded, downloaded or extracted.

## Playback options

| Option | Feasibility / recommendation |
| --- | --- |
| Open YouTube app/browser | Recommended first version; existing url_launcher dependency supports external launch. TV handler availability must be device-tested. |
| Official YouTube iframe inside VesperTV | Technically supported by YouTube, but requires a WebView surface and TV/Windows integration. Conflicts with the earlier external-only project choice unless the owner changes it. |
| Direct trailer file from source/server | Can use native playback if genuinely direct; needs an isolated trailer playback flow to avoid marking the film/show watched. |
| Extract YouTube URL into ExoPlayer/mpv | Excluded by the existing project decision. A YouTube watch URL is not a direct video file. |

The [official iframe API](https://developers.google.com/youtube/iframe_api_reference)
reports removed/private videos, embedding-disabled videos, and error 153
for missing Referer/client identity. Google's
[embedding requirements](https://developers.google.com/youtube/terms/required-minimum-functionality)
explain supported WebViews and application Referer identification. This means
embedding is possible; it is not equivalent to passing a URL to our native
player. A spike must verify D-pad controls, fullscreen, Back, focus return,
Fire OS WebView behaviour, and Windows WebView/runtime support. Do not promise
the embedded route works on our boxes until tested. An external fallback
would still be needed for unembeddable videos.

Android manifest currently queries only PROCESS_TEXT. Before using capability
checks to hide unavailable Trailer actions, add appropriate VIEW/YouTube/HTTPS
visibility declarations. The Flutter team's
[url_launcher documentation](https://pub.dev/packages/url_launcher)
warns that canLaunchUrl can falsely return false without Android 11+ queries,
and actual launches can still fail. Handle failure and restore the same detail
page/focus. Do not hardcode one YouTube package or assume a TV has a browser.

## Implementation outline

1. Shared TrailerCandidate/TrailerService: source, title/type, language if
   known, validated YouTube ID or explicit direct-video URL. Reject malformed
   IDs, unsupported URI schemes and duplicate candidates.
2. Retain provider trailer fields in VodDetails/SeriesDetails and ArchiveMeta
   (including toJson/fromJson for Hub caches). Preserve media-server trailer
   metadata through the existing fetchMeta/series adaptation.
3. Resolve on detail-page entry only; never scan or enrich the whole catalog.
   Cache lookups by type/ID/language with bounded positive/negative TTLs.
   Reuse public metadata already fetched before making a fallback request.
4. Expose a trailer loader/action hook on SeriesDetailScreen so Hub shows use
   their source metadata, rather than the synthetic XtreamSeries with id 0.
   Wire matching DetailPillButton actions on both movie detail screens.
5. Reuse cleanDisplayTitle and extract year before cleanup. Existing subtitle
   helper `_searchImdb` falls back to the first search result; do not copy that
   fallback for automatic trailer selection. No confident identity = no guessed
   trailer. For series use series-level trailers first, not later-season spoilers.
6. Keep trailer playback out of history, resume, watched marks, tracker
   scrobbling, Ready-watch, recording and episode auto-advance. Do not call
   `playArchiveTitle` to play a trailer. Pause/park any background stream, and
   test both Android PlaybackService and Windows DesktopMiniPlayer return paths.
7. Hide action when there is no candidate or supported handler; user initiates
   playback, no automatic previews. Add translated strings in FR/ES/IT/EL and
   remote-tip docs for the final implemented action.

## Suggested delivery and validation

- First cut: shared metadata discovery + external Trailer button for IPTV and
  Hub movies/shows; optional TMDB, keyless Cinemeta fallback. Small/moderate
  change; no patched player or VPS changes needed.
- Separate follow-up: genuine local/direct media-server trailers in an isolated
  native-player route. Embedded YouTube only after an explicit product decision
  and successful platform spike.
- Parser/matching unit tests: both Stremio shapes, provider URL/ID variants,
  bad/missing entries, ambiguity/remakes/year mismatch, movie vs series,
  language ranking, request deduplication/cache expiry and failed lookups.
- Device round: Fire Stick, phone, owner-operated Formuler and Windows; with
  and without a handler, failed/removed video, return to same focus, no audio
  overlap, no watched/history/scrobble changes. No device tests performed here.
