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
  automatic cloud sync can later reuse it — only `VAULT_MAX_TTL` would change.
- **Send log** (`POST /api/log`, Settings > Device & data, `lib/services/app_log.dart`): the app
  sends its redacted log as text with an `X-Log-Code` (`LOG-XXXXXX`); the relay posts it as a
  file to the owner's private Discord channel and keeps nothing. 1 MB cap, 5 an hour per IP (+
  nginx `pairlog` zone). The webhook URL is a secret: `PAIR_LOG_WEBHOOK=` in root-only
  `/etc/pair-relay.env` (`EnvironmentFile`), never in the repo; without it the route answers 503.
- `pair.html` — copy `assets/pair/pair.html` next to `relay.py` (same file the TV serves).
- `pair-relay.service` — systemd unit (`DynamicUser`, read-only filesystem, 128 MB cap).

## Deploy (VPS)

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
uploads/deletes a minute per IP). Updating an existing install: replace the whole block (the
vault adds a `map`, a second zone and the `/api/v/` location), copy the new `relay.py` and
`pair-relay.service`, then `systemctl daemon-reload && systemctl restart pair-relay`. Back up first, then
`nginx -t && systemctl reload nginx` — a reload, not a restart, so streams through the same nginx
keep going.

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
