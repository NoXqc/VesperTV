import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../services/app_update_service.dart';
import '../../services/storage_service.dart';
import '../../utils/tv_theme.dart';
import '../../widgets/mode_button.dart';
import '../../widgets/settings_scaffold.dart';
import '../../l10n/l10n.dart';

/// Settings > Check for Updates — the in-app replacement for a Play Store
/// auto-update, since this is a sideloaded app with no store distribution.
/// See AppUpdateService's doc comment for the full check/download/install
/// mechanism and its one hard limit: Android itself, not this app, decides
/// whether the actual install step needs a fresh user tap on its own
/// confirmation dialog — nothing past handing the APK to the installer can
/// be automated further.
///
/// Update channel (2026-11-21): Stable = the weekly release, Test builds =
/// GitHub pre-releases too ([UpdateChannel]); this device only.
class CheckUpdatesScreen extends StatefulWidget {
  const CheckUpdatesScreen({super.key, this.startWith, this.updateService});

  final AppUpdateService? updateService;

  /// From the launch update popup's "Update": skip the check and start
  /// the download (Android) / open the download page (Windows) at once.
  final UpdateInfo? startWith;

  @override
  State<CheckUpdatesScreen> createState() => _CheckUpdatesScreenState();
}

enum _Status {
  idle,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  readyToInstall,
  error
}

class _CheckUpdatesScreenState extends State<CheckUpdatesScreen> {
  late final _updateService = widget.updateService ?? AppUpdateService();
  String _currentVersion = '';
  _Status _status = _Status.idle;
  UpdateInfo? _update;
  double _downloadProgress = 0;
  String? _errorMessage;
  String? _downloadedApkPath;
  late UpdateChannel _channel;

  /// The version the last Install handed to Android that never arrived
  /// (GitHub #22), shown under the current version.
  String? _lastFailure;

  @override
  void initState() {
    super.initState();
    // Optional: a screen built without the app around it (tests) is Stable.
    _channel = UpdateChannel.parse(
        context.read<StorageService?>()?.getUpdateChannel());
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _currentVersion = info.version);
    });
    _updateService.lastInstallFailure().then((version) {
      if (mounted && version != null) setState(() => _lastFailure = version);
    });
    final start = widget.startWith;
    if (start != null) {
      _update = start;
      _status = _Status.updateAvailable;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateService.downloadInBrowser ? _openWindowsDownload() : _download();
      });
    }
  }

  Future<void> _check() async {
    setState(() {
      _status = _Status.checking;
      _errorMessage = null;
    });
    try {
      final update = await _updateService.checkForUpdate(channel: _channel);
      if (!mounted) return;
      setState(() {
        _update = update;
        _status = update == null ? _Status.upToDate : _Status.updateAvailable;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _errorMessage = e.toString();
      });
    }
  }

  /// Windows' entire update flow — see AppUpdateService.openInBrowser's
  /// doc comment for why there's no download/install state machine to
  /// drive here the way Android's [_download]/[_install] do: nothing past
  /// opening the browser can be automated on this platform at all yet.
  Future<void> _openWindowsDownload() async {
    final update = _update;
    if (update == null) return;
    final opened = await _updateService.openInBrowser(update.downloadUrl);
    if (!mounted || opened) return;
    setState(() {
      _status = _Status.error;
      _errorMessage = tr('Couldn\'t open the download link.');
    });
  }

  Future<void> _download() async {
    final update = _update;
    if (update == null || _status == _Status.downloading) return;
    setState(() {
      _status = _Status.downloading;
      _downloadProgress = 0;
      _downloadedApkPath = null;
    });
    try {
      final file = await _updateService.downloadUpdate(
        update.downloadUrl,
        expectedSizeBytes: update.apkSizeBytes,
        onProgress: (fraction) {
          if (mounted) setState(() => _downloadProgress = fraction);
        },
      );
      debugPrint('AppUpdate: downloaded ${update.version} '
          '(${update.apkSizeBytes ~/ (1024 * 1024)} MB)');
      if (!mounted) return;
      setState(() {
        _downloadedApkPath = file.path;
        _status = _Status.readyToInstall;
      });
    } catch (e) {
      debugPrint('AppUpdate: download of ${update.version} failed: $e');
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _errorMessage = e.toString();
      });
    }
  }

  /// The other channel picked: saved, then checked at once (a download in
  /// progress keeps going).
  Future<void> _setChannel(UpdateChannel channel) async {
    if (channel == _channel) return;
    setState(() => _channel = channel);
    await context.read<StorageService?>()?.setUpdateChannel(channel.name);
    if (!mounted) return;
    if (_status != _Status.downloading && _status != _Status.readyToInstall) {
      await _check();
    }
  }

  Future<void> _install() async {
    final path = _downloadedApkPath;
    if (path == null) return;
    final canInstall = await _updateService.canRequestInstalls();
    if (!canInstall) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('Allow installing updates')),
          content: Text(
            tr('Android needs one-time permission for VesperTV to install an update it downloaded. The next screen is Android\'s own settings — turn the toggle on, then come back here and press Install again.'),
          ),
          // Plain TextButton/FilledButton left which one has D-pad focus
          // ambiguous — FilledButton's permanent solid fill looks the
          // same whether it's actually focused or not. ModeButton is this
          // app's established fix elsewhere for exactly this.
          actions: [
            ModeButton(
              label: tr('Cancel'),
              selected: false,
              onTap: () => Navigator.of(context).pop(false),
            ),
            ModeButton(
              label: tr('Open Settings'),
              selected: false,
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );
      if (proceed == true) await _updateService.requestInstallPermission();
      return;
    }
    debugPrint("AppUpdate: handing ${_update?.version} to Android's installer");
    await _updateService.installApk(path);
  }

  @override
  Widget build(BuildContext context) {
    return withTvThemeIfNeeded(
        context,
        (context) => SettingsScaffold(
              title: tr('Check for Updates'),
              body: ListView(
                // Sized to its rows: a floating panel hugs them.
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    _currentVersion.isEmpty
                        ? tr('Current version: —')
                        : tr('Current version: {currentVersion}',
                            {'currentVersion': _currentVersion}),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (_lastFailure != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      tr("The update to {version} didn't install: this device still has the version above. Try again; if it fails again, free some storage or install it with the Downloader app.",
                          {'version': _lastFailure!}),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ..._buildStatusContent(context),
                  const SizedBox(height: 28),
                  ..._buildChannel(context),
                ],
              ),
            ));
  }

  List<Widget> _buildStatusContent(BuildContext context) {
    switch (_status) {
      case _Status.idle:
        return [
          ModeButton(
            autofocus: true,
            icon: Icons.system_update,
            label: tr('Check for Updates'),
            selected: false,
            onTap: _check,
          ),
        ];
      case _Status.checking:
        return [
          Row(
            children: [
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Text(tr('Checking...')),
            ],
          ),
        ];
      case _Status.upToDate:
        return [
          Text(tr('You\'re on the latest version.')),
          const SizedBox(height: 12),
          ModeButton(
              autofocus: true,
              label: tr('Check Again'),
              selected: false,
              onTap: _check),
        ];
      case _Status.updateAvailable:
        final update = _update!;
        return [
          Text(
            update.testBuild
                ? tr('Test build {version} is available',
                    {'version': update.version})
                : tr('Version {version} is available',
                    {'version': update.version}),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          if (_updateService.downloadInBrowser) ...[
            ModeButton(
              autofocus: true,
              icon: Icons.open_in_browser,
              label: tr('Open Download Page'),
              selected: false,
              onTap: _openWindowsDownload,
            ),
            const SizedBox(height: 4),
            Text(
              // macOS gets the release's .dmg (since 1.0.73), Windows a zip.
              defaultTargetPlatform == TargetPlatform.macOS
                  ? tr(
                      'Opens in your browser — open the downloaded file and drag VesperTV into Applications, replacing the old one.')
                  : tr(
                      'Opens in your browser — unzip the download and run VesperTV.exe to update, replacing the old folder.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else
            // ModeButton, not FilledButton: the solid pastel fill looked the
            // same focused or not, so the remote's cursor was invisible.
            ModeButton(
              autofocus: true,
              icon: Icons.download,
              label: tr('Download & Install'),
              selected: false,
              onTap: _download,
            ),
          // After the button, capped: long release notes used to push the button
          // below the fold of a lazy list, out of the remote's reach (1.0.40).
          if (update.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(plainReleaseNotes(update.releaseNotes),
                maxLines: 12,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ];
      case _Status.downloading:
        return [
          Text(tr('Downloading update... {p}%',
              {'p': (_downloadProgress * 100).toStringAsFixed(0)})),
          const SizedBox(height: 12),
          LinearProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null),
        ];
      case _Status.readyToInstall:
        return [
          Text(tr('Download complete.')),
          const SizedBox(height: 16),
          ModeButton(
            autofocus: true,
            icon: Icons.install_mobile,
            label: tr('Install'),
            selected: false,
            onTap: _install,
          ),
          const SizedBox(height: 4),
          Text(
            tr('Android will ask you to confirm the install — that\'s normal, not every app can skip it.'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ];
      case _Status.error:
        return [
          Text(
              tr('Something went wrong: {p}',
                  {'p': _errorMessage ?? tr('unknown error')}),
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 12),
          ModeButton(
              autofocus: true,
              label: tr('Try Again'),
              selected: false,
              onTap: _check),
        ];
    }
  }

  /// Stable / Test builds, under the check (the check button keeps the
  /// first focus).
  List<Widget> _buildChannel(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return [
      Text(tr('Update channel'), style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ModeButton(
            icon: Icons.verified_outlined,
            label: tr('Stable'),
            selected: _channel == UpdateChannel.stable,
            onTap: () => _setChannel(UpdateChannel.stable),
          ),
          ModeButton(
            icon: Icons.science_outlined,
            label: tr('Test builds'),
            selected: _channel == UpdateChannel.test,
            onTap: () => _setChannel(UpdateChannel.test),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        _channel == UpdateChannel.stable
            ? tr('One tested update a week.')
            : tr(
                'Fixes as soon as they are made, before the weekly update. A test build can have new bugs: send a log if something breaks.'),
        style: small,
      ),
    ];
  }
}

/// The GitHub release body is Markdown; the dialog shows plain text, so
/// `## heading`, `**bold**` and backticks used to show up as-is.
String plainReleaseNotes(String notes) {
  final lines = <String>[];
  for (var line in notes.replaceAll('\r', '').split('\n')) {
    line = line
        .replaceFirst(RegExp(r'^\s*#{1,6}\s*'), '')
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll('`', '')
        .replaceFirstMapped(RegExp(r'^(\s*)[-*]\s+'), (m) => '${m[1]}• ')
        .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m[1]!);
    if (line.trim().isEmpty && (lines.isEmpty || lines.last.isEmpty)) continue;
    lines.add(line.trim().isEmpty ? '' : line);
  }
  return lines.join('\n').trim();
}
