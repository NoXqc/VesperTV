# Android updater storage and download checks (Codex, 2026-10-30)

AppUpdateService.downloadUpdate requires the positive GitHub asset size already
carried in UpdateInfo.apkSizeBytes. Before HTTP/file creation, it asks the existing
com.nox.nox_iptv/app_update channel for getAvailableStorageBytes. MainActivity
returns StatFs(cacheDir.absolutePath).availableBytes as a Long.

At least 3 * APK size must be available for the download and installer staging.
Insufficient space reports the additional shortfall rounded up to a whole MiB,
labelled approximately MB: Free about {mb} MB and try again. Missing/invalid asset
size or unavailable native storage results fail with a plain, translated message;
they cannot silently bypass the check. Windows retains its browser/ZIP flow.

Downloads use GitHub's size for progress and validation, regardless of HTTP
Content-Length. An overlong stream aborts early. After closing/flushing the sink,
the actual file length must exactly match the expected size before it is returned.
Empty/short/long bodies, interrupted streams and HTTP/write failures do not reach
Install; partial files are deleted after closing the sink. The HTTP client owned
by the service is closed. The settings screen passes apkSizeBytes, clears stale
ready paths, and guards repeated starts while a download is in progress.

At the first MainActivity.onCreate in a process, delete only the known internal
cache file noxplayer_update.apk, before Dart can begin a new download. Cleanup
failure cannot block app startup. A process guard prevents activity recreation
from deleting an APK while the package installer may still read it. A successful
app replacement starts a new process on its next launch and reclaims the old APK.
No other cache files, installer permissions or FileProvider paths change.

Four new error messages have FR/ES/IT/EL entries. Optional service HTTP/cache
providers and the settings service injection support contract/UI tests; production
defaults still use the app cache and the existing Windows/Android platform choice.

Validation: app_update_storage_test.dart covers 64-bit native results, 3x reserve,
rounded shortfall, unknown metadata/storage failures, exact match with absent or
misleading HTTP size, empty/truncated/oversized/interrupted bodies and cleanup,
all five UI languages, no Install on failure and verified native installer handoff.
Android :app:compileDebugKotlin succeeded. Cold-launch deletion and a real low-space
Fire OS update still require device QA. No installable APK/version bump or upload
was requested for this change; hosted test530 predates it.
