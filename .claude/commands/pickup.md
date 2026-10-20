---
description: Start a fresh session by reading CLAUDE.md and HANDOFF.md, then summarize where we left off
---

Pick up where the last session stopped:

1. Read `CLAUDE.md` (whole file) and `HANDOFF.md` (if it exists) in the repo root.
2. Run `git status --short` and `git log --oneline -5`; if there are uncommitted changes, `git diff --stat`
   (and the diff itself when small) so you know what the working tree holds.
3. Reply briefly: current release/versionCode, what is uncommitted, anything waiting on my answer,
   and the next steps from `HANDOFF.md`. End with the question(s) I still need to answer, if any.

Don't read `dev-notes/` or big source files yet — only once the task needs them. Don't build, commit
or release until I ask.
