# Cloud sync (sync code, no accounts)

Owner decisions (2026-11-04): no login, no data collection; a **sync code** links devices; data
is encrypted on the device and only the code holder can read it; the server deletes a sync
after **3 months without any device checking in**. Hosted on the VPS relay (`tools/pair_relay`,
`pair.vespertv.app`), next to Transfer's vault. ~400 active users (estimate) is tiny for it.

## What the server sees
An opaque id, a hashed write token, a version number, the expiry and ciphertext (≤ 4 MB).
No IP is stored (nginx `access_log off`, the relay logs no requests); a per-IP request counter
lives in memory only for rate limiting.

## Keys and codes
- **Sync secret**: 16 random bytes, made by the first device, kept by every linked device
  (device-only pref `vesper_sync_link`). `VaultKeys.fromMaster(secret)` gives the sync id, write
  token and AES-256-GCM key (the same HKDF scheme as Transfer, label space `vesper-vault-v1`).
  Never typed; nothing to brute-force offline.
- **Link code** (to add a device): 16 digits, the same as Transfer's code. The linked device
  uploads the secret to the **vault** (`/api/v/`, 10 minutes, envelope `kind: sync-link`); the new
  device types the code (or scans the QR) and gets the secret. Reuses the vault as is.
- **Recovery code**: the secret itself, 26 characters of Crockford base32 (`ABCD-EFGH-…`). Shown
  once at setup ("Save this code. It's the only way back in if you lose all your devices. We
  can't recover it."), again behind the profile PIN, and as a QR. Optional in Backup & restore.
- **Reset sync code** (leak / sold box): new secret, re-upload, delete the old blob; other
  devices then need a new link code.

## What syncs (v1)
The same keys Transfer copies (`StorageService._transferable`): playlists, every viewer's
favourites, hidden groups/channels, own groups, watch positions, history, Sports Trak, Media Hub
sources/favourites/resume, settings. Device-only keys (layout, enabled playlists on this box,
caches, PIN lockout, current viewer, backup timer) never sync. Not in v1: profile photos, imported
M3U files and the recently played / Continue Watching history (files in the cache folder, not
prefs; watch *positions* do sync). **Continue Watching does sync** (since 2026-11-04): each viewer's
`recently_played*` cache file travels as a `file:<name>` key, merges newest first (`mergeSync`
`newestFirst`; Media Hub Recently watched too, by source + title) and is live (`reloadForViewer`).
A missing file means "unknown", never "cleared" (`SyncEngine.keepWhenMissing`): Android may empty the
cache folder, and sync writes the history back instead of wiping every device.

## Size (measured 2026-11-04)
Owner's Windows install: 69 keys, 40 KB gzipped. Synthetic heavy user (13 playlists x ~1650 hidden
groups, 3 profiles, 3000 watched titles): ~600 KB gzipped, hidden groups = most of it. Cap raised
1 MB -> 4 MB (owner OK). Every upload is the whole snapshot: ~600 KB per push for such a user, at most
every 2 min while watching. If Send log `Sync: … pushed N KB` shows big users, split the snapshot
into parts (progress / lists / rest) so playback only sends a few KB.

## Applying while the app runs
Services read storage once at launch and keep their own copy, so a pulled value they own could be
saved back over by them. So:
- **Live keys** (`StorageService.isLiveSyncKey`: favourites, favourite groups/order, own groups,
  hidden groups/channels, watch positions, palette) are written at once and the app runs the
  profile-switch reload (`applyActiveViewer`, `reloadForViewer`, `reloadPaletteForViewer`).
- **Everything else** (playlists, Media Hub, settings, Sports Trak) is **held**
  (`SyncState.deferred`): already merged and on the server, written at the next launch by the
  sync that runs before the services load (`CloudSyncService.syncBeforeLoad`, max 4 s of splash).
  Held keys are never pushed back as old values; a local edit to one is a normal change.
- The engine uploads before writing anything, and skips the round if the user changed one of the
  keys meanwhile (`SyncResult.busy`).

Wiring (`main.dart`): cold sync right after `StorageService.init`, then `startAutomatic()` (every
5 min), `AppLifecycleListener` resume, and `noteLocalChange` on PlaylistManager / ArchiveService /
PlaybackService notifications (at most one change-sync per 2 min, only if something differs).
Send log: `Sync: N in, N held, pushed N KB, T ms` / `Sync: failed (kind)`; never values.

## Merge (on the device; the server only stores the blob)
Each device keeps the **base**: the last snapshot it agreed with the server. On sync, per key:
- unchanged here since base → take the server's value (or its removal);
- changed here, not on the server → keep ours;
- changed on both → by kind:
  - **string list** (favourites, hidden sets): 3-way set merge (server's list + our additions −
    our removals);
  - **JSON list of objects with `id`** (playlists, Media Hub sources, viewer profiles): 3-way per
    id, the same rules per entry, newer stamp wins an entry both changed;
  - anything else: newest stamp wins (each key's stamp = when a device first uploaded the change).
- A device **joining** (no base yet) merges its lists in but takes the server's scalar values.

Uploads are conditional (`If-Match: <version>`); a 412 means another device uploaded meanwhile:
download, merge again, retry (max 3).

## Timing
Push a few seconds after a change (debounced) and when leaving the player; pull at start, when
the app comes back to the screen, when a show/movie page opens, and every 5 minutes while open
(`If-None-Match` → 304, a few bytes). No push notifications (they'd need Google/Amazon).

## Logins that refresh themselves (phase 3)
- Trakt/Simkl refresh tokens rotate: the device that refreshes must sync the new token at once.
- Jellyfin/Emby/Plex logins are per device: sync the server + user, each device signs in once.

## Server API (`relay.py`, `/api/sync/<id>`)
- `GET` → 200 blob + `ETag: "<version>"`, 304 on `If-None-Match` match, 404. Refreshes the
  3-month expiry (written at most once a day per sync).
- `PUT` (`X-Vault-Token`, `If-Match: "<version>"`, `"0"` = create) → 204 + new `ETag`;
  412 version mismatch, 403 wrong token, 413 over 4 MB.
- `DELETE` (`X-Vault-Token`) → 204 / 404.
- 429 over 1200 requests/hour per IP (in memory). Shares the vault's 2 GB disk cap.

## Phases
1. **Core (this branch):** relay endpoint + tests; `cloud_sync.dart` (secret, link/recovery
   codes, client with retries), `sync_merge.dart` (pure merge), storage export/apply; unit +
   local-relay tests. No UI, no app wiring.
2. **App:** lifecycle + live apply + Send log (done, Claude); Settings > Device & data > **Sync**
   screen, playlist matching on join, relay tests/deploy prep, docs (Codex, HANDOFF pickup).
3. **Logins + polish:** token rotation, per-device media-server sign-in, reminder to save the
   recovery code, Backup & restore option.

Deploying the relay change needs the owner's OK (back up the service, restart only pair-relay).
