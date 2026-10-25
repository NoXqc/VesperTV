import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'm3u_parser.dart';
import 'addon_import.dart';
import 'local_playlist_files.dart';

class StorageItem {
  const StorageItem(
      {required this.uri, required this.name, this.folder = false});
  final Uri uri;
  final String name;
  final bool folder;
  factory StorageItem.fromMap(Map map) => StorageItem(
      uri: Uri.parse(map['uri'] as String),
      name: map['name'] as String,
      folder: map['folder'] == true);
  bool get playlist =>
      const ['.m3u', '.m3u8'].contains(p.extension(name).toLowerCase());
  bool get sourceFile =>
      const ['.json', '.txt'].contains(p.extension(name).toLowerCase());
}

class PreparedStorageImport {
  const PreparedStorageImport(this.file, this.count,
      {this.sourceLinks = const []});
  final File file;
  final int count;
  final List<String> sourceLinks;
}

/// Copies selected M3U playlists; extracts add-on links without replacing setup.
class StorageImportService {
  StorageImportService({Directory? destination}) : _destination = destination;
  static const _channel = MethodChannel('com.nox.nox_iptv/storage_import');
  final Directory? _destination;

  Future<List<StorageItem>> roots() async {
    if (Platform.isAndroid) {
      final rows = await _channel.invokeListMethod<Map>('roots') ?? [];
      return rows.map(StorageItem.fromMap).toList();
    }
    if (Platform.isWindows) {
      return [
        for (var letter = 65; letter <= 90; letter++)
          if (await Directory('${String.fromCharCode(letter)}:\\').exists())
            StorageItem(
                uri: Directory('${String.fromCharCode(letter)}:\\').uri,
                name: '${String.fromCharCode(letter)}:',
                folder: true)
      ];
    }
    return [StorageItem(uri: Directory('/').uri, name: '/', folder: true)];
  }

  Future<StorageItem?> pickFolder() async {
    final value = await _channel.invokeMapMethod<String, dynamic>('pickFolder');
    return value == null ? null : StorageItem.fromMap(value);
  }

  Future<List<StorageItem>> children(StorageItem folder,
      {bool all = false}) async {
    final List<StorageItem> items;
    if (folder.uri.scheme == 'content') {
      final rows = await _channel.invokeListMethod<Map>(
              'children', {'uri': folder.uri.toString()}) ??
          [];
      items = rows.map(StorageItem.fromMap).toList();
    } else {
      items = [];
      await for (final entity
          in Directory.fromUri(folder.uri).list(followLinks: false)) {
        if (entity is File || entity is Directory) {
          items.add(StorageItem(
              uri: entity.uri,
              name: p.basename(entity.path),
              folder: entity is Directory));
        }
      }
    }
    return items
        .where((e) => all || e.folder || e.sourceFile || e.playlist)
        .toList()
      ..sort((a, b) => a.folder != b.folder
          ? (a.folder ? -1 : 1)
          : a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<Directory> _directory() async {
    final root = _destination ?? await getApplicationSupportDirectory();
    return Directory(p.join(root.path, 'imported_playlists'))
        .create(recursive: true);
  }

  Future<void> deleteOwnedPlaylist(String? url) =>
      LocalPlaylistFiles(destination: _destination).delete(url);

  /// Rewrites local relative paths to durable file/document URIs. A folder
  /// grant covers its children after relaunch; unsupported paths fail the import.
  Future<Uri> _resolve(StorageItem folder, String value,
      Map<Uri, List<StorageItem>> cache) async {
    if (RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value)) {
      return Uri.file(value, windows: true);
    }
    final uri = Uri.parse(value);
    if (uri.hasScheme) return uri;
    if (folder.uri.scheme != 'content') return folder.uri.resolveUri(uri);
    var current = folder;
    for (final part in uri.pathSegments) {
      if (part == '.' || part.isEmpty) continue;
      if (part == '..') {
        throw const FormatException('relative parent outside folder');
      }
      final entries = cache[current.uri] ??= await children(current, all: true);
      final matches = entries.where((e) => e.name == part);
      if (matches.isEmpty) throw const FormatException('local file missing');
      current = matches.first;
    }
    return current.uri;
  }

  Future<PreparedStorageImport> preparePlaylist(
      StorageItem item, StorageItem folder) async {
    final dir = await _directory();
    final tag = DateTime.now().microsecondsSinceEpoch;
    final scratch = File(p.join(dir.path, '$tag.input'));
    final output = File(p.join(dir.path, '$tag.m3u'));
    IOSink? sink;
    final sourceLinks = <String>{};
    final directoryCache = <Uri, List<StorageItem>>{};
    try {
      if (item.uri.scheme == 'content') {
        await _channel.invokeMethod('copyImportFile',
            {'uri': item.uri.toString(), 'target': scratch.path});
      } else {
        await File.fromUri(item.uri).copy(scratch.path);
      }
      sink = output.openWrite();
      await for (final raw in scratch
          .openRead()
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())) {
        final line = raw.trim();
        sourceLinks.addAll(sourceLinksIn(line));
        if (line.startsWith('#EXT-X-')) {
          throw const FormatException('HLS stream, not a channel playlist');
        }
        if (line.isEmpty || line.startsWith('#')) {
          sink.writeln(raw);
        } else {
          sink.writeln(await _resolve(folder, line, directoryCache));
        }
      }
      await sink.close();
      sink = null;
      final items = await M3uParser.fetchAndParse(output.uri.toString(),
          playlistId: 'validation');
      if (items.isEmpty) throw const FormatException('empty playlist');
      return PreparedStorageImport(output, items.length,
          sourceLinks: sourceLinks.toList());
    } catch (_) {
      await sink?.close();
      if (await output.exists()) await output.delete();
      rethrow;
    } finally {
      if (await scratch.exists()) await scratch.delete();
    }
  }

  /// Plain manifest links, JSON lists, Stremio exports, or source definitions
  /// embedded as JSON strings inside a VesperTV backup. Never log their URLs.
  static List<String> sourceLinksIn(String text) {
    final links = <String>{};
    void visit(Object? value, int depth) {
      if (depth > 8) return;
      if (value is String) {
        links.addAll(AddonImporter.linksIn(value.replaceAll(r'\/', '/')));
        final trimmed = value.trim();
        if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
          try {
            visit(jsonDecode(trimmed), depth + 1);
          } on FormatException {/* Plain source list. */}
        }
      } else if (value is List) {
        for (final item in value) {
          visit(item, depth + 1);
        }
      } else if (value is Map) {
        for (final item in value.values) {
          visit(item, depth + 1);
        }
      }
    }

    visit(text, 0);
    return links.toList();
  }

  Future<List<String>> readSourceLinks(StorageItem item) async {
    final dir = await _directory();
    final scratch = File(
        p.join(dir.path, '${DateTime.now().microsecondsSinceEpoch}.sources'));
    try {
      if (item.uri.scheme == 'content') {
        await _channel.invokeMethod('copyImportFile',
            {'uri': item.uri.toString(), 'target': scratch.path});
      } else {
        await File.fromUri(item.uri).copy(scratch.path);
      }
      // Config files only: avoid accidentally decoding a huge binary file.
      if (await scratch.length() > 16 * 1024 * 1024) {
        throw const FormatException('source configuration too large');
      }
      return sourceLinksIn(await scratch.readAsString());
    } finally {
      if (await scratch.exists()) await scratch.delete();
    }
  }
}
