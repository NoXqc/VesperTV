import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/addon_service.dart';
import 'package:nox_iptv/services/archive_cache.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/hub_remote.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/vesper_ai/mcp_bridge.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Cache extends ArchiveCache {
  @override
  Future<void> deleteSource(String key) async {}
  @override
  Future<void> clear() async {}
}

/// Settings > Media Hub sources > Manage from phone (owner, 2026-11-11):
/// the relay's /hub page sends `hub/...` through the Vesper link.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const streams = ArchiveSource(
    manifestUrl: 'https://torrentio.example/key=secret/manifest.json',
    name: 'Torrentio',
    description: 'Torrent streams.',
    logoUrl: 'https://torrentio.example/logo.png',
    version: '0.0.15',
    catalogProviderUrl: ArchiveCatalogProvider.baseUrl,
    catalogs: [
      ArchiveCatalog(type: ArchiveType.movie, id: 'top', name: 'Popular'),
    ],
  );
  const lists = ArchiveSource(
    manifestUrl: 'https://catalogs.example/manifest.json',
    name: 'Streaming Catalogs',
    listOnly: true,
    catalogs: [
      ArchiveCatalog(type: ArchiveType.movie, id: 'nfx', name: 'Netflix'),
      ArchiveCatalog(type: ArchiveType.series, id: 'nfx-s', name: 'Netflix'),
    ],
  );

  late ArchiveService archive;
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyArchiveSources:
          jsonEncode([streams.toJson(), lists.toJson()]),
    });
    storage = StorageService();
    await storage.init();
    archive = ArchiveService(storage, cache: _Cache());
    HubRemote.instance.attach(archive, storage);
  });

  tearDown(() => archive.dispose());

  Future<Map<String, Object?>> call(String method,
      [Map<String, Object?> params = const {}]) async {
    final reply = await HubRemote.instance.handle(method, params);
    if (reply['error'] != null) {
      return {'error': (reply['error'] as Map)['message']};
    }
    return (reply['result'] as Map).cast<String, Object?>();
  }

  List<Map> sourcesOf(Map<String, Object?> result) =>
      (result['sources'] as List).cast<Map>();

  test('the list: sources, Cinemeta and subtitle add-ons, never a link',
      () async {
    final list = sourcesOf(await call('hub/list'));
    expect(list.map((s) => s['name']),
        ['Torrentio', 'Streaming Catalogs', 'Cinemeta', 'OpenSubtitles v3']);
    final t = list.first;
    expect(t['kind'], 'streams');
    expect(t['tags'], ['streams', 'movies']);
    expect(t['version'], '0.0.15');
    expect(t['logo'], 'https://torrentio.example/logo.png');
    expect(t['cinemeta'], true);
    expect(t['other'], false);
    expect(jsonEncode(list), isNot(contains('secret')),
        reason: 'a debrid key in the link only travels on hub/url');
    expect(list[1]['kind'], 'catalogs');
    expect(list[1]['tags'], ['catalogs', 'movies', 'shows']);
    expect(list[2]['removable'], false);
    expect(list[3]['kind'], 'subtitles');
    expect(list[3]['removable'], false, reason: 'the built-in OpenSubtitles');
  });

  test('switches: enabled, Other, Cinemeta and a subtitle add-on', () async {
    final keys = [for (final s in sourcesOf(await call('hub/list'))) s['key']];
    await call('hub/set', {'key': keys[0], 'field': 'enabled', 'value': false});
    expect(archive.sources.first.enabled, isFalse);
    await call('hub/set', {'key': keys[0], 'field': 'other', 'value': true});
    expect(archive.sources.first.underOther, isTrue);
    expect((await call('hub/set', {'key': keys[0], 'field': 'tv', 'value': true}))['error'],
        isNotNull, reason: 'a stream-only add-on has no TV add-on switch');
    await call('hub/set', {'key': 'cinemeta', 'field': 'enabled', 'value': false});
    expect(archive.showCinemetaCatalog, isFalse);
    await call('hub/set', {'key': keys[3], 'field': 'enabled', 'value': true});
    expect(AddonService(storage).addons.first.enabled, isTrue);
  });

  test('copy a link, remove a source, built-ins stay', () async {
    final keys = [for (final s in sourcesOf(await call('hub/list'))) s['key']];
    expect((await call('hub/url', {'key': keys[0]}))['url'],
        streams.manifestUrl);
    final after = sourcesOf(await call('hub/remove', {'key': keys[1]}));
    expect(after.map((s) => s['name']), isNot(contains('Streaming Catalogs')));
    expect(archive.sources.map((s) => s.name), ['Torrentio']);
    expect((await call('hub/remove', {'key': 'cinemeta'}))['error'],
        contains('built in'));
    expect((await call('hub/add', {'links': 'no link here'}))['error'],
        isNotNull);
  });

  test('the Vesper link answers hub/ even with AI apps off', () async {
    final reply = await McpBridge.instance
        .handle({'jsonrpc': '2.0', 'id': 1, 'method': 'hub/list'});
    expect(reply['error'], isNull);
    expect(((reply['result'] as Map)['sources'] as List), hasLength(4));
    final refused = await McpBridge.instance
        .handle({'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'});
    expect(refused['error'], isNotNull,
        reason: 'AI apps are off: the tools stay closed');
  });
}
