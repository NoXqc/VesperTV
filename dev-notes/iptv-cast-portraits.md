# IPTV cast portraits (Codex, 2026-10-30)

IPTV MovieDetailScreen and SeriesDetailScreen reuse Media Hub's portrait cards,
actor names/roles, person credits screen and remote navigation when a TMDB key
is saved. Movie portraits sit below the cinematic header; shows keep episodes
above the cast section. Cast in the action row jumps directly to the section.
Down from movie actions/episodes enters it; Up returns to actions/episodes.
Back from a person restores the selected actor. Phone touch scrolling also works;
Up from a portrait phone show section returns to Play.

No key means no portrait panel or additional cast lookup: provider names/bubbles
retain their previous behavior. A failed lookup offers Try Again without blocking
Play or episodes. Missing images retain the existing poster placeholder. Existing
Media Hub discovery/order/customization continues through its original constructor.
The new IPTV constructor requests cast only and never needs an ArchiveService.

ArchiveDiscoveryService.castForTitle uses the provider's positive TMDB id first.
Otherwise it searches the clean title with a known/parenthesized/trailing year,
requires one exact normalized title/original-title and year match, and skips
ambiguous remakes or fuzzy matches. Numeric titles such as 1917 are not treated
as release years. This resolves only the opened title, not whole catalogs.
Responses use the existing key/language cache and at most12 actors. No provider
identity, source URL or stored catalog data is rewritten.

Actor movie/show credits load only on selection. Picking a credit searches up
to40 visible catalog matches plus cached visible items in enabled playlists.
Known TMDB ids must agree; otherwise exact title/known year is required. The
existing IPTV detail page opens, or a localized no-match message is shown. No
Media Hub source fallback, automatic playback or complete catalog download.
Request/viewer-generation checks discard stale cast and selected-title results.

Shared DetailPillButton labels can now wrap within available width; a Spanish/
Greek 1.4x phone layout exposed an existing overflow. Focus slots remain intact.
New no-match/metadata-attribution strings have FR/ES/IT/EL entries. Remote guide
and help index updated locally only; no publication or bot/VPS deployment.

Tests: iptv_cast_portraits_test.dart covers movie/show endpoint and image/role
mapping, no-key/default behavior, exact search/remake/numeric-title resolution,
metadata failure, movie/show TV/phone focus/return/scroll, actor credits and
bounded IPTV navigation, five languages at1.4x text, and stale-viewer requests.
Real TMDB account/provider artwork and physical-device checks still pending.
No version bump, installable APK, installation or upload; hosted530 predates this
and the updater storage guard. Next newly built APK must exceed530.

API references: https://developer.themoviedb.org/reference/movie-credits,
https://developer.themoviedb.org/reference/tv-series-credits (latest-season cast),
https://developer.themoviedb.org/reference/search-movie.
