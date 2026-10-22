"""Offline ranking measurement using the preserved audit harness and safe snapshots.

Never reads account configuration or opens streams. Run from the repository root:
python tools/sports_matcher_audit/ranking.py C:/Users/aarse/VesperTV-matcher-audit
The reference Git branch is read, never merged or modified.
"""
import csv
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
REFERENCE = '6cd4da5'  # preserved codex/sports-matcher-audit harness/baseline
OUTPUT = ROOT / '.dart_tool/ranking-audit'


def reference(path):
    return subprocess.check_output(
        ['git', 'show', f'{REFERENCE}:{path}'], cwd=ROOT).decode('utf-8')


def generate(flat):
    source = ROOT / 'lib/services/sports_channel_matcher.dart'
    code = source.read_text(encoding='utf-8')
    if flat:
        marker = 'out[key] = distinctCopiesFirst(list, limit);'
        assert code.count(marker) == 1, 'Matcher changed: re-review cutoff adapter'
        code = code.replace(marker, 'out[key] = list.take(limit).toList();')
    lines = []
    for line in code.splitlines():
        if line.startswith("import '") and not line.startswith("import 'dart:"):
            spec = line.split("'")[1]
            if not spec.startswith('package:'):
                relative = (source.parent / spec).resolve().relative_to(ROOT / 'lib')
                line = line.replace(spec, 'package:nox_iptv/' + relative.as_posix())
        lines.append(line)
    imports = """import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nox_iptv/services/sports_service.dart';
"""
    extra = reference('tools/sports_matcher_audit/runner.dart.inc')
    # Only run the production baseline, not the old experimental modes/controls.
    start = extra.index("      for (final mode in [")
    end = extra.index('      ]) {', start) + len('      ]) {')
    extra = extra[:start] + "      for (final mode in ['baseline']) {" + extra[end:]
    extra = extra.replace('.dart_tool/matcher-audit', '.dart_tool/ranking-audit')
    # Ranking does not depend on the coverage explanation. The historic adapter
    # predates that API: never let it fall through to the app's own EPG database.
    extra = extra.replace('  int queries = 0;', '''  @override
  Future<double?> guideCoverageAt(DateTime at) async => null;
  int queries = 0;''')
    extra = extra.replace("'channelId': m.channel.id,",
                          "'channelId': m.channel.id, 'copyKey': channelCopyKey(m.channel.name),")
    # Cached schedules only. Missing cache entries are failures, never network requests.
    start = extra.index('      try {\n        final response =')
    end = extra.index('\n    }));', start)
    extra = extra[:start] + "      throw StateError('Missing cached schedule');" + extra[end:]
    return imports + '\n'.join(lines) + '\n' + extra


def read_rows(path):
    return {(r['source'], r['gameKey']): r for r in
            map(json.loads, path.read_text(encoding='utf-8').splitlines())
            if r['mode'] == 'baseline'}


def export(flat, current):
    assert flat.keys() == current.keys()
    destination = ROOT / 'dev-notes/sports-ranking-measurement'
    destination.mkdir(parents=True, exist_ok=True)
    changes = []
    summary = {}
    cfl = []
    groups = {}
    for key, after in current.items():
        before = flat[key]
        # Current results contain copies AFTER the distinct leaders; compare the
        # visible first eight separately from copies retained further down.
        old = {m['channelId']: m for m in before['matches'][:8]}
        new = {m['channelId']: m for m in after['matches'][:8]}
        retained = {m['channelId'] for m in after['matches']}
        assert old.keys() <= retained, 'A previously shown channel was lost'
        for m in after['matches']:
            groups.setdefault((key[0], m['copyKey']), set()).add(m['channel'])
        stat = summary.setdefault(key[0], dict(games=0, changed=0, added=0,
                                               removed=0, extraCopies=0,
                                               oldOmittedGuide=0, newOmittedGuide=0))
        stat['games'] += 1
        stat['changed'] += old.keys() != new.keys()
        stat['added'] += len(new.keys() - old.keys())
        stat['removed'] += len(old.keys() - new.keys())
        stat['extraCopies'] += max(0, len(after['matches']) - 8)
        stat['oldOmittedGuide'] += before['omittedGuideChannels']
        stat['newOmittedGuide'] += after['omittedGuideChannels']
        for change, ids, matches in [('added', new.keys() - old.keys(), new),
                                     ('removed', old.keys() - new.keys(), old)]:
            for channel in sorted(ids):
                m = matches[channel]
                changes.append(dict(source=key[0], game=after['game'],
                                    startUtc=after['startUtc'], change=change, **m,
                                    review=('retained after leaders' if change == 'removed'
                                            else 'guide title supports game; playback unverified'
                                            if m['reason'] == 'guide'
                                            else 'name evidence; playback unverified'
                                            if m['reason'] == 'name'
                                            else 'unverified fallback, not guide confirmation')))
        if after['league'] == 'cfl':
            cfl.append({k: after[k] for k in ['source', 'game', 'startUtc',
                        'windowRows', 'bothTeamsTitle', 'cause', 'matches', 'networks']})
    (OUTPUT / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    (OUTPUT / 'cfl.json').write_text(json.dumps(cfl, indent=2), encoding='utf-8')
    with (destination / 'copy-groups.csv').open('w', encoding='utf-8', newline='') as handle:
        writer = csv.writer(handle)
        writer.writerow(['source', 'copyKey', 'names'])
        for (source, key), names in sorted(groups.items()):
            if key and len(names) > 1:
                writer.writerow([source, key, json.dumps(sorted(names), ensure_ascii=False)])
    with (destination / 'deltas.csv').open('w', encoding='utf-8', newline='') as handle:
        fields = ['source', 'game', 'startUtc', 'change', 'channel', 'channelId',
                  'copyKey', 'reason', 'score', 'detail', 'review']
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(changes)
    historic = {(r['source'], r['gameKey']): r for r in csv.DictReader(io.StringIO(
        reference('dev-notes/sports-matcher-audit/games.csv')))}
    historical = {}
    historical_changes = []
    for key, row in current.items():
        assert key in historic, 'New fixture: historical baseline not comparable'
        old_matches = {m['channelId']: m for m in json.loads(historic[key]['matches'])}
        new_matches = {m['channelId']: m for m in row['matches'][:8]}
        old, new = old_matches.keys(), new_matches.keys()
        stat = historical.setdefault(key[0], dict(changed=0, added=0, removed=0))
        stat['changed'] += old != new
        stat['added'] += len(new - old)
        stat['removed'] += len(old - new)
        retained = {m['channelId'] for m in row['matches']}
        for change, ids, matches in [('added', new - old, new_matches),
                                     ('removed', old - new, old_matches)]:
            for channel in sorted(ids):
                m = matches[channel]
                historical_changes.append(dict(source=key[0], game=row['game'],
                    startUtc=row['startUtc'], change=change, channel=m['channel'],
                    reason=m['reason'], detail=m.get('detail'),
                    retained=channel in retained))
    with (destination / 'historical-deltas.csv').open('w', encoding='utf-8', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=['source', 'game', 'startUtc',
            'change', 'channel', 'reason', 'detail', 'retained'])
        writer.writeheader()
        writer.writerows(historical_changes)
    (OUTPUT / 'historical-summary.json').write_text(
        json.dumps(historical, indent=2), encoding='utf-8')
    print(json.dumps(summary, indent=2))


def main():
    snapshot = Path(sys.argv[1]).resolve() / '.dart_tool/matcher-audit'
    OUTPUT.mkdir(parents=True, exist_ok=True)
    # Explicit allowlist: never copy accounts.json, retry data or collector configs.
    for label in ['owner-2', 'owner-2-visible', 'provided-c', 'strong8k-test']:
        folder = OUTPUT / label
        folder.mkdir(exist_ok=True)
        for name in ['channels.json', 'guide.sqlite', 'status.json']:
            shutil.copyfile(snapshot / label / name, folder / name)
    shutil.copytree(snapshot / 'schedule', OUTPUT / 'schedule', dirs_exist_ok=True)
    source = ROOT / 'lib/services/sports_channel_matcher.dart'
    (OUTPUT / 'matcher.sha256').write_text(hashlib.sha256(source.read_bytes()).hexdigest())
    for mode in ['flat', 'current']:
        runner = OUTPUT / 'runner_test.dart'
        runner.write_text(generate(mode == 'flat'), encoding='utf-8')
        with (OUTPUT / f'{mode}.log').open('w', encoding='utf-8') as log:
            subprocess.run(['flutter.bat', 'test', '--no-pub', str(runner),
                            '--plain-name', 'real snapshots:', '--reporter', 'expanded'],
                           cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
        shutil.copyfile(OUTPUT / 'results.ndjson', OUTPUT / f'{mode}.ndjson')
    export(read_rows(OUTPUT / 'flat.ndjson'), read_rows(OUTPUT / 'current.ndjson'))


if __name__ == '__main__':
    main()
