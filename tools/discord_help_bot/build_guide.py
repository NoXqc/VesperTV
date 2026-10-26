"""Build the bot's offline answer index from the public remote guide."""

import argparse
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from urllib.parse import quote


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path(__file__).with_name("guide.json")
GUIDE_URL = "https://vespertv.app/remote.html"


def clean(parts):
    return re.sub(r"\s+", " ", " ".join(parts)).strip()


class GuideParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []
        self.category = None
        self.row = None
        self.entries = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in {"meta", "link", "input", "br", "img", "hr", "source"}:
            return
        classes = attrs.get("class", "").split()
        self.stack.append((tag, classes))
        if tag == "section" and "screen" in classes:
            self.category = attrs["data-tab"]
        if tag == "div" and "row" in classes and self.category:
            self.row = {"title": [], "answer": [], "controls": []}

    def handle_data(self, text):
        if self.row is None:
            return
        classes = {c for _, values in self.stack for c in values}
        tags = {tag for tag, _ in self.stack}
        if "keys" in classes:
            self.row["controls"].append(text)
        elif "what" in classes:
            field = "answer" if "p" in tags else "title"
            self.row[field].append(text)

    def handle_endtag(self, tag):
        if not self.stack:
            return
        # All guide rows are ordinary nested divs. Ignore void closing tags.
        if tag != self.stack[-1][0]:
            return
        _, classes = self.stack.pop()
        if tag == "div" and "row" in classes and self.row is not None:
            entry = {key: clean(parts) for key, parts in self.row.items()}
            if not entry["title"] or not entry["controls"]:
                raise ValueError("A remote tip has no title or controls")
            identity = f"{self.category}|{entry['title']}".encode()
            self.entries.append({
                "id": hashlib.sha256(identity).hexdigest()[:16],
                "category": self.category,
                **entry,
                "url": f"{GUIDE_URL}#{quote(self.category, safe='')}",
            })
            self.row = None
        if tag == "section":
            self.category = None


def main():
    args = argparse.ArgumentParser()
    args.add_argument("--check", action="store_true")
    options = args.parse_args()
    parser = GuideParser()
    parser.feed((ROOT / "docs/remote.html").read_text(encoding="utf-8"))
    if len(parser.entries) < 20:
        raise ValueError("Guide extraction unexpectedly lost most tips")
    ids = [entry["id"] for entry in parser.entries]
    if len(ids) != len(set(ids)):
        raise ValueError("Duplicate guide tip identity")
    expected = json.dumps(parser.entries, ensure_ascii=False, indent=2) + "\n"
    if options.check:
        if not OUTPUT.exists() or OUTPUT.read_text(encoding="utf-8") != expected:
            raise SystemExit("Guide index is stale: run python tools/discord_help_bot/build_guide.py")
    else:
        OUTPUT.write_text(expected, encoding="utf-8", newline="\n")
    print(f"{len(ids)} remote-guide answers {'verified' if options.check else 'indexed'}")


if __name__ == "__main__":
    main()
