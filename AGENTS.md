# AGENTS.md — VesperTV, for any coding agent (Codex, Claude, …)

**Read `CLAUDE.md` first, all of it.** It is this project's single rulebook and status page
(build, signing, rules learned the hard way, every known bug, current release). Despite the name it
applies to every agent. Don't copy its content here; if you learn something worth keeping, add it to
`CLAUDE.md` (or `dev-notes/`) so both agents see it.

This repo is worked on by two agents: **Claude** (Opus — bigger, riskier work) and **Codex** (smaller,
well-scoped tasks). The owner decides who does what. Only one agent works at a time.

## Hard rules (both agents)
- **Never** commit to `main`, push, tag, create/edit a GitHub release, run `gh workflow`, or post to
  Discord unless the owner asked for exactly that in this session.
- **Never** touch secrets: `android/key.properties`, the keystore, anything under `/etc` on the VPS,
  users' tokens/API keys (debrid, Trakt, Stremio…). Never print or commit them; redact as `REDACTED`.
- **No VPS / nginx / relay changes** (`tools/pair_relay/`, `ssh root@…`) unless the owner asks.
- **Don't bump `version:` in `pubspec.yaml`.** Only the agent cutting a release or a test build the
  owner asked for does, and `+N` must always rise.
- **Don't edit `third_party/video_player_android`** (the patched player, CLAUDE.md §9) unless the task
  is explicitly about the player.
- Before handing back: `flutter analyze` must report the baseline **17** issues (no errors, no new
  infos) and `flutter test` must pass. Run `dart format` only on files you changed.
- Every user-visible string goes through `tr()` with entries in `lib/l10n/fr.dart`, `es.dart`,
  `it.dart`, `el.dart` (same `{placeholders}`).
- Every `TextField` is wrapped in `TvTextFieldGate` (a test fails the build otherwise).
- Files are CRLF on the owner's Windows PC; keep the line endings a file already has.
- Don't drive the owner's Formuler over adb (CLAUDE.md §7). The Fire Stick is OK when asked.

## Working tree etiquette (two agents, one repo)
- **Commit (or stash) before switching agents.** Don't start on a tree with someone else's
  uncommitted work you don't understand — ask the owner.
- **Codex works on a branch**: `git switch -c codex/<short-task>` (or a separate worktree:
  `git worktree add ../VesperTV-codex codex/<short-task>`). Commit there; the owner (or Claude, on
  review) merges into `main`.
- Keep changes small and on-topic: one task per branch.

## Good Codex tasks / keep for Claude
| Codex | Claude |
|---|---|
| Translations, wording, string fixes | Native player (ExoPlayer patches), memory/ANR work |
| League bank entries (`kSportsLeagueBank`, e.g. an `espnGroup` conference) | D-pad focus, Fire OS quirks |
| Unit tests for existing logic | Debugging from logs / user photos |
| Site pages (`docs/`, e.g. `docs/remote.html` when a remote move changes) | Multi-screen features |
| Small layout / spacing tweaks | Releases, signing, VPS, Discord |
| `CLAUDE.md` §13 status notes from a diff | Reviewing Codex branches before merge |

## Pickup (start of a session)
1. Read `CLAUDE.md` (whole file) and `HANDOFF.md` if it exists (repo root, git-ignored).
2. `git status --short`, `git branch --show-current`, `git log --oneline -5`; if the tree is dirty,
   `git diff --stat` so you know what's there and who left it (see HANDOFF's "Written by").
3. Tell the owner: current release/versionCode, what's uncommitted, what's waiting on them, next steps.
   Don't build, commit or release until asked. Read `dev-notes/` and big files (`tv_home_screen.dart`)
   only when the task needs them — grep first, then read just the range.

## Handoff (end of a session)
Overwrite `HANDOFF.md` (repo root, **never commit it**, no secrets), under ~60 lines:
- **Written by:** Claude / Codex · date · **Branch:** name · **Last commit:** hash
- **Goal** — what's in progress, 1-3 lines.
- **State** — done & verified (how: analyze 17, tests, which device or "not on a box") / done but
  unverified / not started. Built, installed, pushed, released?
- **Don't touch** — files or areas mid-way through, so the other agent leaves them alone.
- **Files / key locations** — paths + function names to look at first.
- **Decisions & why** — including options the owner rejected.
- **Gotchas** — traps not already in `CLAUDE.md` / `dev-notes/`.
- **Next steps** — ordered; plus questions waiting on the owner.
Link to `CLAUDE.md` / `dev-notes/` instead of repeating them.
