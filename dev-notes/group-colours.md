# Group colours (owner, 2026-11-25)

Owner: "a per group colour ... a red contour and red lettering to my Sports group. It still gets
highlighted normally when I get on it but it could give users a quicker view at their favorite
groups - hold ok - add a colour - show 5-8 presets?"

## What it does
Hold OK on a live group (or one of your own groups) > **Colour…** > No colour + 8 presets (Red,
Orange, Yellow, Green, Aqua, Blue, Purple, Pink), the current one focused and ticked. The row in
the groups column then has a 1.5 px outline, name, icon and count in that colour while the remote
is elsewhere. Focused, open (selected) and moving rows keep the usual highlight. Movies / TV Shows
groups don't offer it (yet).

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
- `tv_home_screen.dart`: `_GroupRow.tint`, menu rows in `_showGroupOptions` (live only) and
  `_showMyGroupOptions`, picker `_pickGroupColor`.

## Tests
`test/group_colors_test.dart` (presets, save + redraw + rename, per viewer, own groups, live sync
key), `test/tv_group_colors_test.dart` (menu, picker, row colour at rest / normal when focused,
No colour).

## Not done
Movies / TV Shows groups, Vesper AI (`groups` / `my_groups` tools could set a colour), a colour in
other group lists (Multiview picker, Group management).
