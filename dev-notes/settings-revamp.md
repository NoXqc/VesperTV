# Settings revamp (owner, 2026-11-10)

Owner: "if I'm brand new to this app and I open the settings I get discouraged right away". Plus, on the
Network folder page: a whole page of full-width fields for 1/8th of the screen's worth of text, while the app
has nice floating translucent menus; and "the pastel selector was supposed to be gone a long time ago".

Plan page (mockup + full old -> new map): https://claude.ai/artifact/8PqbReBQ3RPCvAz2pkVfQo (owner: "Very nice ...
Proceed"). Three test APKs: step 1 shell + new map, step 2 floating panels/roll-downs for the form pages, step 3
search + Start here + the gold wash out of the whole app + "Settings > ..." paths in strings / remote guide.

## Step 1 (branch `claude/settings-revamp`, test +711)

- **Map** (`lib/screens/settings/settings_catalog.dart`): 10 categories - Playlists & sources, Appearance,
  Playback, Sports Trak, Profiles & startup, Recordings & downloads (Android/Windows), Vesper AI, Backup &
  devices, Help, Advanced (after a divider). Every row is a `SettingsItem`: `SettingsToggle` (flips in place),
  `SettingsChoice` (roll-down beside the row; `onStep` = Left/Right too, Guide transparency), `SettingsLink`
  (a real tool keeps its page), `SettingsAction`, `SettingsCustom` (goal overlay probe). Values are read fresh
  each build; **same storage keys and defaults** as before, nothing migrated.
- **Menu** (`settings_menu_screen.dart`): two `GlassPanel`s; rail + pane, each its own `FocusScope`, only
  Left/Right explicit (same pattern as before, CLAUDE.md §10). Pane = header, non-lazy rows under small-caps
  section titles, and `SettingsHelpStrip` with the focused row's full text (the old long subtitles are now
  help text, so rows are one line). Phone: category list -> `SettingsCategoryScreen` (rows show their help as a
  2-line subtitle). Footer (version, credits) moved to Help.
- **Row** (`widgets/setting_row.dart`): `SettingRow` (ListTile, focus = `GlassMenuSurface.rowDecoration`, no
  theme wash), `SettingValue`, `GlassSwitch` (a pill, not a control: one focus stop per setting).
- **Every Settings page** (`widgets/settings_scaffold.dart`): `SettingsBackdrop` = the viewer's Home wallpaper
  (decoded 160 px wide, blurred, dimmed; cached per viewer) or a gold glow; on TV/computer the body floats on a
  `GlassPanel` at most 760 wide and centred (`wide: true` for multi-pane tools: Add Playlist, Playlist Manager,
  Media Hub sources, guide matching/linking, EPG, groups, priority, Recordings tab, a Sports page).
  `SettingsScaffold.glassTheme`: focusColor white 10 % instead of gold 45 %, rounded glass text fields.
  `GlassRowScope` makes TvMenuTile / TvSwitchListTile use the quiet glass row; `GlassFocusFrame` wraps the plain
  ListTile / SwitchListTile / CheckboxListTile rows of 6 pages.
- **The pastel selector**: `RefinedFinish._button` painted focused buttons gold 20 % over grey (the muddy "From
  phone"). Now a white 10 % sheen + no overlay; gold stays in the border and text. App-wide (buttons only).
- (Step 1 kept the old single-setting pages for their tests; step 3 removed them.)
- New strings: 32, in all five dictionaries.

## Steps 2 + 3 (owner: "Do all steps", test +712)

- **Floating panels** (`openSettingsPage(..., floating: true)`, `SettingsFloating`, in `settings_scaffold.dart`): on
  a TV box / computer a short page is a blurred glass panel (680 wide, title + Back inside) over the dimmed screen
  below; Back or a click outside closes it; a phone gets a normal page. Used by every `SettingsLink(floating: true)`
  (wallpaper, Trakt & Simkl, Online subtitles, Playlist editor, countries, Network folder, TMDB, Debrid, posters,
  Profiles, Remote tips, Discord, Send log, Support, Check for updates) and `PhoneLinkScreen.open` (the From phone
  QR). Their body lists are `shrinkWrap` so the panel hugs them. Real tools stay pages (Playlist Manager, EPG,
  Media Hub sources, Sync, Transfer, Backup, Vesper AI's own page).
- **Recordings rows in the list** (`_recordings()`): start early / keep recording / speed / suggested start / space
  as roll-downs, "Save to" from `RecordingService.volumes()` (loaded by the screen: `loadRecordingVolumes`), network
  folder link. `RecordingSettingsScreen` deleted.
- **Vesper AI rows**: Talk to Vesper now, Talk from my phone, Vesper shortcut, Remote voice button (Android), Read
  replies aloud; the rest (own AI key, AI apps, learning the remote's button) stays on its page.
- **Start here** (`SettingsSection(highlight: true)`, `SettingsHighlightCard`): Add Playlist, Language, Theme color
  in a gold-edged card at the top of Playlists & sources while there is no playlist.
- **Search settings**: rail entry 0 (the screen opens on entry 1, Playlists & sources). Pane = gated text field +
  `settingsSearchResults` (accent/case-folded words over title, subtitle, help, choices, category, section); each
  result is the working row with "Category › Section" as its subtitle. Phone: `SettingsSearchScreen`. The pane's
  Left goes back to the rail except inside the typed text (`_paneKey`).
- **Gold wash out of the whole app**: `tv_theme.dart` `focusColor` = white 16 % (was primary 45 %). The stock rows
  that relied on it got `GlassFocusFrame` (Media Hub sheets/settings/stream menus, Sports channel lists, Multiview
  tip dialog, goal overlay probe, Windows player history / Multiview picker); keyed list rows keep their key on the
  frame.
- **Paths**: 4 UI strings (wallpaper, Sync, Transfer, player subtitles) x 6 languages, Vesper AI help/tool texts,
  `docs/remote.html` (paths + a Settings section on in-place changes and search), `tools/discord_help_bot/guide.json`
  regenerated (131 answers). The bot's Node suite has 3 failures that predate this work (old release wording).
- **Removed** (now rows): `GeneralSettingsScreen`, `ThemeScreen`, `GuideSettingsScreen`, the eight Sports
  `*_settings_screen.dart` pages except countries, `SportsModeSettingsScreen`, `RecordingSettingsScreen`; tests
  moved to the rows (`SettingsCategoryScreen`). Sports card scale is in `_GameCard.scaleOf`.
- Preferred playlist: a disabled playlist can't be picked; a saved one that is gone/disabled shows dimmed with the
  "unavailable" text as its help.

## Box checklist (+712)

- Settings opens on the rail; Right enters, Left/Back returns; Up/Down never crosses columns.
- A switch flips in place; a choice rolls down at the row and the pick shows on the right.
- Guide transparency: Left/Right change it by 5 while focused.
- The help line under the list follows focus and is readable from the couch.
- Wallpaper shows (blurred) behind Settings when one is set; the gold glow otherwise.
- Network folder and other pages: a centred glass panel, "From phone" focus = gold outline, no muddy fill.
- Playlist Manager / Add Playlist / Media Hub sources still use the full width.
- Language change still returns to Home in the new language.
- Up from the first category = Search settings; OK on the box opens the keyboard; results change in place.
- Short pages (Network folder, TMDB, QR pages…) float over Settings; Back closes only the panel.
- Recordings category rows (start early, speed, save to…) and Vesper AI rows work.
- Start here card only while there is no playlist.
- Elsewhere (Media Hub sheets, Sports channel lists, Multiview tip): focus is a gold outline, no gold fill.

## Same branch, 2026-11-11 (owner, after testing +713)

- **Sports data credit** in Help's footer (`SettingsFooter`): "Sports scores, schedules and standings come from
  ESPN's and TheSportsDB's public data; VesperTV is not affiliated with or endorsed by either." Text only, 5 languages.
- **Group Management > Countries** (owner: pick countries, not hundreds of groups): `utils/group_regions.dart`
  reads the start of each group name (`US:`, `US|`, `|US|`, `[US]`, `US -`, `AM | US`, `VIP | UK`, `4K | US Sports`,
  `USA ▎`, flag emoji, `US NEWS`; 3-letter codes and names alias to one key: USA/US, GB/UK, CANADA/CA, LATINO/LATAM,
  ARABIC/AR…). Markers in front (continents AM/EU/AF…, VIP, 4K, VOD) are skipped when a country follows; `AM` alone
  stays a plain prefix (Americas, not Armenia). Other prefixes shared by 2+ groups (VIP, NBA…) are listed after the
  countries, then "Groups without a country". `screens/settings/group_regions_panel.dart` = glass dialog, one row
  per entry (flag, groups count, how it was written, state icon); select = hide all if all shown, else show all
  (`setGroupsHidden`, deferred loading kept). Button appears beside Show All / Hide All only when prefixes exist;
  per tab (TV / Movies / TV Shows). Tests: `group_regions_test.dart`, `group_regions_panel_test.dart`. Remote guide
  row + guide.json. In test +715 (worktree VesperTV-claude-test713).

## Media Hub sources as one list + Manage from phone + row eye (2026-11-11, owner: "Do it")

Plan + mockup: https://claude.ai/artifact/HBh78srTG5cuH3ZCHjwJyp (owner: do it, with the defaults: subtitle add-ons in
the list, versions after a refresh, no reordering).

- **Sources page rewritten** (`screens/settings/archive_sources_screen.dart`): glass rail (Add a source, All, Streams,
  Catalogs & lists, Media servers / Live TV only when not empty, Subtitles, Manage from phone, Customize Media Hub,
  Advanced) + pane like Settings (own FocusScopes, Left = rail, help line). One row per `HubEntry`
  (`services/hub_remote.dart`: Media Hub sources, built-in Cinemeta, subtitle add-ons): logo (manifest `logo`, cached),
  name + version, description, tags. OK = on/off (sources per profile, subtitle add-ons per device, Cinemeta = Show
  Cinemeta catalog); Right = ⋯ (second focus stop), hold OK = same; options = floating `_SourceOptions` (Enabled, Show
  under Other, TV add-on, View source URL + Copy, Remove with confirm). Phone: chips + rows, tap row = options, tap
  switch = toggle. Add pane = link field (several links) + From phone / Manage from phone / Stremio / Jellyfin-Emby-Plex /
  Trakt & Simkl / Online subtitles. Advanced = Refresh Media Hub (`refresh(force, manifests)`) + Clear. Old grid test
  replaced by `test/archive_sources_list_test.dart`.
- **`ArchiveSource.version`** from the manifest (`ArchiveApiService._version`), saved; old sources get it at their next
  manifest refresh.
- **Manage from phone**: the pane's Show the code (link starts on OK only, never on passing the rail entry) =
  `McpBridge.startHubLink()` -> QR `https://pair.vespertv.app/hub#<link>` (phone-only link, 1 h idle, same secret as the
  Vesper phone page). The relay page `tools/pair_relay/hub.html` (6 languages) sends `hub/list|set|remove|url|add`
  through `/mcp/<link>`; `McpBridge.handle` answers `hub/` before the AI-apps-off check; `HubRemote` runs them
  (attached in main.dart). Links (they can hold a debrid key) only travel on `hub/url`. Relay deployed 2026-11-11 (VPS
  notes): `/hub` route, `img-src https:` on that page only. Tests: `hub_remote_test.dart`, relay `test_ai_link.py`.
- **Row eye** (`screens/archive_screen.dart`): Continue watching / Recently watched (`row.continuations != null ||
  isHistory`) get an eye beside the title; Up from the row = the eye, OK = hide/show. A hidden row is only its title
  line (owner, +718: "less cluttered"): eye + "{n} titles · OK shows them" (touch: Tap), vertical list uses
  `itemExtentBuilder` (`_extentOf`), the lazy jump sums the heights above; `_focusRow` on a hidden row = its eye,
  Down from it = next row, Up from the row below = that eye. Per viewer `vesper_hub_hidden_rows`
  (`StorageService.get/setHubHiddenRows`). `test/archive_row_eye_test.dart`.
- 47 new strings x 5 languages; remote guide rows (sources list, Manage from phone, the eye) + guide.json.
- Settings branch: analyze 16, 1805 tests. In combined test +717.
