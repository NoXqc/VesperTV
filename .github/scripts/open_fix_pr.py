"""Auto-fix, last step: check Claude's change and open a draft pull request.

Runs on a fresh checkout of main and never runs the changed code. The
change ($PATCH, made with `diff -ruN a b` from the app's code folders
only) is refused if it touches anything outside those folders, holds a
binary file, is too big, or contains one of the secrets ($SCAN_1,
$SCAN_2). Then: branch claude/auto-issue-N, commit, push, draft pull
request (or a compare link when Actions may not open pull requests),
the tests workflow on that branch, and a fixed comment on the issue.
"""
import json
import os
import re
import subprocess
import sys

from post_issue_reply import FOOTER, clean, gh

ALLOWED = ("lib/", "test/", "third_party/video_player_android/android/src/",
           "android/app/src/main/kotlin/")
MAX_PATCH = 300_000


def summary(text):
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a", encoding="utf-8") as f:
            f.write(text + "\n")
    print(text)


def refuse(why):
    summary(f"Auto-fix not opened: {why}")
    return 0


def paths_of(patch):
    for line in patch.splitlines():
        if line.startswith(("--- ", "+++ ")):
            p = line[4:].split("\t")[0].strip()
            yield p


def check(patch):
    if len(patch) > MAX_PATCH:
        return "the change is too big for an automatic fix"
    if any(l.startswith("Binary files ") for l in patch.splitlines()):
        return "the change has a binary file"
    for key in ("SCAN_1", "SCAN_2"):
        secret = os.environ.get(key, "")
        if len(secret) >= 8 and secret in patch:
            return "the change contains a secret"
    seen = set()
    for p in paths_of(patch):
        if not (p.startswith("a/") or p.startswith("b/")):
            return "unexpected file path"
        rel = p[2:]
        if ".." in rel.split("/") or rel.startswith("/") or "\\" in rel:
            return "unexpected file path"
        if not rel.startswith(ALLOWED) or rel.endswith("AndroidManifest.xml"):
            return f"it touches {rel}, outside the app's code folders"
        seen.add(rel)
    if not seen:
        return "no file changed"
    return None


def run(*args, **kw):
    return subprocess.run(list(args), check=True, text=True, **kw)


def main():
    issue = os.environ.get("ISSUE", "")
    repo = os.environ.get("GITHUB_REPOSITORY", "")
    token = os.environ.get("GH_TOKEN", "")
    patch_file = os.environ.get("PATCH", "")
    if not issue.isdigit() or not os.path.isfile(patch_file):
        return refuse("no change to look at")
    try:
        out = json.loads(os.environ.get("RESULT", "") or "{}")
    except ValueError:
        out = {}
    if out.get("fixed") is not True:
        return refuse("Claude didn't find a fix it was sure of")
    with open(patch_file, encoding="utf-8", errors="replace") as f:
        patch = f.read()
    why = check(patch)
    if why:
        return refuse(why)

    run("patch", "-p1", "-E", "--batch", "--forward", "--no-backup-if-mismatch",
        "-i", patch_file)
    branch = f"claude/auto-issue-{issue}"
    title_src = re.sub(r"[\x00-\x1f@<>]", "", os.environ.get("ISSUE_TITLE", ""))
    title = f"Auto-fix for #{issue}: {title_src.strip()[:70]}"
    summ = clean(str(out.get("summary", "")))[:1500]
    git = ["git", "-c", "core.hooksPath=/dev/null",
           "-c", "user.name=github-actions[bot]",
           "-c", "user.email=41898282+github-actions[bot]@users.noreply.github.com"]
    run(*git, "checkout", "-b", branch)
    folders = [d.rstrip("/") for d in ALLOWED if os.path.isdir(d.rstrip("/"))]
    run(*git, "add", "-A", "--", *folders)
    msg = (f"Auto-fix attempt for #{issue} (live playback)\n\n{summ}\n\n"
           "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\n")
    run(*git, "commit", "-q", "-F", "-", input=msg)
    run(*git, "push", "-q",
        f"https://x-access-token:{token}@github.com/{repo}.git",
        f"HEAD:refs/heads/{branch}")

    def field(name, limit=1500):
        return clean(str(out.get(name, "")))[:limit]

    files = "\n".join(f"- `{clean(str(p))[:150]}`" for p in out.get("files", [])[:30])
    body = (
        f"Automatic fix attempt for #{issue}, a live playback report.\n\n"
        "**Not tried on a TV yet.** Claude wrote it without running anything; the Tests workflow "
        "runs on this branch. Review the change, then build and test it on a box before merging.\n\n"
        f"### What changed\n{summ}\n\n### Cause\n{field('cause')}\n\n"
        f"### Files\n{files}\n\n### How to test on a TV\n{field('how_to_test')}\n\n"
        f"### Risk\n{field('risk', 500)}\n"
    )
    with open("pr-body.md", "w", encoding="utf-8") as f:
        f.write(body)
    pr = gh("pr", "create", "--repo", repo, "--draft", "--base", "main",
            "--head", branch, "--title", title, "--body-file", "pr-body.md")
    if pr.returncode == 0:
        link = pr.stdout.strip().splitlines()[-1]
        gh("pr", "edit", link, "--repo", repo, "--add-label", "auto-fix")
    else:
        # Settings > Actions > General > "Allow GitHub Actions to create and
        # approve pull requests" is off: the developer opens it in one click.
        link = f"https://github.com/{repo}/compare/main...{branch}?expand=1"
        summary(f"Pull request not created ({pr.stderr.strip()[:200]}); compare link used.")
    gh("workflow", "run", "tests.yml", "--repo", repo, "--ref", branch)
    gh("issue", "comment", issue, "--repo", repo, "--body-file", "-",
       body=("A possible fix for this is ready for the developer to review: "
             f"{link}\n\nIt hasn't been tried on a TV yet, so it can take a little while to "
             "reach an update. Thanks for the report!" + FOOTER))
    summary(f"Auto-fix: {link}\n\n{summ}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
