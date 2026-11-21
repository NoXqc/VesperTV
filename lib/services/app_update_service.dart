import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../utils/desktop_platform.dart';

/// Which releases Check for Updates offers (Settings > Check for Updates >
/// Update channel, this device only). Since 2026-11-21 (owner, AMD's
/// suggestion) there is one tested stable release a week, and test builds
/// in between: GitHub pre-releases tagged `<next version>-dev.<build>`
/// (dev-notes/release.md).
enum UpdateChannel {
  /// `/releases/latest` only: never a pre-release. The default.
  stable,

  /// The newest release, pre-releases included.
  test;

  static UpdateChannel parse(String? name) => name == test.name ? test : stable;
}

/// A GitHub release newer than what's currently installed.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.apkSizeBytes,
    this.testBuild = false,
  });

  /// The release's tag name (e.g. "3.19.1") — same scheme as the app's own
  /// version, so it's directly comparable via [_isDifferent].
  final String version;
  final String releaseNotes;

  /// The matching asset's direct download URL — an `.apk` on Android, a
  /// `.zip` on Windows (see [AppUpdateService.checkForUpdate]'s own doc
  /// comment for why Windows only ever opens this in a browser instead of
  /// downloading/installing it the way Android does).
  final String downloadUrl;
  final int apkSizeBytes;

  /// A GitHub pre-release (Update channel: Test builds).
  final bool testBuild;
}

/// User-readable updater failure without an "Exception:" prefix.
class UpdateDownloadException implements Exception {
  const UpdateDownloadException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Checks GitHub for a newer release, downloads it, and hands it to
/// Android's own package installer — there's no Play Store auto-update for
/// a sideloaded app, so this is the in-app replacement (Settings > Check
/// for Updates). See MainActivity.kt's doc comment for the native half
/// (install permission check + the actual install intent, which needs a
/// FileProvider — no pure-Dart/Flutter-plugin way to trigger an APK
/// install exists).
class AppUpdateService {
  AppUpdateService(
      {http.Client? downloadClient,
      Future<Directory> Function()? cacheDirectory,
      @visibleForTesting http.Client? apiClient,
      @visibleForTesting String? operatingSystem,
      @visibleForTesting Future<String> Function()? installedVersion})
      : _downloadClient = downloadClient,
        _cacheDirectory = cacheDirectory ?? getTemporaryDirectory,
        _apiClient = apiClient,
        _os = operatingSystem ?? Platform.operatingSystem,
        _installedVersion = installedVersion ??
            (() async => (await PackageInfo.fromPlatform()).version);
  final http.Client? _downloadClient;
  final http.Client? _apiClient;
  final String _os;
  final Future<String> Function() _installedVersion;
  final Future<Directory> Function() _cacheDirectory;
  bool get downloadInBrowser => isDesktop;
  static const _channel = MethodChannel('com.nox.nox_iptv/app_update');

  /// Public, unauthenticated GitHub API — fine for a public repo at this
  /// call volume (a user tapping "Check for Updates" occasionally), no
  /// token needed and none should be embedded in a distributed APK anyway.
  static const _repoApi = 'https://api.github.com/repos/NoXqc/VesperTV';
  static const _apiUrl = '$_repoApi/releases/latest';

  /// Newest first by creation. An older release object renamed in place
  /// (how 1.0.72 was published) can sit further down: [checkForUpdate]
  /// also reads `/releases/latest` for the test channel.
  static const _listUrl = '$_repoApi/releases?per_page=20';

  /// Null if already up to date, the request fails, or the release has no
  /// `.apk` asset attached (shouldn't happen for a real release, but a
  /// malformed/source-only one shouldn't crash the check).
  ///
  /// [channel] test: the newest release with an asset for this device,
  /// test builds (pre-releases) included ([pickNewest]); stable: GitHub's
  /// latest release only. Either way [shouldOffer] decides.
  Future<UpdateInfo?> checkForUpdate(
      {UpdateChannel channel = UpdateChannel.stable}) async {
    // No macOS or Linux release asset yet: never offer the Windows .zip.
    if (_os == 'macos' || _os == 'linux') return null;
    final latest = await _getJson(_apiUrl);
    final candidates = <Map<String, dynamic>>[
      if (latest is Map<String, dynamic>) latest,
    ];
    if (channel == UpdateChannel.test) {
      final list = await _getJson(_listUrl);
      if (list is List) {
        candidates.addAll(list.whereType<Map<String, dynamic>>());
      }
    }
    final release = pickNewest(candidates, _os);
    if (release == null) return null;
    final remote = (release['tag_name'] as String).trim();
    final installed = await _installedVersion();
    if (!shouldOffer(remote, installed, channel)) return null;
    final asset = pickAsset(
        (release['assets'] as List).cast<Map<String, dynamic>>(), _os);
    return UpdateInfo(
      version: remote,
      releaseNotes: (release['body'] as String?)?.trim() ?? '',
      downloadUrl: asset['browser_download_url'] as String,
      apkSizeBytes: (asset['size'] as int?) ?? 0,
      testBuild: release['prerelease'] == true,
    );
  }

  /// The release among [releases] with the highest version
  /// ([compareVersions]) that isn't a draft and has an asset for [os]
  /// ([pickAsset]); null when none has.
  @visibleForTesting
  static Map<String, dynamic>? pickNewest(
      List<Map<String, dynamic>> releases, String os) {
    Map<String, dynamic>? best;
    for (final r in releases) {
      final tag = (r['tag_name'] as String?)?.trim() ?? '';
      if (tag.isEmpty || r['draft'] == true) continue;
      final assets = (r['assets'] as List?)?.cast<Map<String, dynamic>>();
      if (assets == null ||
          pickAsset(assets, os)['browser_download_url'] is! String) {
        continue;
      }
      if (best == null ||
          compareVersions(tag, (best['tag_name'] as String).trim()) > 0) {
        best = r;
      }
    }
    return best;
  }

  /// Whether [remote] (a release tag) is offered over the [installed]
  /// version name. A test build installed (`1.0.73-dev.951`) only takes a
  /// newer version: Android never installs a lower build number, and a
  /// stable 1.0.72 is older. A stable install on the stable channel takes
  /// any different tag ([_isDifferent], the 1.0.0 restart); on the test
  /// channel only a newer one.
  @visibleForTesting
  static bool shouldOffer(
      String remote, String installed, UpdateChannel channel) {
    if (_isTestVersion(installed) || channel == UpdateChannel.test) {
      return compareVersions(remote, installed) > 0;
    }
    return _isDifferent(remote, installed);
  }

  static bool _isTestVersion(String version) => version.contains('-');

  /// GitHub's JSON for [url], or null on 304 (see below).
  Future<Object?> _getJson(String url) async {
    final response = await (_apiClient?.get ?? http.get)(
      Uri.parse(url),
      headers: {
        'Accept': 'application/vnd.github+json',
        // Reported directly on a Fire Stick: GitHub answered a plain,
        // header-less GET with 304 Not Modified — something between this
        // device and GitHub (a carrier/ISP transparent proxy, most
        // likely) was caching the response and serving a conditional
        // 304 on our behalf even though this code never sends an
        // `If-None-Match`/`If-Modified-Since` of its own. These headers
        // ask any such intermediary not to do that, so a real check
        // actually reaches GitHub instead of a stale cache entry.
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 304) {
      // Belt-and-suspenders alongside the no-cache headers above: a 304
      // here means "unchanged from whatever's cached," never an actual
      // failure — surfacing it as "Something went wrong: HTTP 304" (what
      // used to happen, falling through to the generic throw below) was
      // a real, reported bug. With no fresh body to read a version out
      // of, the safe reading is "nothing new to report," the same as a
      // genuine "you're already on the latest version."
      return null;
    }
    if (response.statusCode != 200) {
      // A bare "HTTP 403" reads as a permissions problem, but the actual
      // cause here is almost always GitHub's unauthenticated API rate
      // limit (60 requests/hour, shared by *every* device on the same
      // home network's public IP) — easy to hit when there's more than
      // one box/phone on the same network each tapping this button.
      // `X-RateLimit-Remaining: 0` distinguishes that specifically so the
      // message actually says what's wrong instead of leaving it a
      // mystery, e.g. "check again in the browser and it just works" the
      // next hour once the window resets.
      if (response.statusCode == 403 &&
          response.headers['x-ratelimit-remaining'] == '0') {
        final resetHeader = response.headers['x-ratelimit-reset'];
        final resetSeconds = int.tryParse(resetHeader ?? '');
        final waitMinutes = resetSeconds == null
            ? null
            : ((DateTime.fromMillisecondsSinceEpoch(resetSeconds * 1000)
                        .difference(DateTime.now())
                        .inSeconds) /
                    60)
                .ceil();
        throw Exception(waitMinutes != null && waitMinutes > 0
            ? trPlural(
                waitMinutes,
                'GitHub is temporarily rate-limiting update checks from this network — try again in about {n} minute.',
                'GitHub is temporarily rate-limiting update checks from this network — try again in about {n} minutes.')
            : tr(
                'GitHub is temporarily rate-limiting update checks from this network — try again shortly.'));
      }
      throw Exception('GitHub returned HTTP ${response.statusCode}');
    }
    return jsonDecode(response.body);
  }

  /// The release asset for [os] (`Platform.operatingSystem`), or an empty
  /// map. Android takes the `.apk`. Windows has no package installer to
  /// hand an `.apk` to: its asset is a plain `.zip` of the built Release
  /// folder, opened in a browser (see CheckUpdatesScreen). macOS takes only
  /// a `-macos.zip`, and Windows never does, so a Mac build attached to a
  /// release can't be offered to a PC (older Windows builds take the first
  /// `.zip`: never attach a Mac zip until they've updated).
  @visibleForTesting
  static Map<String, dynamic> pickAsset(
      List<Map<String, dynamic>> assets, String os) {
    bool matches(String name) => switch (os) {
          'android' => name.endsWith('.apk'),
          'macos' => name.endsWith('-macos.zip'),
          'windows' => name.endsWith('.zip') && !name.endsWith('-macos.zip'),
          _ => false,
        };
    return assets.firstWhere(
        (a) => matches((a['name'] as String?)?.toLowerCase() ?? ''),
        orElse: () => const {});
  }

  /// True when the release's tag names a different version from the
  /// installed one — deliberately "different", not "newer". The project was
  /// renamed to VesperTV and its versioning restarts at 1.0.0 (lower than
  /// the old 3.x numbers), so a strict "newer" test would never offer that
  /// release. `/releases/latest` only ever returns the one current release,
  /// so "different" still can't offer anything stale. A differently-shaped
  /// tag (e.g. "1.0" vs "1.0.0") counts as the same ([compareVersions]).
  static bool _isDifferent(String remote, String local) =>
      compareVersions(remote, local) != 0;

  /// Orders version names / tags like semver: numeric `x.y.z` (a missing
  /// or non-numeric part = 0), then a test build's suffix: `1.0.73-dev.951`
  /// is below `1.0.73` and above `1.0.73-dev.950` (dot parts compared as
  /// numbers when both are). An optional leading "v" is ignored: a release
  /// tagged "v3.31.0" by mistake once read as older than 3.29.0 and
  /// reported "up to date".
  @visibleForTesting
  static int compareVersions(String a, String b) {
    (List<int>, List<String>?) parse(String v) {
      v = v.trim();
      if (v.startsWith('v')) v = v.substring(1);
      final dash = v.indexOf('-');
      final core = dash < 0 ? v : v.substring(0, dash);
      return (
        core.split('.').map((s) => int.tryParse(s) ?? 0).toList(),
        dash < 0 ? null : v.substring(dash + 1).split('.'),
      );
    }

    final (ca, pa) = parse(a);
    final (cb, pb) = parse(b);
    for (var i = 0; i < ca.length || i < cb.length; i++) {
      final x = i < ca.length ? ca[i] : 0;
      final y = i < cb.length ? cb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    if (pa == null || pb == null) {
      return pa == pb ? 0 : (pa == null ? 1 : -1);
    }
    for (var i = 0; i < pa.length && i < pb.length; i++) {
      final x = int.tryParse(pa[i]);
      final y = int.tryParse(pb[i]);
      final c =
          x != null && y != null ? x.compareTo(y) : pa[i].compareTo(pb[i]);
      if (c != 0) return c;
    }
    return pa.length.compareTo(pb.length);
  }

  /// Downloads to the app's own cache directory (matching the
  /// FileProvider path config that grants the installer read access to
  /// exactly this one file, nothing broader) — overwrites any previous
  /// download of the same name rather than accumulating old ones.
  Future<File> downloadUpdate(String downloadUrl,
      {required int expectedSizeBytes,
      void Function(double fraction)? onProgress}) async {
    if (expectedSizeBytes <= 0) {
      throw UpdateDownloadException(tr(
          'Could not check the update size. Check for updates and try again.'));
    }
    final available = await getAvailableStorageBytes();
    // Download + installer staging/unpacking headroom on the same data volume.
    final shortfall = expectedSizeBytes * 3 - available;
    if (shortfall > 0) {
      const mb = 1024 * 1024;
      throw UpdateDownloadException(tr('Free about {mb} MB and try again.',
          {'mb': (shortfall + mb - 1) ~/ mb}));
    }

    final client = _downloadClient ?? http.Client();
    File? file;
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw UpdateDownloadException(tr('Download failed. Please try again.'));
      }
      var received = 0;
      final dir = await _cacheDirectory();
      file = File(p.join(dir.path, 'noxplayer_update.apk'));
      sink = file.openWrite();
      await sink.addStream(response.stream.map((chunk) {
        received += chunk.length;
        if (received > expectedSizeBytes) {
          throw UpdateDownloadException(
              tr('Download failed. Please try again.'));
        }
        onProgress?.call(received / expectedSizeBytes);
        return chunk;
      }));
      await sink.close();
      sink = null;
      if (await file.length() != expectedSizeBytes) {
        throw UpdateDownloadException(tr('Download failed. Please try again.'));
      }
      return file;
    } catch (_) {
      // Close first so Windows test hosts can also remove an incomplete file.
      try {
        await sink?.close();
      } catch (_) {}
      try {
        if (file != null && await file.exists()) await file.delete();
      } catch (_) {}
      throw UpdateDownloadException(tr('Download failed. Please try again.'));
    } finally {
      if (_downloadClient == null) client.close();
    }
  }

  /// Android's app-cache filesystem, queried through the existing updater
  /// channel. A missing/unavailable check cannot silently bypass the reserve.
  Future<int> getAvailableStorageBytes() async {
    try {
      final available =
          await _channel.invokeMethod<int>('getAvailableStorageBytes');
      if (available != null && available >= 0) return available;
    } catch (_) {
      // Present one plain message for a platform error or missing bridge.
    }
    throw UpdateDownloadException(
        tr('Could not check free storage. Restart VesperTV and try again.'));
  }

  /// Android 8+ only — earlier versions have no per-app "unknown sources"
  /// gate at all. Always true there, so callers don't need to branch on
  /// OS version themselves.
  Future<bool> canRequestInstalls() async {
    final result = await _channel.invokeMethod<bool>('canRequestInstalls');
    return result ?? false;
  }

  /// Opens the system settings screen where the user grants this app
  /// "install unknown apps" access — Android requires this be a real user
  /// action from Settings, no app (this one included) can grant it to
  /// itself. No-op on pre-Android-8, where it isn't needed.
  Future<void> requestInstallPermission() =>
      _channel.invokeMethod('requestInstallPermission');

  /// Hands the downloaded file to the system package installer — this is
  /// the point where the OS's own install-confirmation UI takes over;
  /// nothing past this call can be automated further from inside the app.
  Future<void> installApk(String filePath) =>
      _channel.invokeMethod('installApk', {'filePath': filePath});

  /// Windows' whole update flow — no `MainActivity.kt`-style native
  /// installer channel exists for it (nothing in this repo builds a
  /// signed Windows installer at all yet, just a plain Release folder),
  /// so there's nothing to silently download-and-install the way Android
  /// does. Opening the asset's direct URL in the system browser and
  /// letting the user unzip/run it themselves is the entire mechanism.
  Future<bool> openInBrowser(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
