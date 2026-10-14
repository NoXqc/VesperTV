#!/usr/bin/env python3
"""VesperTV pairing relay — the "phone not on this Wi-Fi" path of
Add Playlist > "From my phone" (lib/services/phone_pairing_service.dart).

The phone encrypts the playlist form in the browser (AES-GCM, key only in the
QR code's URL fragment) and PUTs the ciphertext here; the TV polls with GET
and the blob is deleted on first read or after TTL seconds. This process
never sees a key or a plaintext, keeps everything in memory only, and logs
no request lines or bodies.

    GET  /p             -> the phone form (pair.html)
    PUT  /api/s/<id>    -> store {"iv","ct"} once (409 if already there)
    GET  /api/s/<id>    -> 200 + delete, or 404

Stdlib only. Listens on 127.0.0.1; nginx terminates TLS in front of it.
"""
import json
import os
import re
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = os.environ.get("PAIR_HOST", "127.0.0.1")
PORT = int(os.environ.get("PAIR_PORT", "8930"))
PAGE = os.environ.get("PAIR_PAGE", os.path.join(os.path.dirname(__file__), "pair.html"))
TTL = 600            # seconds a blob may wait for its TV
MAX_BODY = 8 * 1024  # an encrypted form is well under 2 KB
MAX_ITEMS = 2000     # memory cap; oldest are dropped first

ID_RE = re.compile(r"^/api/s/([A-Za-z0-9_-]{16,64})$")

_lock = threading.Lock()
_store = {}  # id -> (created, body bytes)


def _prune(now):
    for k in [k for k, (t, _) in _store.items() if now - t > TTL]:
        del _store[k]
    while len(_store) > MAX_ITEMS:
        del _store[min(_store, key=lambda k: _store[k][0])]


def _load_page():
    with open(PAGE, "rb") as f:
        return f.read()


class Handler(BaseHTTPRequestHandler):
    server_version = "pair"
    sys_version = ""

    def log_message(self, fmt, *args):  # no access log: URLs carry session ids
        pass

    def _send(self, code, body=b"", ctype="application/json"):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("X-Content-Type-Options", "nosniff")
        if ctype.startswith("text/html"):
            self.send_header(
                "Content-Security-Policy",
                "default-src 'none'; style-src 'unsafe-inline'; "
                "script-src 'unsafe-inline'; connect-src 'self'; "
                "form-action 'none'; base-uri 'none'; frame-ancestors 'none'",
            )
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path in ("/", "/p", "/p/"):
            try:
                return self._send(200, _load_page(), "text/html; charset=utf-8")
            except OSError:
                return self._send(500)
        m = ID_RE.match(path)
        if not m:
            return self._send(404)
        now = time.time()
        with _lock:
            _prune(now)
            item = _store.pop(m.group(1), None)
        if item is None:
            return self._send(404)
        return self._send(200, item[1])

    def do_PUT(self):
        m = ID_RE.match(self.path.split("?", 1)[0])
        if not m:
            return self._send(404)
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return self._send(400)
        if length <= 0 or length > MAX_BODY:
            return self._send(413)
        body = self.rfile.read(length)
        try:
            data = json.loads(body)
            if not (isinstance(data, dict) and isinstance(data.get("iv"), str)
                    and isinstance(data.get("ct"), str)):
                raise ValueError
        except ValueError:
            return self._send(400)
        now = time.time()
        with _lock:
            _prune(now)
            if m.group(1) in _store:
                return self._send(409)
            _store[m.group(1)] = (now, body)
        return self._send(204)

    def do_POST(self):
        self._send(405)


def main():
    _load_page()  # fail fast if the page is missing
    srv = ThreadingHTTPServer((HOST, PORT), Handler)
    srv.daemon_threads = True
    print(f"pair relay on {HOST}:{PORT}", file=sys.stderr, flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
