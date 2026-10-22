# VOD favourites investigation — Codex, 2026-10-22

Report: Sony Android TV user says Live TV favourites work, but Movies and TV
Series favourites do not save/appear. Owner could not reproduce on Fire Stick,
phone or Formuler Z11. Source: screenshot supplied in this session. User's app
version, source type, navigation route, star/toast behaviour remain unknown.

## Confirmed code defects, not yet confirmed as this user's cause

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

Executable diagnostic (assertions deliberately describe the current defects,
not the desired fixed behaviour):

```powershell
flutter test --no-pub dev-notes/vod_favorites_probe_test.dart
```

Result: `00:00 +3: All tests passed!` — normal browse control plus two defects.
Preference writes are verified; actual SQLite writes are mocked, so this does
not test device disk persistence or a database exception.

## Proposed correction for Claude review

- Toggle from the canonical saved id set, then synchronize any loaded copies.
- Resolve Favourites from all saved ids through the catalog, independent of
  the 300-item browse cap. Keep viewer/playlist/hidden-group filtering and M3U
  behaviour; avoid loading the full catalog or dropping the memory cap.
- Do not use SQLite's legacy `is_favorite` bit as the authoritative source:
  non-Main viewers intentionally do not write it. Resolve saved ids per viewer.
- Turn the probe scenarios into desired-behaviour regression tests, and cover
  removal through a different copy, restart, viewer switch, disabled playlists,
  hidden groups, and saved titles outside the loaded category slice.

No production fix, build, install, merge, push or release was performed.
