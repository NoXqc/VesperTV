# Plex missing streams from tracker titles - 2026-10-30

Report: LOG-7K4BPR.txt, VesperTV 1.0.49+531 on onn 4K Pro / Android 14.
User says only about one in ten movies appear despite being in Plex. The
attached Truth or Dare (2012) page is labelled **Simkl**, and its stream
picker says there is no playable stream.

## Evidence and limits

- Plex/server catalog requests in this log mostly take roughly 180-960 ms;
  repeated movie/series pages contain 100 items. Captured searches return
  20/21, 0, 4, 1/2 movie matches, also in under a second.
- Several later ArchiveResume entries have complete stream choices and file
  sizes, including 9.2 GB, 5.9 GB, 8.0 GB and 27.7 GB. Server access/direct-file
  resolution works for at least some titles.
- An addon times out in the previous session. Existing stream scheduling could
  queue a server behind three such addons if one were added as a target.
- Confirmed code gap: tracker/list-only/Cinemeta stream searches do not add
  connected media servers as targets. An IMDb movie opened from Simkl can
  therefore show no playable stream even when Plex contains it.
- The log has no precise per-title miss trace for the pictured movie, nor
  poster-download timings. This proves a reproducible resolver defect matching
  the screenshot; it does not establish every cause of perceived slow browsing
  or prove every missing title has this same cause.

## Fix on codex/plex-tracker-streams (uncommitted)

- Public IMDb titles now also query enabled connected Plex/Jellyfin/Emby
  sources with a matching library type. Servers placed under Other are excluded.
- Search the selected title on demand, including additional filtered search
  pages. No full-library import or dependence on previously browsed pages.
- Resolve IMDb to server item id; if GUID data is missing, allow a unique
  normalized title+year. Conflicting IMDb ids, remakes and ambiguity are rejected.
  For shows, resolve season/episode to its native server id.
- Reserve an initial stream worker for one server; total worker limit stays 3.
  Results appear progressively; retries/session caching/viewer invalidation
  remain in the existing session. Recheck viewer/config between calls.
- Plex successes/empty results log hashed source, safe title reference,
  stream count and elapsed time; no addresses, credentials or file URLs.
- Native server playback still uses its own id directly. Shared matching also
  prevents recommendations substituting a conflicting known film.
- Expose MediaServerApi's catalog page size so targeted searches follow
  Plex/Jellyfin/Emby pagination without an unrelated numeric cap.

## Verification / delivery

The Simkl-to-Plex regression failed before the patch (zero options instead of 1).
Contract tests exercise real Plex JSON parsing through mocked HTTP; they do
not connect to the user's server. Coverage includes tracker/catalog origins,
pagination, remakes/ambiguity, exact-id precedence, episode ids, disabled/Other
sources, direct native playback, retries and viewer changes.
Validation: `16 issues found. (ran in 8.1s)` (existing info baseline);
`00:37 +1076: All tests passed!` Full suite includes 16 new regressions.
Targeted Plex/server/session/library suite: 39 tests passed.

This branch is based on phone-lock b3335a7 and carries that prior committed
feature. It does not include Claude's uncommitted main skip/odds/title changes.
No build, install, upload, merge, release or user-server changes were requested.

Next device check: open the same movie from both its Plex library and Simkl.
The Simkl picker should now offer My Plex. A fresh Send log for any continued
failure will show kind=plex, its title reference and items=0/1+.
Slow poster/browse reports still need a specific title/library example if they
persist after this resolver fix; do not label those independently solved.

Plex API reference: https://developer.plex.tv/pms/ (library queries, metadata,
allLeaves, direct parts). This reuses existing per-library/metadata APIs.
