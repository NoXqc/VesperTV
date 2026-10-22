# VOD favourites investigation — Codex, 2026-10-22

**Fixed, unreleased:** `codex/fix-vod-favorites` implements both corrections
below. The original diagnostic was replaced by ten desired-behaviour tests in
`test/vod_favorites_test.dart`. Device verification remains pending.

Report: Sony Android TV user says Live TV favourites work, but Movies and TV
Series favourites do not save/appear. Owner could not reproduce on Fire Stick,
phone or Formuler Z11. Source: screenshot supplied in this session. User's app
version, source type, navigation route, star/toast behaviour remain unknown.

## Original code defects, not yet confirmed as this user's cause

Reproduced with real PlaylistManager/PlaylistSession and mocked preferences,
using a fake CatalogDatabase that models its fresh objects and category LIMIT.
No Sony/device input was simulated; no user account or network was used.

1. **Detached object:** Search / Expand catalog read new movie/series objects
   from SQLite. Toggling favourites changes only the passed object's flag and
   the saved id sets. `favoriteMovies` / `favoriteSeries` scan the original
   session objects and their stale `isFavorite` flags. The saved preference
   contains the id, but the Favourites row stays empty. A later toggle on a
   stale unstarred browse object adds the already-saved id again instead of
   removing it.
2. **300-item limit:** Session browse caches retain at most 300 entries per
   category. Favourites scans those caches, so a saved title outside them is
   missing altogether. Restamping cached favourites cannot find that object.
   This also applies when a category has not loaded yet.

These are catalog/navigation differences that can occur on any device. They
explain why testing favourites on ordinary browse posters succeeds. They do
not establish a Sony-specific bug or prove which route the reporter used.

## Affected routes and controls

- Expand catalog: holding a movie or series poster toggles a detached object.
- Search: series posters and the opened series detail page use detached objects.
- Movie detail resolves to an existing browse-cache object when available,
  which avoids defect 1 there. A movie beyond the browse cache still hits 2.
- Normal browse posters: control case succeeds for both movies and series.
- Live TV uses a separate, fully loaded list; this probe does not change it.
- Media Hub favourites use different storage/service code; not covered by this
  Xtream reproduction. Ask which source the user means before attributing it.

## How to reproduce without the user's Sony

1. On any device, open an Xtream TV series through Search or Expand catalog.
2. Add it with the detail page's Favorites button; return to TV Shows > Favourites.
3. Compare with adding that same title directly from its ordinary browse row.
4. For movies, hold a poster inside Expand catalog. Also try a category with
   over 300 titles and favourite one beyond the first browse-cache slice.
5. Check whether a star / Added to Favorites appears, whether it appears after
   restart, and whether a title within the first 300 behaves differently.

Regression suite (now asserts the corrected behaviour):

```powershell
flutter test --no-pub test/vod_favorites_test.dart
```

Ten tests pass: normal browse, detached copies/removal, item 301, restart with
unloaded categories, non-Main viewer persistence, hidden groups and disabled
playlists, in-flight viewer switches, restricted allowlists, clearing during
loads, and batching/deduplication for 1,001 saved titles of each type.
Preference writes are verified; actual SQLite reads/writes are mocked, so this
does not test device disk persistence or a database exception.

## Implemented correction

- Toggle from the saved id set and synchronize loaded copies. Search, Expand
  and movie/series detail stars read the saved state instead of stale copies.
- Resolve saved Xtream IDs through catalog `getVodByIds` / `getSeriesByIds` in
  batches of 400. Cache only favourite rows, separately from browse categories.
- Cache queries by viewer, saved ids and enabled playlists; invalidate on
  catalog refresh, viewer change, toggle or clear. Ignore obsolete in-flight
  query results. The Favourites view also ensures resolution is scheduled.
- Keep viewer, enabled-playlist, hidden-group and restricted allowlist checks;
  M3U stays on its existing loaded catalog. Retain the 300-item browse cap.
- Do not use SQLite's legacy Main-only `is_favorite` bit as the source of truth.

No build, install, merge, push or release was performed.
