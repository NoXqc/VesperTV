# Sports Trak matching audit — 2026-10-21

Production baseline: `c583bd3`. No files under `lib/` changed for this audit.
This measures **metadata suggestions**, not successful playback or broadcast rights.
See [measured report](sports-matcher-audit/results.md), [every game](sports-matcher-audit/games.csv),
[empty-result table](sports-matcher-audit/misses.csv), and [experiment deltas](sports-matcher-audit/deltas.csv).

## What runs today

`SportsChannelMatcher.shared(epg)` is reused by the Sports hub, live list, fullscreen
side panel and Multiview. `prepare(visibleChannels(category: 'tv'))` builds normalized
names, word postings, canonical network names, normalized EPG-id buckets and channel-id
lookups. Indexing yields every 3,000 channels. Its signature is only **count + first id
+ last id**: changing a middle name, EPG override or order without changing those can
leave stale indexes. This is demonstrated by a harness control, not counted as a real
snapshot incident. Concurrent callers also share mutable index state; not stress-tested here.

`sportsNormalize` lowercases, folds a fixed accent table, transliterates Greek,
turns punctuation into spaces, preserves `+`, collapses whitespace and pads boundaries.
It is phrase matching, not edit-distance matching. Team phrases are short/full names
at least four characters long, plus curated Greek aliases. There is no general city-only,
abbreviation, translated-club or fuzzy alias expansion. The comment about excluding cities
does not actively detect cities: a feed's shortName such as `Boston` still becomes a phrase.
Empty name groups cannot match. A one-word nickname such as `Heat` can be ambiguous.

### Signals and scores

| Order | Signal | Base score and exclusions |
|---|---|---|
| 1 | Saved event pick, otherwise team/series pick | 1,000, if channel id remains in visible index. Event picks expire after seven days; team picks persist. First team's pick wins over the other's. |
| 2 | Channel name has every name group (both teams) | 100; 120 when a recognized date fits. English month/day or ISO date accepted within start date ±1 day. No time-of-day check or sport check. |
| 2b | Team's full name + league token in channel name | 65 + region bias; full name needs two words; foreign-biased channels rejected. This is a fallback without guide confirmation. |
| 3 | Guide title has both teams | 80, minus `min(abs(start difference minutes),60) ~/ 6`, plus region bias. Start must be in game window. |
| 3, weaker | Guide title has `seriesPhrases` | 70 minus time penalty + bias. Team leagues reject a series-only title naming another game **in the supplied batch of that league**. No general sport classifier. |
| 3b | Event-sport channel has series phrase | 60 + bias, at most three non-foreign candidates. Not used for team leagues. |
| 4 | Schedule broadcaster mapped to channel | 50 + bias; at most three channels **per broadcaster**, no guide confirmation. Streaming-only broadcasters skipped. |

Highest score wins for the same channel id. Distinct quality copies remain distinct.
Sort by score descending, then shorter channel name; default return limit is eight.
There is no minimum score threshold. A match has a reason and detail, but neither
validates that the channel is currently showing the game. Name and guide matching do
not reject the wrong sport, replay, preview, commentary or multiplex coverage.

### Broadcasters: `_networkAliases` and `_callSign`

`canonicalChannelKey` strips the first leading provider/region tag and quality tokens,
then sorts the remaining token set. Thus plain ESPN can match its HD copy, but ESPN+
stays distinct. Canonical matching ignores token order and duplicate tokens; decoration
or extra identity tokens can prevent equality. It is separate from `sportsNormalize`.

Only if **no canonical channel exists** does the matcher try `_networkAliases`, or
`_callSign` when no alias exists. `_callSign` accepts K/W plus two or three capitals,
optional -TV/-DT/-CD/-LD and optional space plus station number. It does not handle
arbitrary station branding (`Utah 16`) or CBS/Fox affiliate markets automatically.
Aliases cover regional brands such as MNMT→Monumental, NBC regional variants,
FanDuel→old Bally names, MSG, YES and others. Alias postings are phrase matches;
shorter names are visited first. No fallback to aliases if canonical hits exist but
are subsequently all rejected for region. Existing prefix aliases can include a Plus
or alternate service: these identities must be checked before expanding the map.

`_streamingOnly` excludes e.g. ESPN+, Prime Video, Peacock, Paramount+, DAZN, NFL+,
NBA League Pass and MLB.TV **in the broadcaster path**, not name/guide paths. A
streaming service's presence in a playlist does not prove a numbered event stream.
All `geoBroadcasts` names are collected; market/region metadata is discarded, so the
broadcast list is not a viewer-specific rights list. CFL's scoreboard supplies no
broadcasters today; its matching therefore relies on names and guide data.

### `homeTags` / `_languageTags`

Whole-word channel-name tags determine bias: league `homeTags` or the Greek UI tag
(`el→gr`, the only `_languageTags` entry) gives +20; English/US/CA/UK gives +10;
foreign tags give −30; otherwise zero. Home/Greek wins before the foreign check.
FR/ES/IT UI languages do not prefer their own channels. Group names and actual audio
language are not inspected. Guide and two-team name matches remain eligible with
negative bias; team-channel, series-channel and network fallbacks reject it. Tags
therefore affect both ordering and eligibility, depending on the signal. CFL prefers CA.

## Guide scan and cache

For normal team games, programme **start** must be in `[kickoff−60m, kickoff+30m)`.
Overlap alone is insufficient: an ongoing programme that started earlier is missed.
Fight/tennis/event windows differ (fight +5h, tennis +4h, all-day golf window).
The batch uses the earliest lower and latest upper bound for one day-wide scan.

SQL terms come from only the first name group (home team), series phrases and Greek
stems for both teams. Longer terms containing a previously retained shorter term are
removed, case-sensitively; final normalized checks still require both teams. Terms
are raw strings, while the final comparison is accent/punctuation folded. SQLite LIKE
is ASCII-case-insensitive but does not perform that folding. Therefore a normalized
hit can be lost **before** final matching (real example: Fenerbahçe vs Fenerbahce).
Other games' terms can accidentally rescue it, so whole-day batches matter.

`EpgDatabase.programmesStartingWithTitle` chunks 400 terms, ORs `title LIKE '%term%'`,
selects only channel id, title and times, and supplies a null description. SQL LIKE
wildcards in a term are not escaped. Chunks can return duplicate programmes.
There is no SQL result cap, sport filter, description search or subtitle search.
`EpgService` catches query failures and returns an empty list, indistinguishable
from no listings to the matcher.

`_guideCache` stores the in-flight/completed Future for 15 minutes from launch,
keyed by `lastUpdated`, exact combined time bounds and sorted terms. Same-batch warm
reruns reuse it, including empty results. A successful guide refresh changes the key;
a different batch/filter/window creates another key. Expiry cleanup happens on access.
Errors swallowed by EpgService become cached empty results. Channel-list changes do
not themselves invalidate this cache (but are remapped through the current index).

## Every exclusion point in this pipeline

1. **Schedule/input:** unselected or unresolved league ids never fetch; request/parse
   failure falls back to old cached events or none. ESPN team events require a competition,
   valid home/away teams and dates. `gamesForDay` deduplicates league+event ids and filters
   local date, carrying yesterday's live games only when viewing today. Event sports have
   additional round/session/participant filters. CFL drops malformed/unknown/TBD squads,
   id-zero playoff placeholders and invalid dates; unsupported feed shapes can fail the load.
   TheSportsDB has UTC-day and capped-round limitations (not part of this league sample).
2. **Catalogue:** disabled playlists, hidden groups/channels, restricted viewer allowlists,
   unloaded/failed live catalogues and bad EPG overrides can remove a channel before prepare.
   Own-group moves can affect group visibility. A tab-only collapsed playlist is a different
   setting from hiding actual channels. Saved picks pointing outside the index do not restore them.
3. **EPG ingestion:** unavailable/truncated sources, invalid/missing ids/times, ids outside the
   known catalogue, and retention remove programme rows. App retention is only ended-before−2h
   and starts-after+36h. Refreshes keep previous rows on failure; conflicting sources share
   channel id/start keys. Missing EPG ids and unpaired name-only channels are not inferred here.
4. **Prepare:** cheap signature can retain stale names/id mapping; token postings omit words
   shorter than three characters. A phrase with no indexed words cannot produce channel hits.
5. **Event names:** every group needs one whole phrase; date outside ±1 day rejects a channel.
   Date parsing has limited formats and no year validation beyond extracting month/day.
6. **Team channels:** full name needs multiple words, exact league short-name token, nonnegative bias.
7. **Guide retrieval:** no indexed EPG ids skips SQL; empty search terms, raw LIKE mismatch,
   programme start outside day window, query failure or cached empty result removes candidates.
8. **Guide acceptance:** per-game start window, missing both name groups and series phrases,
   or series-only title naming another batch game rejects a row. Unmapped channel id cannot emit
   a match. `p.channelId` is assumed normalized by EpgService. No sport rejection exists today.
9. **Event-series fallback:** team leagues excluded, negative bias excluded, first three retained.
10. **Broadcaster fallback:** streaming-only skip; canonical/alias/call-sign lookup failure;
    negative region bias; first three accepted per broadcaster. Alias lookup only on zero canonical hits.
11. **Output:** dedup by channel id keeps highest signal; final eight can hide other valid channels.
    Details dialog displays only the first three channel buttons. Auto-play/side-panel play uses
    the first match, so a valid lower-ranked suggestion can be functionally missed without an empty list.
12. **Presentation:** Sports hub retains games with no matches and offers manual picking. Live list
    starts from live games and can reload that selection. Fullscreen My Teams requires followed teams;
    Live now requires live state and saved leagues. Multiview requires live **and nonempty matches**,
    so an unmatched live game actually disappears there. Manual search requires every normalized word,
    scans in channel order, returns at most 200; it is substring matching, not automatic matching.

## Scope and confidence

The harness invokes a generated, import-rewritten copy of the exact production matcher,
with private helpers available to diagnostic code in the same library; SHA-256 is recorded.
No application hooks, toggles, aliases or matching changes are shipped. SQLite queries
use the same conditions and 400-term chunks. Schedule calls run through SportsService
and real provider JSON; subsequent reruns use captured responses.

Catalogue snapshots contain empty playback URLs, synthetic local channel ids, provider
names and normalized EPG ids. No credentials, server URLs, source URLs, logos or stream
URLs are in reports. Raw snapshots/config remain under ignored `.dart_tool/matcher-audit`.
The owner-visible case applies the active Main viewer's group/channel blocklists; there
were no own groups to reconstruct. All other cases are isolated full catalogues, including
the disabled Strong8K test playlist. Picks are intentionally empty; report language is EN.
It does not combine providers into the app's shared EPG-id namespace, tune streams,
model kid profiles or claim broadcast correctness from an EPG title alone.

Full provider EPG history is retained for a seven-day comparison, **unlike the app**.
The `app-window` counterfactual separately applies −2h/+36h at capture time; a wider
date range cannot create future listings the provider has not published. Sources share
catalogue/guide infrastructure; source-game totals are not independent statistical samples.

## Other apps: evidence versus inference

- TiviGlass documents guide-derived sports fixtures and searching title, description and
  channel name; its teams can come from subtitles. It also documents provider-id/name guide
  pairing. These are documented behaviors, not evidence of its internal matcher algorithm.
  [Sports Hub](https://tiviglass.com/guide/search-and-the-sports-hub),
  [guide pairing](https://tiviglass.com/guide/troubleshooting).
- Channels documents using content metadata and guide data, with live-only and sports-talk
  controls. [Channels Sports Section](https://getchannels.com/sports-section/).
- Plex's catalogue schema exposes airing/channel relationships, regions and `is_live`,
  richer signals than a bare XMLTV title. This does not prove a specific Plex sports
  matching algorithm. [Plex FAST schema](https://catalogs-docs.plex.tv/catalog_fast/).
- **Safe to copy conditionally:** use explicit game/subtitle/description metadata with two
  team identities, compatible competition, time and multiplex/replay guards. Improve
  normalized search indexing; keep descriptions distinct from titles. Display fallback
  confidence and guide coverage. Preserve user visibility and choice.
- **Schedule broadcasters:** useful low-confidence fallback already partly implemented.
  Add curated aliases and retain regional/market information; a network's regional feeds,
  Plus channels and local affiliates are not interchangeable. CFL broadcaster enrichment
  needs its own measured sample; no CFL event in this snapshot's guide window.
- **Fuzzier names:** likely a recall strategy in some apps, but undocumented here. Do not
  claim TiviMate or another closed app uses edit distance. City-only and fuzzy nicknames
  can collide across clubs/sports/women/youth teams. Curated league/team-id aliases with
  two-team and competition validation are safer; no blind fuzzy fix is recommended.

Recommendations and measured acceptance/rejection decisions are in the results report.
