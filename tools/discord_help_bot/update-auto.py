"""Update only the existing automatic-help bot; preview unless --apply is given.

Never accesses the token file, container environment, or user messages.
"""
import argparse
import base64
import json
from pathlib import Path
import shlex
import subprocess


REMOTE = r'''
import base64, datetime, json, pathlib, subprocess, sys, time
files = json.load(sys.stdin)
target = pathlib.Path('/opt/vespertv-discord-auto')
name = 'vespertv-discord-auto'
def run(*args):
    return subprocess.run(args, check=True, text=True, capture_output=True).stdout
if not target.is_dir(): raise SystemExit('Existing automatic bot directory missing.')
run('docker', 'inspect', '--format', '{{.State.Status}}', name)
stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')
backups = {}
for filename in files:
    if filename not in ('gateway.mjs', 'guide.json'): raise SystemExit('Unexpected file')
    path = target / filename
    backup = target / (filename + '.bak.' + stamp)
    run('cp', '--preserve=mode,ownership,timestamps', str(path), str(backup))
    backups[path] = backup
try:
    for filename, encoded in files.items():
        path = target / filename
        temporary = target / (filename + '.new.' + stamp)
        temporary.write_bytes(base64.b64decode(encoded))
        temporary.chmod(0o644)
        temporary.replace(path)
    run('docker', 'exec', name, 'node', '--check', '/app/gateway.mjs')
    run('docker', 'restart', name)
    time.sleep(6)
    status = run('docker', 'inspect', '--format', '{{.State.Status}}', name).strip()
    if status != 'running': raise RuntimeError('Automatic bot did not remain running')
    print('Updated automatic-help guide and access diagnostics; restarted only its container.')
    logs = run('docker', 'logs', '--since', '15s', name)
    # Emit only known static diagnostics, never arbitrary log text.
    for known in (
        'VesperTV automatic help connected; one channel enabled.',
        'Help channel access verified.',
        'Configured server unavailable: install this application with the bot scope.',
        'Configured help channel does not belong to the configured server.',
        'Help channel permissions missing: View Channel, Send Messages or Read Message History.',
        'Help channel unavailable: check channel ID and View Channel permission.',
        'Discord login failed. Check token and Message Content Intent.',
    ):
        # console.error uses stderr; captured separately below without displaying it.
        if known in logs: print(known)
    recent = subprocess.run(['docker','logs','--since','15s',name], text=True, capture_output=True)
    for known in (
        'Configured server unavailable: install this application with the bot scope.',
        'Configured help channel does not belong to the configured server.',
        'Help channel permissions missing: View Channel, Send Messages or Read Message History.',
        'Help channel unavailable: check channel ID and View Channel permission.',
        'Discord login failed. Check token and Message Content Intent.',
    ):
        if known in recent.stderr: print(known)
except Exception:
    for path, backup in backups.items():
        run('cp', '--preserve=mode,ownership,timestamps', str(backup), str(path))
    run('docker', 'restart', name)
    raise SystemExit('Update failed; prior bot files restored and its container restarted.')
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ssh', required=True, help='SSH destination supplied by the owner')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if not args.apply:
        print('Preview: back up gateway.mjs and guide.json, update these two files, syntax-check,')
        print('restart only vespertv-discord-auto and print static access diagnostics.')
        print('No token, nginx, relay or Tuliprox changes. Use --apply after approval.')
        return
    directory = Path(__file__).resolve().parent
    files = {name: base64.b64encode((directory / name).read_bytes()).decode()
             for name in ('gateway.mjs', 'guide.json')}
    result = subprocess.run(
        ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10', args.ssh,
         'python3 -c ' + shlex.quote(REMOTE)],
        input=json.dumps(files), text=True,
    )
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
