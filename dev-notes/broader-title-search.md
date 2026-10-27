# Broader global and Media Hub title search (cdx, 2026-10-27)

Owner example: `spiderman` should find Spider-Man / Spider Man movies. Global
search had literal substring matching in M3U/live rows and literal SQLite LIKE
for Xtream. Media Hub folded punctuation to spaces and then required a title
word prefix: Cinemeta returned Spider-Man titles which the app discarded.
It also discarded required-search catalogs while reading source manifests.

## Shared matching

`TitleSearch` in lib/utils/title_search.dart folds case, common Latin/Greek
accents, combining accents and ligatures, keeps Unicode letters/numbers and
ignores punctuation/spacing. All query words may match in any order. Direct
title prefixes and word prefixes rank ahead of broader substring matches.
No automatic spelling corrections or title-specific franchise dictionary.

Global Live TV/M3U movie/show filtering uses the same matcher. Xtream's full
SQLite catalog uses stored compact `search_name` keys, so matching stays native
and does not materialize a 100k-title library into Dart per keystroke. Schema9
adds/backfills that column in500-row batches, preserving rows/IDs/art/favourites.
New/upserted movie and series names write their keys with the real name.
SQL still scopes enabled playlist IDs; PlaylistManager still applies visibility.

## Media Hub retrieval

Each searchable catalog gets at most3 spelling variants, including the original
query. Punctuation/spacing variants share meaning; a long single joined word
also gets a4-character prefix discovery query. Full-query provider results may
match an alternate/translated title, so they remain after direct name matches.
Prefix-discovery results must match the original query locally: unrelated
Spiderwick results do not become spiderman matches. Replies retain request order
and deduplicate per source. Catalog groups remain sequential; at most3 variant
requests per catalog run together (global movies/shows can run concurrently).

On2026-10-27 public Cinemeta returned13 movie entries for spiderman,17 for
spider man and22 for spid; local matching previously rejected the hyphenated
names. These counts are observations, not a coverage promise. Searches remain
limited by configured sources, provider results/page sizes and stored cache.
Non-searchable sources can search cached rows even before opening the Hub tab.

Modern `extra: [{name: search, isRequired: true}]` and legacy search-required
catalogs are retained as `ArchiveCatalog.searchOnly`, used only for search.
Unsupported required extras remain excluded. Search-only custom sources still
offer Other so their search button is reachable. Global search excludes Other;
disabled sources and the Cinemeta visibility switch retain their meaning.

Older saved source definitions lack `searchCatalogsChecked`: first search
rechecks those manifests once, sharing concurrent movie/show requests and
persisting the upgrade. Failure preserves the saved definition/cache and avoids
retrying every keystroke in the same session. Removed sources cannot be revived;
current Enabled/Other choices survive. No remove/re-add or ID changes required.
A source that actually declares only search catalogs now has search endpoints
rather than silently substituting automatic browse feeds.

## Verification / package

Tests cover matching/ranking/Unicode, actual SQLite fresh/v8 upgrade/replacement,
1201 cached rows over multiple migration batches, playlist scope/limits, global
M3U/live widgets, both Hub entry points, provider aliases, broad-query noise,
required-search endpoints, Other, cold cache, concurrent upgrade and offline
fallback. Exact full-check and signed test+477 installation results: HANDOFF.md.
Analyze16/all774Flutter tests passed; production-signed+477 installed over+476
on Formuler, signature/version/ZIP/ABIs/installed hash verified. No UI driving.
No native-player, UI layout/focus, translations or Windows player-stack changes;
search code itself is shared on Android and Windows. Device acceptance pending.

Protocol source: [Stremio SDK manifest: search-only catalogs](https://github.com/Stremio/stremio-addon-sdk/blob/master/docs/api/responses/manifest.md#extra-properties).
