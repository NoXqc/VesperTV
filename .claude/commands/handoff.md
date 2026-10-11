---
description: Write HANDOFF.md so a fresh session can continue this work without the old context
---

Write (overwrite) `HANDOFF.md` in the repo root so a brand-new session can pick up exactly where this
one stops, then tell me it is ready and that I should start a fresh session (or `/clear`).

Keep it under ~60 lines, concrete, no fluff, and **no secrets** (no passwords, tokens, keys, provider
logins — reference where they live instead). Use these sections:

1. **Goal** — what we are in the middle of, in 1-3 lines.
2. **State** — what is done and verified vs done-but-unverified vs not started. Include commit hashes,
   release tag/version/versionCode, and whether anything is built/installed/pushed.
3. **Files touched / key locations** — paths (with function names) a newcomer must look at first.
4. **Decisions & why** — choices already made (and options the user rejected) so they are not re-litigated.
5. **Gotchas** — traps hit this session that are not already in `CLAUDE.md` / `dev-notes/`.
6. **Next steps** — an ordered, actionable list, plus anything waiting on the user's answer.

Do not copy things already documented in `CLAUDE.md` or `dev-notes/`; link to them instead.
`HANDOFF.md` is git-ignored — never commit it.
