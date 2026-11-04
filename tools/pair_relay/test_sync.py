"""Local-only sync API regressions; Python standard library, no credentials.

Run from the repository root:
    python -m unittest discover -s tools/pair_relay -p "test_*.py" -v
"""
import http.client
import json
from pathlib import Path
import tempfile
import threading
import types
import unittest
from unittest.mock import patch

import relay
import smoke_sync


class SyncApiTests(unittest.TestCase):
    sid = "fixture_sync_012345678901"
    token = "fixture_write_token_01234567890123456789"
    wrong_token = "different_write_token_0123456789012345"
    blob = b"\x01" + bytes(range(63))

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="vesper-sync-test-")
        self.addCleanup(self.directory.cleanup)
        self.now = 1_800_000_000
        self.patches = [
            patch.object(relay, "VAULT_DIR", self.directory.name),
            patch.object(relay, "REQUIRE_APP", True),
            # Replace only relay's clock, not Python's shared time module.
            patch.object(relay, "time", types.SimpleNamespace(time=lambda: self.now)),
        ]
        for item in self.patches:
            item.start()
            self.addCleanup(item.stop)
        relay._sync_hits.clear()
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
        self.assertFalse(self.thread.is_alive())

    def request(self, method="GET", *, path=None, body=None, headers=None):
        connection = http.client.HTTPConnection(*self.server.server_address, timeout=3)
        try:
            connection.request(method, path or f"/api/sync/{self.sid}", body=body,
                               headers={"X-VesperTV-App": "VesperTV", **(headers or {})})
            response = connection.getresponse()
            return response.status, dict(response.getheaders()), response.read()
        finally:
            connection.close()

    def put(self, version=0, *, body=None, token=None, path=None, headers=None):
        return self.request("PUT", path=path, body=self.blob if body is None else body,
                            headers={"X-Vault-Token": token or self.token,
                                     "If-Match": f'"{version}"', **(headers or {})})

    def delete(self, *, token=None, path=None):
        return self.request("DELETE", path=path,
                            headers={"X-Vault-Token": token or self.token})

    def meta_path(self):
        return Path(self.directory.name, f"s.{self.sid}.meta")

    def meta(self):
        return json.loads(self.meta_path().read_text(encoding="utf-8"))

    def test_conditional_versions_and_wrong_token(self):
        self.assertEqual(self.request()[0], 404)
        status, headers, _ = self.put()
        self.assertEqual((status, headers["ETag"]), (204, '"1"'))
        self.assertEqual(self.put()[0], 412)
        self.assertEqual(self.put(1, token=self.wrong_token)[0], 403)
        self.assertEqual(self.delete(token=self.wrong_token)[0], 403)
        self.assertEqual(self.request()[2], self.blob)
        status, headers, body = self.request(headers={"If-None-Match": '"1"'})
        self.assertEqual((status, headers["ETag"], body), (304, '"1"', b""))
        self.assertEqual(self.put(1, body=self.blob[::-1])[1]["ETag"], '"2"')
        self.assertEqual(self.request()[2], self.blob[::-1])
        status, headers, _ = self.put(1)
        self.assertEqual((status, headers["ETag"]), (412, '"2"'))
        self.assertEqual(self.delete()[0], 204)
        self.assertEqual(self.delete()[0], 404)
        self.assertEqual(self.request()[0], 404)

    def test_expires_exactly_after_90_days_without_check_in(self):
        self.assertEqual(relay.SYNC_TTL, 90 * 24 * 3600)
        self.put()
        expiry = self.now + relay.SYNC_TTL
        self.assertEqual(self.meta()["exp"], expiry)
        self.now = expiry
        self.assertEqual(self.request()[0], 404)
        self.assertEqual(list(Path(self.directory.name).iterdir()), [])
        # A recovery-code owner may recreate an expired snapshot at version 0.
        self.assertEqual(self.put()[1]["ETag"], '"1"')

    def test_pruner_removes_unused_sync_and_vault_but_keeps_active_sync(self):
        self.put()
        self.put(path=f"/api/v/{self.sid}", headers={"X-Vault-Ttl": "60"})
        self.now += 89 * 24 * 3600
        self.assertEqual(self.request()[0], 200)  # active sync gets a new expiry
        self.now += 2 * 24 * 3600
        relay._vault_prune()
        self.assertEqual(self.request()[0], 200)
        self.assertEqual(self.request(path=f"/api/v/{self.sid}")[0], 404)
        self.now += relay.SYNC_TTL
        relay._vault_prune()
        self.assertEqual(list(Path(self.directory.name).iterdir()), [])

    def test_get_touches_expiry_at_most_once_per_day_even_on_304(self):
        self.put()
        initial = self.meta()["exp"]
        with patch.object(relay, "_write_atomic", wraps=relay._write_atomic) as writes:
            for elapsed in [1, 3600, relay.SYNC_TOUCH_EVERY]:
                self.now = initial - relay.SYNC_TTL + elapsed
                self.assertEqual(self.request(headers={"If-None-Match": '"1"'})[0], 304)
            writes.assert_not_called()
            self.now += 1
            self.assertEqual(self.request(headers={"If-None-Match": '"1"'})[0], 304)
            self.assertEqual(writes.call_count, 1)
            self.assertEqual(self.meta()["exp"], self.now + relay.SYNC_TTL)
            self.assertEqual(self.meta()["ver"], 1)
            self.now += 3600
            self.assertEqual(self.request()[0], 200)
            self.assertEqual(writes.call_count, 1)

    def test_four_megabyte_boundary_and_413_leave_previous_blob_intact(self):
        self.assertEqual(relay.SYNC_MAX_BODY, 4 * 1024 * 1024)
        body = b"x" * relay.SYNC_MAX_BODY
        self.assertEqual(self.put(body=body)[0], 204)
        # Only the declared size is needed: over-limit requests are rejected
        # before reading their body. Avoid a platform-dependent broken pipe.
        self.assertEqual(self.put(1, headers={
            "Content-Length": str(relay.SYNC_MAX_BODY + 1)})[0], 413)
        self.assertEqual(self.request()[2], body)
        self.assertEqual(self.meta()["ver"], 1)

    def test_429_all_methods_per_ip_and_next_hour_resets_counter(self):
        self.assertEqual(relay.SYNC_PER_HOUR, 1200)
        self.put()
        ip = "192.0.2.10"  # documentation-only fixture, no external request
        for method in ["GET", "PUT", "DELETE"]:
            relay._sync_hits[ip] = (int(self.now // 3600), 1200)
            self.assertEqual(self.request(method, headers={"X-Real-IP": ip})[0], 429)
        self.assertEqual(self.request(headers={"X-Real-IP": "192.0.2.11"})[0], 200)
        relay._sync_hits[ip] = (int(self.now // 3600), 1199)
        self.assertEqual(self.request(headers={"X-Real-IP": ip})[0], 200)
        self.assertEqual(self.request(headers={"X-Real-IP": ip})[0], 429)
        self.now += 3600
        self.assertEqual(self.request(headers={"X-Real-IP": ip})[0], 200)
        self.assertEqual(relay._sync_hits[ip][1], 1)

    def test_revocation_is_an_opaque_blob_without_server_interpretation(self):
        # The real app encrypts this. The relay must never decode/act on it.
        marker = b'{"kind":"revoked","arbitrary":"fixture padding"}'
        self.assertEqual(self.put(body=marker)[0], 204)
        self.assertEqual(self.request()[2], marker)
        self.assertEqual(self.put(1, body=self.blob)[0], 204)
        self.assertEqual(self.request()[2], self.blob)

    def test_identical_vault_and_sync_ids_are_isolated_for_read_write_delete(self):
        vault_path = f"/api/v/{self.sid}"
        vault_blob = b"vault fixture" * 5
        self.assertEqual(self.put(path=vault_path, body=vault_blob,
                                 headers={"X-Vault-Ttl": "60"})[0], 204)
        self.assertEqual(self.put()[0], 204)
        self.assertEqual(self.request()[2], self.blob)
        self.assertEqual(self.request(path=vault_path)[2], vault_blob)
        self.assertEqual(self.delete()[0], 204)
        self.assertEqual(self.request(path=vault_path)[2], vault_blob)
        self.assertEqual(self.put()[0], 204)
        self.assertEqual(self.delete(path=vault_path)[0], 204)
        self.assertEqual(self.request()[2], self.blob)
        self.assertEqual({p.name for p in Path(self.directory.name).iterdir()},
                         {f"s.{self.sid}.bin", f"s.{self.sid}.meta"})
        self.assertEqual(self.request(path=f"/api/v/s.{self.sid}")[0], 404)

    def test_sync_and_vault_share_disk_cap_and_failed_update_is_atomic(self):
        with patch.object(relay, "VAULT_MAX_TOTAL", len(self.blob) * 2):
            self.assertEqual(self.put()[0], 204)
            self.assertEqual(self.put(path=f"/api/v/{self.sid}",
                                     headers={"X-Vault-Ttl": "60"})[0], 204)
            self.assertEqual(self.put(1, body=self.blob + b"x")[0], 507)
            self.assertEqual(self.request()[2], self.blob)
            self.assertEqual(self.meta()["ver"], 1)
            self.assertEqual(self.delete(path=f"/api/v/{self.sid}")[0], 204)
            self.assertEqual(self.put(1, body=self.blob + b"x")[0], 204)

    def test_metadata_contains_only_hashed_token_expiry_size_version(self):
        self.put()
        meta = self.meta()
        self.assertEqual(set(meta), {"exp", "tok", "size", "ver"})
        self.assertEqual(meta["tok"], relay._token_hash(self.token))
        self.assertNotIn(self.token, self.meta_path().read_text(encoding="utf-8"))

    def test_deploy_smoke_uses_disposable_blob_and_cleans_up(self):
        smoke_sync.smoke("http://127.0.0.1:" + str(self.server.server_port))
        self.assertEqual(list(Path(self.directory.name).iterdir()), [])

    def test_app_header_and_malformed_requests(self):
        for method in ["GET", "PUT", "DELETE"]:
            self.assertEqual(self.request(method, headers={"X-VesperTV-App": ""})[0], 403)
        self.assertEqual(self.put(headers={"If-Match": "garbage"})[0], 400)
        self.assertEqual(self.put(token="short")[0], 400)
        self.assertEqual(self.put(body=b"tiny")[0], 400)
        self.assertEqual(self.request(path="/api/sync/../bad")[0], 404)
        self.assertEqual(list(Path(self.directory.name).iterdir()), [])


if __name__ == "__main__":
    unittest.main()
