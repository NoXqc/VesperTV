# Live TV / Sports Trak navigation visibility (2026-11-04)

Settings > Interface > Tabs has **Hide Live TV** and **Hide Sports Trak**.
Both are device-wide, off by default, independently persisted, and translated in
FR/ES/IT/EL/DE. They use the existing navigation visibility settings pattern.

- Hide Live TV removes the TV tab from the wide navigation rail and phone bar,
  and the Live TV entry/panel in Sports Mode. The remote Guide shortcut respects
  it. Automatic last-channel playback at launch is skipped while Live TV is hidden.
- Hide Sports Trak removes its rail/phone links and turns off Sports Mode.
  Explicitly enabling Sports Mode again unhides Sports Trak. Turning off Hide
  Sports Trak alone keeps Sports Mode off.
- Closing Settings after hiding the active content tab selects the first visible
  tab: TV, Movies, then TV Shows. When all three are hidden, Home renders inside
  the root beside the navigation rail (or above the phone bar), with Settings
  still reachable. Back from Home/Media Hub/Sports also uses a visible tab.
- A hidden startup choice uses the same visible-tab fallback. The startup crash
  guard recovers to TV when available, otherwise Home, avoiding a retry of a
  crashing browse tab. With Live TV hidden, startup Home renders in the root
  rather than a duplicate overlay.

The settings control navigation; saved playlists, favourites and league choices
remain available. Existing Home rows and manual search/playback retain their
current behavior.

Implementation: `AppPreferences` visibility/fallbacks, `StorageService` and
`AppConstants` keys; `TvHomeScreen` rail/phone/Guide/return paths;
`SportsScreen` Sports Mode rail/panel; `StartupRoutes` and `main.dart` startup.
Tests: `navigation_visibility_test.dart`, `startup_routes_test.dart` and
`sports_mode_test.dart` cover persistence, toggling, startup, Guide, phone/wide
navigation and all-hidden Home recovery.

Validation: `16 issues found. (ran in 8.3s)`; full suite
`00:38 +1241: All tests passed!`. No physical-device QA or app build.
