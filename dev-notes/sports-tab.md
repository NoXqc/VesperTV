# Sports tab — design + v1 status (2026-10-13)

Roadmap item from CLAUDE.md §13. **v1 is built and committed (test build 1.0.3+221 on the Formuler, not released)** — see "v1 as built"
right below; the rest of this file is the design and the tests behind it.

## v1 as built
- Entry: a **Sports** row in the TV tabs column (under Multiview) opens `SportsScreen` full-screen
  (`lib/screens/sports_screen.dart`). Phone layout has no entry yet.
- Data: `SportsService` (ESPN scoreboard, key-less, one call per league per ESPN date; fetches the day
  either side and filters by *local* date; in-memory cache, 50 s freshness while a game is live).
  Leagues in `models/sports.dart` (`kSportsLeagues`): NHL, NFL, NBA, MLB, NCAAF, WNBA, MLS, EPL, UCL,
  LaLiga, Bundesliga, Serie A, Ligue 1. Logos via ESPN's resizer (~8 KB) and the `/500-dark/` variant
  (falls back to the normal logo on 404) so navy/black logos show on black.
- Matching: `SportsChannelMatcher` — user pick > event channel name (both team names, a date in the
  name must fit) > guide title (one SQL `LIKE` scan per day, `EpgService.findProgrammesByTitle`) >
  exact national-network name. Region bias ranks US/CA/UK feeds first, sinks foreign-tagged ones,
  and drops foreign networks ("RU: TNT"). Measured on trex_5 (57k channels): index 0.3 s on PC,
  32 games matched in 13 ms; NHL 18/18 today, NBA 7/12 (misses = tomorrow, no event channels yet).
- Manual: game dialog lists channels + "Choose a different channel" (chips for team names /
  league / networks, plus a text field) → "Just this game" or "Always for <team>"; stored per viewer
  (`vesper_sports_channel_picks`, game picks expire after 7 days). "Forget my pick" undoes it.
- UI: league chips (+ Edit leagues, Scores shown/hidden), day strip (Yesterday..+6), hero of the
  focused game with team-colour glow, rows Live now / Later today / Final. Explicit Up/Down zones.
- Standings: a centered **Standings** button between the day strip and the hero (was the last league
  chip — owner: hard to find; label names the filtered league, e.g. "NHL standings") opens
  `SportsStandingsScreen` (shared widgets live in `widgets/sports_widgets.dart`). Data:
  `site.api.espn.com/apis/v2/sports/{path}/standings` (note `/apis/v2`, not `/apis/site/v2`), 15 min
  cache, parsed off-isolate (`parseEspnStandings`). ESPN's entries are **not in table order** — sorted
  by `rank` (soccer) / `playoffSeed`, falling back to points/win % when seeds are all 0. Season label
  from the table's `seasonDisplayName` (top-level `season` says 2027 for a finished MLB 2026);
  "Preseason" only for non-soccer `seasonType == 1` (soccer always reports 1). College football
  repeats its stat set per split — keep the first (overall). NHL "Last Ten" has a trailing ", 0".
  Columns per sport, trimmed to fit the width; soccer zone stripes + legend from `note`. D-pad: league
  chips / conference chips / rows (explicit Up/Down, jumpTo scrolling), Left/Right on rows flips
  conference.
- Owner feedback round (2026-10-14, +217..+221):
  - Focus look = the app's gold sheen (`sportsFocusSheen`, same as `_SelectableRow`) on chips and
    cards; *selected* chip = gold text + faint outline, clearly quieter than focus.
  - Game card: **OK plays** the best match (user pick ranks first); no match → the game menu.
    **Hold OK** = game menu (other channels / pick / forget). A small hint under the focused card says
    "Hold OK to pick or swap the channel" (height always reserved, so rows don't jump).
  - Hold-opened menus must swallow the held press: the remote keeps sending Select *repeats* and the
    ambient ActivateIntent accepts repeats, so the menu's first item fired instantly ("hold does
    nothing"). `SwallowHeldActivate` (hold_to_activate.dart) wraps the game menu.
  - League chips: **hold OK = move mode** (‹ › arrows, Left/Right moves, OK/Back done, saved each
    step to `setSportsLeagues`); other chips dimmed + unfocusable meanwhile. Chips are **keyed by
    league id** — unkeyed, the reorder swapped focus nodes between States: focus lost and stale
    "focused" outlines (three at once). `SportsChip` also re-seeds `_focused` when its node changes.
  - Channel picker: the search field's own `FocusNode.onKeyEvent` maps Down → first result, Up →
    suggestion chips, OK → reopen keyboard (Back closes the keyboard but EditableText kept the arrows).
- **My Teams — built 2026-10-14 (+222..+225), owner approved.** On the real 1080p TV the details
  column is only ~300 logical px wide: game rows are three lines (opponent / date / channel) and the
  mini table uses short names and 36 px stat columns — don't widen them back into one line. Code:
  `sports_my_teams_screen.dart` (gets play/menu/match callbacks from `SportsScreen`, so picks and
  player are shared), `SportsFollows` (`sports_follows.dart`, prefs `vesper_sports_followed_teams`,
  `leagueId|teamId` per viewer), `SportsService.teamSchedule` + `parseEspnTeamSchedule`. Schedule JSON
  differs from the scoreboard: `score` is `{displayValue}`, record is `record[0].displayValue`
  ("2-1-0, 4 PTS"), logos in `team.logos[]`, broadcasts `{media: {shortName}}`, no team colours
  (the followed team's own is filled in). Soccer: default = played games only, `?fixture=true` =
  upcoming only → two calls, merged by id. Standings: OK or hold OK on a row = Follow/Unfollow
  dialog, star on followed rows. Original decisions:
  - Entry: a **My Teams** button next to Standings.
  - Layout: **team list on the left + details on the right** (like Standings). Rows: logo, name,
    record, next game. Details: record + standing line, a mini table around the team, the **next
    2 weeks** of games (OK to watch, hold to pick, same as cards). Details pane takes the **team's
    colours** (glow like the hero's `_TeamGlow`).
  - Adding: **from Standings** — hold OK on a team row → Follow/Unfollow. A "+ Add team" row in My
    Teams just opens Standings with that hint. (No separate team picker, no game-menu follow.)
  - **Star** followed teams' games on the cards and sort them first in Live now / Later today.
  - Data: `site.api.espn.com/apis/site/v2/sports/{path}/teams/{id}/schedule` = full season, with
    broadcasts, `team.recordSummary` and `team.standingSummary` ("7th in Pacific Division"), one call
    per team. Check the soccer variant (may need `?fixture=true` for upcoming games). Store followed
    teams per viewer as `{leagueId, teamId}`.
- Not yet: Sports Multiview, phone layout (only My Teams + Standings adapted in 1.0.6), BYOK providers, division view for standings.
- Reference (owner, 2026-10-14): **SportioTV** https://github.com/trenntl/SportioTV/releases/tag/v1.0.6
  has 81 leagues in its sports hub — study how it sources/covers them before adding more leagues.

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

## Test results (2026-10-13, owner's free key)
- **API-SPORTS free plan has NO current season**: `games?league=57&season=2026` (NHL) and NFL
  `season=2026` both return `{"plan": "Free plans do not have access to this season, try from 2022 to
  2024."}`. `games?date=` alone fails ("The Season field is required"). → The free tier is useless
  for live scores/schedules; API-SPORTS can only be a *paid* BYOK option. Key-less ESPN default is
  now the plan of record.
- Confirmed: quota is per sport (hockey and american-football each 100/day, separate counters);
  `/status` did not consume quota; rate-limit headers `x-ratelimit-requests-remaining/-limit` are
  present on counted calls (absent on plan errors); keys are 32 lowercase hex chars → the 16-key
  hex pad works.

## Channel-matching test (2026-10-13, ESPN week Oct 13-19 vs trex_5 / BlckTV via Tuliprox)
- ESPN scoreboard (`site.api.espn.com/apis/site/v2/sports/{hockey/nhl|basketball/nba|football/nfl}/scoreboard?dates=YYYYMMDD`,
  one day per call — a `dates=A-B` range returned an error) works key-less: 91 games, broadcasters
  in `competitions[0].broadcasts[].names` + `geoBroadcasts[].media.shortName`. **US networks only**
  (no TSN/Sportsnet/RDS/TVA) — e.g. Sabres @ Canadiens listed only MSGB.
- Provider: 57k live channels, only 8.3k with an EPG id; **guide horizon ~1 day** (latest programme
  Oct 14 16:00 UTC) → only 21/91 games fell inside the guide.
- **EPG title match** (both team names in a programme starting −45/+20 min): NHL 13/51 overall, but
  13 of the 16 NHL games inside the guide horizon (~80%); NBA 1/5 inside horizon.
- **Channel-NAME match is the strongest signal**: providers pre-name event channels, e.g.
  `NHL | 01 - 6pm Devils at Red Wings`, `NHL: Montreal Canadiens vs Buffalo Sabres @ Oct 14 00:35 :TeliaPlay SE 23`,
  `US (ESPN+ 065) | Washington Capitals vs. Carolina Hurricanes Oct 13 6:15PM ET`,
  `Molson Habs Hockey: Sabres vs. Canadiens @ Oct 13 18:30 :TSN+ 47` (this is how Canadian regional
  coverage shows up). NHL 28/51, NBA 8/26, NFL 3/14 for the whole week — effectively all of
  *today's* NHL games. Caveat: names include stale events (yesterday's) and repeat match-ups → parse
  the date/time in the name or only match games within ~±12 h.
- **Broadcaster-name match is weak**: substring search explodes ("Fox" → 565 channels, "CBS" → CBS
  Drama/Reality); regional US nets mostly absent. Use only an exact canonical map for national nets
  (ESPN, TNT, NBA TV, NHL Network, ABC/NBC/CBS/Fox) as a last fallback.
- → Matching order: (1) event channel names for today's games, (2) EPG titles inside the guide
  horizon, (3) national-network map, (4) user override. One provider tested — others name event
  channels differently; keep the name parser tolerant (`vs`, `vs.`, `at`, `@`, full name or nickname).

## Open questions / tests before building
- [x] **Owner: test the API-SPORTS free tier on the current season.** (Done — no current season, see above.) Sign up at dashboard.api-sports.io,
      then (header `x-apisports-key: <key>`):
      - `GET https://v1.hockey.api-sports.io/status` — plan + requests used today
      - `GET https://v1.hockey.api-sports.io/leagues?search=NHL` — get the NHL league id
      - `GET https://v1.hockey.api-sports.io/games?league=<id>&season=2026` (season = start year)
        and `.../games?date=2026-10-13` — do current-season games and live scores come back, or a
        plan/season error?
      Repeat one call on `v1.american-football.api-sports.io` (NFL) to confirm the per-sport quota.
- [x] Check ESPN scoreboard broadcaster names against the owner's EPG channel names (match quality). (Done — see above.)
- [x] Confirm API-SPORTS key format (hex?) for the custom key pad. (32 lowercase hex.)
- [ ] Pick BYOK #2 for sure (TheSportsDB premium vs. another).

## Windows (1.0.5, 2026-10-14)
Owner tested Sports on a 4K Windows display: no way out (no remote Back) and everything tiny. Fixed in
`widgets/sports_widgets.dart`, all Windows-only or a no-op on TV boxes:
- `SportsScreenFrame` wraps Sports, Standings, My Teams and the channel picker: when the logical
  width exceeds 1440 it lays the screen out at 1440 px and scales it up (FittedBox + MediaQuery
  with scaled size/devicePixelRatio, so logos decode sharp); never shrinks. Esc = maybePop on Windows.
- `SportsBackButton`: a back arrow before each screen title (ExcludeFocus — stays out of the D-pad zones).
- `SportsRowArrows`: mouse ‹ › over each game-card row (per-row ScrollController `_rowScrolls`),
  shown only when there's more that way, ~one screen per click via jumpTo.
- Dialogs (game menu, pick scope) are separate routes and are not scaled.
