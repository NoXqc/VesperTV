"""Vesper AI link (ai_link.py): MCP passthrough to a polling TV.

Run from the repository root:
    python -m unittest discover -s tools/pair_relay -p "test_*.py" -v
"""
import http.client
import json
import threading
import time
import unittest
from http.server import ThreadingHTTPServer
from unittest.mock import patch

import ai_link
import relay

SECRET = "fixture_link_secret_0123456789abcdefghijkl"
APP = {"X-VesperTV-App": "1", relay.ai_link.LINK_HEADER: SECRET}


class AiLinkTests(unittest.TestCase):
    def setUp(self):
        ai_link._links.clear()
        self.patches = [
            patch.object(ai_link, "POLL_WAIT", 2),
            patch.object(ai_link, "WAIT", 3),
            patch.object(relay, "REQUIRE_APP", True),
        ]
        for p in self.patches:
            p.start()
            self.addCleanup(p.stop)
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), relay.Handler)
        self.server.daemon_threads = True
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)
        self.port = self.server.server_address[1]

    def request(self, method, path, body=None, headers=None):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        data = json.dumps(body).encode() if body is not None else None
        h = {"Content-Type": "application/json"}
        h.update(headers or {})
        conn.request(method, path, body=data, headers=h)
        res = conn.getresponse()
        raw = res.read()
        conn.close()
        return res.status, (json.loads(raw) if raw else None)

    def mcp(self, method, params=None, id_=1):
        msg = {"jsonrpc": "2.0", "id": id_, "method": method}
        if params is not None:
            msg["params"] = params
        return self.request("POST", f"/mcp/{SECRET}", msg)

    def tv(self, answer):
        """One poll + reply, like McpBridge; returns what the TV received."""
        got = {}

        def run():
            status, item = self.request("GET", "/api/ai/poll", headers=APP)
            if status != 200:
                got["status"] = status
                return
            got["msg"] = item["msg"]
            self.request("POST", "/api/ai/reply",
                         {"id": item["id"], "msg": answer(item["msg"])},
                         headers=APP)

        t = threading.Thread(target=run)
        t.start()
        # Wait until the poll is held open (the TV counts as open).
        key = ai_link._key(SECRET)
        for _ in range(200):
            link = ai_link._links.get(key)
            if link is not None and link.seen > 0:
                break
            time.sleep(0.01)
        return t, got

    def test_initialize_and_ping_are_answered_by_the_relay(self):
        status, body = self.mcp("initialize", {"protocolVersion": "2025-06-18"})
        self.assertEqual(status, 200)
        self.assertEqual(body["result"]["protocolVersion"], "2025-06-18")
        self.assertEqual(body["result"]["serverInfo"]["name"], "VesperTV")
        self.assertEqual(self.mcp("ping")[1]["result"], {})
        status, _ = self.request(
            "POST", f"/mcp/{SECRET}",
            {"jsonrpc": "2.0", "method": "notifications/initialized"})
        self.assertEqual(status, 202)

    def test_tool_call_reaches_the_tv_and_comes_back(self):
        # The TV must have polled once to count as open.
        t, got = self.tv(lambda m: {"result": {"tools": [{"name": "search"}]}})
        status, body = self.mcp("tools/list", id_=7)
        t.join()
        self.assertEqual(got["msg"]["method"], "tools/list")
        self.assertEqual(status, 200)
        self.assertEqual(body["id"], 7)
        self.assertEqual(body["result"]["tools"][0]["name"], "search")

        t, got = self.tv(lambda m: {"result": {
            "content": [{"type": "text", "text": "playing"}]}})
        status, body = self.mcp("tools/call",
                                {"name": "play", "arguments": {"name": "TSN 1"}},
                                id_="abc")
        t.join()
        self.assertEqual(got["msg"]["params"]["arguments"]["name"], "TSN 1")
        self.assertEqual(body["id"], "abc")
        self.assertEqual(body["result"]["content"][0]["text"], "playing")

    def test_offline_tv_gets_a_clear_answer_and_cached_tools(self):
        status, body = self.mcp("tools/call", {"name": "search"})
        self.assertEqual(status, 200)
        self.assertTrue(body["result"]["isError"])
        self.assertIn("not open", body["result"]["content"][0]["text"])
        # Once a tools/list went through, it is answered while offline.
        t, _ = self.tv(lambda m: {"result": {"tools": [{"name": "x"}]}})
        self.mcp("tools/list")
        t.join()
        with patch.object(ai_link, "ONLINE", -1):
            status, body = self.mcp("tools/list", id_=3)
        self.assertEqual(body["result"]["tools"][0]["name"], "x")

    def test_poll_and_reply_need_the_app_header_and_a_link(self):
        status, _ = self.request("GET", "/api/ai/poll",
                                 headers={relay.ai_link.LINK_HEADER: SECRET})
        self.assertEqual(status, 403)
        status, _ = self.request("GET", "/api/ai/poll",
                                 headers={"X-VesperTV-App": "1"})
        self.assertEqual(status, 400)
        status, _ = self.request("GET", "/api/ai/poll", headers=APP)
        self.assertEqual(status, 204)
        status, _ = self.request("POST", "/api/ai/reply",
                                 {"id": "nope", "msg": {}}, headers=APP)
        self.assertEqual(status, 404)

    def test_secret_is_only_kept_hashed_and_batches_are_refused(self):
        self.mcp("ping")
        self.assertNotIn(SECRET, ai_link._links)
        status, body = self.request("POST", f"/mcp/{SECRET}", [{"a": 1}])
        self.assertEqual(status, 400)
        status, _ = self.request("POST", "/mcp/short", {"jsonrpc": "2.0"})
        self.assertEqual(status, 405)

    def test_help_page_and_phone_page(self):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        conn.request("GET", f"/mcp/{SECRET}", headers={"Accept": "text/html"})
        res = conn.getresponse()
        self.assertEqual(res.status, 200)
        self.assertIn(b"Vesper AI link", res.read())
        conn.request("GET", f"/mcp/{SECRET}", headers={"Accept": "text/event-stream"})
        res = conn.getresponse()
        res.read()
        self.assertEqual(res.status, 405)
        conn.request("GET", "/ai")
        res = conn.getresponse()
        self.assertEqual(res.status, 200)
        self.assertIn(b"vesper/say", res.read())
        conn.close()


if __name__ == "__main__":
    unittest.main()
