import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/backup_service.dart';
import '../../services/storage_service.dart';
import '../../utils/time_format.dart';
import '../../utils/tv_theme.dart';
import '../../widgets/section_label.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_dialog_option.dart';
import '../../widgets/tv_menu_tile.dart';
import '../../widgets/tv_switch_list_tile.dart';
import '../../l10n/l10n.dart';
import 'replace_setup.dart';

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
  List<BackupEntry>? _entries;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      // Android 10 only: reading backups a previous install left behind.
      await _backups.ensurePermission(write: false);
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
      _toast(tr('Backup saved to {path}', {
        'path': '${BackupService.locationLabel}/${entry.name}',
      }));
    } catch (e) {
      _toast(tr('Backup failed: {error}', {'error': '$e'}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _refresh();
  }

  Future<void> _setAuto(bool value) async {
    if (value && !await _backups.ensurePermission(write: true)) {
      _toast(tr('VesperTV needs storage access to save backups.'));
      return;
    }
    await _storage.setAutoBackup(value);
    if (mounted) setState(() => _auto = value);
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
              'This device has no file picker. Copy the backup into {path} on this device instead.',
              {'path': BackupService.locationLabel})
          : e.message ?? e.code);
      return;
    } on FormatException {
      _toast(tr('This file is not a VesperTV backup.'));
      return;
    }
    if (values == null || !mounted) return;
    await _restore(values, tr('the chosen file'));
  }

  /// Cancel is focused by default so a stray Select can't replace anything.
  Future<void> _restore(Map<String, Object?> values, String from) async {
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
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    // Undo point; best effort (no storage access on Android 9- = no undo).
    try {
      if (await _backups.ensurePermission(write: true)) {
        await _backups.create(auto: true);
      }
    } catch (e) {
      debugPrint('Pre-restore backup failed: $e');
    }
    if (!mounted) return;
    await replaceSetupAndExit(context,
        title: tr('Backup restored'),
        importer: (storage) => storage.importForBackup(values));
  }

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
                  {'path': BackupService.locationLabel}),
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
              subtitle: Text(tr(
                  'Once a week, when VesperTV starts. Keeps the last {n}.',
                  {'n': '${BackupService.keepAuto}'})),
              value: _auto,
              onChanged: _setAuto,
            ),
            if (Platform.isAndroid)
              TvMenuTile(
                icon: Icons.folder_open,
                title: tr('Restore from a file'),
                subtitle:
                    tr('Pick a backup file, e.g. after reinstalling VesperTV'),
                enabled: !_busy,
                onTap: _restoreFromFile,
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
