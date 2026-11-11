# Playlist editor: Move / Copy channels to a group (2026-11-11)

Owner ask: in the playlist editor, tick several channels and change their group, with Move and Copy
clearly different, and the destination can be one of the viewer's custom groups or a group of any
playlist.

## What it does
- Channels tab bottom bar: **Move to group…** (gold), **Copy to group…** (green), **Reset group**.
- Dialog: title/explanation/button change with the mode ("Move: the channels leave their current
  group and show only in the group you pick" / "Copy: they stay… and also show…"). "Where" =
  *My custom groups* (existing ones + a "new group name" field) or any enabled playlist (its groups,
  with counts, hidden ones tagged).
- Applied on the TV at once (not part of the editor's Save / draft), per viewer.
- Row tags: `moved to X`, `copy in Y`. Reset group = back in the provider group, copies removed.
- TV: hold OK on a copy in the group being browsed (own or provider) > Remove from {group}, and
  Move Up / Down places it in that group.
- Kids (restricted) profiles can use it (the editor is behind the parent PIN); the dialog notes that
  their allowlist still decides what shows (below).

## Model (`services/user_groups.dart`, key `nox_my_groups`, per viewer)
Existing: `groups`, `moves` (id -> own group), `order`. New, written only when used:
- `pmoves`: id -> `GroupRef` of a **provider group** (any playlist) the channel was moved into.
- `copies`: id -> [GroupRef] groups that also show the channel.
`GroupRef` = `o:<title>` (own group) or `p:<playlistId>\0<title>` (provider group, by the title the
TV shows). Sync (`sync_merge.dart`) maps the ids and the playlist ids inside the refs.

## Listing (`services/playlist_manager.dart`)
- `_withPlaced(base, ref)` appends channels moved/copied into `ref` to a group's list
  (`_visibleChannels`, both the per-playlist and the all-playlists path); dedup by id, channels
  hidden on the TV left out. `_placedChannels()` resolves ids -> channels once per notify.
- A channel **moved** into a provider group leaves its own group: `_myGroupOf` (the session's
  `liveGroupOf` hook) returns the destination title for the same playlist, and a title no group has
  (`\0<playlist>\0<title>`) for another playlist, so a same-named group in its home playlist does
  not pick it up. A destination playlist that is gone or off sends the channel home.
- `liveGroupCount` counts moves/copies under their destination. `PlaylistManager.liveGroupOf`
  (TV hold menus) returns the readable destination title.

## Limits revisited (same day)
- **Move Up / Down** where placed channels are listed: a provider group that received a channel
  keeps its order in `UserGroups.porder` (GroupRef -> [Channel.id], its own and placed channels,
  any playlist), applied by `_withPlaced` (`orderedIn`). It stays the group's order after the
  placed channels leave (`ordersHere`), so the order never snaps back. `moveChannel(..., inGroup:)`
  takes the browsed group from the TV (a copy is listed in a group that isn't its liveGroupOf;
  before, Move Up / Down on a copy moved it in its home group, and a cross-playlist move did
  nothing). `_placedGroupOf` picks the segment by title: the move / copy destination, else the
  channel's own playlist. Sync maps `porder` keys like the other refs.
- **Flat lists** (Search, Multiview, player side panel, Catch-up, group counts) go through
  `_flatPlaced`: a channel moved into another playlist's hidden group is left out (unless a copy of
  it is in a shown group); a channel whose own group is hidden but copied into a shown group is
  listed. Same-playlist moves were already right (the session's hidden check sees the title).
- **Kids profiles**: allowed; nothing a kid's allowlist hides can be shown by a placement.
  `_myGroupOf` returns null on a restricted viewer when the channel's provider group is hidden
  (`_nativeHidden`, either title), `_withPlaced` skips such channels (`_placedVisible`), and the
  flat-list "copy out of a hidden group" rule is off for them. Allowing the group later makes the
  placements apply.

## Editor server (`services/playlist_editor_server.dart`) and page (`assets/editor/editor.html`)
`GET /api/groupdest?pl=` (own groups + playlists; `&to=<playlist>` its groups, loads Xtream live
lists on first need), `POST /api/place?pl=` `{ids, mode: move|copy, to: {own}|{newOwn}|{playlist,
group}}`, `POST /api/unplace?pl=` `{ids}`; both return the playlist's `placements` map
(`rawId -> {mv, cp}`) and `/api/channels` rows carry `mv` / `cp`.

## Tests
`test/editor_group_placement_test.dart` (model + manager listing across two playlists),
`test/playlist_editor_groups_test.dart` (real server routes), `test/editor_group_move.test.mjs`
(page logic; run `node --test test/editor_group_move.test.mjs`), `test/sync_playlist_match_test.dart`
(id remap of `pmoves` / `copies` / `porder`). Not box-tested; the editor page
needs a phone/PC browser pointed at the TV.
