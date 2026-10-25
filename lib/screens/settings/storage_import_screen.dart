import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/playlist_profile.dart';
import '../../services/backup_service.dart';
import '../../services/playlist_manager.dart';
import '../../services/archive_service.dart';
import '../../models/archive_models.dart';
import '../../services/storage_import_service.dart';
import '../../services/storage_service.dart';
import '../../utils/tv_theme.dart';
import '../../widgets/mode_button.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_menu_tile.dart';

/// Additive import, separate from replacing the setup with a backup.
class StorageImportScreen extends StatefulWidget {
  const StorageImportScreen({super.key, this.importer});
  final StorageImportService? importer;
  @override
  State<StorageImportScreen> createState() => _StorageImportScreenState();
}

class _StorageImportScreenState extends State<StorageImportScreen> {
  late final _importer = widget.importer ?? StorageImportService();
  final _path = <StorageItem>[];
  final _first = FocusNode(debugLabel: 'storage-first');
  List<StorageItem> _items = [];
  bool _loading = true, _busy = false;
  int _readGeneration = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void dispose() {
    _first.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _read() async {
    final generation = ++_readGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_path.isEmpty && Platform.isAndroid) {
        await BackupService(context.read<StorageService>())
            .ensurePermission(write: false);
      }
      final items = _path.isEmpty
          ? await _importer.roots()
          : await _importer.children(_path.last);
      if (!mounted || generation != _readGeneration) return;
      setState(() => _items = items);
    } catch (_) {
      if (mounted && generation == _readGeneration) {
        setState(() {
          _items = [];
          _error = tr(
              'Could not read this storage location. Use Choose a folder to grant access.');
        });
      }
    } finally {
      if (mounted && generation == _readGeneration) {
        setState(() => _loading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ModalRoute.of(context)?.isCurrent == true) {
            _first.requestFocus();
          }
        });
      }
    }
  }

  Future<void> _chooseFolder() async {
    try {
      final folder = await _importer.pickFolder();
      if (folder == null || !mounted) return;
      _path
        ..clear()
        ..add(folder);
      await _read();
    } on PlatformException catch (e) {
      _toast(e.code == 'NO_PICKER'
          ? tr(
              'No folder picker on this device. Browse the storage devices below instead.')
          : tr(
              'Could not read this storage location. Use Choose a folder to grant access.'));
    }
  }

  void _up() {
    if (_busy) return;
    _path.removeLast();
    _read();
  }

  Future<void> _import(StorageItem item) async {
    if (_busy || _path.isEmpty) return;
    final name = p.basenameWithoutExtension(item.name);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _StorageImportConfirmation(name: name));
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final manager = context.read<PlaylistManager>();
    final archive = context.read<ArchiveService>();
    PreparedStorageImport? prepared;
    String? addedId;
    var importedItems = 0,
        addedSources = 0,
        existingSources = 0,
        failedSources = 0;
    try {
      final List<String> links;
      if (item.playlist) {
        prepared = await _importer.preparePlaylist(item, _path.last);
        links = prepared.sourceLinks;
        final id = 'local_${DateTime.now().microsecondsSinceEpoch}';
        final order = manager.profiles
                .fold<int>(-1, (n, p) => p.sortOrder > n ? p.sortOrder : n) +
            1;
        await manager.addPlaylist(PlaylistProfile(
            id: id,
            name: name,
            mode: 'm3u',
            m3uUrl: prepared.file.uri.toString(),
            sortOrder: order,
            createdAt: DateTime.now()));
        addedId = id;
        await manager.loadPlaylist(id);
        if (manager.error != null) throw const FormatException('import failed');
        importedItems = prepared.count;
      } else {
        links = await _importer.readSourceLinks(item);
        if (links.isEmpty) throw const FormatException('no source links');
      }
      final checked = <ArchiveSource>[];
      for (final link in links) {
        if (archive.hasSource(link)) {
          existingSources++;
          continue;
        }
        try {
          checked.add(await archive.checkSource(link));
        } catch (_) {
          failedSources++;
        }
      }
      if (checked.isNotEmpty) {
        addedSources = (await archive.addCheckedSources(checked)).length;
      }
      _toast(tr(
          'Imported {items} playlist items and {sources} Media Hub sources. {existing} sources already existed; {failed} could not be reached.',
          {
            'items': importedItems,
            'sources': addedSources,
            'existing': existingSources,
            'failed': failedSources
          }));
    } catch (_) {
      // Undo only this new playlist if its load failed. Preserve an already
      // imported playlist when an unrelated source save fails later.
      if (addedId != null && importedItems == 0) {
        await manager.removePlaylist(addedId);
      }
      if (prepared != null &&
          importedItems == 0 &&
          await prepared.file.exists()) {
        await prepared.file.delete();
      }
      _toast(tr(
          'Could not import this file. Choose an M3U channel playlist or a TXT/JSON file containing Media Hub manifest links.'));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _first.requestFocus();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => withTvThemeIfNeeded(
      context,
      (context) => PopScope(
            canPop: _path.isEmpty && !_busy,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && !_busy && _path.isNotEmpty) _up();
            },
            child: SettingsScaffold(
                title: tr('Import from storage'),
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(tr(
                            'Import M3U playlists and Media Hub source links from USB, SD card or external storage. Choose M3U/M3U8 playlists or TXT/JSON source files.'))),
                    if (Platform.isAndroid)
                      TvMenuTile(
                          icon: Icons.folder_open,
                          title: tr('Choose a folder'),
                          enabled: !_busy && !_loading,
                          onTap: _chooseFolder),
                    if (_path.isNotEmpty)
                      TvMenuTile(
                          icon: Icons.arrow_upward,
                          title: tr('Back'),
                          subtitle: _path.last.name,
                          enabled: !_busy && !_loading,
                          onTap: _up),
                    if (_busy || _loading) const LinearProgressIndicator(),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_error!)),
                    if (!_loading && _items.isEmpty && _error == null)
                      Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(tr(
                              'No playlists or source files in this folder.'))),
                    Expanded(
                        child: ListView.builder(
                            key: ValueKey(_path.lastOrNull?.uri),
                            itemCount: _items.length,
                            itemBuilder: (_, i) {
                              final item = _items[i];
                              return TvMenuTile(
                                  focusNode: i == 0 ? _first : null,
                                  icon: item.folder
                                      ? Icons.folder_outlined
                                      : item.playlist
                                          ? Icons.playlist_play
                                          : Icons.extension_outlined,
                                  title: item.name,
                                  titleMaxLines: 2,
                                  enabled: !_busy && !_loading,
                                  onTap: () {
                                    if (item.folder) {
                                      _path.add(item);
                                      _read();
                                    } else {
                                      _import(item);
                                    }
                                  });
                            })),
                  ],
                )),
          ));
}

/// A concrete default target keeps a remote from opening an unfocused dialog.
class _StorageImportConfirmation extends StatefulWidget {
  const _StorageImportConfirmation({required this.name});
  final String name;
  @override
  State<_StorageImportConfirmation> createState() =>
      _StorageImportConfirmationState();
}

class _StorageImportConfirmationState
    extends State<_StorageImportConfirmation> {
  final _cancel = FocusNode(debugLabel: 'storage-import-cancel')
    ..requestFocus();
  @override
  void dispose() {
    _cancel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(tr('Import from storage?')),
          content: Text(tr(
              'Import "{name}"? M3U playlists and included Media Hub sources are added without replacing your current setup.',
              {'name': widget.name})),
          actions: [
            ModeButton(
                focusNode: _cancel,
                label: tr('Cancel'),
                selected: false,
                onTap: () => Navigator.pop(context, false)),
            ModeButton(
                label: tr('Import'),
                selected: false,
                onTap: () => Navigator.pop(context, true)),
          ]);
}
