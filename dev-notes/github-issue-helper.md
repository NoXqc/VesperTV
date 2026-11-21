# GitHub issue helper (owner, 2026-11-21)

The owner asked for Claude to go through GitHub issues automatically, with users able to add
their log. Two workflows:

| Workflow | Starts on | Who can start it | Claude can |
|---|---|---|---|
| `.github/workflows/issue-helper.yml` | a new issue; a reporter's comment with a `LOG-` code | anyone | **read only** (repo, issue, log) |
| `.github/workflows/claude.yml` | a comment containing `@claude` | the repo owner only | edit, branch, open a pull request |

## Issue helper (anyone)
1. `.github/scripts/fetch_issue_log.py` finds the first `LOG-XXXXXX` in the issue (or the new
   comment) and downloads it from the relay (`GET pair.vespertv.app/api/log/<code>`, header
   `X-Log-Key` = secret `VESPER_LOG_READ_KEY`) into `.issue-log/<code>.txt`, NVIDIA/Amazon noise lines
   dropped. The log is never posted.
2. `anthropics/claude-code-action@v1` (Sonnet 5.5, 30 turns) with `allowed_non_write_users: "*"`
   (issues come from strangers) and only `Read, Grep, Glob, gh issue view, gh issue list`; Edit /
   Write / web tools are disallowed. It returns JSON through `--json-schema`: `kind` (bug / feature /
   question / duplicate / not_vesper / spam), `labels`, `reply`, `owner_note`.
3. `.github/scripts/post_issue_reply.py` (not an AI) is the only writer: labels from its fixed list
   (created on first use), raw HTML dropped, links only to vespertv.app / this repo / the Discord
   invite / r/VesperTV, `@name` can't ping, 6000 characters max, an "Automatic reply" footer. Spam =
   nothing posted. `owner_note` goes to the run's summary page.

Why this split: issue text and logs are written by strangers and may try to steer the AI (prompt
injection). With no write tools, the worst a trick issue can get is an odd comment.

## @claude (owner only)
`github.event.comment.user.login == github.repository_owner`, so nobody else can spend the plan or get
code written. Flutter 3.47.9 is set up so Claude can run `flutter analyze` / `flutter test`. House rules
go in through `--append-system-prompt` (no `prompt` input: that switches the action out of answering
the comment). It pushes a `claude/...` branch and opens a pull request; nothing merges or releases.

## Logs on the relay
`tools/pair_relay/relay.py`: with `PAIR_LOG_READ_KEY` set in `/etc/pair-relay.env`, every Send log is
also kept 14 days (`LOG_KEEP`) in `/var/lib/pair-relay/logs/` (300 MB cap, oldest first); without it the
relay behaves as before (Discord only). `docs/privacy.html` says so. Tests: `test_log_store.py`.

## One-time setup
1. Owner: install the Claude GitHub app on NoXqc/VesperTV (https://github.com/apps/claude).
2. Owner, in his own terminal: `claude setup-token`, then `gh secret set CLAUDE_CODE_OAUTH_TOKEN
   --repo NoXqc/VesperTV` and paste the token (never into a Claude chat).
3. Key: a random string as `PAIR_LOG_READ_KEY=` in `/etc/pair-relay.env` (deploy relay.py, restart
   `pair-relay` only) and as the repo secret `VESPER_LOG_READ_KEY`.
4. Push this branch to main (workflows only run from the default branch).

Cost: each run uses the owner's Claude plan (Sonnet for the helper). Old logs sent before step 3
were never kept, so codes from before then can't be read.
