"""Dev only. Download catalogue/XMLTV metadata, never play a stream.

Secrets enter through an ignored JSON config or the owner's local preferences.
Only URL-free channel metadata and programme fields are retained in snapshots.
No account response, address, credential, or exception text is printed.
"""
import argparse
import concurrent.futures
import datetime as dt
import gzip
import json
import os
from pathlib import Path
import sqlite3
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET


def fetch(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'VesperTV-matcher-audit'})
    return urllib.request.urlopen(request, timeout=60)


def stamp(value):
    try:
        return int(dt.datetime.strptime(value.strip(), '%Y%m%d%H%M%S %z').timestamp() * 1000)
    except ValueError:
        return None


def collect(account, output):
    label = account['label']
    root = output / label
    root.mkdir(parents=True, exist_ok=True)
    status = {'label': label, 'capturedUtc': dt.datetime.now(dt.timezone.utc).isoformat()}
    try:
        server = account.get('server', account.get('xtreamServer', '')).rstrip('/')
        login = {'username': account.get('username', account.get('xtreamUsername')),
                 'password': account.get('password', account.get('xtreamPassword'))}
        def api(action):
            with fetch(server + '/player_api.php?' + urllib.parse.urlencode({**login, 'action': action})) as reply:
                return json.load(reply)
        start = time.monotonic()
        streams = api('get_live_streams')
        if not isinstance(streams, list):
            raise ValueError('not a catalogue')
        channels = []
        for i, row in enumerate(streams):
            epg = str(row.get('epg_channel_id') or '').strip().lower()
            channels.append({'id': f'{label}::{i}', 'rawId': epg or f'xt_live_{i}',
                             'epgId': epg or f'xt_live_{i}', 'name': row.get('name', ''),
                             'group': str(row.get('category_id', '')), 'playlistId': label})
        (root / 'channels.json').write_text(json.dumps(channels), encoding='utf-8')
        status.update(channels=len(channels), catalogueSeconds=round(time.monotonic()-start, 3))
        known = {c['epgId'] for c in channels}
        epg_url = account.get('epgUrl') or server + '/xmltv.php?' + urllib.parse.urlencode(login)
        db = sqlite3.connect(root / 'guide.sqlite')
        db.execute('DROP TABLE IF EXISTS programme')
        db.execute('CREATE TABLE programme(channel_id TEXT,start INTEGER,stop INTEGER,title TEXT,descr TEXT)')
        db.execute('CREATE INDEX idx_start ON programme(start)')
        start = time.monotonic()
        count = 0
        # A bounded rolling window; includes historical coverage where supplied.
        now = dt.datetime.now(dt.timezone.utc)
        lower = int((now-dt.timedelta(days=7)).timestamp()*1000)
        upper = int((now+dt.timedelta(days=8)).timestamp()*1000)
        with fetch(epg_url) as response:
            import io
            stream = io.BufferedReader(response)
            xml = gzip.GzipFile(fileobj=stream) if stream.peek(2)[:2] == b'\x1f\x8b' else stream
            batch = []
            for _, element in ET.iterparse(xml, events=('end',)):
                if element.tag == 'programme':
                    channel = element.get('channel', '').strip().lower()
                    begin, end = stamp(element.get('start', '')), stamp(element.get('stop', ''))
                    if channel in known and begin is not None and end is not None and lower <= begin < upper:
                        batch.append((channel, begin, end, element.findtext('title', ''), element.findtext('desc', '')))
                        count += 1
                    element.clear()
                    if len(batch) >= 2000:
                        db.executemany('INSERT INTO programme VALUES(?,?,?,?,?)', batch)
                        batch.clear()
            db.executemany('INSERT INTO programme VALUES(?,?,?,?,?)', batch)
        db.commit()
        bounds = db.execute('SELECT MIN(start),MAX(start),COUNT(DISTINCT channel_id) FROM programme').fetchone()
        db.close()
        status.update(programmes=count, minStart=bounds[0], maxStart=bounds[1],
                      epgChannels=bounds[2], guideSeconds=round(time.monotonic()-start, 3), result='ok')
    except Exception as error:
        # Exception messages and HTTP response bodies can contain credentials.
        status.update(result='unavailable', errorType=type(error).__name__,
                      httpStatus=getattr(error, 'code', None))
    (root / 'status.json').write_text(json.dumps(status, indent=2), encoding='utf-8')
    print(json.dumps(status), flush=True)
    return status


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', type=Path)
    parser.add_argument('--owner', action='store_true')
    parser.add_argument('--output', type=Path, default=Path('.dart_tool/matcher-audit'))
    args = parser.parse_args()
    accounts = json.loads(args.config.read_text(encoding='utf-8')) if args.config else []
    if args.owner:
        prefs = Path(os.environ['APPDATA']) / 'com.nox/nox_iptv/shared_preferences.json'
        saved = json.loads(prefs.read_text(encoding='utf-8'))
        raw = saved.get('flutter.nox_playlists', saved.get('nox_playlists', '[]'))
        profiles = json.loads(raw) if isinstance(raw, str) else raw
        for i, profile in enumerate(profiles):
            if profile.get('enabled') or profile.get('name', '').lower() == 'dom og':
                accounts.append({**profile, 'label': 'strong8k-test' if profile.get('name', '').lower() == 'dom og' else f'owner-{i+1}'})
    args.output.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(lambda a: collect(a, args.output), accounts))
    (args.output / 'collection.json').write_text(json.dumps(results, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
