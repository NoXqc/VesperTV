import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/backup_folder.dart';
import '../../services/backup_service.dart';
import '../../services/icloud_backups.dart';
import '../../services/storage_service.dart';
import '../../utils/desktop_platform.dart';
import '../../utils/time_format.dart';
import '../../utils/tv_theme.dart';
import '../../widgets/section_label.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_dialog_option.dart';
import '../../widgets/tv_menu_tile.dart';
import '../../widgets/tv_switch_list_tile.dart';
import '../../l10n/l10n.dart';
import 'icloud_backups_screen.dart';
import 'replace_setup.dart';
import 'storage_import_screen.dart';

/// Settings > Backup & restore — see [BackupService]. Restoring first saves
/// the current setup as an automatic backup, so a wrong pick can be undone.
///
/// No custom D-pad handling — see SettingsMenuScreen's doc comment.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late final StorageService _storage = context.read<StorageService>();
  late final BackupService _backups = BackupService(_storage);
  late bool _auto = _storage.getAutoBackup();
  late int _autoDays = _storage.getAutoBackupDays();
  late bool _cloud = _storage.getBackupToICloud();
  List<BackupEntry>? _entries;
  bool _busy = false;

  /// iPhone / iPad: the Files folder backups go to, null = On My iPhone.
  String? _folder;
  String _location = BackupService.locationLabel;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      // Android 10 only: reading backups a previous install left behind.
      await _backups.ensurePermission(write: false);
      final location = await _backups.location();
      String? folder;
      try {
        folder = await _backups.folderName();
      } on PlatformException {
        folder = location;
      }
      if (mounted) {
        setState(() {
          _location = location;
          _folder = folder;
        });
      }
      final entries = await _backups.list();
      if (mounted) setState(() => _entries = entries);
    } catch (e) {
      if (mounted) setState(() => _entries = const []);
      _toast(tr('Couldn\'t read the backup folder: {error}', {'error': '$e'}));
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 4)));
  }

  Future<void> _backUpNow() async {
    if (_busy) return;
    if (!await _backups.ensurePermission(write: true)) {
      _toast(tr('VesperTV needs storage access to save backups.'));
      return;
    }
    setState(() => _busy = true);
    try {
      final entry = await _backups.create();
      final cloudError = _backups.lastICloudError;
      _toast(cloudError != null
          ? tr('Backup saved to {path}, but not to iCloud: {error}', {
              'path': _location,
              'error': ICloudBackups.errorMessage(cloudError),
            })
          : tr('Backup saved to {path}', {
              'path': '$_location/${entry.name}',
            }));
    } catch (e) {
      _toast(tr('Backup failed: {error}', {'error': '$e'}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _refresh();
  }

  Future<void> _exportToFile() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (await _backups.exportToFile()) _toast(tr('Backup exported.'));
    } catch (e) {
      _toast(tr('Backup failed: {error}', {'error': '$e'}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setAuto(bool value) async {
    if (value && !await _backups.ensurePermission(write: true)) {
      _toast(tr('VesperTV needs storage access to save backups.'));
      return;
    }
    await _storage.setAutoBackup(value);
    if (mounted) setState(() => _auto = value);
  }

  /// Also save to iCloud: on = this device's newest backup is also kept in
  /// iCloud ([ICloudBackups]); turning it on makes one right away. Off
  /// leaves the copy already there.
  Future<void> _setCloud(bool value) async {
    if (_busy) return;
    if (value) {
      final status = await ICloudBackups().status();
      if (status != 'available') {
        _toast(ICloudBackups.statusMessage(status));
        return;
      }
    }
    await _storage.setBackupToICloud(value);
    if (!mounted) return;
    setState(() => _cloud = value);
    if (value) await _backUpNow();
  }

  /// iPhone / iPad: pick a Files folder (iCloud Drive, OneDrive, an SMB
  /// share…) or go back to On My iPhone.
  Future<void> _pickFolder() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr('Backup folder')),
        children: [
          TvDialogOption(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop('choose'),
            child: Text(tr('Choose a folder')),
          ),
          if (_folder != null)
            TvDialogOption(
              onPressed: () => Navigator.of(context).pop('device'),
              child: Text(tr('On this device')),
            ),
          TvDialogOption(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('Cancel')),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    final folder = BackupFolder();
    try {
      if (choice == 'choose') {
        final name = await folder.choose();
        if (name == null) return;
        _toast(tr('Backups now go to {name}.', {'name': name}));
      } else {
        await folder.clear();
      }
    } on PlatformException catch (e) {
      _toast(e.message ?? e.code);
    }
    await _refresh();
  }

  static String _daysLabel(int days) => switch (days) {
        1 => tr('Every day'),
        3 => tr('Every 3 days'),
        14 => tr('Every 2 weeks'),
        30 => tr('Every month'),
        _ => tr('Every week'),
      };

  Future<void> _pickAutoDays() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr('How often')),
        children: [
          for (final d in BackupService.intervalChoices)
            TvDialogOption(
              autofocus: d == _autoDays,
              onPressed: () => Navigator.of(context).pop(d),
              child: Text(_daysLabel(d)),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await _storage.setAutoBackupDays(picked);
    if (mounted) setState(() => _autoDays = picked);
  }

  String _label(BackupEntry e) => TimeFormat.dateTime(e.modified);

  String _subtitle(BackupEntry e) {
    final kind = e.isAuto ? tr('Automatic') : tr('Manual');
    final kb = (e.size / 1024).ceil();
    return '$kind · $kb KB';
  }

  Future<void> _showEntry(BackupEntry entry) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(_label(entry)),
        children: [
          TvDialogOption(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop('restore'),
            child: Text(tr('Restore this backup')),
          ),
          TvDialogOption(
            onPressed: () => Navigator.of(context).pop('delete'),
            child: Text(tr('Delete')),
          ),
          TvDialogOption(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('Cancel')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'restore':
        final Map<String, Object?> values;
        try {
          values = await _backups.load(entry);
        } catch (e) {
          _toast(tr('Couldn\'t read this backup: {error}', {'error': '$e'}));
          return;
        }
        await _restore(values, _label(entry));
      case 'delete':
        if (!await _backups.delete(entry)) {
          _toast(tr('Couldn\'t delete this backup.'));
        }
        await _refresh();
    }
  }

  Future<void> _restoreFromFile() async {
    final Map<String, Object?>? values;
    try {
      values = await _backups.pickAndLoad();
    } on PlatformException catch (e) {
      _toast(e.code == 'NO_PICKER'
          ? tr(
              'This device has no file picker. Copy the backup onto a USB drive and open it in Import from storage.')
          : e.message ?? e.code);
      return;
    } on FormatException {
      _toast(tr('This file is not a VesperTV backup.'));
      return;
    }
    if (values == null || !mounted) return;
    await _restore(values, tr('the chosen file'));
  }

  Future<void> _restore(Map<String, Object?> values, String from) =>
      restoreBackup(context, values,
          from: from, onStart: () => setState(() => _busy = true));

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return withTvThemeIfNeeded(
      context,
      (context) => SettingsScaffold(
        title: tr('Backup & restore'),
        body: ListView(
          children: [
            TvMenuTile(
              icon: Icons.save_alt,
              title: tr('Back up now'),
              subtitle: tr(
                  'Playlists, favourites, profiles, progress and settings, saved to {path}',
                  {'path': _location}),
              autofocus: true,
              enabled: !_busy,
              trailing: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : null,
              onTap: _backUpNow,
            ),
            TvSwitchListTile(
              title: Text(tr('Automatic backup')),
              subtitle: Text(tr('When VesperTV starts. Keeps the last {n}.',
                  {'n': '${BackupService.keepAuto}'})),
              value: _auto,
              onChanged: _setAuto,
            ),
            if (_auto)
              TvMenuTile(
                icon: Icons.schedule,
                title: tr('How often'),
                subtitle: _daysLabel(_autoDays),
                onTap: _pickAutoDays,
              ),
            if (BackupFolder.supported)
              TvMenuTile(
                icon: Icons.folder_outlined,
                title: tr('Backup folder'),
                subtitle: _folder ??
                    tr('On this device. Choose iCloud Drive, OneDrive or a network share in Files instead.'),
                enabled: !_busy,
                onTap: _pickFolder,
              ),
            if (ICloudBackups.supported) ...[
              TvSwitchListTile(
                title: Text(tr('Also save to iCloud')),
                subtitle: Text(tr(
                    'Each backup also goes to your iCloud, so your other Apple devices (Apple TV too) can restore it. iCloud keeps the newest one from this device.')),
                value: _cloud,
                onChanged: _setCloud,
              ),
              TvMenuTile(
                icon: Icons.cloud_download_outlined,
                title: tr('Restore from iCloud'),
                subtitle: tr(
                    'From a backup your iPhone, iPad or Apple TV saved to iCloud'),
                enabled: !_busy,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ICloudBackupsScreen())),
              ),
            ],
            if (Platform.isMacOS)
              TvMenuTile(
                icon: Icons.ios_share,
                title: tr('Export a backup'),
                subtitle: tr('Save a backup file anywhere on this Mac'),
                enabled: !_busy,
                onTap: _exportToFile,
              ),
            // Not on Apple TV: no Files app to pick from (Restore from
            // iCloud above instead).
            if (Platform.isAndroid ||
                Platform.isMacOS ||
                (Platform.isIOS && !isAppleTv))
              TvMenuTile(
                icon: Icons.folder_open,
                title: tr('Restore from a file'),
                subtitle:
                    tr('Pick a backup file, e.g. after reinstalling VesperTV'),
                enabled: !_busy,
                onTap: _restoreFromFile,
              ),
            // iOS has no USB drives to browse: Restore from a file covers
            // a backup in Files.
            if (!Platform.isIOS)
              TvMenuTile(
                icon: Icons.usb,
                title: tr('Import from storage'),
                subtitle: tr(
                    'Add M3U playlists, Media Hub sources or a backup from USB or external storage'),
                enabled: !_busy,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const StorageImportScreen())),
              ),
            const Divider(height: 32),
            SectionLabel(tr('Backups')),
            const SizedBox(height: 4),
            if (entries == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(tr('No backups yet.')),
              )
            else
              for (final entry in entries)
                TvMenuTile(
                  icon: entry.isAuto ? Icons.schedule : Icons.backup_outlined,
                  title: _label(entry),
                  subtitle: _subtitle(entry),
                  enabled: !_busy,
                  onTap: () => _showEntry(entry),
                ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Text(
                tr('Backups include your playlist logins. Keep the files private.'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Replaces this device's setup with the backup [values] and closes the
/// app. Settings > Backup & restore and Import from storage (a backup file
/// on USB, for boxes with no file picker) both end here. Cancel is focused
/// by default so a stray Select can't replace anything; the current setup
/// is saved as an automatic backup first.
Future<void> restoreBackup(BuildContext context, Map<String, Object?> values,
    {required String from, VoidCallback? onStart}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(tr('Restore backup?')),
      content: Text(tr(
          'Everything on this device (playlists, favourites, profiles, settings) is replaced by the backup from {from}. Your current setup is saved as an automatic backup first. VesperTV closes afterwards.',
          {'from': from})),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(tr('Restore')),
        ),
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(tr('Cancel')),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  onStart?.call();
  final backups = BackupService(context.read<StorageService>());
  // Undo point; best effort (no storage access on Android 9- = no undo).
  try {
    if (await backups.ensurePermission(write: true)) {
      // Not to iCloud: it would replace this device's good copy there
      // with the setup being thrown away.
      await backups.create(auto: true, cloud: false);
    }
  } catch (e) {
    debugPrint('Pre-restore backup failed: $e');
  }
  if (!context.mounted) return;
  await replaceSetupAndExit(context,
      title: tr('Backup restored'),
      importer: (storage) => storage.importForBackup(values));
}
