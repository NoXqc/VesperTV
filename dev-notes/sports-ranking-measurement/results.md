# Sports ranking measurement — 2026-10-22

Reused the URL-free snapshots from the preserved `codex/sports-matcher-audit`
worktree (reference commit `6cd4da5`). No account configuration was read, no
collector/network requests were made, and no streams/devices were opened.
The fixture week remains October 19–25: 141 distinct games per source, 564
source-games including the owner's full-catalogue control. Three primary scopes
(`owner-2-visible`, `provided-c`, `strong8k-test`) give 423 source-games.
Owner and provided-c are correlated catalogues, not independent providers.

The main comparison uses the **same current matcher and same data**, changing
only its final `distinctCopiesFirst(list, limit)` call to the previous flat
`list.take(limit)` in an ignored generated runner. This isolates ranking from
the other shipped alias/index changes. Both runs require seven guide scans per
source despite running each day with limit 8 and unlimited. Guide coverage
explanations return unknown in this adapter: it never queries the installed
app's EPG database. The guide title queries still use the snapshot SQLite data.

## Main eaadf6f, before the date correction

| Scope | Games with changed first eight | Additions / removals | Copies retained beyond eight |
| --- | ---: | ---: | ---: |
| owner-2 control | 12 | 24 / 24 | 46 |
| owner-2-visible | 7 | 16 / 16 | 25 |
| provided-c | 10 | 23 / 23 | 41 |
| strong8k-test | 36 | 54 / 54 | 82 |

This exposed a precision problem: dated event feeds rejected by the both-team
path could reappear through the one-team fallback, which had no date check.
Examples include the ESPN PLUS 168 October 18/19 NHL listing for later games,
and Strong8K CFL channels labelled **Sat 8th Nov** for October 23/24 fixtures.
The date parser also did not understand ordinal dates such as `8th Nov`.

## Correction and repeat measurement

The team-channel fallback now uses the same date guard as event-name matches.
Both date orders accept `st/nd/rd/th`. Undated team channels still work; valid
current event channels and the existing ±1-day timezone allowance remain.
Guide evidence and explicit user picks can still independently select a channel.
Two production tests cover stale ISO/month-first event feeds, permanent team
feeds, current ordinal dates and the real CFL November-name counterexample.

Matcher SHA-256 after correction:
`e513a2af99a68d66d2b53144485c1fd98ff87c438d352c5cad976166786f4311`.

| Scope | Games with changed first eight | Additions / removals | Copies retained beyond eight |
| --- | ---: | ---: | ---: |
| owner-2 control | 12 | 22 / 22 | 44 |
| owner-2-visible | 7 | 14 / 14 | 23 |
| provided-c | 10 | 22 / 22 | 40 |
| strong8k-test | 19 | 25 / 25 | 40 |

Across the primary scopes, ranking promotes **61 game-channel results**:
25 guide-supported, 14 event-name, 14 team-channel and 8 broadcaster fallbacks.
These are result occurrences, not 61 unique channels or verified broadcasts.
All 61 displaced first-eight entries remain in the complete returned list;
the runner asserts that **every** previously returned flat-cutoff channel is
retained. The full list can exceed eight. Across these scopes it omits 37 fewer
guide candidate occurrences than the flat cutoff (10 + 21 + 6).

[Every ranking addition/removal](deltas.csv) includes reason, title evidence and
review classification. Guide additions have matching title evidence; event-name
additions have name evidence. Team/network additions are explicitly unverified
fallbacks, and must not be presented as guide-confirmed broadcasts. Displaced
entries are retained copies, not unavailable streams. No playback ground truth
was collected.

[Copy-group review](copy-groups.csv) contains all 104 multi-name groups appearing
in the returned results. Inspected names differ by quality, decoration or space;
no ESPN/ESPN+, TSN-number, East/West or country collision was observed in these
groups. The existing identity tests also keep those distinctions. This does not
certify every provider name outside the observed results. Backup markers (`BK`)
and different region tags remain separate, conservatively using extra slots.

## Historical baseline comparison

Compared with the committed original audit `games.csv`, the final first eight
change as follows (includes alias/index fixes since that baseline and the date
correction, so these numbers are **not** ranking-only effects):

| Scope | Changed games | Additions | Removals from first eight |
| --- | ---: | ---: | ---: |
| owner-2 control | 62 | 35 | 85 |
| owner-2-visible | 58 | 28 | 72 |
| provided-c | 61 | 35 | 86 |
| strong8k-test | 57 | 54 | 80 |

[Historical per-channel deltas](historical-deltas.csv) indicate whether each
removed entry is still retained further down. The 240 historical result
occurrences absent from the complete final lists are dated event-feed suggestions
for other days; no historical guide-supported channel is lost. The old audit
labelled team fallbacks as `name`, before the shipped confidence-label change.
All unique wholly removed names were inspected for dates. A lower suggestion
count after removing stale events is a precision correction, not lost coverage.

## CFL: what can and cannot be concluded

All four captured guides contain **zero programmes in the CFL game windows**.
Their latest programme starts stop by October 23 00:14 UTC; the first fixture is
Montreal at Toronto, **Friday October 23, 23:00 UTC (19:00 Toronto)**. The next
fixtures start October 24 at 02:00 and 19:00 UTC. The handoff's Thursday label for
October 23 was a calendar error.

The prior three Strong8K CFL suggestions were November 8 event feeds; the
correction removes all three. The saved schedule has no broadcaster labels for
these games, so no TSN/RDS/CBSSN fallback can be inferred from it. All CFL results
are now empty on these snapshots, correctly avoiding stale-event suggestions.
This **does not verify** CFL matching once a fresh guide reaches kickoff. That
check remains pending on a newly supplied URL-free snapshot/device observation;
no provider credentials were accessed to refresh it, and no guide fixtures were
invented as proof of real coverage.

## Reproduction

From the main checkout with Flutter on PATH:

```powershell
python tools/sports_matcher_audit/ranking.py C:/Users/aarse/VesperTV-matcher-audit
```

The script reads the pinned reference harness using `git show`; it never merges
the reference branch. It copies only `channels.json`, `guide.sqlite`, `status.json`
for four named scopes and the public schedule cache into ignored
`.dart_tool/ranking-audit`. Missing schedule cache entries fail instead of using
the network. Results/logs/raw snapshots stay ignored; only the credential-free
CSV reviews and this report are committed. This is PC metadata testing, not a
Formuler performance or playback test.
