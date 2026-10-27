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

Real TV remote acceptance remains pending. Owner requested a follow-up local
test build: production-signed 1.0.43+473 installed on the Formuler over +471.
Analyze16 and all750 Flutter tests passed; installed version and APK hash verified.
No player changes. Updated remote guide and generated help index remain local
until separately published/deployed. Artifact details are in root HANDOFF.md.


## Formuler correction after +473

The owner could not enter the grid. Root cause: `_SourceControl` built its InkWell
key from `FocusNode.debugLabel!`, which Flutter sets only inside assertions. In a
release APK this is null, so every control failed to build (white ErrorWidgets in
the photo) and there were no focusable targets below the connectors. The row
navigation itself was not the cause. Each control now receives a separate stable
ID; diagnostic labels are never used for runtime behavior.

Regression tests strip all existing diagnostic labels, rebuild the cards, then
navigate into the grid, between controls, and toggle Other. A second test starts
at the link field with four connectors on the first row and Trakt/Simkl below,
matching the 960x540 TV layout. Entering a normal-height card now reveals its
whole header and controls; oversized accessibility cards reveal the active row.

Grey cards came from RefinedFinish.decorate replacing the original palette
fill with neutral grey glass. These source cards now keep their own near-black
palette gradient, icon inset and role badge. Refined finish adds stronger colour
lighting, depth and the existing painted bevel; plain mode stays dark. Controls
use explicit dark fills and accent focus borders. No shared theme changes.
Actual rendered Neon Green pixels are checked with finish both off and on; tests
use the real RefinedFinish.apply theme path. Package/checks: root HANDOFF.md.


Correction packaged as production-signed 1.0.43+474 and installed over +473 on
Formuler at the owner's request. Analyze16, all754 Flutter tests; package version,
signature, ZIP integrity and installed hash verified. UI was not driven over adb;
the owner's physical-remote acceptance is still pending. No publication.
