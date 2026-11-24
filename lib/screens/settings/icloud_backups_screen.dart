import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/backup_service.dart';
import '../../services/icloud_backups.dart';
import '../../services/storage_service.dart';
import '../../utils/time_format.dart';
import '../../utils/tv_theme.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_dialog_option.dart';
import '../../widgets/tv_menu_tile.dart';
import 'backup_screen.dart' show restoreBackup;

/// Restore from iCloud ([ICloudBackups]): each Apple device's newest backup
/// in the viewer's iCloud. From Settings > Backup & restore and from the
/// first launch's From another device (an Apple TV restoring the iPhone's
/// setup, BallerMC 2026-11-22).
class ICloudBackupsScreen extends StatefulWidget {
  const ICloudBackupsScreen({super.key, this.icloud});

  /// Tests.
  final ICloudBackups? icloud;

  @override
  State<ICloudBackupsScreen> createState() => _ICloudBackupsScreenState();
}

class _ICloudBackupsScreenState extends State<ICloudBackupsScreen> {
  late final ICloudBackups _icloud = widget.icloud ?? ICloudBackups();
  List<ICloudBackupEntry>? _entries;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _entries = null;
      _message = null;
    });
    String? message;
    var entries = const <ICloudBackupEntry>[];
    final status = await _icloud.status();
    if (status != 'available') {
      message = ICloudBackups.statusMessage(status);
    } else {
      try {
        entries = await _icloud.list();
      } catch (e) {
        message = ICloudBackups.errorMessage(e);
      }
    }
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _message = message;
    });
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 4)));
  }

  String _title(ICloudBackupEntry e) {
    final device = e.device.isEmpty ? 'iCloud' : e.device;
    if (!e.mine) return device;
    return e.device.isEmpty
        ? tr('This device')
        : '$device · ${tr('This device')}';
  }

  String _subtitle(ICloudBackupEntry e) {
    final kb = (e.size / 1024).ceil();
    return [
      TimeFormat.dateTime(e.modified),
      if (e.size > 0) '$kb KB',
      if (e.app.isNotEmpty) 'VesperTV ${e.app}',
    ].join(' · ');
  }

  Future<void> _open(ICloudBackupEntry entry) async {
    if (_busy) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(_title(entry)),
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
        setState(() => _busy = true);
        final Map<String, Object?> values;
        try {
          values = await BackupService(context.read<StorageService>(),
                  icloud: _icloud)
              .loadFromICloud(entry);
        } on FormatException {
          _toast(tr('This file is not a VesperTV backup.'));
          return;
        } catch (e) {
          _toast(tr('Couldn\'t read this backup: {error}',
              {'error': ICloudBackups.errorMessage(e)}));
          return;
        } finally {
          if (mounted) setState(() => _busy = false);
        }
        if (!mounted) return;
        await restoreBackup(context, values,
            from: entry.device.isEmpty ? 'iCloud' : entry.device,
            onStart: () => setState(() => _busy = true));
      case 'delete':
        try {
          await _icloud.delete(entry.id);
        } catch (e) {
          _toast(ICloudBackups.errorMessage(e));
        }
        await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final retry = TvMenuTile(
      autofocus: true,
      icon: Icons.refresh,
      title: tr('Try again'),
      onTap: _load,
    );
    return withTvThemeIfNeeded(
      context,
      (context) => SettingsScaffold(
        title: tr('Restore from iCloud'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Text(
                tr('Backups your iPhone, iPad or Apple TV saved to iCloud with this Apple ID. Each device keeps its newest one there.'),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            if (entries == null || _busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (entries != null && _message != null) ...[
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_message!),
              ),
              retry,
            ] else if (entries != null && entries.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(tr(
                    'No backups in iCloud yet. On the other device: Settings > Backup & devices > Backup & restore > Also save to iCloud.')),
              ),
              retry,
            ] else if (entries != null)
              for (var i = 0; i < entries.length; i++)
                TvMenuTile(
                  autofocus: i == 0,
                  icon: entries[i].device.toLowerCase().contains('tv')
                      ? Icons.tv
                      : Icons.phone_iphone,
                  title: _title(entries[i]),
                  subtitle: _subtitle(entries[i]),
                  enabled: !_busy,
                  onTap: () => _open(entries[i]),
                ),
          ],
        ),
      ),
    );
  }
}
