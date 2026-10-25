import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/playlist_profile.dart';

/// Private M3U snapshots travel with backups/transfers, unlike catalog caches.
class LocalPlaylistFiles {
  LocalPlaylistFiles({this.destination});
  final Directory? destination;
  Future<Directory> get directory async => Directory(p.join(
      (destination ?? await getApplicationSupportDirectory()).path,
      'imported_playlists'));

  Future<File?> owned(String? url) async {
    final uri = Uri.tryParse(url ?? '');
    if (uri?.scheme != 'file') return null;
    final dir = p.normalize(p.absolute((await directory).path));
    final file = File.fromUri(uri!);
    if (!p.isWithin(dir, p.normalize(p.absolute(file.path))) ||
        !await file.exists()) {
      return null;
    }
    if (!p.isWithin(dir, await file.resolveSymbolicLinks())) return null;
    return file;
  }

  Future<void> delete(String? url) async => (await owned(url))?.delete();

  Future<Map<String, String>> export(List<PlaylistProfile> profiles) async {
    final result = <String, String>{};
    for (final profile in profiles) {
      final file = await owned(profile.m3uUrl);
      if (file != null) {
        result[profile.id] = await file
            .openRead()
            .transform(gzip.encoder)
            .transform(base64.encoder)
            .join();
      }
    }
    return result;
  }

  Future<List<PlaylistProfile>> restore(
      List<PlaylistProfile> profiles, Map data) async {
    final result = <PlaylistProfile>[];
    for (final profile in profiles) {
      final encoded = data[profile.id];
      if (encoded is! String) {
        result.add(profile);
        continue;
      }
      final dir = await (await directory).create(recursive: true);
      final output = File(
          p.join(dir.path, '${DateTime.now().microsecondsSinceEpoch}.m3u'));
      final compressed = base64.decode(encoded);
      Stream<List<int>> chunks() async* {
        for (var i = 0; i < compressed.length; i += 65536) {
          yield compressed.sublist(i, math.min(i + 65536, compressed.length));
        }
      }

      final sink = output.openWrite();
      var size = 0;
      try {
        await for (final chunk in chunks().transform(gzip.decoder)) {
          size += chunk.length;
          if (size > 256 * 1024 * 1024) {
            throw const FormatException('playlist snapshot too large');
          }
          sink.add(chunk);
        }
        await sink.close();
      } catch (_) {
        await sink.close();
        if (await output.exists()) await output.delete();
        rethrow;
      }
      result.add(profile.copyWith(m3uUrl: output.uri.toString()));
    }
    return result;
  }
}
