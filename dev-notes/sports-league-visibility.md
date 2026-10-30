# Hide leagues with no games (Codex, 2026-10-30)

Settings > Sports Trak > Hide leagues with no games is off by default and
per viewer. It follows the selected local calendar day, including live games
carried past midnight and the service's existing multi-day tournament rules.
Upcoming, live and completed games all count. This is a display preference;
channel matching, scores, playback and saved league membership are unchanged.

## Data and navigation

With the option enabled, SportsScreen._load requests all saved leagues for
the selected day, even while one league is selected. The existing SportsService
cache/in-flight requests and freshness policies are reused. The resulting full
day determines visibility, then game cards are filtered to the selected league.
A confirmed empty selected league falls back to All; its stored favourite is
retained. With the option off, the previous selected-league-only loading stays.

SportsService.hasReliableSchedule requires successful, usable responses for
all dates needed by that provider/local day. Failed refreshes keep cached games
but cannot establish emptiness. Missing/malformed events fields and wholly
unparseable event lists are unknown. ESPN validation shares its existing decode
on the worker isolate. SportsDB's explicit null events is a valid empty result;
CFL keeps its season-feed success/failure state. Adjacent-date failures leave a
league visible, conservatively. No new HTTP endpoint or polling timer.

_navigationLeagues feeds regular chips, the Sports Mode top-five rail/remaining
bar, and the All dropdown. Standings, My Teams, Edit leagues and saved order
continue to receive the complete list. Focus is restored after a disappearing
league or a top-five boundary change. An active move freezes visible membership
until it finishes; reorder skips hidden neighbours and saves the complete list.

Storage: keySportsHideEmptyLeagues, viewer-scoped; ProfileCopy.sports includes
it. Existing Backup/Transfer includes it automatically. The settings editor
uses TvSwitchListTile and guards writes against a viewer change. FR/ES/IT/EL
strings included. Remote guide/help index updated locally, not deployed.

## Verification

sports_empty_leagues_test.dart covers reliable empty versus failed/unfetched/
malformed schedules, adjacent-day independence/recovery, cache reuse, SportsDB,
live midnight carry-over, profile copy/Backup/Transfer, TV/phone settings access
and all five languages with large text and stale-viewer protection.
sports_mode_test.dart adds regular/Sports Mode phone/TV navigation, unknown
leagues, quiet favourite/all-empty day, Tomorrow, focused removal/top-five
crossing, disabling/restoring, failure recovery and reorder during a refresh.

No APK/version bump, installation or publication. Existing APK529 predates this
and preferred playlist. Physical-device smoke testing still remains.

Full-suite validation exposed a pre-existing calendar logo-cache test race:
sports_schedule_test.dart now supplies path_provider directories and unmounts
the calendar before draining async work. No calendar application code changed.
