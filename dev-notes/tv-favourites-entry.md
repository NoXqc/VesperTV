# TV entry starts on Favourites (cdx, 2026-11-05)

Owner's +613 photos show TV selecting the first provider group with nothing
playing. The previous fallback chose a playing/resumable channel's group, or
the first provider group; Favourites only won when that channel was starred.

- `TvHomeScreen.initState` explicitly selects the TV Favourites sentinel,
  including no playback, a non-favourite playing/resumable channel and empty
  favourites. Movies/TV Shows retain their own initial destinations.
- `_openHome` marks the return as a new Favourites entry. `_restoreTvTab`
  recreates column scopes, clears stale programme/group focus requests and
  guide filtering, resets the group/list scroll and focuses the TV tab.
  Right then enters Favourites rather than the previously browsed group.
- Ordinary in-tab group choices and returning from group menus keep the
  selected group. Other overlay returns and fullscreen return logic retain
  their existing policies. No stored favourites, group order or playback
  startup preferences are changed.
- `test/tv_favourites_entry_test.dart` checks both guide modes with stopped,
  playing, pending-resume and empty-favourite states; Home after a distant
  group selection; startup Home; Home from Movies; and group-menu dismissal.
  The menu geometry change is documented in `glass-hold-menus.md`.
