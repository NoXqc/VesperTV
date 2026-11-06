"""Vesper AI link: lets the viewer's own AI app (Claude, ChatGPT or any MCP
client) talk to VesperTV on their TV, and the phone page talk to it from any
network (lib/services/vesper_ai/mcp_bridge.dart, dev-notes/vesper-ai.md).

The TV makes a random link secret and shows it as a connector URL:

    https://pair.vespertv.app/mcp/<secret>

The AI app speaks MCP (Streamable HTTP, JSON answers) to that URL. This
relay answers `initialize` / `ping` itself and passes everything else to the
TV, which long-polls for it and posts the answer back. Nothing is stored:
requests wait in memory for the TV (at most WAIT seconds) and only the
SHA-256 of the secret is kept, as the queue's name. The TV runs the tools;
this relay never sees the viewer's playlists except the answers it carries.

    POST /mcp/<secret>    MCP JSON-RPC from the AI app (one message)
    GET  /mcp/<secret>    a help page in a browser; 405 for MCP clients
    GET  /ai              the phone page (assets/vesper_ai/phone.html copy);
                          its link is in the URL fragment
    GET  /api/ai/poll     the TV: X-Vesper-Link; 200 {"id","msg"} or 204
    POST /api/ai/reply    the TV: X-Vesper-Link; {"id","msg"} -> 204
"""
import base64
import hashlib
import json
import os
import re
import threading
import time
import urllib.parse
import uuid

SECRET_RE = re.compile(r"^/mcp/([A-Za-z0-9_-]{32,128})/?$")
LINK_HEADER = "X-Vesper-Link"
LINK_RE = re.compile(r"^[A-Za-z0-9_-]{32,128}$")

POLL_WAIT = 25          # seconds the TV's poll is held open
WAIT = 75               # seconds an MCP request waits for the TV's answer
ONLINE = 45             # a TV that polled this recently counts as open
MAX_PENDING = 20        # queued requests per link
MAX_LINKS = 5000        # memory cap
MAX_WAITERS = 300       # held requests in all (each holds a thread)
MCP_MAX_BODY = 64 * 1024
REPLY_MAX_BODY = 512 * 1024
MCP_PER_HOUR = 1200     # per link
PROTOCOLS = ("2025-06-18", "2025-03-26", "2024-11-05")

PAGE = os.environ.get(
    "PAIR_AI_PAGE", os.path.join(os.path.dirname(__file__), "ai.html"))

INSTRUCTIONS = (
    "VesperTV is a TV app playing the viewer's own IPTV playlists (live "
    "channels with a guide, movies, TV shows) and Sports Trak scores. These "
    "tools act on the viewer's TV right now: search before playing, keep "
    "messages on the TV short. Plays and changes may need the viewer to "
    "press OK on the TV."
)


class _Link:
    __slots__ = ("queue", "waiting", "seen", "tools", "hits", "cond")

    def __init__(self):
        self.queue = []          # [(rid, msg)]
        self.waiting = {}        # rid -> [event, reply]
        self.seen = 0.0
        self.tools = None        # last tools/list result (bytes)
        self.hits = []
        self.cond = threading.Condition(_lock)


_lock = threading.Lock()
_links = {}
_waiters = 0


def _key(secret):
    return hashlib.sha256(secret.encode()).hexdigest()


def _link(key, now):
    link = _links.get(key)
    if link is None:
        if len(_links) >= MAX_LINKS:
            # Drop the longest-silent link (its waiters time out).
            oldest = min(_links, key=lambda k: _links[k].seen)
            del _links[oldest]
        link = _links[key] = _Link()
    return link


def _body(h, limit):
    try:
        length = int(h.headers.get("Content-Length", "0"))
    except ValueError:
        return None
    if length <= 0 or length > limit:
        return None
    data = h.rfile.read(length)
    return data if len(data) == length else None


def _rpc(id_, result=None, error=None):
    msg = {"jsonrpc": "2.0", "id": id_}
    if error is not None:
        msg["error"] = error
    else:
        msg["result"] = result
    return json.dumps(msg).encode()


def _offline_text():
    return ("VesperTV is not open on the TV right now. Ask the viewer to open "
            "VesperTV (Settings > Vesper AI > AI apps must stay on).")


# ------------------------------------------------------------------- MCP


def mcp_post(h, secret, clock=time.time):
    global _waiters
    raw = _body(h, MCP_MAX_BODY)
    if raw is None:
        return h._send(413 if h.headers.get("Content-Length") else 400)
    try:
        msg = json.loads(raw)
    except ValueError:
        return h._send(400, _rpc(None, error={"code": -32700, "message": "Parse error"}))
    if not isinstance(msg, dict):
        return h._send(400, _rpc(None, error={
            "code": -32600, "message": "One JSON-RPC message per request"}))
    method = msg.get("method")
    id_ = msg.get("id")
    now = clock()
    key = _key(secret)
    with _lock:
        link = _link(key, now)
        link.hits = [t for t in link.hits if t > now - 3600]
        if len(link.hits) >= MCP_PER_HOUR:
            return h._send(429)
        link.hits.append(now)
        online = now - link.seen < ONLINE
        cached_tools = link.tools

    if not isinstance(method, str):
        # A response or garbage from the client: nothing to do.
        return h._send(202)
    if id_ is None:
        # Notifications (initialized, cancelled): accepted, not forwarded.
        return h._send(202)
    if method == "initialize":
        params = msg.get("params") or {}
        asked = params.get("protocolVersion") if isinstance(params, dict) else None
        version = asked if asked in PROTOCOLS else PROTOCOLS[0]
        return h._send(200, _rpc(id_, {
            "protocolVersion": version,
            "capabilities": {"tools": {"listChanged": False}},
            "serverInfo": {"name": "VesperTV", "version": "1.0"},
            "instructions": INSTRUCTIONS,
        }))
    if method == "ping":
        return h._send(200, _rpc(id_, {}))

    if not online:
        if method == "tools/list" and cached_tools is not None:
            return h._send(200, _rpc(id_, json.loads(cached_tools)))
        if method == "tools/call":
            return h._send(200, _rpc(id_, {
                "content": [{"type": "text", "text": _offline_text()}],
                "isError": True,
            }))
        return h._send(200, _rpc(id_, error={"code": -32000, "message": _offline_text()}))

    rid = uuid.uuid4().hex
    event = threading.Event()
    slot = [event, None]
    with _lock:
        if _waiters >= MAX_WAITERS or len(link.queue) >= MAX_PENDING:
            return h._send(503)
        _waiters += 1
        link.waiting[rid] = slot
        link.queue.append((rid, msg))
        link.cond.notify_all()
    try:
        event.wait(WAIT)
    finally:
        with _lock:
            _waiters -= 1
            link.waiting.pop(rid, None)
            link.queue = [q for q in link.queue if q[0] != rid]
    reply = slot[1]
    if reply is None:
        if method == "tools/call":
            return h._send(200, _rpc(id_, {
                "content": [{"type": "text", "text":
                             "The TV did not answer in time. Try again."}],
                "isError": True,
            }))
        return h._send(200, _rpc(id_, error={
            "code": -32001, "message": "The TV did not answer in time."}))
    try:
        out = json.loads(reply)
        if not isinstance(out, dict):
            raise ValueError
    except ValueError:
        return h._send(502)
    out["jsonrpc"] = "2.0"
    out["id"] = id_
    if method == "tools/list" and isinstance(out.get("result"), dict):
        with _lock:
            link.tools = json.dumps(out["result"]).encode()
    return h._send(200, json.dumps(out).encode())


HELP_PAGE = """<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="no-referrer"><title>Vesper AI link</title>
<style>body{margin:0;background:#050505;color:#eee;font:16px/1.5 system-ui,sans-serif}
main{max-width:620px;margin:0 auto;padding:24px 16px}h1{color:#d4af37;font-size:22px}
code{display:block;word-break:break-all;background:#151515;border:1px solid #333;
border-radius:10px;padding:12px;margin:8px 0 6px;color:#fff}
button{background:#d4af37;color:#000;border:0;border-radius:10px;padding:10px 16px;
font-weight:700;font-size:15px}ol{padding-left:20px}li{margin:6px 0}
.dim{color:#999;font-size:14px}</style></head><body><main>
<h1>&#10022; Vesper AI link</h1>
<p>This is your TV's private connector address. Add it to your AI app:</p>
<code id="u"></code><button id="c" type="button">Copy</button>
<ol><li><b>Claude</b>: Settings &gt; Connectors &gt; Add custom connector, paste the address.</li>
<li><b>ChatGPT</b>: Settings &gt; Connectors (developer mode) &gt; Create, paste the address, no authentication.</li>
<li>Any other MCP client: a Streamable HTTP server at this address.</li></ol>
<p class="dim">Keep it private: anyone with it can control VesperTV while it is open.
Reset it on the TV in Settings &gt; Vesper AI &gt; AI apps.</p>
<script>var u=location.origin+location.pathname;document.getElementById('u').textContent=u;
document.getElementById('c').onclick=function(){navigator.clipboard.writeText(u).then(function(){
document.getElementById('c').textContent='Copied';});};</script></main></body></html>"""


def mcp_get(h, secret):
    accept = h.headers.get("Accept", "")
    if "text/html" in accept:
        return h._send(200, HELP_PAGE.encode(), "text/html; charset=utf-8")
    # No server-to-client stream: MCP clients fall back to POST only.
    h.send_response(405)
    h.send_header("Allow", "POST")
    h.send_header("Content-Length", "0")
    h.end_headers()


def phone_page(h):
    try:
        with open(PAGE, "rb") as f:
            body = f.read()
    except OSError:
        return h._send(404)
    return h._send(200, body, "text/html; charset=utf-8")


# -------------------------------------------------------------------- TV


def _tv_key(h):
    secret = h.headers.get(LINK_HEADER, "")
    return _key(secret) if LINK_RE.match(secret) else None


def poll(h, clock=time.time, wait=None):
    key = _tv_key(h)
    if key is None:
        return h._send(400)
    deadline = clock() + (POLL_WAIT if wait is None else wait)
    with _lock:
        link = _link(key, clock())
        link.seen = clock()
        while not link.queue:
            left = deadline - clock()
            if left <= 0:
                break
            link.cond.wait(min(left, 5))
            link.seen = clock()
        item = link.queue.pop(0) if link.queue else None
    if item is None:
        return h._send(204)
    rid, msg = item
    return h._send(200, json.dumps({"id": rid, "msg": msg}).encode())


def reply(h, clock=time.time):
    key = _tv_key(h)
    if key is None:
        return h._send(400)
    raw = _body(h, REPLY_MAX_BODY)
    if raw is None:
        return h._send(413)
    try:
        data = json.loads(raw)
        rid = data["id"]
        msg = data["msg"]
        if not isinstance(rid, str) or not isinstance(msg, dict):
            raise ValueError
    except (ValueError, KeyError, TypeError):
        return h._send(400)
    with _lock:
        link = _links.get(key)
        slot = link.waiting.get(rid) if link else None
        if link is not None:
            link.seen = clock()
        if slot is None:
            return h._send(404)
        slot[1] = json.dumps(msg).encode()
        slot[0].set()
    return h._send(204)


# ----------------------------------------------------------------- OAuth
#
# Claude (and other MCP apps) may insist on an OAuth sign-in before using a
# connector. The link secret in the URL is what grants access, so this is a
# minimal OAuth 2.1 server that approves at once: discovery metadata,
# dynamic client registration, an authorize step that redirects straight
# back with a code (PKCE S256 checked), and opaque tokens. The MCP endpoint
# accepts requests with or without a token (the phone page sends none).

ISSUER = os.environ.get("PAIR_PUBLIC_BASE", "https://pair.vespertv.app")
CODE_TTL = 300
_codes = {}  # code -> (expires, redirect_uri, challenge, method)
_codes_lock = threading.Lock()
WELL_KNOWN_PR = re.compile(
    r"^/\.well-known/oauth-protected-resource(/mcp/[A-Za-z0-9_-]{32,128})?/?$")
WELL_KNOWN_AS = re.compile(
    r"^/\.well-known/(oauth-authorization-server|openid-configuration)(/.*)?$")


def _as_metadata():
    return {
        "issuer": ISSUER,
        "authorization_endpoint": ISSUER + "/oauth/authorize",
        "token_endpoint": ISSUER + "/oauth/token",
        "registration_endpoint": ISSUER + "/oauth/register",
        "response_types_supported": ["code"],
        "grant_types_supported": ["authorization_code", "refresh_token"],
        "code_challenge_methods_supported": ["S256"],
        "token_endpoint_auth_methods_supported": ["none"],
        "scopes_supported": ["vespertv"],
    }


def oauth_get(h, path, query):
    """GET routes under /.well-known and /oauth; False if not ours."""
    m = WELL_KNOWN_PR.match(path)
    if m:
        resource = ISSUER + (m.group(1) or "/mcp")
        h._send(200, json.dumps({
            "resource": resource,
            "authorization_servers": [ISSUER],
            "scopes_supported": ["vespertv"],
            "bearer_methods_supported": ["header"],
        }).encode())
        return True
    if WELL_KNOWN_AS.match(path):
        h._send(200, json.dumps(_as_metadata()).encode())
        return True
    if path == "/oauth/authorize":
        q = urllib.parse.parse_qs(query)
        one = lambda k: (q.get(k) or [""])[0]
        redirect = one("redirect_uri")
        parsed = urllib.parse.urlparse(redirect)
        local = parsed.hostname in ("localhost", "127.0.0.1")
        if one("response_type") != "code" or not parsed.netloc or not (
                parsed.scheme == "https" or (parsed.scheme == "http" and local)):
            h._send(400, json.dumps({"error": "invalid_request"}).encode())
            return True
        code = uuid.uuid4().hex + uuid.uuid4().hex
        with _codes_lock:
            now = time.time()
            for k in [k for k, v in _codes.items() if v[0] < now]:
                del _codes[k]
            if len(_codes) > 5000:
                _codes.clear()
            _codes[code] = (now + CODE_TTL, redirect,
                            one("code_challenge"), one("code_challenge_method"))
        params = {"code": code}
        if one("state"):
            params["state"] = one("state")
        sep = "&" if parsed.query else "?"
        h.send_response(302)
        h.send_header("Location", redirect + sep + urllib.parse.urlencode(params))
        h.send_header("Cache-Control", "no-store")
        h.send_header("Content-Length", "0")
        h.end_headers()
        return True
    return False


def _token_reply(h):
    h._send(200, json.dumps({
        "access_token": "vtv_" + uuid.uuid4().hex + uuid.uuid4().hex,
        "token_type": "Bearer",
        "expires_in": 365 * 24 * 3600,
        "refresh_token": "vtr_" + uuid.uuid4().hex + uuid.uuid4().hex,
        "scope": "vespertv",
    }).encode())


def oauth_post(h, path):
    """POST /oauth/register and /oauth/token; False if not ours."""
    if path == "/oauth/register":
        raw = _body(h, 16 * 1024)
        try:
            req = json.loads(raw) if raw else {}
            if not isinstance(req, dict):
                raise ValueError
        except ValueError:
            h._send(400, json.dumps({"error": "invalid_client_metadata"}).encode())
            return True
        out = {
            "client_id": "vtc_" + uuid.uuid4().hex,
            "client_id_issued_at": int(time.time()),
            "token_endpoint_auth_method": "none",
            "grant_types": ["authorization_code", "refresh_token"],
            "response_types": ["code"],
        }
        for k in ("redirect_uris", "client_name", "scope"):
            if k in req:
                out[k] = req[k]
        h._send(201, json.dumps(out).encode())
        return True
    if path == "/oauth/token":
        raw = _body(h, 16 * 1024) or b""
        ctype = h.headers.get("Content-Type", "")
        try:
            if "json" in ctype:
                form = {k: str(v) for k, v in json.loads(raw).items()}
            else:
                form = {k: v[0] for k, v in
                        urllib.parse.parse_qs(raw.decode()).items()}
        except (ValueError, AttributeError):
            form = {}
        grant = form.get("grant_type")
        if grant == "refresh_token" and form.get("refresh_token"):
            _token_reply(h)
            return True
        if grant != "authorization_code":
            h._send(400, json.dumps({"error": "unsupported_grant_type"}).encode())
            return True
        with _codes_lock:
            item = _codes.pop(form.get("code", ""), None)
        bad = item is None or item[0] < time.time()
        if not bad and form.get("redirect_uri") and form["redirect_uri"] != item[1]:
            bad = True
        if not bad and item[2]:
            verifier = form.get("code_verifier", "")
            digest = base64.urlsafe_b64encode(
                hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
            bad = digest != item[2]
        if bad:
            h._send(400, json.dumps({"error": "invalid_grant"}).encode())
            return True
        _token_reply(h)
        return True
    return False
