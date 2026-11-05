# Requested soccer competitions (2026-11-04)

The owner's list contains 13 competitions. None was already in the league bank at
`71689ba` (1.0.56+611). The existing Carabao Cup is not the EFL Trophy or Premier
League Cup; men's EURO and Women's Champions League are also separate entries.
Additions stay optional in Sports > Edit leagues; existing selections/defaults stay
unchanged. Competition names follow the bank's existing proper-name convention.

## ESPN additions

Checked the public scoreboard both without a date (to detect frozen feeds) and on
a known match date; also checked standings. These use the existing ESPN adapter.

| Competition | Bank id / ESPN slug | Fixture check | Standings |
| --- | --- | --- | --- |
| FA Community Shield | `eng.charity` | 2026-08-16, Manchester City at Arsenal | No table |
| National League | `eng.5` | 2026-11-07, Tamworth at Gateshead | 24 teams |
| EFL Trophy | `eng.trophy` | 2026-11-03, 4 games | 64 group-stage teams |
| Women's League Cup (England) | `eng.w.league_cup` | 2026-11-01, 5 games | 23 group-stage teams |
| UEFA Women's Europa Cup | `uefa.w.europa` | 2026-11-10, Wolfsburg at Feyenoord | No table |
| UEFA Women's European Championship | `uefa.weuro` | 2025-07-27 final, Spain at England | 16 teams (2025) |

ESPN currently calls the English women's cup **WSL Players Cup**. The bank uses
the sponsor-independent Women's League Cup name to cover the request's older
FA Women's League Cup wording. Unlike the Community Shield and Women's Europa
Cup, it and the EFL Trophy have group-stage standings, so their table button stays
available.

Women's EURO's default response is still the 2025 final because it is between
editions, not an abandoned annual feed. [UEFA confirms the next finals are in
summer 2029](https://www.uefa.com/womenseuro/news/02a2-1fda09d464bd-38334f35f773-1000--women-s-euro-2029-all-you-need-to-know/).
No 2026 fixtures are invented; this entry is normally empty until the next edition.

Source patterns (public, no key):

- `https://site.api.espn.com/apis/site/v2/sports/soccer/{slug}/scoreboard?dates=YYYYMMDD`
- `https://site.api.espn.com/apis/v2/sports/soccer/{slug}/standings`
- [ESPN soccer league catalogue](https://sports.core.api.espn.com/v2/sports/soccer/leagues?limit=1000)

## TheSportsDB additions

These competitions are absent from ESPN's soccer catalogue. Their `espnPath` is
only a sport/path identifier; `sportsDbId` routes all requests to TheSportsDB.
Use the existing free public `123` endpoints, never a paid or personal key.

| Competition | Bank id | TheSportsDB id | Checked |
| --- | --- | --- | --- |
| Chilean Primera B | `chi.2` | `4899` | 2026 season; 2 games on Nov 1; 5 table rows |
| Serie A Women | `ita.w.1` | `5205` | 2026-27; 3 games on Nov 1; Nov 7 next match; 5 table rows |
| UEFA Youth League | `uefa.youth` | `5417` | 2026-27; Nov 4 games; Nov 24 next match; no usable free table |

TheSportsDB free data has final scores/schedules, no live minute/box score, and
only the top five table rows. A day response is capped at three fixtures; the
existing `SportsDbSource.roundUrls` expansion fetches the full round when possible.
It cannot fill missing provider records. Primera B's next-game endpoint was null
after the regular season; future postseason fixtures depend on provider updates.

Source: [TheSportsDB soccer catalogue](https://www.thesportsdb.com/sport/soccer?all=1),
[Primera B 2026](https://api.thesportsdb.com/season/4899-chile-primera-b/2026),
[Serie A Women 2026-27](https://api.thesportsdb.com/season/5205-italy-serie-a-women/2026-2027),
[Youth League 2026-27](https://api.thesportsdb.com/season/5417-uefa-youth-league/2026-2027).

## Spain: group entries

The three requested tiers are not three single national feeds: Primera Federación
has two groups, Segunda Federación five, and Tercera Federación eighteen. They
are separate optional entries under **Spain**, with stable ids per tier/group;
this keeps schedules and tables in the correct group without a new adapter or
combining unrelated tables. No historical Segunda B ids are reused: TheSportsDB
also has old `4673` / `4750` records that stopped in 2020-21 / 2019-20.

| Tier | Bank ids | TheSportsDB ids |
| --- | --- | --- |
| Primera Federación, Groups 1–2 | `esp.3.1`–`esp.3.2` | `5086`, `5088` |
| Segunda Federación, Groups 1–5 | `esp.4.1`–`esp.4.5` | `5087`, `5089`, `5090`, `5091`, `5092` |
| Tercera Federación, Groups 1–18 | `esp.5.1`–`esp.5.18` | `5538`–`5555`, in group order |

Badges and group ids come from the complete TheSportsDB soccer catalogue linked
above. Each group's November 1 day response (October 31 for Primera Group 1,
Segunda Group 3 and Tercera Group 15) and default table were checked on the
free API. All 25 groups returned 2026-27 table rows. These use
the same three-fixture day cap / round expansion and five-row table as the other
TheSportsDB soccer leagues.

## Premier League Cup: pending a supported feed

The [Premier League's own explanation](https://www.premierleague.com/en/youth-competitions/u21/premier-league-cup-explained)
identifies this as the Under-21 cup. It is not the Carabao Cup or the National
League Cup. No matching competition was found in ESPN's 220-league soccer API
catalogue or TheSportsDB's 702-entry soccer website catalogue. Free catalogue
API searches are capped, so the complete website list was checked too.
Do not add a guessed slug that would leave users with an empty/broken league.
A new source/adapter or new coverage in either existing provider is needed.

## Validation

The soccer/all schedule regression previously used `eng.trophy` as its unknown
competition. It now uses the synthetic `eng.test_cup` so it continues to exercise
fallback metadata after EFL Trophy becomes a known bank entry.

- Added 12 requested competitions as 34 optional bank entries (25 Spanish groups).
- Live response parser smoke: 28 new TheSportsDB leagues, 78 fixtures and 27
  tables parsed through the app's existing Dart adapters; team names, league ids,
  final scores and capped-day round URLs checked against the responses.
- Full rounds checked: Youth League 18 fixtures, Serie A Women 6, Primera Group 2
  10, Segunda Group 1 9 and Tercera Group 1 9. These are whole-round counts across
  multiple dates; the existing service retains only the selected UTC day.
- `flutter analyze`: `16 issues found. (ran in 7.8s)` (existing infos only).
- `flutter test --no-pub --reporter compact`: `00:39 +1229: All tests passed!`
- No app build, physical-device QA, version bump, push or release.
