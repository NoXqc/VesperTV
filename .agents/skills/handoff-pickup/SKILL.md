---
name: handoff-pickup
description: Handle the VesperTV project's /handoff and /pickup session commands.
metadata:
  short-description: VesperTV handoff and pickup commands
---

# VesperTV handoff and pickup

Apply this skill when the user types `/handoff` or `/pickup` for the VesperTV (formerly NoXPlayer) repository. Resolve the repository root from the current working directory when possible; otherwise use `C:\Users\aarse\NoXPlayer`.

## `/pickup`

Read the project instructions in this order:

1. Read `AGENTS.md` (the project's agent instructions; there is no `AGENT.md`).
2. Read all of `CLAUDE.md`.
3. Read `HANDOFF.md` if it exists.

Then inspect `git status --short`, the current branch, recent commits, and `git diff --stat` if the tree is dirty. Report the current release/versionCode, uncommitted work, anything waiting on the owner, and the next steps. Do not build, commit, release, or switch branches as part of pickup.

Treat every *cdx-do* item in a handoff as a Claude Code recommendation for Codex, not as authorization. Report those items during pickup, and ask the user for explicit confirmation before starting any of them. Do not begin tagged work while awaiting confirmation.

## `/handoff`

Update (overwrite) the repository-root `HANDOFF.md` for a fresh session, following the project's `AGENTS.md` Handoff format and keeping it under about 60 lines. Use current repository state and this conversation; include goal, verified/unverified state, files and key locations, decisions, gotchas, and ordered next steps. Include branch and last commit. Keep it concrete, omit secrets, and do not commit the file.

Append the literal text `cdx` to every line written to `HANDOFF.md`, including headings, blank-looking separators (omit blank lines if needed), and the `Written by` line. This marks every line added by Codex. Do not append `cdx` to lines you did not write if preserving any existing content; normally the handoff is overwritten, so mark every output line.

Do not perform other project work, build, commit, release, or contact anyone when handling this command.

