# Media Hub source cards (Codex, 2026-10-27)

`ArchiveSourcesScreen` is shared by Settings > Media Hub > Media Hub sources
and Sources in the Media Hub tab. The link field and all five existing add/import/
connector actions now precede the source grid.

- Playback sources: stream-only add-ons, add-ons with their own catalogs, and
  Jellyfin/Emby servers. Cards label the role and catalog counts; stream-only
  cards explicitly identify Cinemeta as the catalog provider.
- Catalogs & lists: the existing Cinemeta visibility switch, list-only add-ons,
  and tracker accounts. These cards explain that playback uses other sources.
- Each installed source retains Enabled (hold OK = confirmed removal), View
  source URL (except trackers), and Show under Other (add-ons only).
  Existing URL reveal/copy behavior and service/storage paths are unchanged.

The grid uses eager, equal-height rows (one to three columns, responsive to
width/text scale). Source counts are small; keeping controls mounted avoids the
old off-screen Add/focus failure. No catalog posters or source logos are fetched.

`_bands` records the actual responsive rows and each card's control nodes.
CallbackShortcuts owns arrows before default traversal. Left/Right keeps the
control index in adjacent cards, clamped for servers/trackers with fewer controls;
Up/Down walks controls, then the next row in the nearest visual column. Partial
rows clamp without horizontal wrapping. Focus reveals use immediate scrolling.
The gated TV text field explicitly enters Add; keyboard Done retains its existing
add behavior. `SettingsScaffold.backFocusNode` optionally exposes its existing Back
button for deterministic Up-to-Back/Down-to-field navigation on this page.

Stable nodes are keyed by source hash/action, retained through toggles and resize.
Removal focuses a surviving source or the link field; Clear returns to the field.
Dialogs and connector routes keep their own navigation while covering the page.

`test/archive_sources_grid_test.dart` exercises arrows/repeats, partial rows,
scrolling both ways, toggle/dialog/remove/clear focus, roles, tracker/server control
differences, resizing, empty state, TV keyboard submission, phone widths, large
French/Greek text, and equal-height cards. Optional MEDIAHUB_GRID_PREVIEW=1 writes
a fixture screenshot to ignored Logs/; optional MEDIAHUB_PREVIEW_FONT and
MEDIAHUB_PREVIEW_ICONS paths supply real fonts for local visual review.

Real TV remote acceptance remains pending. No player changes or package/version
changes are part of this branch. Updated remote guide and generated help index
are local until separately published/deployed.
