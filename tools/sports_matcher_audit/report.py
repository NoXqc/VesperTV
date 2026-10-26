"""Export reviewable, credential-free measurements from the dev harness."""
from collections import Counter
import csv
import datetime as dt
import hashlib
import json
from pathlib import Path

root = Path('.dart_tool/matcher-audit')
destination = Path('dev-notes/sports-matcher-audit')
destination.mkdir(parents=True, exist_ok=True)
rows = [json.loads(line) for line in (root/'results.ndjson').read_text(encoding='utf-8').splitlines()]
baseline = {(r['source'], r['gameKey']): r for r in rows if r['mode'] == 'baseline'}
for mode in ['normalized','description','guarded-description','network-aliases','app-window']:
    assert {(r['source'],r['gameKey']) for r in rows if r['mode']==mode} == set(baseline), f'Incomplete run: {mode}'
variants = {(r['source'], r['gameKey'], r['mode']): r for r in rows}
primary = {'owner-2-visible', 'provided-c', 'strong8k-test'}
selected = [r for r in baseline.values() if r['source'] in primary]


def explanations(row):
    causes = []
    full = baseline.get(('owner-2', row['gameKey']))
    if row['source'] == 'owner-2-visible' and not row['matches'] and full and full['matches']:
        causes.append('matching channels hidden by viewer')
    if row['windowRows'] == 0:
        causes.append('no programmes in captured game-start window')
    alias = variants.get((row['source'], row['gameKey'], 'network-aliases'))
    if not row['matches'] and alias and alias['matches']:
        causes.append('curated broadcaster alias supplies a fallback')
    if row['bothTeamsDescription'] and not row['bothTeamsTitle']:
        causes.append('teams only in description (inspect multiplex/full-game distinction)')
    if not row['matches'] and not causes:
        causes.append(row['cause'])
    return '; '.join(causes) or row['cause']


fields = ['source','league','gameKey','game','startUtc','cause','explanation',
          'windowRows','bothTeamsTitle','bothTeamsDescription','oneTeamTitle',
          'preLimitCandidates','truncated','omittedGuideChannels','dateRejected',
          'matches','networks']


def export(path, data):
    with path.open('w', encoding='utf-8', newline='') as output:
        writer = csv.DictWriter(output, fieldnames=fields, extrasaction='ignore')
        writer.writeheader()
        for original in sorted(data, key=lambda r: (r['source'],r['startUtc'],r['gameKey'])):
            row = {**original, 'explanation': explanations(original)}
            for key in ['matches','networks']:
                row[key] = json.dumps(row[key], ensure_ascii=False)
            writer.writerow(row)


export(destination/'games.csv', baseline.values())
misses = [r for r in selected if not r['matches']]
export(destination/'misses.csv', misses)
delta_rows = []
for row in rows:
    if row['mode'] == 'baseline':
        continue
    old = baseline[row['source'], row['gameKey']]
    before = {m['channelId']:m for m in old['matches']}
    after = {m['channelId']:m for m in row['matches']}
    for channel in sorted(before.keys() | after.keys()):
        kind = 'added' if channel not in before else 'removed' if channel not in after else 'changed'
        if kind == 'changed' and before[channel] == after[channel]:
            continue
        delta_rows.append({'source':row['source'],'mode':row['mode'],'game':row['game'],
                           'gameKey':row['gameKey'],'change':kind,
                           'before':json.dumps(before.get(channel),ensure_ascii=False),
                           'after':json.dumps(after.get(channel),ensure_ascii=False)})
with (destination/'deltas.csv').open('w',encoding='utf-8',newline='') as output:
    writer = csv.DictWriter(output,fieldnames=['source','mode','gameKey','game','change','before','after'])
    writer.writeheader()
    writer.writerows(delta_rows)

def table(headers, data):
    return '\n'.join(['| '+' | '.join(headers)+' |',
                      '| '+' | '.join(['---']*len(headers))+' |'] +
                     ['| '+' | '.join(str(v).replace('|','/').replace('\n',' ') for v in line)+' |' for line in data])

def utc(ms):
    return dt.datetime.fromtimestamp(ms/1000,dt.timezone.utc).strftime('%b %d %H:%M UTC') if ms else 'none'

statuses = [json.loads(p.read_text()) for p in root.glob('*/status.json')]
timings = json.loads((root/'timings.json').read_text())
source_table = []
for s in sorted(statuses,key=lambda s:s['label']):
    source_table.append([s['label'],s.get('channels','—'),s.get('programmes','—'),
                         f"{utc(s.get('minStart'))} – {utc(s.get('maxStart'))}" if s.get('programmes') else '—',
                         s['result'] + (f" HTTP {s['httpStatus']}" if s.get('httpStatus') else '')])
outcomes = []
for source in sorted({r['source'] for r in baseline.values()}):
    data = [r for r in baseline.values() if r['source']==source]
    counts = Counter(r['cause'] for r in data)
    outcomes.append([source,len(data),counts['guide_match'],counts['event_name_match'],
                     counts['fallback_only_unverified'],sum(not r['matches'] for r in data)])
causes = Counter()
for row in misses:
    for explanation in explanations(row).split('; '):
        causes[explanation] += 1

experiment_rows = []
for mode in ['normalized','description','guarded-description','network-aliases','app-window']:
    data = [r for r in rows if r['source'] in primary and r['mode']==mode]
    rescued = sum(bool(r['matches']) and not baseline[r['source'],r['gameKey']]['matches'] for r in data)
    changed = sum(r['matches']!=baseline[r['source'],r['gameKey']]['matches'] for r in data)
    additions = [r for r in delta_rows if r['source'] in primary and r['mode']==mode and r['change']=='added']
    removed = sum(r['source'] in primary and r['mode']==mode and r['change']=='removed' for r in delta_rows)
    suspect = sum(bool(r['suspectMatches']) for r in data)
    experiment_rows.append([mode,rescued,changed,len(additions),removed,suspect])

league_rows = []
for league in sorted({r['league'] for r in selected}):
    data = [r for r in selected if r['league']==league]
    counts = Counter(r['cause'] for r in data)
    league_rows.append([league,len(data),counts['guide_match'],counts['event_name_match'],
                        counts['fallback_only_unverified'],sum(not r['matches'] for r in data)])
ranking_games = sum(r['truncated']>0 for r in selected)
omitted_guide_games = sum(r.get('omittedGuideChannels',0)>0 for r in selected)
markers = ('multiplex','final score','commentary')
naive_counterexamples = [r for r in delta_rows if r['mode']=='description' and
                        r['change']=='added' and any(m in r['after'].lower() for m in markers)]
guarded_counterexamples = [r for r in delta_rows if r['mode']=='guarded-description' and
                          r['change']=='added' and any(m in r['after'].lower() for m in markers)]
naive_scopes = ', '.join(f'{source}: {count}' for source,count in
                         sorted(Counter(r['source'] for r in naive_counterexamples).items()))

report = f"""# Measured Sports Trak matcher results

Captured 2026-10-22 00:19 UTC (Oct 21 evening in Toronto). Fixtures: Oct 19–25, 2026,
**141 distinct games** per source: 14 NFL, 43 NBA, 48 NHL, 3 MLB, 11 EPL, 18 Champions
League, 4 CFL. Seven days deliberately include games outside the downloaded guide;
an unavailable future programme is **not an algorithm failure**.

Production matcher SHA-256: `{(root/'matcher.sha256').read_text().strip()}`.
Generated-library baseline plus isolated experiments; no production matching changes.

## Data availability

{table(['Source','Channels','Programmes','Programme start range','Result'],source_table)}

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

{table(['Source','Games','Guide among top 8','Event-name, no guide in top 8','Fallback only','Empty'],outcomes)}

An event-name suggestion is stronger evidence than a national network, but neither
proves live playback. Fallback-only includes team channels and broadcasters.
The primary comparison excludes the duplicate owner full-catalogue control:
**{len(selected)} source-game opportunities; {len(misses)} empty results**.

{table(['League','Source-games','Guide','Event name','Fallback only','Empty'],league_rows)}

{ranking_games} source-games have more candidates than the final eight; {omitted_guide_games}
omit at least one guide-matched channel at that cutoff. This is a candidate-level
omission, not necessarily a missed game: many omitted channels are quality copies.

## Causes of empty results, ranked

These explanations **overlap**: a game outside guide coverage can still gain a
broadcaster fallback. Counts are source-games, not unique fixtures or summed percentages.

{table(['Cause/evidence','Empty results explained'],causes.most_common())}

Visibility is deliberate, not a reason to reveal hidden channels. A missing guide
listing cannot be repaired by fuzzy text matching. Description evidence includes
one multiplex-only listing; that is not proof of a full-game stream.

See [all empty games and evidence](misses.csv) and [every game's channels, scores,
reason, broadcasts and rejection evidence](games.csv). The per-game CSV includes
both the eight returned matches and candidate counts before final truncation.

## Isolated proposals on the same snapshots

{table(['Experiment','Empty→suggestion','Games changed','Top-8 channel additions','Top-8 removals','Sport-conflict flags'],experiment_rows)}

“Changed” includes a known channel upgrading from network/name to guide evidence.
An empty→suggestion is not automatically a verified correct broadcast.
Top-8 removals can be displaced duplicates, not lost underlying candidates.
Zero sport flags does not certify precision: the classifier is intentionally limited.
[Channel-by-channel deltas](deltas.csv) retain details for adjudication.

Marker review of the naive additions finds **{len(naive_counterexamples)} full-game counterexamples**
across all four scopes ({naive_scopes}):
multiplex or Final Score/commentary channels. The guarded variant adds
{len(guarded_counterexamples)} of those counterexamples. Negative controls also reject wrong sport, replay, Canadian/West
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

{table(['Source','Mode','Prepare ms','Guide SQL ms','Total ms incl diagnostics','Queries'],[(r['source'],r['mode'],r['prepareMs'],r['sqlMs'],r['totalMs'],r['queries']) for r in timings if r['mode'] in ['baseline','normalized']])}

Each mode runs the seven day batches twice (limit 8 then unlimited). Assertions require
only seven guide scans, proving warm reruns reuse the cache. Unlimited results still
retain the production three-per-network cap. The synthetic stale-index control confirms
same count/first/last ids leave a middle renamed channel unchanged; no incidence estimate
is claimed for that bug. Tests are metadata only; no streams were opened.

For the complete algorithm/drop-point writeup and documented competitor comparisons,
see [the audit](../sports-matcher-audit.md). Reproduction: [harness README](../../tools/sports_matcher_audit/README.md).
"""
(destination/'results.md').write_text(report,encoding='utf-8')
print(json.dumps({'games':len(baseline),'primaryEmpty':len(misses),'causes':dict(causes),
                  'experimentRows':experiment_rows}))
