"""Add an owner-visible snapshot; read only playlist/group preferences.

Does not modify the installed app or its database. The full catalogue snapshot
remains available to separate hidden-channel effects from matching failures.
"""
import json
import os
from pathlib import Path
import shutil
from collect import fetch
import urllib.parse

root = Path('.dart_tool/matcher-audit')
saved = json.loads((Path(os.environ['APPDATA']) /
                    'com.nox/nox_iptv/shared_preferences.json').read_text(encoding='utf-8'))


def pref(key, default=None):
    return saved.get('flutter.' + key, saved.get(key, default))


profiles = pref('nox_playlists', '[]')
profiles = json.loads(profiles) if isinstance(profiles, str) else profiles
viewer = pref('nox_active_viewer', 'main')
for index, profile in enumerate(profiles):
    if not profile.get('enabled'):
        continue
    source = root / f'owner-{index+1}'
    if not (source / 'channels.json').exists():
        continue
    try:
        url = profile['xtreamServer'].rstrip('/') + '/player_api.php?' + urllib.parse.urlencode({
            'username': profile['xtreamUsername'], 'password': profile['xtreamPassword'],
            'action': 'get_live_categories'})
        with fetch(url) as response:
            categories = {str(c['category_id']): c['category_name'] for c in json.load(response)}
        # StorageService._vkp: playlist suffix, then viewer suffix.
        suffix = '' if viewer == 'main' else '__vp_' + viewer
        hidden_groups = set(pref('nox_hidden_groups_' + profile['id'] + suffix, []))
        hidden_channels = set(pref('nox_hidden_channels_' + profile['id'] + suffix, []))
        raw = json.loads((source / 'channels.json').read_text(encoding='utf-8'))
        visible = [c for c in raw if c['rawId'] not in hidden_channels and
                   categories.get(c['group'], 'Uncategorized') not in hidden_groups]
        destination = root / (source.name + '-visible')
        destination.mkdir(exist_ok=True)
        (destination / 'channels.json').write_text(json.dumps(visible), encoding='utf-8')
        shutil.copyfile(source / 'guide.sqlite', destination / 'guide.sqlite')
        state = json.loads((source / 'status.json').read_text())
        state.update(label=destination.name, channels=len(visible), hiddenRemoved=len(raw)-len(visible),
                     mainViewer=viewer == 'main',
                     scope='enabled owner playlist, active viewer group/channel blocklists')
        (destination / 'status.json').write_text(json.dumps(state, indent=2))
        print(json.dumps({'label': state['label'], 'channels':len(visible), 'hiddenRemoved':len(raw)-len(visible)}))
    except Exception as error:
        print(json.dumps({'label':source.name, 'visibilityError':type(error).__name__}))
