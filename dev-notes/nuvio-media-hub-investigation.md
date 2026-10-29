# Nuvio TV comparison and Media Hub improvement plan

Research date: 2026-10-29. This document records the original investigation.
The subsequent implementation is documented in [Media Hub experience update](media-hub-experience.md).

VesperTV revision: `84256c113f6fc0e6788cd9b1693ad2e91cf33db6`.
Nuvio development revision: `d14832e1c477cca2b5613b893e590fd5fcab83ee` (`dev`).
Nuvio latest stable release at research time: [1.0.0](https://github.com/NuvioMedia/NuvioTV/releases/tag/1.0.0), revision `9f17e8bf4abc799dc8c832d2894a8b3b166e4353`, published September 19, 2026.

This is a source review, not a device benchmark or hands-on review of their APK.
The feature descriptions below refer to the pinned development source. Several
corresponding files also exist in stable, but their existence alone does not
establish identical stable behavior.

## What matters most

Media Hub already has substantial functionality. The strongest opportunity is to
make discovering a title, choosing a suitable stream, and continuing a series
feel like one coherent experience. Start with source selection and playback
compatibility, then improve the library and discovery presentation.

## What Nuvio does

### Source searches produce usable results progressively

Nuvio launches supported add-on requests concurrently, merges results as they
arrive, and publishes successive result snapshots. Its stream screen has source
filters and per-source status chips. A slow source can keep loading while results
from another are available. Completed searches have an in-memory cache keyed by
profile, title/episode, and source configuration; the inspected default TTL is
15 minutes. That is a reference behavior, not a recommended universal expiry for
VesperTV links.

Sources: [stream repository](https://github.com/NuvioMedia/NuvioTV/blob/d14832e1c477cca2b5613b893e590fd5fcab83ee/app/src/main/java/com/nuvio/tv/data/repository/StreamRepositoryImpl.kt),
[search session cache](https://github.com/NuvioMedia/NuvioTV/blob/d14832e1c477cca2b5613b893e590fd5fcab83ee/app/src/main/java/com/nuvio/tv/data/repository/StreamSearchSessionCache.kt),
[stream screen state](https://github.com/NuvioMedia/NuvioTV/blob/d14832e1c477cca2b5613b893e590fd5fcab83ee/app/src/main/java/com/nuvio/tv/ui/screens/stream/StreamScreenUiState.kt).

### Playback selection has more context

Nuvio supports manual selection, first-playable selection, and regex-based
autoplay, with source preferences. Episode selection can reuse the add-on's
`behaviorHints.bingeGroup`, keeping a series on the same release group when
available. Its stream model retains request headers, subtitle lists, file
information, and debrid state. Direct debrid resolution has separate implementations
for Real-Debrid, TorBox, and Premiumize.

Sources: [autoplay selector](https://github.com/NuvioMedia/NuvioTV/blob/d14832e1c477cca2b5613b893e590fd5fcab83ee/app/src/main/java/com/nuvio/tv/core/player/StreamAutoPlaySelector.kt),
[stream model](https://github.com/NuvioMedia/NuvioTV/blob/d14832e1c477cca2b5613b893e590fd5fcab83ee/app/src/main/java/com/nuvio/tv/domain/model/Stream.kt),
[direct debrid resolver](https://github.com/NuvioMedia/NuvioTV/blob/d14832e1c477cca2b5613b893e590fd5fcab83ee/app/src/main/java/com/nuvio/tv/core/debrid/DirectDebridResolver.kt).

### Discovery extends beyond the first detail page

Nuvio provides collection and similar-title sections with selectable cards. Its
home catalog pipeline supports custom titles, disabled rows, and ordering, while
its catalog editor supports moving rows and toggling their visibility. Search
includes debouncing, cancellation, suggestions, and explicit search generations.
These are useful patterns for a remote-controlled interface with many catalogs.

Sources: [collections](https://github.com/NuvioMedia/NuvioTV/blob/d14832e1c477cca2b5613b893e590fd5fcab83ee/app/src/main/java/com/nuvio/tv/ui/screens/detail/CollectionSection.kt),
[similar titles](https://github.com/NuvioMedia/NuvioTV/blob/d14832e1c477cca2b5613b893e590fd5fcab83ee/app/src/main/java/com/nuvio/tv/ui/screens/detail/MoreLikeThisSection.kt),
[catalog ordering](https://github.com/NuvioMedia/NuvioTV/blob/d14832e1c477cca2b5613b893e590fd5fcab83ee/app/src/main/java/com/nuvio/tv/ui/screens/addon/CatalogOrderViewModel.kt),
[search](https://github.com/NuvioMedia/NuvioTV/blob/d14832e1c477cca2b5613b893e590fd5fcab83ee/app/src/main/java/com/nuvio/tv/ui/screens/search/SearchViewModel.kt).

### Continuing a series is a dedicated part of the home experience

Nuvio explicitly reconciles in-progress titles and next-up episodes, excludes
dismissed next-up entries, protects against stale concurrent enrichment, and
separates upcoming items. This is a stronger model than treating all recently
opened titles alike.

Source: [Continue Watching/Next Up reconciliation](https://github.com/NuvioMedia/NuvioTV/blob/d14832e1c477cca2b5613b893e590fd5fcab83ee/app/src/main/java/com/nuvio/tv/ui/screens/home/ContinueWatchingNextUpReconciliation.kt).

## What VesperTV already has

Do not scope these as new features:

- Stremio-style add-on manifests, catalogs, metadata, stream lookup, and import.
- Jellyfin and Emby libraries; Trakt and Simkl connections, lists, scrobbling,
  and imported watched/resume state.
- Artwork, hero presentation, trailers, cast-name presentation, favorites,
  watched state, resume/restart, episode queues, and next-episode playback.
- A shared Home Continue Watching row that includes Media Hub items, plus Media
  Hub Recently watched rows. Episode detail pages already use resume/Next Up logic.
- Cache-first catalogs, lazy poster rows, catalog expansion, genre/Newest
  filtering, search history, phone-based setup, and a recently refined source grid.
- Switching sources during playback and identifying debrid download placeholders.

Relevant implementation: `lib/screens/archive_screen.dart`,
`lib/screens/archive_detail_screen.dart`, `lib/screens/series_detail_screen.dart`,
`lib/screens/home_screen.dart`, `lib/screens/archive_playback.dart`,
`lib/services/archive_service.dart`, `lib/services/tracker_sync.dart`, and
`dev-notes/mediahub-source-grid.md`.

## Verified gaps and recommended changes

| Priority | Improvement | User-visible result | Relative scope |
| --- | --- | --- | --- |
| 1 | Progressive source picker | Open immediately; play a returned result while other add-ons finish. | Medium |
| 2 | Clearer stream cards and playback preferences | Choose by readable quality/language/size information; retain a suitable release for the next episode. | Medium–large |
| 3 | Better Continue Watching and Up Next | Resume the exact episode or play the next available unwatched episode from a useful home card. | Large |
| 4 | Personalize Media Hub rows | Pin, move, hide, and rename catalog rows without disabling their stream provider. | Medium |
| 5 | Richer detail pages | Explore a collection, related titles, and cast credits from the title already open. | Medium–large |
| 6 | Faster discovery with useful source status | Search results arrive progressively; one failed catalog does not obscure working sources. | Medium–large |

### 1. Progressive source picker

`ArchiveService.streams()` currently loops through sources with `await ask(...)`
and returns one final list. `playArchiveTitle()` waits for that list before
opening `pickArchiveStream()`. The HTTP timeout is 20 seconds per request, so
multiple slow sources can add substantial delay. This is a code observation;
actual latency has not been benchmarked.

Use a request session with bounded concurrency, incremental results, source
states, and retry for one failed source. Preserve source ordering and stable
focused-card identity as replies arrive. Drop stale updates after the user
changes titles or profiles. Cache briefly using profile, canonical title/episode,
and source configuration; refresh expired or failed links.

Acceptance: with a fast add-on, a delayed add-on, and a failing add-on, the fast
result is selectable before the delayed request completes. Late replies never
move focus or replace the selected stream. Only the chosen video is opened;
parallel metadata lookup must not become parallel media playback.

Primary files: `lib/services/archive_service.dart`,
`lib/screens/archive_playback.dart`, `lib/services/archive_playback_sources.dart`,
`lib/widgets/archive_source_drawer.dart`.

### 2. Clearer stream cards and preferences

The current picker largely shows add-on-provided name/title text. Existing
selection includes an Auto Largest option and source/name preference for the
next episode. Extend this with simple profile preferences: preferred language,
maximum quality, preferred source, and supported playback formats. Show useful
badges only when the source provides reliable information; leave unknown values
unknown. Keep manual source choice accessible.

First improve compatibility: `ArchiveStream.fromJson()` currently retains only
the first supplied subtitle URL and drops `bingeGroup` and request-header hints.
Preserve complete subtitle metadata and route applicable headers through
resolution and playback. Scope headers to their intended requests and origins.
Use `bingeGroup` before the existing source/name heuristic for episode continuity;
return to the picker when no acceptable match exists.

The [official Stremio stream schema](https://github.com/Stremio/stremio-addon-sdk/blob/master/docs/api/responses/stream.md)
documents these fields. Do not promise all add-ons work merely because their
manifest imports successfully. Raw torrent entries remain outside current
Vesper playback support.

Acceptance: retain language-specific subtitle choices, play a test source that
requires headers, and preserve release-group preference across two episodes
without silently choosing an incompatible alternative.

Primary files: `lib/models/archive_models.dart`,
`lib/screens/archive_playback.dart`, `lib/services/archive_resume_source.dart`,
plus the selected player and subtitle integration paths.

### 3. Continue Watching and Up Next

Improve the existing feature rather than adding another history row. Show the
episode number/title, progress, and a clear Resume or Next episode action in
Media Hub. Keep unaired episodes separate from playable next episodes.

Current history/favorite entries include the source URL, and playback IDs
include the source key. A title supplied by two catalogs can therefore have
separate local identities. Add canonical identity where IMDb/TMDB mapping is
reliable, retaining the selected source as playback provenance. Preserve
namespaced identities for custom add-on IDs and server items with no safe match.
Keep watch state scoped to the active profile and migrate existing history.

Acceptance: watching through one catalog and reopening the same mapped title
through another preserves progress. Finishing an episode produces the next
available episode; changing profiles exposes only the correct profile's state.

Primary files: `lib/services/archive_service.dart`,
`lib/screens/home_screen.dart`, `lib/screens/archive_screen.dart`,
`lib/services/tracker_sync.dart`, `lib/services/watch_tracker.dart`.

### 4–6. Personalization, richer details, and discovery

- Extend the existing row hold menu, which currently offers Expand catalog and
  Go to row, with Move, Pin, Hide row, and Rename. Row visibility must be
  independent of whether its add-on remains available for playback.
- Add collections/franchises and similar titles after the existing detail
  content. Turn cast information into selectable credits when metadata supports
  it. Load these sections after the primary title content, and preserve the
  exact originating card when navigating Back. They need metadata integration;
  a new widget alone will not supply the data.
- Retain existing normalized search, cached results, and search history. Add
  progressive results across catalogs, bounded parallel requests, cancellation,
  and clear source filters. Current search parallelizes query variants inside a
  catalog but still walks catalog groups sequentially and returns a final list.
- Refresh visible catalog rows first. Current cache-first refresh publishes
  completed rows progressively, but walks catalogs sequentially. Add a small
  concurrency limit and request generations rather than unbounded prefetch.
- Show source-specific failures with retry and useful empty states: no sources,
  catalog unavailable, no results, or no compatible stream. Keep provider URLs
  and credentials out of diagnostics shown to users.

## Suggested delivery order

1. Source-selection update: progressive results, stable D-pad focus, per-source
   status, complete subtitle/header handling, and release-group continuity.
2. Library update: canonical identity migration, better existing Continue
   Watching/Up Next cards, and row personalization.
3. Discovery update: collections/related titles/cast credits and progressive
   search with catalog scheduling improvements.

Direct debrid resolution is a separate optional project. Vesper's current
`debrid_api.dart` checks readiness in the user's Real-Debrid/TorBox account;
it does not implement Nuvio's direct resolver. Whether to add that capability
should be decided separately from improving the existing add-on experience.
Likewise, native torrent playback, extension execution, and account-backed
profile sync introduce separate playback/backend scope.

Keep Vesper's Flutter architecture, existing source setup, IPTV integration,
and visual identity. Nuvio's Kotlin/Compose implementation offers useful behavior
patterns; it is not a drop-in component for this app. Measure first-usable-result
time and check focus restoration on the Formuler and Fire Stick during any
implementation. This investigation made no APK, device, release, or Windows changes.
