"""Issue helper, step 1: fetch the reporter's Send log from its code.

Reads the issue (or comment) text from $TEXT, finds the first LOG-XXXXXX
code and downloads that log from the relay with $LOG_KEY (the
VESPER_LOG_READ_KEY secret) into .issue-log/<code>.txt for Claude to read.
The log never goes into the issue. No key, no code or no log = nothing to
do (the helper then asks for one). Prints only the code and a line count.
"""
import os
import re
import sys
import urllib.error
import urllib.request

RELAY = "https://pair.vespertv.app/api/log/"
CODE_RE = re.compile(r"\bLOG-[2-9A-HJ-NP-Z]{6}\b")
# Box noise that drowns the app's own lines (NVIDIA / Amazon firmware).
NOISE = ("Access denied finding property", "HwBinder")


def main():
    text = os.environ.get("TEXT", "")
    key = os.environ.get("LOG_KEY", "")
    m = CODE_RE.search(text)
    if not m:
        print("No log code in the text.")
        return 0
    code = m.group(0)
    if not key:
        print(f"{code}: no VESPER_LOG_READ_KEY secret, skipped.")
        return 0
    req = urllib.request.Request(RELAY + code, headers={
        "X-Log-Key": key,
        "User-Agent": "VesperTV-issue-helper",
    })
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            body = r.read(2 * 1024 * 1024).decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        print(f"{code}: relay answered HTTP {e.code} (expired or never sent).")
        return 0
    except (urllib.error.URLError, OSError) as e:
        print(f"{code}: relay unreachable ({e.__class__.__name__}).")
        return 0
    lines = [l for l in body.splitlines() if not any(n in l for n in NOISE)]
    os.makedirs(".issue-log", exist_ok=True)
    with open(os.path.join(".issue-log", code + ".txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"{code}: {len(lines)} lines saved for the helper.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
