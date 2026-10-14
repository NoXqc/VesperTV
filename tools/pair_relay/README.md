# Pairing relay

Server half of Add Playlist > **From my phone** when the phone is *not* on the TV's Wi-Fi
(the Wi-Fi path needs no server: the TV serves `assets/pair/pair.html` itself).

- `relay.py` — stdlib Python, memory-only, no access log. Stores one AES-GCM blob per session
  (`PUT /api/s/<id>`), hands it to the TV once (`GET /api/s/<id>`, then deleted), expires after
  10 min. It never receives the key: that lives in the QR code's URL fragment.
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
`access_log off`, 8 KB body, 5 r/s + burst 20 per IP). Back up first, then
`nginx -t && systemctl reload nginx` — a reload, not a restart, so streams through the same nginx
keep going.

Live since 2026-10-13: `https://pair.vespertv.app` (Cloudflare A record, DNS only).

The app's relay address is `kPairRelayBase` in `lib/services/phone_pairing_service.dart`.
