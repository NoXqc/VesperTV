# Profile matching on sync join (Codex, 2026-11-04)

Task 6, based on `codex/sync-playlist-match` f497581. Profile photos are
cancelled: users set their photo on each device. No photo payload or transfer.

`sync_profile_match.dart` contains the pure `matchSyncProfiles` function and
`matchSyncJoin`, which composes playlist matching followed by profile matching.
`SyncEngine._sync` calls that boundary before the existing merge, on first join
or while an identity migration is held. Existing merge rules and service APIs
are unchanged; `sync_merge.dart` is untouched.

Names match after trimming, case folding and the established title-search accent
folding. Punctuation, emoji and interior whitespace remain distinct. Main never
maps by name, and another viewer never maps into Main. Already shared ids retain
their identity. Among new local profiles with the same name, the first claims a
unique unclaimed server profile; others stay separate with their own data. Two
unclaimed server profiles with the same name are ambiguous, so neither is guessed.

Mapped profiles take the server's entry, including `isRestricted`. The global
parental PIN follows the ordinary server-scalar rule on join. The remapper changes
every exact `__vp_<id>` suffix and `file:recently_played_vp_<id>` key, including
playlist-scoped keys. Explicit JSON `viewerId` / `profileId` references and their
snake-case / plural-list forms map too; unrelated ids, user ids, names, passwords,
URLs and text are untouched. Inputs are never mutated. Canonical orphan-key
collisions keep canonical scalar values and merge lists using existing join rules.

An active app keeps both profile and playlist identity migrations held until the
next cold start, including old-key removal. Matching reuses the still-loaded
definitions, and reserves already-shared duplicate ids on repeat syncs. This keeps
the preserved second same-name profile from making the first match ambiguous.
Device-only preferences still follow the existing sync exclusion rules.

Tests: `sync_profile_match_test.dart` uses actual `StorageService` / `ViewerProfile`
fixtures and composed playlist/profile migrations. `sync_profile_join_test.dart`
starts a disposable relay on its own ephemeral loopback port and runs real engine
joins, both cold and held, with a preserved duplicate, PIN/restriction checks,
history, idle syncs and local edits. Existing `cloud_sync_test.dart` covers the
playlist path, conditional uploads, history order and deleted-profile histories.
Real TV/phone join and restart QA is still required after integration.
