"""Send log store for the GitHub issue helper; local only, no credentials.

Run from the repository root:
    python -m unittest discover -s tools/pair_relay -p "test_*.py" -v
"""
import http.client
import os
import tempfile
import threading
import types
import unittest
from unittest.mock import patch

import relay

KEY = "fixture_read_key_0123456789abcdef0123456789"
CODE = "LOG-7K2QXM"


class LogStoreTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="vesper-log-test-")
        self.addCleanup(self.directory.cleanup)
        self.now = 1_800_000_000
        self.sent = []
        self.patches = [
            patch.object(relay, "VAULT_DIR", self.directory.name),
            patch.object(relay, "REQUIRE_APP", True),
            patch.object(relay, "LOG_READ_KEY", KEY),
            patch.object(relay, "LOG_WEBHOOK", "https://discord.invalid/hook"),
            patch.object(relay, "_post_discord",
                         lambda code, text: self.sent.append(code) or True),
            patch.object(relay, "time", types.SimpleNamespace(time=lambda: self.now)),
        ]
        for item in self.patches:
            item.start()
            self.addCleanup(item.stop)
        relay._log_hits.clear()
        self.server = relay.ThreadingHTTPServer(("127.0.0.1", 0), relay.Handler)
        self.server.daemon_threads = True
        self.thread = threading.Thread(
            target=self.server.serve_forever, kwargs={"poll_interval": .01}, daemon=True)
        self.thread.start()
        self.addCleanup(self.close_server)

    def close_server(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def request(self, method, path, body=None, headers=None):
        c = http.client.HTTPConnection(*self.server.server_address, timeout=3)
        try:
            c.request(method, path, body=body, headers=headers or {})
            r = c.getresponse()
            return r.status, r.read()
        finally:
            c.close()

    def send_log(self, code=CODE, text=b"Device: Homatics\nPlayback error x\n"):
        return self.request("POST", "/api/log", text, {
            "X-VesperTV-App": "VesperTV", "X-Log-Code": code,
            "Content-Type": "text/plain"})

    def read_log(self, code=CODE, key=KEY):
        return self.request("GET", f"/api/log/{code}", headers={"X-Log-Key": key})

    def test_sent_log_reaches_discord_and_the_helper(self):
        self.assertEqual(self.send_log()[0], 204)
        self.assertEqual(self.sent, [CODE])
        status, body = self.read_log()
        self.assertEqual(status, 200)
        self.assertIn(b"Playback error", body)

    def test_wrong_or_missing_key_is_refused(self):
        self.send_log()
        self.assertEqual(self.read_log(key="nope")[0], 403)
        self.assertEqual(self.request("GET", f"/api/log/{CODE}")[0], 403)

    def test_unknown_code_and_bad_paths(self):
        self.assertEqual(self.read_log("LOG-AAAAAA")[0], 404)
        self.assertEqual(self.read_log("LOG-../../x")[0], 404)
        self.assertEqual(self.read_log("LOG-1I0O00")[0], 404)  # not the alphabet

    def test_gone_after_14_days(self):
        self.send_log()
        self.now += relay.LOG_KEEP + 1
        self.assertEqual(self.read_log()[0], 404)
        relay._log_prune()
        self.assertEqual(os.listdir(os.path.join(self.directory.name, "logs")), [])

    def test_without_the_key_nothing_is_kept(self):
        with patch.object(relay, "LOG_READ_KEY", ""):
            self.assertEqual(self.send_log()[0], 204)  # Discord as before
            self.assertEqual(self.read_log()[0], 404)
        self.assertFalse(os.path.exists(os.path.join(self.directory.name, "logs")))

    def test_kept_even_when_discord_fails(self):
        with patch.object(relay, "_post_discord", lambda code, text: False):
            self.assertEqual(self.send_log()[0], 204)
        self.assertEqual(self.read_log()[0], 200)

    def test_oldest_logs_go_past_the_size_cap(self):
        with patch.object(relay, "LOG_STORE_MAX", 100):
            for i, code in enumerate(["LOG-AAAAA2", "LOG-AAAAA3", "LOG-AAAAA4"]):
                self.now += 10
                relay._log_hits.clear()
                self.send_log(code, bytes([65 + i]) * 60)
            self.assertEqual(self.read_log("LOG-AAAAA2")[0], 404)
            self.assertEqual(self.read_log("LOG-AAAAA3")[0], 404)
            self.assertEqual(self.read_log("LOG-AAAAA4")[0], 200)


if __name__ == "__main__":
    unittest.main()
