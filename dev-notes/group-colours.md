# Group colours (owner, 2026-11-25)

Owner: "a per group colour ... a red contour and red lettering to my Sports group. It still gets
highlighted normally when I get on it but it could give users a quicker view at their favorite
groups - hold ok - add a colour - show 5-8 presets?"

## What it does
Hold OK on a live group (or one of your own groups) > **Colour…** > No colour + 8 presets (Red,
Orange, Yellow, Green, Aqua, Blue, Purple, Pink), the current one focused and ticked. The row in
the groups column then wears a fine left-to-right fade of that colour (`groupColorFade`: 42 % at the
icon, 14 % halfway, gone at the right), name and icon white as usual, while the remote is elsewhere
(the open group keeps it under its usual outline). The focused and moving row get the usual highlight
instead. Movies / TV Shows groups don't offer it (yet).

The first try (996, box-tested "works well") drew a 1.5 px outline + name / icon / count in the
colour; owner the same day: "I'd like to try a fine gradient instead". The fade is its own
`DecoratedBox` inside the row's Material, always in the tree: the Refined finish replaces the
row Container's own gradient, so a gradient there would vanish with it.

## Where
- `lib/utils/group_colors.dart`: `GroupColor.presets` (stable ids are saved; shades can change,
  ids never rename), `GroupColor.of(id)`, `ownScope = 'own'`.
- Storage `AppConstants.keyGroupColors` = `vesper_group_colors_<playlistId|own>` per viewer
  (`_vkp`), JSON `{title: id}`; `StorageService.getGroupColors` / `setGroupColors` (empty map =
  key removed). Transferred, backed up, synced while the app runs (`_liveSyncPrefixes`), playlist
  id remapped by sync (`sync_merge.dart` `_playlistKeys`), copied with a new profile's
  visibility (`ProfileCopy.visibility`).
- `PlaylistSession.groupColors` (loaded with the group star in `_loadViewerScopedState`,
  `setGroupColor`, carried by `carryLiveGroupState` on a rename / merge).
- `PlaylistManager.groupColorOf(playlistId?, title)` / `setGroupColor` (null playlist = own
  group, `_myGroupColors`); own group rename carries it, delete drops it. `liveViewSignature`
  part `groupColors` (map identities: every change makes a new map), CLAUDE.md §10 rule 18.
- `tv_home_screen.dart`: `_GroupRow.tint` (the fade layer), menu rows in `_showGroupOptions` (live only) and
  `_showMyGroupOptions`, picker `_pickGroupColor`.

## Tests
`test/group_colors_test.dart` (presets, save + redraw + rename, per viewer, own groups, live sync
key), `test/tv_group_colors_test.dart` (menu, picker, the fade at rest with a white name, none when
focused, No colour).

## Not done
Movies / TV Shows groups, Vesper AI (`groups` / `my_groups` tools could set a colour), a colour in
other group lists (Multiview picker, Group management).

## Column lines (owner, 2026-11-25)
"Users don't want background color options but some would like color options for these separator lines instead"
(photo: the thin line right of the tabs column). Settings > Appearance > Look > **Column lines** (per viewer,
`vesper_column_lines`, copied with a new profile's look like Interface size): Default ('', the theme's), Theme color
('accent' = `scheme.primary`), White (white70), or a `GroupColor` id. `columnLineColorOf` (group_colors.dart) ->
top-level `_columnLineColor` set each TV home build (like `_largeUi`), used by the two column `VerticalDivider`s (a
hidden column's stays transparent) and the Timeline guide's two (ruler + channels/programmes). Owner on 1003 (photo):
"We also need the horizontal lines": the tabs column's separators, the preview / guide divider (4 layouts), the line
under the guide's hours and the programme cells' outlines (on now: the line colour at 85 % instead of the theme
colour; others: 45 % instead of white24; the focused cell keeps its highlight). 3 strings x 7
languages; tv_group_colors_test (+3).
