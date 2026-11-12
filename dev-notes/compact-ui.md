# Interface size: Compact / Normal / Large (Claude, 2026-11-10, Large 2026-11-11)

Owner (2026-11-10): "a compact UI toggle where left tab and groups and even channels are
more compact; some apps use an even smaller UI." Then (2026-11-11): three sizes,
**Large for older folks with lesser vision**. Per profile.

## Setting
Settings > Appearance > Look > **Interface size** (Compact / Normal / Large), Normal by
default. `AppPreferences.uiSize` ('compact' | 'normal' | 'large'; getters `compactUi`,
`largeUi`), key `vesper_ui_size` through `_vk` (per viewer, no fallback to Main's value).
The old switch key `vesper_compact_ui` (bool) seeds it when unset (a viewer who had
Compact UI on reads 'compact') and is kept in step on every write, so an older build
still sees Compact. Both keys are copied with "Home" in a profile copy.
Vesper AI: `settings` key `ui_size` (choice) + the old `compact_ui` switch (off leaves
Large alone).

## What changes (TV home only, `tv_home_screen.dart`)
Top-level `_compactUi` / `_largeUi`, set at the top of each `_build`.
| | Compact | Normal | Large |
|---|---|---|---|
| Tabs column | 136 | 160 | 200 |
| Groups column | 220 | 260 | 320 |
| Row padding (outer / inner) | 1.5 / 6 | 3 / 10 | 4 / 13 |
| Row icon | 18 | 20 | 26 |
| Row text | -1 size | as is | x1.2 (`_uiText`) |
| Live list logo / row estimate | 32 / 52 | 40 / 72 | 52 / 96 |
| Timeline row | 40 | 64 (48 Compact guide) | 84 (even with Compact guide) |
| Timeline channel column / logo | 136 / 24 | 160 / 32 | 210 / 42 |
| Full-video guide | 5 rows | 3 rows | 3 rows |

Large text = `_uiText`: a `MediaQuery` textScaler 1.2x the system's around the tabs
column, groups column, live region (list, Timeline, preview box) and the full-video
description card. Always the same wrapper (no remount on change). Compact also uses
the slim top bar.

Not changed: Movies/TV Shows posters (fixed cards; Wide cards is its own switch), Home,
Settings, the player. A whole-app Large (Settings, player bar, Sports Trak) would be
a separate step: many fixed-height widgets there.

## Tests
`test/compact_ui_test.dart`: default, per profile, restart, migration from the old
switch, profile copy. Look checked on a box only (no golden test).
