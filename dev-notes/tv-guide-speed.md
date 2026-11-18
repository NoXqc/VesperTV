# TV guide speed (2026-11-18, +838..+847, `claude/dispatcharr`)

Owner on +837 (Homatics, two Xtream playlists of ~27k live channels, ~500k movies, ~70k shows): "The live view
does look and feel a little slow", "groups and channels all three feel slow and a little glitchy". Measured by
driving the box over adb, one kind of move per 10 s `Frames:` window, with per-part timers added for it.

## What cost the time
1. **Every PlaylistManager notify rebuilt the whole TV screen** (`context.watch`). The Movies / TV Shows warm-up
   notifies every few hundred ms for minutes: 5-10 rebuilds per 10 s while just moving in the tabs, 300-850 ms each.
2. **Group counts recounted ~53k channels on every rebuild** (`notifyListeners` drops `_liveCounts`): 330-610 ms.
3. **A group change scanned every live channel of each playlist** (`liveGroupOf` per channel): ~120 ms per new group.
4. **Favourites** did the same scan for starred channels and favourited groups: ~145 ms.

## Fixes
- `TvHomeScreen` listens to PlaylistManager (`_onPlaylistChanged`) and, on the TV tab, rebuilds only when
  `PlaylistManager.liveViewSignature()` changes (computed once per notify). `_TvTopBar` reads `isLoading` itself.
  Browse tabs: every change, as before. `LiveView: changed [liveLists, edits, groups]` = what moved.
- `liveGroupCountShown`: the last counts until `_liveCountsSignature` changes, then a recount after 1.5 s quiet;
  `liveCountsShown` (ValueNotifier) repaints only the groups column. `liveGroupCount` stays exact (editor, tests).
- `PlaylistSession._liveChannelsOfGroup`: index of live channels by group, keyed by the live list, edits and the
  manager's `_liveCountsSignature` (`liveGroupsToken`). Xtream lists; M3U keeps its own path.
- `_favoritesOf`: starred channels via the cheap flag first, favourited groups from the index, playlist order kept.

## Measured on the Homatics (same moves)
| | +837 | +847 |
|---|---|---|
| Tabs moves during warm-up | 5-10 rebuilds / 10 s, 300-850 ms | 0 rebuilds |
| Stopping on a new group | 350-430 ms frames | <= 156 ms, list ready in ~8 ms |
| Favourites list | 145 ms | 8 ms |
| Channel moves | 0 rebuilds | 0 rebuilds |

Left: drawing ~24-28 ms per frame with a 59 fps channel behind the full-video guide (GPU); a legitimate
rebuild when the event-channel refresh renames ~27k channels after start (`LiveRefresh`).

## Diagnostics kept
`Frames: ... parts(max/total ms): groups=.. tabs=.. list=.. row=.. listMake=.. visible=.. favourites=.. counts=..`
(`TimedSubtree` = a subtree's build; `*Make` = the eager part of a column's build; parts inside LayoutBuilders
are their own timers). Only printed when a 10 s window had jank.

## Driving the box for measurements
Leave focus where the owner put it and check a screenshot before each step: Right in the channel list opens
full screen (`_goFullscreenIfPlaying`) and Up / Down there then zap (+847 run: wrong numbers, owner had to
bring the box back).
