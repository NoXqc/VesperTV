# EPG channel logos in the playlist editor

Investigation: Codex, 2026-11-06. Base: main bd7e13c (source 1.0.58+645).
Status: proposal only; no application or editor behavior changed.

## Requested behavior

The owner supplied a user's request to use the channel logo from their own XMLTV
EPG, rather than the playlist/provider logo, through the playlist editor's EPG
popup. This means channel branding, not programme artwork, sports team crests,
Media Hub posters, or an arbitrary file upload system.

## Finding

Feasible using the existing logo override layer. The missing work is retaining
XMLTV channel icons and identifying which guide a candidate came from. It is
more than adding a button: the current catalog deliberately flattens sources.
No native player changes, Android libraries, release build, or server deployment
are needed for this feature's implementation.

XMLTV defines optional channel icons as `<channel><icon src="..."/></channel>`.
The same `icon` element can occur under programmes and ratings, so parsing must
track its parent and accept channel icons only. Multiple channel icons are
allowed; start with the first nonempty supported HTTP(S) URL.
Primary reference: [XMLTV DTD](https://github.com/XMLTV/xmltv/blob/master/xmltv.dtd)
(channel declaration and icon definition).

## Existing implementation

- `lib/services/epg_service.dart`: `_parseXmltvStream` streams programme rows to
  SQLite and collects channel names and current programmes, but ignores icons.
  `_channelCatalog` is normalized channel ID -> name, rebuilt by EPG refreshes
  each app session. It is not persisted. `_refreshOne` keeps the first name for a
  duplicate ID across sources; that tie-break is unsuitable for logo selection.
- `lib/main.dart`: `_epgSources` loads each enabled playlist's main guide before
  its extra guides. Custom feeds are already supported through `extraEpgUrls`.
- `lib/services/playlist_editor_server.dart`: `/api/epg/search` searches the global
  name catalog, with no playlist/source parameter, and returns only ID + name.
  `/api/epg/link` saves a programme-ID override and schedules a guide reload.
- `assets/editor/editor.html`: `openGuide`, `gdSearch`, `linkGuide` implement that
  popup. Linking immediately closes it. The existing Set logo bulk action takes
  a URL; channel rows already preview `edits.logos[rawId]` over the provider logo.
- `lib/services/playlist_edits.dart`: `logos` is raw channel ID -> URL within the
  playlist's edit document. `apply` stamps `Channel.logoOverride` on live rows.
  Values are currently capped at 1000 characters on decode.
- `lib/models/channel.dart`: `logoUrl` returns override, then provider logo;
  serialization retains the provider value separately. Existing consumers include
  the channel list/guide/player-side panel. No per-widget logo-source lookup needed.
- `PlaylistSession.saveEdits` applies edits, persists and notifies. Storage uses
  `_vkp(keyPlaylistEdits, playlistId)`: logo edits are scoped to viewer + playlist.
  Existing Backup/Transfer/sync handling carries this document; sync remaps
  playlist references and leaves logo URL values intact.
- Programme-ID overrides are currently playlist-wide (`setEpgIdOverrides`), while
  logo overrides are per viewer. Preserve these existing scopes; do not silently
  make logo selection a shared setting or rewrite EPG matching scope.

## Recommended first version

1. In the channel's Guide popup, show the guide source (Provider guide / Extra
   guide 1, etc.), candidate name/ID, and a small logo preview. Let the user
   filter sources so identical IDs from different feeds remain selectable.
2. Offer **Use EPG logo** for a specific candidate, disabled when it has no usable
   icon. Keep programme matching separate: the existing Link action still links
   programmes only. A later **Link and use logo** shortcut can do both explicitly.
3. Copy the chosen URL into the existing `PlaylistEdits.logos[rawId]` entry. Show
   it in the editor's normal draft and apply through its existing Save flow.
   Do not save the whole stale edit document from a separate immediate server
   action: pending browser renames/hide rules could otherwise be lost.
4. Offer **Use provider logo** to remove just this logo override. Do not route
   that action through Reset name: the current bReset handler clears both names
   and logos. Selecting/relinking an EPG ID must not overwrite a manual logo.
5. On content update/restart, existing applyEdits restores the saved logo.
   This is a URL snapshot, not a downloaded image or a live binding: later feed
   changes do not replace it automatically. The user can select a newer URL.

This satisfies the supplied request without adding a global logo-source setting
or changing every channel automatically. A future Follow EPG logo option would
need saved source+channel references, metadata cache persistence/invalidation,
manual-vs-EPG precedence, and explicit feed removal/relink behavior; defer it.

## Implementation boundaries and edge cases

- Add a source-aware metadata directory alongside the old name catalog, keyed by
  source identity + normalized XMLTV channel ID. Keep existing matching APIs
  intact; use a separate editor hook for rich candidates. Search should receive
  the selected playlist and offer its configured main/extra feeds, not silently
  take another playlist's first-seen entry.
- Publish/replace a source's metadata only after successful parsing. A failed
  refresh retains its last successful directory. A successful refresh removes
  dropped logos/channels from that source's candidates; removing a configured
  source removes it from picker results. Saved URL snapshots remain until reset.
- Preserve the streaming programme pipeline. Keep only channel-level metadata;
  never load programme XML into memory or download all logos during refresh.
- For the initial version, the directory can remain session-only, like today's
  EPG picker. An empty directory after restart should offer Update EPG Now.
  Previously chosen logos still work because their overrides are persisted.
  Persistent candidate metadata would be a separate cache/schema enhancement.
- Normalize IDs with normalizeEpgId. Do not collapse distinct source candidates
  merely because their IDs match, or change programme collision precedence here.
- Resolve relative icon references against the feed URL; accept HTTP(S) only.
  Test escaped query strings, blank icons and multiple icons. Do not turn a
  programme poster into a channel logo. Validate URLs server-side as well as
  in the browser, and handle overlong URLs explicitly rather than truncating a
  newly chosen one into a broken link under the existing 1000-character limit.
- Reuse current image rendering/cache behavior. Browser preview success does
  not prove the TV can decode a format or reach a host. Test PNG/JPEG and a
  failed image; do not promise SVG or header-authenticated images without
  additional renderer/auth work. Do not add an unrestricted image proxy.
- Capture viewer + playlist + rawId and recheck after awaits. An open draft must
  not save to a newly active viewer or a different selected playlist. Keep source
  credentials/full URLs out of logs and source labels; return opaque candidate
  handles or a source index tied to the configured guide list.
- New labels must use tr() with FR/ES/IT/EL/DE. The current standalone editor
  HTML has hard-coded English labels; add a small localized server text payload
  for the new labels rather than treating that older pattern as permission to
  add untranslated UI. Update remote tips/help index when the feature ships.

## Verification for implementation

- Streaming XML fixtures: channel icon vs programme/rating icons; multiple icons;
  normalized IDs; HTTP(S)/relative/invalid URLs; no programmes; split XML chunks.
- Duplicate channel ID in provider and extra feeds: choosing the extra guide
  selects its logo regardless of fetch order. Removed/failed/refreshed feeds.
- Persist/reload/edit-layer tests: provider reset, existing manual logo, content
  refresh, per-viewer and per-playlist isolation, Backup/Transfer/sync round trip.
- Editor integration: selecting a candidate with/without logo; logo-only change
  leaves programme link unchanged; linking alone leaves logo unchanged; pending
  draft edits survive; switching playlist/viewer while a search is pending.
- Real phone/PC editor against a TV and Windows: preview, Save, guide/player logo,
  reset, restart. Use a synthetic public fixture; no user credentials in tests.
- Run changed-file formatting, baseline16 analyze, full flutter test, and any
  editor JavaScript checks added for the implementation. No implementation tests
  were added for this investigation-only document.
