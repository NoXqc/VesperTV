# Sports tab — design (draft, 2026-10-13, not started)

Roadmap item from CLAUDE.md §13. This is the agreed direction so far; nothing is built. Update it as
decisions are made. Status of open questions is at the bottom.

## Goals
- A Sports tab with: **league filter** (NHL, NFL, NBA, MLB, PGA, ...), **My Teams**, **Standings**,
  scoreboard by day, game detail, and a **Watch** button that opens the matching IPTV channel.
- Zero infrastructure cost, no embedded API keys (open-source rule, CLAUDE.md §10).
- Works on Android TV / Fire Stick with a D-pad, on phones, and on Windows.

## Key decisions / findings
1. **BYOK is about keyed APIs only.** VesperTV has no server: every request goes device → provider,
   so a key-less source costs the project nothing either. Don't gate the whole tab behind a key; keys
   unlock *extra* leagues/detail.
2. **API-SPORTS has no WebSocket that we could find** — it is REST, polled. The earlier "use
   WebSockets to save the 100/day quota" plan does not hold.
3. **API-SPORTS quota is 100 requests/day per sport API** (hockey, american-football, basketball,
   baseball are separate hosts, same key) and per *key*, so every device using the same key shares it.
   A 3 h game polled every 60 s = 180 calls → free tier = minutes-old scores, not live.
   **Unverified: whether the free plan includes the current season** (sources conflict). Test below.
   API-SPORTS has **no golf** API.
4. **TheSportsDB is not keyless**: free v1 uses the shared public test key `123` (has changed before),
   30 req/min, heavily truncated results (team next events: 1, home only; day schedule: 3). Livescores
   and v2 are premium ($9/mo). Artwork is mostly fan-made, no stated licence → decorative only, cache
   it, always have a fallback (team initials on team colour).
5. **Fixed 30–60 s "spoiler delay" doesn't fit**: polling is coarser than the delay, and IPTV latency
   varies 5 s – 2 min+ (catch-up/timeshift break any fixed value). Use a **spoiler mode** (hide scores
   until a game is opened / hide the score of the game you're watching) + optional delay slider 0–120 s.
6. **Channel matching uses the user's EPG** (already in SQLite, `EpgDatabase`): find programmes
   overlapping the game start whose title contains both teams (name / nickname / abbreviation), rank
   channels by the API's broadcaster names (TSN, SN, ESPN, TNT, RDS, ...). Show best match +
   "Other channels"; allow a per-user override ("always this channel for team X").

## Provider plan
Pluggable providers behind one internal model, so a provider that breaks is one adapter to disable.

| Layer | Provider | Use |
|---|---|---|
| Default, no key | ESPN public JSON (`site.api.espn.com/apis/site/v2/sports/<sport>/<league>/scoreboard`, `.../standings`) — fallbacks NHL `api-web.nhle.com`, MLB `statsapi.mlb.com` | NHL/NFL/NBA/MLB/PGA/MLS/college: scores, standings, logos, **broadcasts** |
| BYOK #1 | API-SPORTS | Soccer + international leagues, deeper stats |
| BYOK #2 | TheSportsDB premium | Artwork, TV schedule, backup livescores |

Risk: ESPN/NHL endpoints are unofficial/undocumented (Home Assistant's TeamTracker relies on ESPN's).
MLB StatsAPI carries "individual non-commercial use" terms. Revisit if any of them breaks or objects.

```dart
abstract class SportsProvider {
  Set<LeagueId> get leagues;
  bool get needsKey;
  Future<List<Event>> scoreboard(LeagueId league, DateTime day);
  Future<List<StandingGroup>> standings(LeagueId league);
  Future<Event> eventDetail(String id);
}
```

Model: `League`, `Team`, `Event` (with a `competitors` list — **not** home/away only, so golf/F1/UFC
leaderboards fit), `Competitor`, `StandingGroup`. All times stored UTC, converted only for display.

## Request budget (keyed providers)
- One "games for date" call per league per refresh returns every game's score — never one call per game.
- Standings: once per day per league. Game detail: only on demand.
- Poll only while the Sports tab is visible or a My Teams game is live; pause when covered (`RouteAware`),
  backgrounded or asleep.
- Read the provider's remaining-quota response headers, back off automatically, and show
  "N updates left today". Quota exhausted = a real state ("limit reached, resets at …" + cached data).

## Key entry (TV-friendly — no QR code)
Owner: a QR code is impractical for a TV app. Instead:
1. **Need a key less often**: the default layer is key-less, so most users never enter one.
2. **Custom on-screen key pad** for TV (like `widgets/pin_pad.dart`): if the provider's keys are
   hex (API-SPORTS keys look like 32 hex chars — **verify**), a 16-key 0-9/a-f grid with big
   Backspace/Paste/Done is far faster than the system keyboard and sidesteps the Fire OS keyboard
   Back-button problem (CLAUDE.md §10). Physical number keys on the Formuler remote type digits
   directly. Show the key in groups of 4 so it's easy to check against the dashboard.
3. Phones/Windows: normal text field with paste.
4. Optional later: "On your phone or PC, open `http://<box-ip>:<port>`" — a tiny LAN page served by the
   app for pasting the key (typed address, no camera needed). Only if (2) proves insufficient.
- Validate the key on save with a status call (API-SPORTS `/status`; believed not to count against
  quota — verify), and show a clear error: invalid key / no access to this sport / current season not in plan.

## Security
- Store keys with `flutter_secure_storage` (Android Keystore, Windows Credential Manager), never
  SharedPreferences. Keys per app, not per viewer profile.
- Never log keys; redact them from URLs (TheSportsDB puts the key in the path) and request headers.
- Leave keys out of any export/backup; check Android `allowBackup`.
- No default/demo key in the repo.

## State / performance
- `SportsService` is its own `ChangeNotifier`; `TvHomeScreen` must **not** watch it wholesale (same
  rebuild trap as the EPG → use narrow signals like `guideRowsLoaded`).
- Cache scoreboards/standings/teams in sqflite (like `catalog_database.dart`); show cache first, then refresh.
- One shared HTTP client with timeouts and back-off; small cached logos (reuse the poster cache approach).
- **My Teams per viewer profile**, without rewriting Main's storage keys (CLAUDE.md §12).

## UI (TV)
- **League chips** row (user picks which leagues show + order; remembers last).
- **Date strip** (yesterday / today / tomorrow / …), Left/Right changes day.
- **Scoreboard grid**: logos, score or start time, status (LIVE in gold, period + clock),
  "on TSN 1" when a channel matched. Select → game detail.
- **My Teams**: one cross-league row of next/current games; in-app pill when a My Teams game starts
  (like the live island), Select → watch. Later: score toast while watching another channel.
- **Standings**: division / conference / league toggle, My Teams rows highlighted.
- **PGA**: leaderboard view (pos, player, to-par, thru) instead of game cards.
- **Game detail**: score by period, scorers, matched channels, Watch.
- **Settings > Sports**: keys, remaining quota, spoiler mode/delay, leagues shown, channel-match overrides.
- Focus: one `FocusScopeNode` per zone (chips, dates, grid) + explicit D-pad dispatch (CLAUDE.md §10).
- Windows needs its own entry points where the desktop stack differs; the data layer is shared Dart.

## Open questions / tests before building
- [ ] **Owner: test the API-SPORTS free tier on the current season.** Sign up at dashboard.api-sports.io,
      then (header `x-apisports-key: <key>`):
      - `GET https://v1.hockey.api-sports.io/status` — plan + requests used today
      - `GET https://v1.hockey.api-sports.io/leagues?search=NHL` — get the NHL league id
      - `GET https://v1.hockey.api-sports.io/games?league=<id>&season=2026` (season = start year)
        and `.../games?date=2026-10-13` — do current-season games and live scores come back, or a
        plan/season error?
      Repeat one call on `v1.american-football.api-sports.io` (NFL) to confirm the per-sport quota.
- [ ] Check ESPN scoreboard broadcaster names against the owner's EPG channel names (match quality).
- [ ] Confirm API-SPORTS key format (hex?) for the custom key pad.
- [ ] Pick BYOK #2 for sure (TheSportsDB premium vs. another).
