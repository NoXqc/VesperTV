# Pairing relay

Server half of Add Playlist > **From my phone** when the phone is *not* on the TV's Wi-Fi
(the Wi-Fi path needs no server: the TV serves `assets/pair/pair.html` itself).

- `relay.py` — stdlib Python, memory-only, no access log. Stores one AES-GCM blob per session
  (`PUT /api/s/<id>`), hands it to the TV once (`GET /api/s/<id>`, then deleted), expires after
  10 min. It never receives the key: that lives in the QR code's URL fragment.
- **Vault** (same process, `/api/v/<id>`): Settings > Transfer > *Different network*
  (`lib/services/cloud_transfer.dart`). The app uploads its setup encrypted under a key derived
  from a 16-digit code; the relay keeps the ciphertext on disk in `PAIR_VAULT_DIR`
  (`/var/lib/pair-relay`, systemd `StateDirectory`) until its expiry (≤ 7 days), serves it to any
  number of GETs, and deletes it on expiry or a `DELETE` with the write token (stored hashed).
  Caps: 8 MB per blob, 2 GB total (507 when full); expired files are pruned every 5 min. Built so
  short-lived link codes for cloud sync reuse this vault with `X-Vault-Once: 1`:
  one download, one device, then deleted. Ordinary Transfer uploads remain multi-read.
- **Cloud sync** (`/api/sync/<id>`, `lib/services/cloud_sync.dart`): opaque ciphertext
  up to 4 MB, versioned with ETags and conditional uploads. Deleted after **90 days**
  without a GET/PUT (the UI calls this 3 months). GET, including 304, extends expiry
  at most once a day. Wrong token = 403, stale version = 412, over 4 MB = 413,
  over 1,200 requests/hour/IP = 429. Shares the vault's 2 GB disk cap (507).
  Files use an `s.` prefix, so even identical vault/sync ids never collide.
  Each sync has **3 device slots** identified by hashed random `X-Sync-Device` ids.
  A fourth device gets 403 plus `X-Sync-Error: device-limit` / `X-Sync-Max-Devices: 3`.
  `DELETE /api/sync/<id>/device` frees the caller's slot; 30 days idle frees it automatically.
  Reset (`X-Sync-Revoke: 1`) overwrites the old encrypted snapshot, drops its slots and leaves
  only an opaque reset marker for 30 days. Later PUTs on the old id return 410; GETs do not
  extend the marker's expiry. The relay never decrypts the snapshot or marker.
- **Send log** (`POST /api/log`, Settings > Device & data, `lib/services/app_log.dart`): the app
  sends its redacted log as text with an `X-Log-Code` (`LOG-XXXXXX`); the relay posts it as a
  file to the owner's private Discord channel and keeps nothing. 1 MB cap, 5 an hour per IP (+
  nginx `pairlog` zone). The webhook URL is a secret: `PAIR_LOG_WEBHOOK=` in root-only
  `/etc/pair-relay.env` (`EnvironmentFile`), never in the repo; without it the route answers 503.
- `pair.html` — copy `assets/pair/pair.html` next to `relay.py` (same file the TV serves).
- `hub.html` — Settings > Media Hub sources > **Manage from phone** (2026-11-11), served at `/hub`. It
  sends JSON-RPC `hub/list|set|remove|url|add` to `/mcp/<link>` like the Vesper phone page (`/ai`);
  the TV answers them in phone-only mode (`McpBridge`, `lib/services/hub_remote.dart`). Its page alone
  allows `img-src https:` for the add-ons' own logos (`ai_link.HUB_CSP`). Lives only here (the TV never
  serves it); deploy it next to `relay.py` with `ai_link.py`.
- `pair-relay.service` — systemd unit (`DynamicUser`, read-only filesystem, 128 MB cap).

## Local tests (no server access)

From the repository root:

```sh
python -m unittest discover -s tools/pair_relay -p 'test_*.py' -v
```

Standard library only; binds an ephemeral loopback port and uses a temporary folder,
fixture tokens and a patched clock. Covers 90-day expiry/pruning, daily touch (including
304), the exact 4 MB cap, 429 per IP/hour, 412/403/304, fourth-device GET/PUT refusal,
leave and 30-day slot expiry, reset wipe/410/fixed marker expiry, hashed device metadata,
single-use links versus multi-read Transfer, device-header enforcement and shared disk cap.
All expiry checks use a patched clock. The smoke runs only against a disposable local relay.

## Device-limit / reset-wipe redeploy (pending owner approval)

**Do not execute these commands until the owner approves the exact commands for that
session.** Read the owner's private VPS notes first to resolve the SSH destination and
nginx config path. Keep these private details out of this public repository.

1. Run the local tests above. The initial sync route is already deployed; this update
   replaces **only `relay.py`** and uses the reviewed smoke helper. Stage those two files
   only after approval. Do not copy `pair.html`, a systemd unit, an environment file or
   nginx config. No install, daemon-reload, enable or nginx reload is needed.
2. The existing `/api/sync/` prefix location also proxies `/api/sync/<id>/device` and the
   new headers. Keep its **4 MB** body limit, overwritten `X-Real-IP`, no access log and
   all current pairing/vault/log/download locations. For a fresh install, the sample
   `nginx-pair.conf` includes that location; the generic pairing route caps bodies at 8 KB.
3. Leave `PAIR_SYNC_REQUIRE_DEVICE` **unset or 0** for +609/+610 compatibility: those test
   clients send no device id and are not counted. Modern clients are counted immediately.
   Requiring the header (`PAIR_SYNC_REQUIRE_DEVICE=1`) is a separate owner-approved rollout
   after those old clients are retired. Do not edit `/etc/pair-relay.env` for this update.
4. Resolve the two reviewed staged paths from the private notes before submitting these
   exact server commands for approval (run as the service administrator):

```sh
set -eu
# Set these to the reviewed, absolute paths before requesting approval:
: "${PAIR_RELAY_STAGED:?reviewed staged relay.py path}"
: "${PAIR_SMOKE_STAGED:?reviewed staged smoke_sync.py path}"
python3 -m py_compile "$PAIR_RELAY_STAGED" "$PAIR_SMOKE_STAGED"
nginx -t
cp /opt/pair-relay/relay.py /opt/pair-relay/relay.py.bak.$(date +%Y%m%d-%H%M%S)
cp "$PAIR_RELAY_STAGED" /opt/pair-relay/relay.py
systemctl restart pair-relay
systemctl is-active pair-relay
python3 "$PAIR_SMOKE_STAGED" http://127.0.0.1:8930
python3 "$PAIR_SMOKE_STAGED" https://pair.vespertv.app
```

`set -eu` stops before service actions on failed syntax/config validation. Restart
**only pair-relay**. Never restart nginx or Tuliprox; this relay-only update needs no nginx
reload. If validation or either smoke fails, stop and inspect. Do not automatically retry,
deploy other files or delete user data. Resolve the exact timestamped backup and get approval
for any rollback command. No certificates, keys or private environment files need changing.

`smoke_sync.py` creates one random disposable 16 KB fixture under `/api/sync/`, verifies
GET/304/412/update, fourth-device refusal on GET and PUT, leaving/replacing a slot, then reset
overwrite and 410 on the old id. It deletes its own marker in `finally`, then checks 404.
All device ids and tokens are random fixtures and are never printed. The public smoke also
verifies the nginx body limit/proxy route and new `/device` endpoint. It sends no logs, calls
no Discord API and touches no existing user blob. Record approved rollout/smoke results
in root `HANDOFF.md` and lasting server changes in the owner's private VPS notes.

## Fresh install (VPS)

```sh
mkdir -p /opt/pair-relay
cp relay.py /opt/pair-relay/ && cp ../../assets/pair/pair.html /opt/pair-relay/
cp pair-relay.service /etc/systemd/system/
systemctl daemon-reload && systemctl enable --now pair-relay
```

Certificate: add the host to the port-80 `server_name`, `mkdir -p /var/www/certbot`, then
`certbot certonly --webroot -w /var/www/certbot -d pair.vespertv.app`.

nginx: append `nginx-pair.conf` inside the `http {}` block (its own `server`, certificate,
`access_log off`, 8 KB body, 5 r/s + burst 20 per IP; `/api/v/` allows 8 MB bodies and 10
uploads/deletes a minute per IP). For an existing install, follow the scoped update above; preserve existing locations.
Back up first, validate with `nginx -t`, and reload nginx so existing streams keep going.

Live since 2026-10-13: `https://pair.vespertv.app` (Cloudflare A record, DNS only).

The app's relay address is `kPairRelayBase` in `lib/services/phone_pairing_service.dart`.

## Forks: run your own relay

`pair.vespertv.app` serves the official VesperTV app only. If you fork the app, deploy this folder
on your own server and point `kPairRelayBase` at it — don't ship a build that uses ours.

App calls (the TV's poll and all vault calls) send `X-VesperTV-App` (`kRelayAppHeaders`). The
relay logs an hourly count of calls with/without it (`journalctl -u pair-relay`) and, with
`PAIR_REQUIRE_APP=1` (on in `pair-relay.service` since 2026-10-17), rejects calls without it with
403. 1.0.14/1.0.15 installs don't send the header, so their Transfer and From-phone pairing stop
working until they update. It's not a secret, only a speed bump: a fork that
copies the header on purpose is deliberate abuse and can be blocked at nginx.
