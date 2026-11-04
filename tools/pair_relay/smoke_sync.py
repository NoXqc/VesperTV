"""Explicit, disposable sync smoke test (stdlib only).

Creates a random test-only blob, checks conditional requests, then deletes it.
No user data, sync secrets or ids are printed. Never run against production
without the owner's approval. Usage: python smoke_sync.py BASE_URL
"""
import secrets
import sys
import urllib.error
import urllib.request


def smoke(base):
    url = base.rstrip("/") + "/api/sync/" + secrets.token_urlsafe(24)
    token = secrets.token_urlsafe(32)
    # Opaque fixture bytes, not an app snapshot. >8 KB catches missing nginx
    # sync routing, where the generic pairing limit would reject the upload.
    blob = b"\x01" + secrets.token_bytes(16383)

    def request(method, data=None, **headers):
        req = urllib.request.Request(url, data=data, method=method, headers={
            "X-VesperTV-App": "VesperTV", "X-Vault-Token": token, **headers})
        try:
            response = urllib.request.urlopen(req, timeout=30)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            return response.code, response.headers, response.read()

    created = False
    try:
        status, headers, _ = request("PUT", blob, **{"If-Match": '"0"'})
        if status != 204 or headers.get("ETag") != '"1"':
            raise RuntimeError(f"create: expected 204/version 1, got {status}")
        created = True
        if request("GET")[2] != blob:
            raise RuntimeError("GET did not return the test blob")
        if request("GET", **{"If-None-Match": '"1"'})[0] != 304:
            raise RuntimeError("conditional GET did not return 304")
        if request("PUT", blob, **{"If-Match": '"0"'})[0] != 412:
            raise RuntimeError("stale update did not return 412")
        if request("PUT", blob, **{"If-Match": '"1"'})[1].get("ETag") != '"2"':
            raise RuntimeError("update did not return version 2")
    finally:
        if created and request("DELETE")[0] != 204:
            raise RuntimeError("test blob cleanup failed")
    if request("GET")[0] != 404:
        raise RuntimeError("deleted test blob did not return 404")
    print("Sync smoke passed: >8 KB upload, GET, 304, 412, update, delete, 404.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: python smoke_sync.py BASE_URL")
    smoke(sys.argv[1])
