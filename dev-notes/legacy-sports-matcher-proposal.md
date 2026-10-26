> Historical Sports Trak matching proposal, merged for reference on 2026-10-26. This is not the current task list; consult CLAUDE.md and current matcher code.

# Proposal: improve Sports Trak channel matching

**Status:** Proposed, based on the measured audit at `9adbc7f`.
**Branch:** `codex/sports-matcher-audit`.
**Scope:** Recommendations and development experiments. Production matching is unchanged.

## Evidence

The audit ran 141 fixtures over Oct 19–25, 2026 across NFL, NBA, NHL, MLB, EPL,
Champions League and CFL. The primary comparison covers the owner's visible
channels, supplied account C and the Strong8K test account: **423 source/game
checks, with 63 empty results**. The owner's full catalogue is a separate control.

| Finding | Empty results explained |
| --- | ---: |
| No programmes in the captured game-start window | 45 |
| Matching channels excluded by the viewer's hide settings | 25 |
| Narrow broadcaster aliases supply an additional fallback | 14 |
| Team names appear only in a description, with multiplex evidence | 1 |

These causes overlap. A network fallback can help when a guide listing is absent.
A hidden channel is an intentional exclusion. A suggested channel is not proof
that a stream plays or that its regional feed carries the game.

The provider guides span about 48 hours; the app retains ended programmes for two
hours and future starts for 36 hours. Historical and future fixture dates therefore
include expected coverage gaps. Two supplied accounts were inaccessible; results
must not be generalized to those accounts or to every provider.

## Recommended first patch: narrow broadcaster aliases

Promote the following mappings from the dev harness after reviewing their deltas:

| Schedule label | Channel identity |
| --- | --- |
| CBSSN | CBS Sports Network |
| NFL Net | NFL Network |
| NHL Net | NHL Network |
| NBC Sports Phil | NBC Sports Philadelphia |
| USA Net | US USA Network, generic or East feed |

The experiment recovers **14 source/game cases across 10 distinct fixtures**:
nine on the owner's visible list, three on supplied C and two on Strong8K.
It adds 46 channels to the primary top-eight results and displaces two entries.
Review those displaced entries as well as additions before changing production.

Required safeguards:

- Apply only when the original canonical broadcaster lookup has no hits.
- Require a US tag and the exact canonical network identity. Permit only the
  explicitly checked provider decoration; do not match dated event-channel names.
- Exclude foreign, Plus, alternate and USA Network West/Canada services.
- Preserve the existing low network score, three-per-broadcaster cap, final
  eight-result limit, saved picks and hidden-channel restrictions.
- Keep the result labelled as a broadcaster fallback, without guide confirmation.

The captured additions agree with the schedule's network labels. Country,
alternate-feed and stale-event negative controls pass. Actual regional broadcast
availability still needs a device check; do not expand this into arbitrary
Fox/CBS affiliates or numbered streaming-service channels.

## Next patches, kept separate

### 1. Explain coverage and match confidence

Distinguish a guide-confirmed listing from a team-channel/network fallback, and
show when the guide does not cover the fixture time. An empty match should not
silently imply that the provider has no broadcast. Keep manual channel picking.
Do not expose or restore hidden channels, and do not expand EPG retention as part
of this patch. Reuse translated wording across the Sports hub, live list,
fullscreen side panel and Multiview where applicable.

### 2. Make channel-index invalidation reliable

`prepare` currently compares only channel count and the first/last ids. A synthetic
control proves that changing a middle name can leave the index stale. Use a
catalogue revision that also changes when names, order or EPG overrides change,
or another measured invalidation scheme. No real miss count is attributed to
this defect. Preserve indexing yields and shared matcher/cache reuse.

### 3. Evaluate guarded description matching

Reject naive title/description concatenation: it introduces **13 identifiable
multiplex/Final Score/commentary counterexamples** across the audit scopes.

The guarded experiment preserves existing title matches, requires both teams and
compatible sport metadata, rejects multiple simultaneous fixtures, and excludes
known replay/news/multiplex markers for new description-derived matches. It rejects
all 13 identified counterexamples and passes synthetic wrong-sport/replay controls.
In the primary comparison it changes 23 games but resolves no empty game; it can
improve evidence and channel choice without reducing the empty-result count.

Before promotion, review every addition and displacement, add multilingual replay
and round-up counterexamples, and measure on a TV box. Unlabelled replays remain a
risk. Keep descriptions as separate evidence, with their source and match reason.

### 4. Improve normalized guide retrieval only if justified

Raw SQL LIKE can miss an accented title before the normalized comparison runs.
The Fenerbahçe example recovers five alternate channels in the full-catalogue
control, with no new primary matches. The prototype's whole-window normalization
scan is much more expensive than baseline SQL on this PC.

Evaluate indexed normalized titles or tightly curated raw aliases. Benchmark
ingestion, database size, cold search and warm cache reuse before choosing a design.
Do not ship the scan prototype or broaden names to arbitrary cities/edit distance.

### 5. Review ranking and duplicate copies

Seventy-three primary checks exceed eight candidates; 39 omit a guide-matched
channel at the cutoff. Many omissions are quality copies. Measure any proposal
to group equivalent channel copies, retaining a way to select each stream.
Do not assume these counts represent 39 missed games or lower all foreign feeds.

## Acceptance checks for each future implementation

1. Run the frozen corpus through baseline and candidate code; export additions,
   removals, score/reason changes and empty-result counts for every game/source.
2. Manually adjudicate all new channel identities and any displaced valid choices.
   Preserve known correct matches; reject wrong sport, opponents, replay, multiplex,
   region, alternate feed and stale event names. A zero keyword-conflict count
   alone does not establish correctness.
3. Preserve saved picks, visibility rules, Greek/home-country preferences and CFL
   behavior. The current CFL sample lacks guide-window coverage, so collect a
   real CFL game-window sample before claiming a CFL improvement.
4. Keep warm reruns at one scan per unchanged day batch, invalidate on guide refresh,
   and compare cold indexing/search costs on the same PC and a connected TV box.
5. Run the project checks: analyze at the 17-info baseline and the complete test
   suite passing. Check the shared entry points on a box before release work.

Implement each patch on its own branch/change. This proposal includes no build,
installation, merge, push or release.

## Supporting material

- [Measured outcomes and experiment results](dev-notes/sports-matcher-audit/results.md)
- [Every empty result and its evidence](dev-notes/sports-matcher-audit/misses.csv)
- [Every game's matched channels and scores](dev-notes/sports-matcher-audit/games.csv)
- [Channel additions, removals and reason changes](dev-notes/sports-matcher-audit/deltas.csv)
- [Current algorithm, exclusion points, caches and competitor comparison](dev-notes/sports-matcher-audit.md)
- [Development harness and reproduction steps](tools/sports_matcher_audit/README.md)
