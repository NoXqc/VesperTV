# Compact UI (Claude, 2026-11-10)

Owner: "a compact UI toggle where left tab and groups and even channels are more
compact (we have a compact guide toggle already); some apps use an even smaller UI
and some users like that." Per profile (owner).

## Setting
Settings > Interface > Tabs > **Compact UI** (first row), off by default.
`AppPreferences.compactUi`, key `vesper_compact_ui` through `_vk` (per viewer). Unlike
the guide settings it never falls back to Main's value: it is new, nothing to migrate,
so a new profile starts off. Copied with "Home" in a profile copy (`profile_copy.dart`).
Vesper AI: `settings` tool key `compact_ui` (tabs).

## What changes (TV home only, `tv_home_screen.dart`)
Top-level `_compactUi`, set at the top of each `_build` like `_wideBrowseCards`.
- Top bar: the slim one (`_TvTopBar(dense:)`, as on a phone held sideways).
- Tabs column 160 -> 136, groups column 260 -> 220 (collapsed strip stays 56).
- `_SelectableRow` / `_GroupRow` (tabs, groups, live list rows): vertical padding
  3+10 -> 1.5+6, icon 20 -> 18, text one size smaller (14 -> 13, groups 13 -> 12).
  Live list logo 40 -> 32 (`_liveLogoSize`); `_liveRowHeightEstimate` 72 -> 52.
  Playlist divider rows tighter.
- Timeline: rows 40 (`_compactUiRowHeight`; beats Compact guide's 48), channel column
  160 -> 136 (`_channelColumnWidth`, now set each build), logo 24, name 12; programme
  titles one line (the 40 px row holds one). Full-video guide: 5 rows instead of 3.

Not changed: Movies/TV Shows posters (Wide cards is its own switch), Home, Settings,
the player, the preview box.

## Tests
`test/compact_ui_test.dart`: default off, per profile, survives restart, profile copy.
Look checked on a box only (no golden test).
