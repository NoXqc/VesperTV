# Measured Sports Trak matcher results

Captured 2026-10-22 00:19 UTC (Oct 21 evening in Toronto). Fixtures: Oct 19–25, 2026,
**141 distinct games** per source: 14 NFL, 43 NBA, 48 NHL, 3 MLB, 11 EPL, 18 Champions
League, 4 CFL. Seven days deliberately include games outside the downloaded guide;
an unavailable future programme is **not an algorithm failure**.

Production matcher SHA-256: `2558aeec5959381e8648d4cc4615049098bb9578534f4facb38e020772a6112a`.
Generated-library baseline plus isolated experiments; no production matching changes.

## Data availability

| Source | Channels | Programmes | Programme start range | Result |
| --- | --- | --- | --- | --- |
| owner-2 | 28758 | 211537 | Oct 20 12:00 UTC – Oct 22 12:00 UTC | ok |
| owner-2-visible | 2908 | 211537 | Oct 20 12:00 UTC – Oct 22 12:00 UTC | ok |
| provided-a | — | — | — | unavailable |
| provided-b | — | — | — | unavailable HTTP 403 |
| provided-c | 28758 | 211255 | Oct 21 00:00 UTC – Oct 23 00:00 UTC | ok |
| strong8k-test | 57086 | 227833 | Oct 21 00:14 UTC – Oct 23 00:14 UTC | ok |

`owner-2-visible` applies the active Main viewer's saved hide rules (25,850 channels
removed; no custom groups). `owner-2` is its full-catalogue control. Strong8K is the
saved disabled dom OG test account, loaded only inside this audit (app settings untouched). Supplied account A
failed DNS resolution; B returned HTTP 403 (same-host HTTPS also failed transport).
No substitute endpoints or credentials
were guessed. No game metrics are fabricated for inaccessible accounts.

The owner and supplied C catalogues have identical name/EPG-id ordering; their guide
snapshots differ. They are correlated observations, not independent providers.
Raw provider history is retained for the multi-day audit. `app-window` applies the
app's −2h/+36h retention separately. These are PC timings, not Formuler measurements.

## Baseline outcomes

| Source | Games | Guide among top 8 | Event-name, no guide in top 8 | Fallback only | Empty |
| --- | --- | --- | --- | --- | --- |
| owner-2 | 141 | 35 | 8 | 88 | 10 |
| owner-2-visible | 141 | 21 | 4 | 81 | 35 |
| provided-c | 141 | 28 | 17 | 86 | 10 |
| strong8k-test | 141 | 12 | 46 | 65 | 18 |

An event-name suggestion is stronger evidence than a national network, but neither
proves live playback. Fallback-only includes team channels and broadcasters.
The primary comparison excludes the duplicate owner full-catalogue control:
**423 source-game opportunities; 63 empty results**.

| League | Source-games | Guide | Event name | Fallback only | Empty |
| --- | --- | --- | --- | --- | --- |
| cfl | 12 | 0 | 0 | 3 | 9 |
| eng.1 | 33 | 0 | 10 | 9 | 14 |
| mlb | 9 | 0 | 2 | 7 | 0 |
| nba | 129 | 25 | 18 | 86 | 0 |
| nfl | 42 | 1 | 3 | 34 | 4 |
| nhl | 144 | 28 | 15 | 92 | 9 |
| uefa.champions | 54 | 7 | 19 | 1 | 27 |

73 source-games have more candidates than the final eight; 39
omit at least one guide-matched channel at that cutoff. This is a candidate-level
omission, not necessarily a missed game: many omitted channels are quality copies.

## Causes of empty results, ranked

These explanations **overlap**: a game outside guide coverage can still gain a
broadcaster fallback. Counts are source-games, not unique fixtures or summed percentages.

| Cause/evidence | Empty results explained |
| --- | --- |
| no programmes in captured game-start window | 45 |
| matching channels hidden by viewer | 25 |
| curated broadcaster alias supplies a fallback | 14 |
| teams only in description (inspect multiplex/full-game distinction) | 1 |

Visibility is deliberate, not a reason to reveal hidden channels. A missing guide
listing cannot be repaired by fuzzy text matching. Description evidence includes
one multiplex-only listing; that is not proof of a full-game stream.

See [all empty games and evidence](misses.csv) and [every game's channels, scores,
reason, broadcasts and rejection evidence](games.csv). The per-game CSV includes
both the eight returned matches and candidate counts before final truncation.

## Isolated proposals on the same snapshots

| Experiment | Empty→suggestion | Games changed | Top-8 channel additions | Top-8 removals | Sport-conflict flags |
| --- | --- | --- | --- | --- | --- |
| normalized | 0 | 0 | 0 | 0 | 0 |
| description | 0 | 67 | 39 | 31 | 0 |
| guarded-description | 0 | 23 | 38 | 31 | 0 |
| network-aliases | 14 | 36 | 46 | 2 | 0 |
| app-window | 0 | 29 | 45 | 109 | 0 |

“Changed” includes a known channel upgrading from network/name to guide evidence.
An empty→suggestion is not automatically a verified correct broadcast.
Top-8 removals can be displaced duplicates, not lost underlying candidates.
Zero sport flags does not certify precision: the classifier is intentionally limited.
[Channel-by-channel deltas](deltas.csv) retain details for adjudication.

Marker review of the naive additions finds **13 full-game counterexamples**
across all four scopes (owner-2: 12, provided-c: 1):
multiplex or Final Score/commentary channels. The guarded variant adds
0 of those counterexamples. Negative controls also reject wrong sport, replay, Canadian/West
USA Network, Plus services and dated event channels under a network alias. This does
not establish universal precision; unlabelled replays and multilingual metadata remain risks.

1. **Coverage / visibility first:** expose coverage time and fallback confidence; respect
   hidden groups. Refreshing may help today/tomorrow, never guarantees future days.
   `app-window` shows how much historical evidence normal app retention removes.
   Do not widen retention or unhide channels as a matching “fix” without a separate decision.
2. **Curated broadcaster aliases:** dev-only map tests CBSSN→CBS Sports Network,
   NFL Net→NFL Network, NHL Net→NHL Network, NBC Sports Phil→NBC Sports Philadelphia,
   USA Net→US USA Network. Keep the low network score; require US tagging and exact
   canonical network identity. Skip foreign, Plus/alternate, dated-event and West
   services (only generic/East USA Network is allowed), avoiding Canadian namesakes. This
   supplies useful fallbacks without claiming guide confirmation. Review every new
   channel in deltas.csv before proposing a production patch. No Fox/CBS affiliate
   expansion, streaming-service renaming or blanket TSN/Sportsnet expansion was added.
3. **Description matching:** reject the naive concatenation proposal. Real data adds
   Canal+ Multiplex and BBC Final Score/commentary as if each were the full game.
   The guarded experiment rejects those and replay/news markers, requires exactly
   one simultaneous fixture and compatible sport metadata. Synthetic controls include
   wrong-sport, replay and multiplex false matches. It still needs multilingual
   adjudication and device performance measurements before shipping.
4. **Normalized SQL retrieval:** real Fenerbahçe listings can be lost before normalized
   matching. The experiment keeps final rules unchanged and recovers five alternate channels
   in the owner full-catalogue control, but none in the primary visible/test comparisons.
   The naive full-window normalization scan costs much
   more CPU than baseline SQL: prefer a persisted normalized title index or carefully
   curated raw variants. No broad fuzzy/city-only expansion was tested or recommended.
5. **Ranking:** duplicate quality variants can occupy eight slots. This audit records
   omitted guide candidates and all final-limit truncations; no guessed ranking change
   is shipped. A future proposal should group copies while preserving user choice,
   rather than deleting lower-ranked international coverage.

## Timing and cache

| Source | Mode | Prepare ms | Guide SQL ms | Total ms incl diagnostics | Queries |
| --- | --- | --- | --- | --- | --- |
| owner-2 | baseline | 131 | 445 | 2579 | 7 |
| owner-2 | normalized | 113 | 8966 | 9037 | 7 |
| owner-2-visible | baseline | 14 | 437 | 2524 | 7 |
| owner-2-visible | normalized | 14 | 8945 | 9003 | 7 |
| provided-c | baseline | 104 | 312 | 2024 | 7 |
| provided-c | normalized | 101 | 5786 | 5838 | 7 |
| strong8k-test | baseline | 268 | 338 | 2170 | 7 |
| strong8k-test | normalized | 261 | 6270 | 6330 | 7 |

Each mode runs the seven day batches twice (limit 8 then unlimited). Assertions require
only seven guide scans, proving warm reruns reuse the cache. Unlimited results still
retain the production three-per-network cap. The synthetic stale-index control confirms
same count/first/last ids leave a middle renamed channel unchanged; no incidence estimate
is claimed for that bug. Tests are metadata only; no streams were opened.

For the complete algorithm/drop-point writeup and documented competitor comparisons,
see [the audit](../sports-matcher-audit.md). Reproduction: [harness README](../../tools/sports_matcher_audit/README.md).
