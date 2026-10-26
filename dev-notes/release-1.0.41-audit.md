# 1.0.41 branch/worktree audit - Codex, 2026-10-26

Owner requested a new release and confirmed everything should be merged.

- All completed Codex feature branches are ancestors of the release source, including
  Goals alert 1fe2257; main is fast-forwarded to the checked release commit before push.
- Claude profiles (156c7fb), Fire TV trailers (ff668a8) and the zap-freeze tree (8651fdf)
  are already ancestors of main. Their worktrees were read-only during this audit.
- Claude's dirty zap-freeze worktree contains the older +437 snapshot described in
  dev-notes/merge-all-20261025.md. Its NativeVideoSurface.java is text-identical to
  release source; both that patch and its guide viewport guard reverse-apply cleanly.
  No new uncommitted source work is missing. Generated registrants/version437 are
  intentionally not copied over current source/version455.
- Every other existing worktree is clean. Main-checkout owner .gitignore and untracked
  proposal/settings/attachments/build helpers remain untouched and are not committed.

The following historical heads are intentionally not replayed:
- claude/native-surface-prepare: isolated +427 branch of the bind-before-prepare fix;
  equivalent implementation plus preparation diagnostics are already in main, with
  subsequent channel-reuse and frozen-frame fixes that must not be reverted.
- claude/network-cards: only a historical CLAUDE.md status commit; network picks/logos
  and Home implementation are already integrated. It describes completed work as old
  unmerged work, so should not replace current status.
- claude/tunneling-test: obsolete +420 experiment explicitly excluded in the earlier
  integration decision. Native video surface supersedes it; no experimental player
  settings or patches were reintroduced for this release.

All runtime source changes since published1.0.40 are included. No native player patch
is changed by this release; Android PiP uses the application-side Kotlin bridge.
Release notes: release-1.0.41.md. Exact checks/artifacts/publication: root HANDOFF.md.
