"""Issue helper, step 3: post what Claude wrote, safely.

Claude only reads (the issue, the code, the log) and returns JSON
($RESULT, the action's structured_output). This script is the only part
that writes to GitHub, and it is not an AI: labels come from a fixed list,
links outside VesperTV's own places are dropped, @mentions can't ping
anyone, and the reply gets a footer saying it is automatic. A spam verdict
posts nothing. $ISSUE = issue number, $GITHUB_REPOSITORY, $GH_TOKEN.
"""
import json
import os
import re
import subprocess
import sys
from urllib.parse import urlparse

LABELS = {
    # name: (colour, description)
    "bug": ("d73a4a", "Something isn't working"),
    "enhancement": ("a2eeef", "New feature or request"),
    "question": ("d876e3", "How do I..."),
    "duplicate": ("cfd3d7", "Already reported"),
    "needs-log": ("fbca04", "Waiting for a Send log code"),
    "needs-info": ("fbca04", "Waiting for more details"),
    "known-limitation": ("bfdadc", "Device or provider limit, not fixable in the app"),
    "android-tv": ("0e8a16", "Android TV / Google TV boxes"),
    "fire-tv": ("ff9900", "Amazon Fire TV"),
    "phone": ("1d76db", "Android phones and tablets"),
    "windows": ("0052cc", "Windows"),
    "linux": ("5319e7", "Linux"),
    "apple": ("555555", "iPhone, iPad, Apple TV, Mac"),
    "playback": ("c5def5", "Playing streams, audio, subtitles"),
    "guide": ("c5def5", "TV guide / EPG"),
    "sports-trak": ("c5def5", "Sports Trak"),
    "media-hub": ("c5def5", "Media Hub, add-ons, Jellyfin / Emby / Plex"),
    "multiview": ("c5def5", "Multiview"),
    "playlists": ("c5def5", "Adding / updating playlists, the editor"),
}
FOOTER = ("\n\n---\n<sub>Automatic reply from VesperTV's issue helper (Claude). "
          "The developer reads every issue too.</sub>")
MAX_REPLY = 6000


def link_ok(url):
    try:
        u = urlparse(url)
    except ValueError:
        return False
    host = (u.hostname or "").lower()
    path = u.path or "/"
    if u.scheme != "https":
        return False
    if host in ("vespertv.app", "www.vespertv.app", "pair.vespertv.app"):
        return True
    if host == "github.com":
        return path.lower().startswith("/noxqc/vespertv")
    if host == "discord.gg":
        return path.startswith("/VPQ849NPV")
    if host in ("reddit.com", "www.reddit.com"):
        return path.lower().startswith("/r/vespertv")
    return False


def clean(text):
    text = text.replace("\r\n", "\n")
    text = re.sub(r"<[^>\n]{1,200}>", "", text)  # no raw HTML
    # Markdown links / images: keep the words, drop foreign targets.
    def md(m):
        bang, words, url = m.group(1), m.group(2), m.group(3)
        if link_ok(url) and not bang:
            return f"[{words}]({url})"
        return words
    text = re.sub(r"(!?)\[([^\]\n]{0,200})\]\(([^)\s]+)\)", md, text)
    text = re.sub(r"https?://[^\s)\]>\"']+",
                  lambda m: m.group(0) if link_ok(m.group(0)) else "(link removed)",
                  text)
    # @name pings nobody (a zero-width space after the @).
    text = re.sub(r"(?<![\w`/])@(?=[A-Za-z0-9])", "@​", text)
    if len(text) > MAX_REPLY:
        text = text[:MAX_REPLY].rsplit("\n", 1)[0] + "\n\n…"
    return text.strip()


def gh(*args, body=None):
    return subprocess.run(["gh", *args], input=body, text=True,
                          capture_output=True, check=False)


def summary(lines):
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")


def main():
    raw = os.environ.get("RESULT", "").strip()
    issue = os.environ.get("ISSUE", "")
    repo = os.environ.get("GITHUB_REPOSITORY", "")
    if not raw or not issue.isdigit():
        print("Nothing to post.")
        return 0
    try:
        out = json.loads(raw)
    except ValueError:
        print("The helper's answer wasn't JSON; nothing posted.")
        return 0
    kind = str(out.get("kind", ""))
    note = str(out.get("owner_note", ""))[:500]
    summary([f"### Issue #{issue}: {kind}", "", note])
    if kind == "spam":
        print("Spam verdict: nothing posted.")
        return 0

    wanted = [l for l in out.get("labels", []) if isinstance(l, str)]
    labels = [l for l in dict.fromkeys(wanted) if l in LABELS][:6]
    if labels:
        have = gh("label", "list", "--repo", repo, "--limit", "200",
                  "--json", "name", "--jq", ".[].name")
        existing = set(have.stdout.split("\n")) if have.returncode == 0 else set()
        for name in labels:
            if name not in existing:
                colour, desc = LABELS[name]
                gh("label", "create", name, "--repo", repo,
                   "--color", colour, "--description", desc)
        r = gh("issue", "edit", issue, "--repo", repo,
               "--add-label", ",".join(labels))
        print("Labels:", ", ".join(labels), "" if r.returncode == 0 else r.stderr)

    reply = clean(str(out.get("reply", "")))
    if reply:
        r = gh("issue", "comment", issue, "--repo", repo, "--body-file", "-",
               body=reply + FOOTER)
        print("Reply posted." if r.returncode == 0 else r.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
