"""Update existing help-bot answers; preview unless --apply is given.

Never accesses token files, container environments, or user messages.
"""
import argparse
import base64
import json
from pathlib import Path
import shlex
import subprocess


REMOTE = r'''
import base64, datetime, json, pathlib, subprocess, sys, time, urllib.request
payload = json.load(sys.stdin)
files = payload['files']
if set(files) != {'guide.json', 'search.mjs'}: raise SystemExit('Unexpected files')
decoded = {filename: base64.b64decode(encoded, validate=True) for filename, encoded in files.items()}
guide = json.loads(decoded['guide.json'])
if not isinstance(guide, list) or len(guide) < 20: raise SystemExit('Invalid guide')
expected_count = len(guide)
targets = [('/opt/vespertv-discord-auto', 'vespertv-discord-auto')]
if payload.get('include_slash'):
    targets.append(('/opt/vespertv-discord-help', 'vespertv-discord-help'))

def run(*args):
    return subprocess.run(args, check=True, text=True, capture_output=True).stdout

# Verify all targets and back up all files before changing either service.
stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S-%f')
backups = {}
for directory, name in targets:
    target = pathlib.Path(directory)
    if not target.is_dir(): raise SystemExit('Existing help-bot directory missing.')
    if run('docker', 'inspect', '--format', '{{.State.Status}}', name).strip() != 'running':
        raise SystemExit('Existing help bot is not running; inspect before updating.')
    for filename in files:
        path = target / filename
        backup = target / (filename + '.bak.' + stamp)
        if not path.is_file() or path.is_symlink() or backup.exists():
            raise SystemExit('Unexpected bot file or backup collision.')
        run('cp', '--preserve=mode,ownership,timestamps', str(path), str(backup))
        backups[path] = backup

try:
    for directory, name in targets:
        target = pathlib.Path(directory)
        for filename, content in decoded.items():
            temporary = target / (filename + '.new.' + stamp)
            temporary.write_bytes(content)
            temporary.chmod(0o644)
            temporary.replace(target / filename)
        run('docker', 'exec', name, 'node', '--check', '/app/search.mjs')
        run('docker', 'exec', name, 'node', '-e', "const f=require('node:fs');const g=JSON.parse(f.readFileSync('/app/guide.json','utf8'));if(!Array.isArray(g)||g.length<20||!g.every(e=>['id','title','controls','answer','url'].every(k=>typeof e[k]==='string'&&e[k])))process.exit(1)")
    for directory, name in targets:
        restarted = datetime.datetime.now(datetime.timezone.utc).isoformat()
        run('docker', 'restart', name)
        for attempt in range(15):
            time.sleep(1)
            status = run('docker', 'inspect', '--format', '{{.State.Status}}', name).strip()
            if status != 'running': continue
            if name == 'vespertv-discord-auto':
                logs = run('docker', 'logs', '--since', restarted, name)
                ready = all(line in logs for line in (
                    'VesperTV automatic help connected; one channel enabled.',
                    'Help channel access verified.',
                ))
            else:
                try:
                    with urllib.request.urlopen('http://127.0.0.1:8790/health', timeout=2) as response:
                        health = json.load(response)
                    ready = health.get('ok') is True and health.get('answers') == expected_count
                except Exception:
                    ready = False
            if ready: break
        else: raise RuntimeError('Help-bot readiness not verified')
        print(name + ': updated guide/search and verified readiness (' + str(expected_count) + ' answers).')
except Exception:
    for path, backup in backups.items():
        run('cp', '--preserve=mode,ownership,timestamps', str(backup), str(path))
    for directory, name in targets:
        run('docker', 'restart', name)
    raise SystemExit('Update failed; prior bot files restored and help containers restarted.')
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ssh', required=True, help='SSH destination supplied by the owner')
    parser.add_argument('--include-slash', action='store_true', help='Also update the existing /howto service')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if not args.apply:
        print('Preview: back up guide.json and search.mjs, replace only these files, syntax-check,')
        print('restart vespertv-discord-auto and verify its connection and help-channel access.')
        if args.include_slash:
            print('Also update/restart vespertv-discord-help and verify its /health answer count.')
        print('Rollback restores both files if readiness fails. No token, nginx, relay or Tuliprox changes.')
        print('Use --apply after approval.')
        return
    directory = Path(__file__).resolve().parent
    files = {name: base64.b64encode((directory / name).read_bytes()).decode()
             for name in ('guide.json', 'search.mjs')}
    result = subprocess.run(
        ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10', args.ssh,
         'python3 -c ' + shlex.quote(REMOTE)],
        input=json.dumps({'files': files, 'include_slash': args.include_slash}), text=True,
    )
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
