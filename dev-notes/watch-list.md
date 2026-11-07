# Watch list (manual + Vesper AI) — Claude, 2026-11-07

One per-viewer list (`vesper_watchlist`, `WatchList` in
`lib/services/vesper_ai/watch_list.dart`), synced and transferred like before.
An entry is an IPTV movie (`channel`), an IPTV show (`series`) or a Media Hub
title (`hub`: `HubTitle` = source manifest URL + `ArchiveMeta`, id
`h:<src>|<id>|<wire>`, so the same title from two sources is two entries).

- **Adding by hand:** the **Watch list** pill on the IPTV movie page, IPTV show
  page, Media Hub movie page and Media Hub show page (`WatchListButton`;
  pressing it again takes the title off). Poster hold stays Favourites.
- **IPTV:** a **Watch list** row under Continue Watching in Movies (movies)
  and TV Shows (shows), not in the Favourites view; hold OK on a card removes
  it. A **Watch list** entry under Favourites in the groups column jumps to
  the row (only when the tab has one). Pseudo-group `__watch_list__` with
  playlistId '' in `_browseRowKeys`, like the Favourites rows.
- **Media Hub:** rail entry **Watch list** (phone: the menu) opens
  `ArchiveWatchListScreen`: a Movies row and a TV Shows row (empty rows are
  left out), explicit Up/Down between them, OK opens through the title's
  source (missing/disabled source = a message), hold OK removes.
- **Home:** the existing Watch list row shows every entry; Media Hub ones open
  through their source.
- **Vesper AI / AI apps:** the `watchlist` tool takes `source: iptv |
  media_hub`; by name it tries the playlists, then Media Hub
  (`ArchiveService.findTitle`, never Other titles), then live channels. Hub
  entries get `h` refs; remove by name matches what is saved first.

Not done: remote tips page (`docs/remote.html`) entry; Windows has the same
screens (no separate desktop work needed) but is untested. Device test pending.
