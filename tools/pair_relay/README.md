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
  short-lived link codes for cloud sync reuse this vault without changing its TTL.
- **Cloud sync** (`/api/sync/<id>`, `lib/services/cloud_sync.dart`): opaque ciphertext
  up to 4 MB, versioned with ETags and conditional uploads. Deleted after **90 days**
  without a GET/PUT (the UI calls this 3 months). GET, including 304, extends expiry
  at most once a day. Wrong token = 403, stale version = 412, over 4 MB = 413,
  over 1,200 requests/hour/IP = 429. Shares the vault's 2 GB disk cap (507).
  Files use an `s.` prefix, so even identical vault/sync ids never collide.
  Code resets are encrypted app-level revocation blobs; the relay does not inspect them.
- **Send log** (`POST /api/log`, Settings > Device & data, `lib/services/app_log.dart`): the app
  sends its redacted log as text with an `X-Log-Code` (`LOG-XXXXXX`); the relay posts it as a
  file to the owner's private Discord channel and keeps nothing. 1 MB cap, 5 an hour per IP (+
  nginx `pairlog` zone). The webhook URL is a secret: `PAIR_LOG_WEBHOOK=` in root-only
  `/etc/pair-relay.env` (`EnvironmentFile`), never in the repo; without it the route answers 503.
- `pair.html` — copy `assets/pair/pair.html` next to `relay.py` (same file the TV serves).
- `pair-relay.service` — systemd unit (`DynamicUser`, read-only filesystem, 128 MB cap).

## Local tests (no server access)

From the repository root:

```sh
python -m unittest discover -s tools/pair_relay -p 'test_*.py' -v
```

Standard library only; binds an ephemeral loopback port and uses a temporary folder,
fixture tokens and a patched clock. Covers 90-day expiry/pruning, daily touch (including
304), the exact 4 MB cap, 429 per IP/hour for all methods, 412/403/304, opaque revocation,
shared disk cap, metadata privacy and vault/sync namespace isolation. No sleeps for expiry.

## Sync rollout on an existing install (pending owner approval)

**Do not execute these commands until the owner approves the exact commands for that
session.** Read the owner's private VPS notes first to resolve the SSH destination and
nginx config path. Keep these private details out of this public repository.

1. Run the local tests above. Stage the reviewed `relay.py`, `smoke_sync.py` and nginx
   change on the server only after approval. Do not copy `pair.html`, the systemd unit,
   or the environment file during this update. No install, daemon-reload or enable needed.
2. The new `/api/sync/` location in `nginx-pair.conf` is required: the generic pairing
   route caps bodies at 8 KB and lacks `X-Real-IP`. Merge **only that location** into the
   live pairing server block; preserve all current vault/log/download locations. The relay
   trusts only nginx's overwritten `X-Real-IP` for its in-memory sync request budget.
3. Prepare the staged nginx file with that one addition, review its diff, and resolve the
   three staged/config paths below from the private notes. The following is the complete
   server command sequence to submit for approval (run as the service administrator):

```sh
set -eu
# Set these to the reviewed, absolute paths before requesting approval:
: "${PAIR_RELAY_STAGED:?reviewed staged relay.py path}"
: "${PAIR_NGINX_STAGED:?reviewed staged nginx config path}"
: "${PAIR_NGINX_CONFIG:?existing pairing nginx config path}"
: "${PAIR_SMOKE_STAGED:?reviewed staged smoke_sync.py path}"
cp /opt/pair-relay/relay.py /opt/pair-relay/relay.py.bak.$(date +%Y%m%d-%H%M%S)
cp "$PAIR_NGINX_CONFIG" "$PAIR_NGINX_CONFIG.bak.$(date +%Y%m%d-%H%M%S)"
cp "$PAIR_RELAY_STAGED" /opt/pair-relay/relay.py
cp "$PAIR_NGINX_STAGED" "$PAIR_NGINX_CONFIG"
nginx -t && systemctl restart pair-relay && systemctl reload nginx
systemctl is-active pair-relay
python3 "$PAIR_SMOKE_STAGED" http://127.0.0.1:8930
python3 "$PAIR_SMOKE_STAGED" https://pair.vespertv.app
```

The command chain stops before any service action if nginx validation fails. Restart
**only pair-relay**, then **reload nginx**. Never restart nginx or Tuliprox. If validation
or either smoke fails, stop and inspect; do not automatically retry, deploy other files,
or delete data. Resolve the exact backup paths and get approval for any rollback commands.
No changes to certificates, keys or `/etc/pair-relay.env` are needed.

`smoke_sync.py` creates one random disposable 16 KB fixture under `/api/sync/`, verifies
GET/304/412/update/delete/404, and deletes it in `finally`. It prints no id or token.
The public smoke also verifies the nginx body limit/proxy route. It sends no logs, calls
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
