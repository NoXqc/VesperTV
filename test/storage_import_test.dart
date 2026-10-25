import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/local_playlist_files.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/m3u_parser.dart';
import 'package:nox_iptv/services/storage_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late StorageImportService importer;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('vesper_import_test_');
    importer = StorageImportService(destination: temp);
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test('imports a local M3U with remote and relative file references',
      () async {
    final source = await Directory('${temp.path}/USB').create();
    final video = await File('${source.path}/Movie with spaces.mp4')
        .writeAsString('fixture');
    final m3u = await File('${source.path}/channels.m3u').writeAsString(
        '#EXTM3U\n#EXTINF:-1 tvg-id="one" group-title="Live",Station\nhttps://example.com/live?token=example\n'
        '#EXTINF:-1 tvg-id="xt_vod_local_one" group-title="Movies",Local movie\nMovie with spaces.mp4\n');
    final prepared = await importer.preparePlaylist(
        StorageItem(uri: m3u.uri, name: 'channels.m3u'),
        StorageItem(uri: source.uri, name: 'USB', folder: true));
    expect(prepared.count, 2);
    final channels = await M3uParser.fetchAndParse(prepared.file.uri.toString(),
        playlistId: 'saved');
    expect(channels.first.url, 'https://example.com/live?token=example');
    expect(Uri.parse(channels.last.url), video.uri);
    expect(channels.last.id, 'saved::xt_vod_local_one');
    expect(Channel.isLiveId(channels.last.rawId), isFalse);
    expect(await video.readAsString(), 'fixture');
    expect(prepared.file.path, isNot(m3u.path));
  });

  test('invalid or HLS-only input leaves no private playlist or scratch file',
      () async {
    final folder = StorageItem(uri: temp.uri, name: 'USB', folder: true);
    for (final content in [
      'not a playlist',
      '#EXTM3U\n#EXT-X-TARGETDURATION:8\nsegment.ts'
    ]) {
      final input = await File('${temp.path}/bad.m3u').writeAsString(content);
      await expectLater(
          importer.preparePlaylist(
              StorageItem(uri: input.uri, name: 'bad.m3u'), folder),
          throwsFormatException);
      expect(await Directory('${temp.path}/imported_playlists').list().toList(),
          isEmpty);
      expect(await input.readAsString(), content);
    }
  });

  test('folder lists only playlists/source definitions and folders', () async {
    await Directory('${temp.path}/Movies').create();
    await File('${temp.path}/list.M3U8').writeAsString('');
    await File('${temp.path}/sources.JSON').writeAsString('');
    await File('${temp.path}/notes.txt').writeAsString('');
    final entries = await importer
        .children(StorageItem(uri: temp.uri, name: 'USB', folder: true));
    expect(entries.map((e) => e.name),
        ['Movies', 'list.M3U8', 'notes.txt', 'sources.JSON']);
  });

  test(
      'source definitions support plain links and nested backup JSON without duplicates',
      () async {
    const link = 'https://example.com/config/manifest.json';
    expect(StorageImportService.sourceLinksIn('$link\n$link'), [link]);
    final source = jsonEncode([
      {'manifestUrl': link}
    ]);
    final backup = jsonEncode({
      'data': {'vesper_archive_sources': source}
    });
    expect(StorageImportService.sourceLinksIn(backup), [link]);
    final file = await File('${temp.path}/sources.json').writeAsString(backup);
    expect(
        await importer
            .readSourceLinks(StorageItem(uri: file.uri, name: 'sources.json')),
        [link]);
    expect(await file.readAsString(), backup);
    expect(await Directory('${temp.path}/imported_playlists').list().toList(),
        isEmpty);
  });

  test('M3U comments can carry included Media Hub source links', () async {
    final file = await File('${temp.path}/combined.m3u').writeAsString(
        '#EXTM3U\n# Media Hub: https://example.com/addon/manifest.json\n#EXTINF:-1,Station\nhttps://example.com/live\n');
    final result = await importer.preparePlaylist(
        StorageItem(uri: file.uri, name: 'combined.m3u'),
        StorageItem(uri: temp.uri, name: 'USB', folder: true));
    expect(result.count, 1);
    expect(result.sourceLinks, ['https://example.com/addon/manifest.json']);
  });

  test('removing an imported snapshot never deletes its external original',
      () async {
    final source = await File('${temp.path}/external.m3u').writeAsString(
        '#EXTM3U\n#EXTINF:-1,Station\nhttps://example.com/live\n');
    final imported = await importer.preparePlaylist(
        StorageItem(uri: source.uri, name: 'external.m3u'),
        StorageItem(uri: temp.uri, name: 'USB', folder: true));
    await importer.deleteOwnedPlaylist(source.uri.toString());
    expect(await source.exists(), isTrue);
    await importer.deleteOwnedPlaylist(imported.file.uri.toString());
    expect(await imported.file.exists(), isFalse);
    expect(await source.exists(), isTrue);
  });

  for (final transfer in [false, true]) {
    test(
        'imported M3U survives ${transfer ? 'transfer' : 'backup restore'} with a new private path',
        () async {
      final from = await Directory('${temp.path}/from/imported_playlists')
          .create(recursive: true);
      final original = await File('${from.path}/1.m3u').writeAsString(
          '#EXTM3U\n#EXTINF:-1,Station\nhttps://example.com/live\n');
      SharedPreferences.setMockInitialValues({});
      final sender = StorageService(
          localPlaylists: LocalPlaylistFiles(destination: from.parent));
      await sender.init();
      await sender.setPlaylists([
        PlaylistProfile(
            id: 'one',
            name: 'USB',
            mode: 'm3u',
            m3uUrl: original.uri.toString(),
            sortOrder: 0,
            createdAt: DateTime(2026))
      ]);
      final payload = await sender.withProfilePhotos(
          transfer ? sender.exportForTransfer() : sender.exportForBackup());
      expect(payload.containsKey('vesper_imported_playlists'), isTrue);
      SharedPreferences.setMockInitialValues({});
      final recipient = StorageService(
          localPlaylists:
              LocalPlaylistFiles(destination: Directory('${temp.path}/to')));
      await recipient.init();
      if (transfer) {
        await recipient.importForTransfer(payload);
      } else {
        await recipient.importForBackup(payload);
      }
      final profile = recipient.getPlaylists().single;
      expect(profile.id, 'one');
      expect(profile.m3uUrl, isNot(original.uri.toString()));
      expect(
          (await M3uParser.fetchAndParse(profile.m3uUrl!,
                  playlistId: profile.id))
              .single
              .url,
          'https://example.com/live');
      expect(await original.exists(), isTrue);
    });
  }

  test('Android folder-granted URIs resolve nested local M3U references',
      () async {
    const channel = MethodChannel('com.nox.nox_iptv/storage_import');
    final root = StorageItem(
        uri: Uri(scheme: 'content', host: 'documents', path: '/tree/USB'),
        name: 'USB',
        folder: true);
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'copyImportFile') {
        final args = call.arguments as Map;
        await File(args['target'] as String)
            .writeAsString('#EXTM3U\n#EXTINF:-1,Movie\nMovies/Test.mp4\n');
        return args['target'];
      }
      if (call.method == 'children') {
        final uri = (call.arguments as Map)['uri'];
        return uri == root.uri.toString()
            ? [
                {
                  'uri': 'content://documents/tree/USB/document/folder1',
                  'name': 'Movies',
                  'folder': true
                }
              ]
            : [
                {
                  'uri': 'content://documents/tree/USB/document/video1',
                  'name': 'Test.mp4',
                  'folder': false
                }
              ];
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final result = await importer.preparePlaylist(
        StorageItem(
            uri: Uri.parse('content://documents/tree/USB/document/playlist'),
            name: 'list.m3u'),
        root);
    final items = await M3uParser.fetchAndParse(result.file.uri.toString(),
        playlistId: 'one');
    expect(items.single.url, 'content://documents/tree/USB/document/video1');
    expect(calls, ['copyImportFile', 'children', 'children']);
  });
}
