# Compact Sports Trak header - 2026-10-30

Local branch: codex/sports-compact-header, based on main 5138160 / test +533.

- The regular Sports Trak and Sports Mode top strips use existing league
  shortName values (AHL, EPL, UCL, F1, etc.), matching the existing Sports Mode
  sidebar. Full names remain in Edit leagues and the All-leagues menu.
- Removed Prefer highest quality from the strip and its explicit focus order.
  The control is now Settings > Sports Trak > Prefer highest quality.
- Reuses StorageService.getSportsPreferQuality/setSportsPreferQuality and the
  existing per-viewer vesper_sports_prefer_quality key. Existing saved false
  choices remain false; default remains true. No migration or matcher changes.
- Settings page uses the existing TV switch/focus pattern and rejects saves
  from an old viewer after a profile switch. Labels/help have FR/ES/IT/EL.
- Existing SportsScreen.didPopNext refreshes and rematches on return; no new
  refresh mechanism is necessary. This is covered by a real matcher test
  where the game changes from a 4K-first to provider-order HD-first result.
- Remote guide/help index updated locally (87 entries); no deployment.

Coverage: phone/TV Settings entry and saved values; touch/remote toggle;
viewer isolation; compact regular/Mode league labels; Edit leagues retaining
American Hockey League; no dead focus slot after Edit; re-ranking on return.
The existing visibility-settings phone test now scrolls to its destination,
which can be lazily unbuilt below the added quality setting.

Owner requested local commit and merge after validation. No build, version
bump, installation, push or release requested.
Real device appearance/remote acceptance still pending.

Verified: analyzer `16 issues found. (ran in 45.2s)` (baseline infos);
full Flutter suite `00:34 +1090: All tests passed!`; 15 Node help tests pass;
`87 remote-guide answers verified`; git diff --check clean.
