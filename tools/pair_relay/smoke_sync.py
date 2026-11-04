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
    device = secrets.token_urlsafe(16)
    # Opaque fixture bytes, not an app snapshot. >8 KB catches missing nginx
    # sync routing, where the generic pairing limit would reject the upload.
    blob = b"\x01" + secrets.token_bytes(16383)

    def request(method, data=None, *, suffix="", **headers):
        req = urllib.request.Request(url + suffix, data=data, method=method, headers={
            "X-VesperTV-App": "VesperTV", "X-Vault-Token": token,
            "X-Sync-Device": device, **headers})
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
        second, third, fourth = [secrets.token_urlsafe(16) for _ in range(3)]
        for other in (second, third):
            if request("GET", **{"X-Sync-Device": other})[0] != 200:
                raise RuntimeError("could not fill the test device slots")
        status, headers, _ = request("GET", **{"X-Sync-Device": fourth})
        if status != 403 or headers.get("X-Sync-Error") != "device-limit":
            raise RuntimeError("fourth device GET was not refused")
        if request("PUT", blob, **{"If-Match": '"2"', "X-Sync-Device": fourth})[0] != 403:
            raise RuntimeError("fourth device PUT was not refused")
        if request("DELETE", suffix="/device", **{"X-Sync-Device": second})[0] != 204:
            raise RuntimeError("test device could not leave")
        if request("GET", **{"X-Sync-Device": fourth})[0] != 200:
            raise RuntimeError("leaving did not free the test slot")
        marker = b"\x01" + secrets.token_bytes(63)
        if request("PUT", marker, **{"If-Match": '"2"', "X-Sync-Revoke": "1"})[0] != 204:
            raise RuntimeError("test reset marker was not accepted")
        if request("GET")[2] != marker:
            raise RuntimeError("test reset did not replace the old snapshot")
        if request("PUT", blob, **{"If-Match": '"3"'})[0] != 410:
            raise RuntimeError("test reset still allowed an upload")
    finally:
        if created and request("DELETE")[0] != 204:
            raise RuntimeError("test blob cleanup failed")
    if request("GET")[0] != 404:
        raise RuntimeError("deleted test blob did not return 404")
    print("Sync smoke passed: >8 KB, 304/412, device limit/leave, reset/410, cleanup/404.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: python smoke_sync.py BASE_URL")
    smoke(sys.argv[1])
