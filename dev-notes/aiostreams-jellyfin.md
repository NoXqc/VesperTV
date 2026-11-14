# AIOStreams as a Jellyfin server + collections (Claude, 2026-11-14, uncommitted)

Owner idea (Discord video from a user): AIOStreams 2.37 serves a configuration as a **Jellyfin server**
(catalogs = libraries, each add-on stream = one version of a title). For the iOS build that could replace
Stremio add-ons someday (Apple). **Owner: keep add-ons in the iOS build for now**; this only makes the
Jellyfin connector good enough to use with it. Never host a converter on vespertv.app / the VPS (legal +
App Review exposure); a self-hosted standalone tool would only duplicate AIOStreams.

## AIOStreams facts (read from Viren070/AIOStreams `packages/server/src/routes/jellyfin/*`, checked live)
- Address `https://<instance>/jellyfin`; username = config UUID, password = config password. The
  "sign-in picker" address (`/jellyfin/<uuid>/<encryptedPassword>`) still asks for the password.
- `/System/Info/Public`: ProductName "Jellyfin Server", Version 12.0.0 -> our `discover` says Jellyfin.
- `POST /Items/{id}/PlaybackInfo` runs the add-ons (~5.5 s, cached after): up to 25 `MediaSources`, each
  `Path` = the stream link itself, `Name`, `Size`, `RequiredHttpHeaders`, plus an `aiostreams` block with
  the add-on stream's own `name` / `description` / `filename` / `size` / `bingeGroup`. Notices are
  `Type: Placeholder` ("No streams found"). `/Videos/{id}/stream?MediaSourceId=` 302s to that link.
- Libraries: `Path` = `/aiostreams/{type}/{instance}.{catalog id}` (type may be AIOMetadata's `movies`,
  CollectionType then empty); a catalog that needs a genre has `aiostreams.genreRequired: true` and lists
  **nothing without `Genres=`** -> we send `Genres=None` (AIOMetadata's no-genre option).
- As a plain Stremio add-on, AIOStreams renames carried catalogs `{instance}.{id}` too (manifest id
  `com.aiostreams.viren070.<uuid prefix>`); there a no-genre request works.
- Python urllib gets 403 from the owner's instance (Cloudflare UA check): send a `User-Agent`.

## What changed in the app
- `media_server_api.dart` `streams`: PlaybackInfo -> one `ArchiveStream` per version (AIOStreams: its
  link + add-on name/description; plain Jellyfin/Emby: `/Videos/{id}/stream?static=true&MediaSourceId=`).
  Any failure / one plain version = the old single link (remembered picks keep matching).
  `libraries`: `ArchiveCatalog.addonCatalogId` from the path, `homeHidden` from genreRequired, type from
  the path when CollectionType is missing. `fetchCatalog`: no newest-first sort for AIOStreams
  libraries (add-on order), `Genres` = tile genre or `None` for genre-only ones.
- `archive_playback.dart` `_resolve`: a server stream off the server's base (AIOStreams version) is
  followed once like an add-on link.
- `archive_service.dart`: `_catalogsById` indexes server libraries by `addonCatalogId` and AIOStreams
  add-on catalogs also by their id without the instance prefix (`_isAioStreams`, `_aioInstance`);
  `_refreshLibraries` re-reads a server's libraries on explicit Refresh.
- Tests: `test/media_server_test.dart` (versions, AIOStreams versions, libraries), 
  `test/hub_collections_test.dart` (server libraries, AIOStreams add-on, look-alike ids).

## Live results (owner's NoxRemux config, 2026-11-14)
Project Hail Mary 25 versions (94.5 -> 41.8 GB), SVU S1E1 25; 165 libraries after AIOMetadata was added
to the config (10 rows, 155 genre-only); Vesper pack 29 of 112 tiles found (same as with the AIOMetadata
add-on on Android; the rest point at catalogs his AIOMetadata config lacks). Nuvio Perfect: 3 of 83.
