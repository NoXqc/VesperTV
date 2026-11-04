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
  device types the code (or scans the QR) and gets the secret. `X-Vault-Once: 1` makes each
  link code single-use, for one device; Transfer uploads stay multi-read. Every link/recovery
  code for that secret shares the same limit of 3 devices per sync.
- **Recovery code**: the secret itself, 26 characters of Crockford base32 (`ABCD-EFGH-…`). Shown
  once at setup ("Save this code. It's the only way back in if you lose all your devices. We
  can't recover it."), again behind the profile PIN, and as a QR. Optional in Backup & restore.
- **Reset sync code** (leak / sold box): overwrite the old encrypted snapshot with a reset
  marker, drop all its device slots, then start a new sync from this device's local data
  using a new secret and the same device id. Other devices must link again. Save the new
  recovery code. The marker expires after 30 days and refuses uploads meanwhile (410).

## What syncs (v1)
The same keys Transfer copies (`StorageService._transferable`): playlists, every viewer's
favourites, hidden groups/channels, own groups, watch positions, history, Sports Trak, Media Hub
sources/favourites/resume, settings. Device-only keys (layout, enabled playlists on this box,
caches, PIN lockout, current viewer, backup timer) never sync. Profile photos and imported M3U
files do not sync. **Continue Watching does sync** (since 2026-11-04): each viewer's
`recently_played*` cache file travels as a `file:<name>` key, merges newest first (`mergeSync`
`newestFirst`; Media Hub Recently watched too, by source + title) and is live (`reloadForViewer`).
A missing file means "unknown", never "cleared" (`SyncEngine.keepWhenMissing`): Android may empty the
cache folder, and sync writes the history back instead of wiping every device.

## Profiles (checked 2026-11-04)
- Every profile syncs: the list (`nox_viewer_profiles`, merged per id), each one's keys (`__vp_<id>`
  suffix) and Continue Watching file. Which profile is active stays per device; switching on one box
  never moves another. One sync per device covers all profiles (Settings is PIN-gated for kids).
- Parental PIN (hashed) syncs, so it's the same everywhere; lockout counters stay per device.
- Deleting a profile removes it everywhere; a box using it falls back to Main at its next launch
  (`ViewerProfileService` init). Its history file counts as removed, not "missing"
  (`keepHistoryWhenMissing`).
- **Not synced: profile photos** (files up to 2 MB each): other devices show the default avatar.
- Profiles match on join by trimmed, case/accent-insensitive name. Main never remaps; only the
  first local duplicate claims an unambiguous server profile. Other duplicates keep their data.
  See `dev-notes/sync-profile-matching.md` for held migrations, suffixes and history-file ids.

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
All current clients send `X-VesperTV-App` and a random `X-Sync-Device` id. A sync has at most
3 device slots, stored as hashes and last check-in times in `dev`; no hardware ids. Valid GETs
(including 304) and PUTs enroll/check in the device. A slot expires after 30 days idle; its
last-seen write is throttled to once an hour. New link/recovery codes never reset this budget.

- `GET` → 200 blob + `ETag: "<version>"`, 304 on `If-None-Match` match, 404. Refreshes the
  active snapshot's 3-month expiry (at most once a day); reset markers never extend their expiry.
- `PUT` (`X-Vault-Token`, `If-Match: "<version>"`, `"0"` = create) → 204 + new `ETag`;
  412 version mismatch, 403 wrong token, 413 over 4 MB, 507 shared disk cap. A reset adds
  `X-Sync-Revoke: 1`, overwrites the old snapshot, drops `dev`, sets `revoked: true` and a fixed
  30-day expiry. Further PUTs to that id get 410, including resets retried after success.
- Fourth device on GET/PUT → **403**, `X-Sync-Error: device-limit`, `X-Sync-Max-Devices: 3`.
  The client throws `SyncDeviceLimit`; the service clears its state and shows `SyncStatus.full`.
  This differs from 403 for a wrong write token, which has no device-limit header.
- `DELETE /api/sync/<id>/device` (`X-Vault-Token`, `X-Sync-Device`) → 204 / 404; frees only
  this device's slot, retaining the snapshot and other devices. Wrong token = 403, malformed
  device/token = 400. Stop syncing calls it best effort before deleting the local sync state.
- `DELETE /api/sync/<id>` (`X-Vault-Token`) → 204 / 404; removes the entire server copy.
- 429 over 1200 requests/hour per IP (in memory). Shares the vault's 2 GB disk cap.
- Legacy clients without `X-Sync-Device` remain allowed/unaccounted while
  `PAIR_SYNC_REQUIRE_DEVICE` is unset/0 (+609/+610 compatibility). With it set to 1, missing
  device ids are rejected with 400 on the slot-checking paths. Invalid supplied ids are always
  rejected. Changing that flag needs separate owner approval; no count endpoint was added.

`/api/v/<id>` link uploads add `X-Vault-Once: 1`: first GET returns the encrypted blob and deletes
both files; later GETs return 404. Vault uploads without that header retain Transfer's normal
multi-read lifetime. The relay never decrypts either snapshot or reset marker.

## Phases
1. **Core (this branch):** relay endpoint + tests; `cloud_sync.dart` (secret, link/recovery
   codes, client with retries), `sync_merge.dart` (pure merge), storage export/apply; unit +
   local-relay tests. No UI, no app wiring.
2. **App:** lifecycle + live apply + Send log (done, Claude); Settings > Device & data > **Sync**
   screen, playlist matching on join, relay tests/deploy prep, docs (Codex, HANDOFF pickup).
3. **Logins + polish:** token rotation, per-device media-server sign-in, reminder to save the
   recovery code, Backup & restore option.

Deploying the relay change needs the owner's OK (back up the service, restart only pair-relay).

## Device limit + reset wipe (Claude, 2026-11-04, owner-approved design)
- **3 devices per sync**, counted per sync (secret), not per link code: every code and the
  recovery code lead to the same sync id, so a new code never resets the count.
  Each device keeps a random `SyncState.deviceId` (state file key `device`; old states get one at
  their next sync) and sends `X-Sync-Device` on every sync call. The relay keeps a hash of it +
  last check-in in the meta (`dev`); a 4th id gets **403 + `X-Sync-Error: device-limit`**
  (`X-Sync-Max-Devices: 3`) -> `SyncDeviceLimit` -> `SyncStatus.full` (engine stopped, nothing
  kept). `joinWithLinkCode`/`joinWithRecoveryCode` throw `SyncDeviceLimit` for the screen.
  A device silent **30 days** loses its slot. **Stop syncing** frees the slot first
  (`DELETE /api/sync/<id>/device`, best effort). Requests without a device id are allowed and not
  counted until `PAIR_SYNC_REQUIRE_DEVICE=1` (test builds +609/+610 don't send one).
- **Link codes are single-use** (`X-Vault-Once: 1`): the relay deletes the code on the first
  download. Transfer codes are unchanged (any number of downloads until expiry).
- **Reset sync code** PUTs the reset marker with `X-Sync-Revoke: 1`: the encrypted snapshot is
  overwritten, all device slots dropped, later PUTs on the old id get **410**, and the marker
  itself is deleted after **30 days** (devices that were offline still learn of the reset).
  The resetting device keeps its device id on the new sync.
- Limitation (no accounts): a modified build could reuse another device's id. Fine for the
  normal app / casual sharing.

### CODEX PICKUP (sync device limit — completed 2026-11-04)
Done by Claude (committed on `claude/cloud-sync`): relay (`tools/pair_relay/relay.py`), client
(`cloud_sync.dart`, `cloud_sync_service.dart`, `cloud_transfer.dart`), the link-code test updated.
Initial checks: analyze 16, `test/cloud_sync_test.dart` 12/12, relay unittest OK.
**Codex follow-up checklist (items 1–5 now complete; verification below):**
1. **Sync screen** (`lib/screens/settings/sync_screen.dart`):
   - `SyncStatus.full` banner (like `revoked`): "This sync already has 3 devices. Stop syncing on
     one of them, then try again. A device unused for 30 days frees its place on its own."
   - Join screen: catch `SyncDeviceLimit` from `joinWithLinkCode`/`joinWithRecoveryCode` and show
     the same text (don't treat it as a wrong code).
   - **Reset confirmation text** (owner wording, polish it): "Resetting the sync code removes all
     your encrypted data from the server. Every other device stops syncing and must be linked
     again with a new code. Save the new recovery code." (replaces "Other devices will stop
     syncing until you link them again. Save the new recovery code.")
   - Link-a-device screen: say the code works for **one** device.
   - Optional: "Devices: n of 3" needs a relay count endpoint; skip unless the owner asks.
2. **Translations** for every new string: fr, es, it, el, de.
3. **Tests**: relay unittest cases (4th device 403 on GET and PUT, leave frees a slot, 30-day idle
   frees a slot, revoke drops `dev` + 30-day exp + 410 on PUT, `X-Vault-Once` deletes on first GET,
   Transfer vault still multi-read, `PAIR_SYNC_REQUIRE_DEVICE`); update
   `test_metadata_contains_only_hashed_token_expiry_size_version` for `dev`/`revoked`/`once`.
   Dart: limit -> `SyncStatus.full`, stop() calls leave, reset keeps deviceId, old state without
   `device` gets one.
4. **Docs**: remote guide Sync tab + FAQ + homepage "05 / SYNC" section in `docs/index.html`
   (3 devices, single-use link code, reset wording), README/help index regen, this file's Server
   API section (new endpoint/headers/status codes).
5. **Deploy prep only**: relay redeploy steps in `tools/pair_relay/README.md`. **Do not deploy,
   push, merge to main or release** without the owner's OK.

Codex verification (2026-11-04): analyzer **16 issues found**; **1,229 Flutter tests passed**
(including all 19 Sync widget tests and 17 core sync tests); **18 relay unittests passed**,
including the disposable smoke with device ids required. Guide extraction: **102 answers**;
**17 Node help tests** and **6 Python help deployment-script tests** pass locally.
The full-state join test also caught/fixed a parent-route focus steal: status changes under
the join page no longer move focus away from its retry action. All new strings have
FR/ES/IT/EL/DE entries. The relay-only redeploy instructions preserve compatibility for
+609/+610 (`PAIR_SYNC_REQUIRE_DEVICE` unset/0); changing that flag requires separate approval.
No deployment, push, merge to main, release, version bump or device installation was performed.
Exact commit and results: main-checkout `HANDOFF.md`.
