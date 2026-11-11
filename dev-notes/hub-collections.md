# Media Hub collections (Nuvio's tiles) — Claude, 2026-11-11

Owner sent a screen recording of an iPhone Nuvio setup: under Continue Watching, rows of tiles
("Streaming": Netflix, Prime Video, Disney+, HBO Max; "New & Latest": In Theaters, Blu-ray
Release; "Kids"), each opening a page of catalog rows ("Latest Disney+ (Movies)", "Disney+ Top
10 (Series)"…). It is Nuvio's **Collections** with a community pack ("Nuvio Perfect Collections",
luckynumb3rs/stremio-perfect-setup) over **AIOMetadata** catalogs. The moving tiles are animated
WebP ("they look like GIFs"): `coverImageUrl` is still (1280x720), `focusGifUrl` animated (90
frames, ~280 KB), `titleLogoUrl` / `heroBackdropUrl` (3840x2160) for the page.

## Format (Nuvio's export, imported as is)
`[{id, title ("🎬 Streaming"), showAllTab, viewMode, pinToTop, focusGlowEnabled, folders: [{id,
title, tileShape LANDSCAPE|POSTER(|SQUARE), hideTitle, focusGifEnabled, coverEmoji,
coverImageUrl, focusGifUrl, titleLogoUrl, heroBackdropUrl, catalogSources: [{addonId
("aio-metadata"), catalogId ("tmdb.discover.movie.streaming.netflix"), type, genre ("None" =
none)}]}]}]`. Older exports: `sources` instead of `catalogSources`, plus `provider: "addon"`
(other providers skipped). Also accepted: `{collections: [...]}` or one collection object.
`lib/models/hub_collection.dart` (`HubCollection.parseExport`, `label` drops the leading
emoji, `rawLink` turns a GitHub page link into raw, `isFileLink` = a `.json` that isn't a
manifest). Not used: `showAllTab`, `viewMode`, `pinToTop` (tiles always sit after Continue
watching), `focusGlowEnabled` (our focus = gold outline + glow).

## How it works
- **Storage:** per viewer, `vesper_archive_collections` (`getArchiveOptionsJson('collections')`):
  `{list: [...], hideRows: bool}`. Our own `enabled` and `link` (Update) are added per collection.
- **Matching:** `ArchiveSource.addonId` (manifest `id`, new; read at add and at every manifest
  refresh) + catalog id + type. A source saved before its id was read matches by catalog id +
  type alone. `genre` = the catalog narrowed with the `genre` extra (`withGenre`, forced when the
  manifest doesn't list it). Index `_catalogsById`, rebuilt only when the sources JSON / the
  profile's source switches / the viewer change (identical() on the prefs strings).
- **Tab:** `ArchiveService.collectionRows(type)` (not part of `rows()`: they hold no titles, other
  callers of rows() stay clean) = enabled collections with the folders whose catalogs are
  installed. `ArchiveScreen._rowsOf` puts them after search + Continue watching and, with
  `collectionsHideRows` (default on), drops the main rows of every catalog a tile shows (plain
  and genre-narrowed keys, `collectionRowKeys`). Hidden while searching / genre / Newest.
  Tile rows are `ArchiveRow`s with `collection` + `folders` (placeholder source/catalog, key
  `collection|<id>`); same height as poster rows (tiles 120 high + 30 title), slots per shape
  (`CollectionTile.slotOf`, `_tileStart` for mixed widths). No wide preview, no bar jump button,
  no hold menu. The hero shows the folder's title logo + "Streaming · 2 catalogs".
- **Tile:** `widgets/collection_tile.dart`: still cover; the animated picture only while focused
  (TV) or always on a phone (no focus; Nuvio's phone app plays them); `HoldToActivate` so OK opens
  on every platform (a computer's click only focuses, like PosterCard).
- **Page:** `screens/hub_folder_screen.dart`: backdrop + logo, one lazy poster row per catalog
  (`folderRows`), `loadFolder` reads the cache then fetches missing/stale catalogs (the tab's
  refresh usually has them; genre-narrowed ones only load here). Explicit D-pad, first title
  focused on a TV, Back pops, hold OK = favourites/remove like the tab.
- **Settings:** Media Hub sources > **Collections** (`screens/settings/hub_collections_pane.dart`):
  Add from a link, From phone (`PhoneLinkScreen`), the community pack (one OK, hidden once
  imported; `kPerfectCollectionsLink` = raw GitHub file), "Hide their catalogs from the rows",
  then each collection ("n of m tiles found in your add-ons"; OK = on/off, move, update, remove).
  A `.json` pasted in **Add a source** or sent from the **Manage from phone** page (`hub/add`)
  is imported as collections (no relay change needed).
- Tests: `test/hub_collections_test.dart` (format, import, matching, genre, switches, search),
  `test/hub_collections_tab_test.dart` (tab rows, D-pad into a tile's page, rows return with the
  switch off, missing catalogs message, Settings import). `archive_large_catalog_test` unchanged
  (tile rows read the public genre/search getters).

## Catalogs kept off the home screen (+721)
AIOMetadata's "not in home" catalogs (`showInHome: false`, e.g. the whole Nuvio pack) come with a **required genre**
(`isRequired: true`, options start with "None"). `fetchManifest` used to drop any catalog with a required extra other
than search; now a required genre alone keeps it as `ArchiveCatalog.homeHidden` (stored `homeHidden`): never a row,
never fetched by the tab's refresh, never searched, no genre filter options; collection tiles use it, requested
without a genre (AIOMetadata answers it like `genre=None`, checked). `test/hub_collections_test.dart`.

## On Home (+722, owner: "having these gifs-category to home if a user chose so")
Collection menu (Settings > Media Hub sources > Collections) > **Show on Home** (`HubCollection.onHome`, stored
`home`). Home gets `HomeRowKind.collections` ("Collections": placed under Continue Watching / New episodes / Watch
list for new and existing viewers, movable/hideable like any Home row) that expands into one row per collection
(`_HomeRow.id` = `collection|<id>`; Home's maps are keyed by row id now, not kind). Cards: wide for landscape tiles,
poster otherwise; the animated picture plays while focused (`_HomeItem.focusImageUrl`); OK opens `HubFolderScreen`;
hold OK adds **Remove from Home**. Home listens to the Media Hub and reloads only when the Home collections change.
`test/home_collections_test.dart`, `test/home_rows_test.dart`.

## Title logos (+724)
The pack's `titleLogoUrl` pictures are white wordmarks centred on a 1280x720 transparent canvas (Netflix: visible box
132..1148 x 223..497), so a fitted logo came out a third of its size. `widgets/trimmed_logo.dart` (`TrimmedLogo`)
measures the visible box once per link (decoded 640 wide, alpha > 16) and draws only that. Used by Home's hero for a
collection tile (`_HomeItem.titleLogoUrl`; owner: the NETFLIX wordmark, not "Netflix" in text), the Media Hub hero for a
focused tile and the tile page's hero. `test/trimmed_logo_test.dart`.

## Brand colours + Home focus (+725)
The pack's wordmarks are pure white (checked: saturation 0), so `TrimmedLogo.tint` (srcIn) paints a service's brand
colour from `TrimmedLogo.brandColor(name)` (Netflix red, Prime Video blue, Hulu, Paramount, Crunchyroll, HBO Max,
Shudder, YouTube; the others stay white). Owner's mock-up: red NETFLIX in Home's hero.
Home focus lost after Back from a tile's page (owner, box only; the widget test kept it): focus on the route's scope
means no key reaches Home's `_onKey`. Home now refocuses the card after any page it opened closes
(`_refocusAfterReturn`, also after the reload) and `_noteKey` turns the first arrow/OK with no Home card focused into
`_restoreFocus` (consumed). `test/home_collections_test.dart` drops focus to the scope and presses Right.

## +726: Customize Media Hub keys + TEMP Home key diagnostic
- `widgets/archive_row_settings.dart`: Left / Right walk a row's buttons (hide, pin, up, down, rename); Flutter's own
  search only jumped hide <-> pen (owner photo). `test/archive_row_settings_keys_test.dart`.
- Home Left / Right dead after Back from a collection page until Up / Down (owner). A TEMP on-screen line (+726, removed
  in +727) showed it: focus on "Disney Plus" (Streaming, row 1) but Home's `_row` = 2 (New episodes, one card). A card's
  `onFocus` closure held the row index of an older build: Home under a page isn't laid out, so its lazy row's cards keep
  old closures, and Back restores the focus before the relayout. Fix (+727): `onFocus` finds its row by id, and `_onKey`
  first syncs `_row` / `_cardIndex` from the focused card's node key (`_syncFromFocus`, nodes are `rowId#index`).
  `test/home_collections_test.dart` (a row above goes while the page is open, then Left) failed before, passes now.

## +728: wide card on the tile pages
A poster focused for 2 s on a tile's page opens wide (backdrop + title logo), like the Media Hub tab's rows (owner:
"the 2 sec card expansion" was missing). `HubFolderScreen._armWide` / `_wideIndex`, `itemExtentBuilder` (always a
builder), closes on any move or row change, only at TV / computer widths, only while the page is in front.
`test/hub_collections_tab_test.dart`.

## AIOMetadata answers unknown catalog ids (checked 2026-11-11 on the owner's ElfHosted instance)
The owner's AIOMetadata (34 default catalogs) matched Discover 3/4, Genres 1/19, every other row of the pack 0. Asking
it for a catalog it doesn't list (`tmdb.discover.movie.genres.animation`, `…theme.revenge`, `…studios.dc`,
`…decades.2010s`) answers HTTP 200 with the **same generic list** for all of them: the definitions live in the user's
AIOMetadata config. So never request a collection's catalog that isn't in the manifest; the user imports the pack's
AIOMetadata catalogs (`templates/AIOMetadata-All-Catalogs.json`, 186) on the configure page, then Refresh Media Hub.
The tab's refresh skips catalogs that are inside tiles (with "Hide their catalogs" on): a tile's page loads them.

## +729: Vesper AI `collections` tool + "movies" types
A user (Discord) asked for the AI connector to add / remove catalogs in our collections, pointing at
antonangel/nuvio-template (a Nuvio + AIOMetadata template generator: it writes the AIOMetadata config and the
collections file). Owner chose: arrange collections inside VesperTV, from catalogs the add-ons already have; new
catalogs are still made on AIOMetadata's page (password-protected config, we don't touch it), then Refresh Media Hub.
- `vesper_ai/collections_tool.dart` (`VesperToolbox.archive`): list (with collection: each tile's catalogs), catalogs
  (query; keys `type:id` from `ArchiveService.collectionCatalogs()`), turn_on / turn_off, home, move, remove,
  add_catalogs / remove_catalogs (keys; addonId = the source's manifest id), create_tile (collection made if new),
  rename_tile, remove_tile (last tile removes the collection), hide_rows. Remove asks on the TV for remote apps;
  restricted profiles can only read. Saved with `ArchiveService.saveCollections` (per viewer, same storage).
- `HubCollectionSource.fromJson`: "movies" = movie, "shows" / "tv shows" = series (the template writes the plural;
  those tiles found no catalog). `HubFolder.copyWith`, `HubCollection.copyWith(folders:)`.
- `test/vesper_collections_tool_test.dart` (6). AI apps must reconnect the connector to see the tool.

## +730: Vesper AI `hub_rows` tool
Owner: "I should be able to tell my Claude MCP to hide anything I don't want". `vesper_ai/hub_rows_tool.dart`: the Media
Hub tab's rows like Customize Media Hub: list (movies / shows, hidden / pinned), hide / show / pin / unpin by row name
(every row of that name, `source` narrows to one add-on), move (top / bottom / up / down), rename. Uses
`ArchiveService.setRowFlag` / `moveRow` / `renameRow`; restricted profiles only list. Only loaded rows are listed.
`test/vesper_hub_rows_tool_test.dart` (2).
Same day, owner's second AIOMetadata (ElfHosted, antonangel/nuvio-template `aiometadata-setup.json` via Import a
setup): ElfHosted caps a config at 200 enabled catalogs and refuses to save MDBList catalogs without an MDBList key;
154 MDBList + 108 TVDB catalogs were disabled (not deleted), 161 left (Streaming Services, Genres, Decades TMDB rows).

## +731: "movies" / "shows" catalog types
antonangel's AIOMetadata setup sets a display type: its manifest declares 69 movie catalogs as type `movies` (titles
inside are `movie`). VesperTV read `movies` as a custom type (wireType: browsed under Other, not a normal row), so
the owner's movie tiles showed the wrong things and he reverted to the Perfect pack. Owner: "fix it anyway and allow
for movies and movie". `ArchiveType.aliasOf`: `movies` = movie, `shows` / `tv shows` = series (never `tv`: Stremio's
live channels). A catalog keeps no wireType for an alias, only `requestType` (saved), sent in `/catalog/` requests
(`ArchiveCatalog.requestWire`; AIOMetadata answers `movie` and `movies` the same, other add-ons may not). Metas typed
`movies` are movies (streams asked as `movie`). `test/archive_type_alias_test.dart` (3).
Same build: **Remove remembers a collection's switches** (owner: removing the Perfect pack and adding it back lost
Streaming's Show on Home). `ArchiveService.removeCollection` keeps `{on, home}` by id under the collections prefs'
`removed` (newest 100); `importCollections` gives a returning id its switches back and forgets them. The pack's
"only Streaming on" leaves restored ones alone (`rememberedCollectionIds`). `test/hub_collections_test.dart`.

## Not done / to check on a box
- Performance of the animated WebP on the Formuler (one decoder at a time on TV).
- The pack's ~130 AIOMetadata catalogs: the tab's refresh still fetches every catalog (2 pages
  each) as before; with that many it takes a while, the page fetches its own first.
- Nuvio's other source providers (non add-on) are skipped.
