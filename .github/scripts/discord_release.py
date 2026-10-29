"""Announce a VesperTV GitHub release on Discord as a gold embed.

Used by .github/workflows/discord-release.yml. Reads the release JSON
(`gh api repos/<repo>/releases/tags/<tag>`) from the file given as argv[1]
and POSTs to the webhook in $DISCORD_RELEASE_WEBHOOK. `--dry-run` prints the
payload instead (no webhook needed) - handy for checking the look locally.

Standard library only, so the runner needs nothing installed.
"""
import json
import os
import re
import sys
import urllib.request
from datetime import datetime, timezone

GOLD = 0xF0C75E
REPO = 'NoXqc/VesperTV'
LOGO = f'https://raw.githubusercontent.com/{REPO}/main/assets/icon/icon_flat.png'
DOWNLOADER_CODE = '1760256'
DESCRIPTION_LIMIT = 3500  # Discord allows 4096; keep room for safety


def notes_for_discord(body: str) -> str:
    """Release notes in Discord-friendly markdown.

    Drops the leading "## VesperTV x.y.z" title (the embed title says it) and
    the "Install" section (the embed has its own download fields), and turns
    headings into bold lines (headings render inconsistently in embeds).
    """
    out, skipping = [], False
    for line in body.replace('\r\n', '\n').split('\n'):
        heading = re.match(r'^#{1,6}\s+(.*)$', line)
        if heading:
            text = heading.group(1).strip()
            skipping = text.lower().startswith('install')
            if skipping or re.match(r'^VesperTV\s+\d', text):
                continue
            out.append(f'**{text}**')
            continue
        if not skipping:
            out.append(line)
    text = re.sub(r'\n{3,}', '\n\n', '\n'.join(out)).strip()
    if len(text) > DESCRIPTION_LIMIT:
        text = text[:DESCRIPTION_LIMIT].rsplit('\n', 1)[0] + '\n…'
    return text


def asset_url(release: dict, suffix: str) -> str | None:
    for asset in release.get('assets', []):
        if asset['name'].lower().endswith(suffix):
            return asset['browser_download_url']
    return None


def build_payload(release: dict) -> dict:
    tag = release['tag_name']
    page = release['html_url']
    apk = asset_url(release, '.apk')
    zip_ = asset_url(release, '.zip')
    android = (f'[Download the APK]({apk})' if apk else f'[Release page]({page})') + \
        f' · Downloader code **{DOWNLOADER_CODE}** · or Settings > Check for Updates'
    windows = (f'[Download the zip]({zip_}) · unzip, then run `VesperTV.exe`'
               if zip_ else 'No Windows update in this release. '
               '[Existing Windows download](https://vespertv.app/#install)')
    return {
        'username': 'VesperTV',
        'avatar_url': LOGO,
        'content': f'✨ **VesperTV {tag} is out!**',
        'allowed_mentions': {'parse': []},
        'embeds': [{
            'title': release.get('name') or f'VesperTV {tag}',
            'url': page,
            'description': notes_for_discord(release.get('body') or ''),
            'color': GOLD,
            'thumbnail': {'url': LOGO},
            'fields': [
                {'name': '📺 Android TV · Fire Stick · phone', 'value': android},
                {'name': '🖥️ Windows 10/11', 'value': windows},
            ],
            'footer': {'text': 'Free · open source · no ads · github.com/' + REPO},
            # Now, not published_at: releases are usually edited in place,
            # so published_at is the date of the first one.
            'timestamp': datetime.now(timezone.utc).isoformat(),
        }],
    }


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    dry_run = '--dry-run' in sys.argv
    with open(args[0], encoding='utf-8') as f:
        release = json.load(f)
    if release.get('draft') or release.get('prerelease'):
        print(f"{release['tag_name']} is a draft/pre-release - not announced.")
        return 0
    payload = build_payload(release)
    if dry_run:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return 0
    webhook = os.environ.get('DISCORD_RELEASE_WEBHOOK', '').strip()
    if not webhook:
        print('::error::The DISCORD_RELEASE_WEBHOOK secret is not set.')
        return 1
    req = urllib.request.Request(
        webhook + ('&' if '?' in webhook else '?') + 'wait=true',
        data=json.dumps(payload).encode('utf-8'),
        headers={'Content-Type': 'application/json',
                 'User-Agent': 'VesperTV-release-announcer'},
        method='POST')
    with urllib.request.urlopen(req, timeout=30) as resp:
        print(f"Announced {release['tag_name']} on Discord (HTTP {resp.status}).")
    return 0


if __name__ == '__main__':
    sys.exit(main())
